"""Synteza własnych dźwięków spadku gwiazdy (T38).

Uruchom z katalogu repo:  python tools/sfx_gen.py
Wynik: art/audio/stars/*.wav (48 kHz, 16 bit PCM, mono, pik -1 dBFS).

- Wszystko liczone z numpy, deterministycznie (SEED) — ten sam wynik przy każdym uruchomieniu.
- Pętle (`*_loop`, `star_hum`, `crater_sizzle`) mają przenikanie końca w początek — grają bez szwu.
- Wzór narzędzi: E:\\CarImportEmpire\\tools\\sfx_gen.py (T50). Głośności w grze: Shared/Config/SoundIds.luau.
"""

from __future__ import annotations

import wave
from pathlib import Path
from typing import Callable

import numpy as np

SR = 48_000
SEED = 38
PEAK_DBFS = -1.0
LOOP_XFADE = 0.35  # s przenikania końca pętli w jej początek
OUT_DIR = Path(__file__).resolve().parent.parent / "art" / "audio" / "stars"


# ---------------------------------------------------------------- narzędzia


def db(x: float) -> float:
    return 10 ** (x / 20)


def tt(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def decay(dur: float, tau: float, attack: float = 0.002) -> np.ndarray:
    t = tt(dur)
    env = np.exp(-t / tau)
    a = max(1, int(attack * SR))
    env[:a] *= np.linspace(0, 1, a)
    return env


def fft_filter(x: np.ndarray, lo: float | None = None, hi: float | None = None, order: int = 2) -> np.ndarray:
    """Filtr pasmowy Butterwortha (tylko moduł) w dziedzinie częstotliwości."""
    n = len(x)
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1e-3
    mask = np.ones_like(f)
    if hi is not None:
        mask /= np.sqrt(1 + (f / hi) ** (2 * order))
    if lo is not None:
        mask /= np.sqrt(1 + (lo / f) ** (2 * order))
    return np.fft.irfft(spec * mask, n)


def sweep_lowpass(x: np.ndarray, cutoff: np.ndarray) -> np.ndarray:
    """Dwubiegunowy lowpass ze zmienną częstotliwością odcięcia."""
    a = 1 - np.exp(-2 * np.pi * np.asarray(cutoff) / SR)
    y = np.empty_like(x)
    s1 = s2 = 0.0
    for i in range(len(x)):
        s1 += a[i] * (x[i] - s1)
        s2 += a[i] * (s1 - s2)
        y[i] = s2
    return y


def osc_phase(freq: np.ndarray | float, n: int) -> np.ndarray:
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    return 2 * np.pi * np.cumsum(f) / SR


def saw(freq: np.ndarray | float, n: int, harmonics: int = 14) -> np.ndarray:
    ph = osc_phase(freq, n)
    return sum(np.sin(k * ph) / k for k in range(1, harmonics + 1)) * (2 / np.pi)


def mix_at(buf: np.ndarray, sig: np.ndarray, start: float, gain: float = 1.0) -> None:
    i = int(start * SR)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i] * gain


def smooth_noise(rng: np.random.Generator, n: int, rate: float) -> np.ndarray:
    """Wolnozmienny szum 0..1 (np. migotanie płomienia, LFO bez okresu)."""
    points = rng.random(int(n / SR * rate) + 3)
    xs = np.linspace(0, len(points) - 1, n)
    return np.interp(xs, np.arange(len(points)), points)


def bell(freq: float, dur: float, tau: float) -> np.ndarray:
    t = tt(dur)
    partials = ((1.0, 1.0), (2.76, 0.5), (5.4, 0.25), (8.93, 0.12))
    return sum(a * np.sin(2 * np.pi * freq * r * t) * np.exp(-t / (tau / r**0.4)) for r, a in partials)


def crackles(rng: np.random.Generator, dur: float, count: int, lo: float = 1500, hi: float = 9000) -> np.ndarray:
    """Trzaski elektryczne/ogniowe: krótkie impulsy filtrowanego szumu w losowych miejscach."""
    out = np.zeros(int(dur * SR))
    for _ in range(count):
        d = rng.uniform(0.004, 0.03)
        f0 = rng.uniform(lo, hi)
        pop = fft_filter(rng.standard_normal(int(d * SR)), lo=f0 * 0.6, hi=f0 * 1.5) * decay(d, d / 5, 0.0003)
        mix_at(out, pop, rng.uniform(0, dur - d), rng.uniform(0.2, 1.0))
    return out


def rubble(rng: np.random.Generator, dur: float, count: int, heavy: float = 0.25) -> np.ndarray:
    """Grzechot odłamków skał: setki krótkich uderzeń, gęstsze na początku."""
    out = np.zeros(int(dur * SR))
    for _ in range(count):
        start = dur * rng.random() ** 1.7 * 0.92
        d = rng.uniform(0.04, 0.25)
        f0 = rng.uniform(200, 2600)
        hit = fft_filter(rng.standard_normal(int(d * SR)), lo=f0 * 0.5, hi=f0 * 1.6) * decay(d, d / 4, 0.001)
        if rng.random() < heavy:
            hit += np.sin(2 * np.pi * rng.uniform(55, 130) * tt(d)) * decay(d, d / 3) * 0.9
        mix_at(out, hit, start, rng.uniform(0.2, 1.0) * np.exp(-start / (dur * 0.5)))
    return out


def make_loop(x: np.ndarray, fade: float = LOOP_XFADE) -> np.ndarray:
    """Przenika ostatnie `fade` s w początek — pętla bez kliknięcia."""
    c = int(fade * SR)
    body = x[:-c].copy()
    ramp = np.linspace(0, 1, c)
    body[:c] = body[:c] * np.sqrt(ramp) + x[-c:] * np.sqrt(1 - ramp)
    return body


def soft_clip(x: np.ndarray, drive: float = 1.8) -> np.ndarray:
    return np.tanh(drive * x / (np.max(np.abs(x)) + 1e-12))


# ------------------------------------------------------------------ dźwięki


def announce_sting(rng: np.random.Generator) -> np.ndarray:
    """Alarm: niski „róg” otwierający filtr, uderzenie i migocący dzwonek na górze."""
    dur = 2.6
    t = tt(dur)
    n = len(t)
    horn = sum(saw(f * (1 + rng.uniform(-0.004, 0.004)), n) for f in (55.0, 82.4, 110.0, 164.8))
    cutoff = 180 + 2600 * np.clip(t / 0.9, 0, 1) ** 2 * np.exp(-np.clip(t - 0.9, 0, None) / 0.7)
    horn = sweep_lowpass(horn, cutoff) * np.minimum(1, t / 0.5) * np.exp(-np.clip(t - 1.1, 0, None) / 0.6)
    hit = np.sin(osc_phase(45 + 90 * np.exp(-t / 0.08), n)) * decay(dur, 0.5, 0.002)
    out = horn * 0.8
    mix_at(out, hit, 0.85, 0.9)
    for i, f in enumerate((1318.5, 1975.5, 2637.0)):
        mix_at(out, bell(f, 1.6, 0.6), 0.9 + i * 0.07, 0.18)
    riser = fft_filter(rng.standard_normal(n), lo=2000, hi=9000) * np.clip(t / 0.85, 0, 1) ** 3 * (t < 0.9)
    return out + riser * 0.25


def countdown_tick(rng: np.random.Generator) -> np.ndarray:
    dur = 0.3
    t = tt(dur)
    click = np.sin(2 * np.pi * 1760 * t) * decay(dur, 0.03, 0.0005) + 0.5 * np.sin(2 * np.pi * 3520 * t) * decay(dur, 0.015)
    thump = np.sin(osc_phase(90 + 60 * np.exp(-t / 0.02), len(t))) * decay(dur, 0.06)
    return click * 0.7 + thump


def thunder_far(rng: np.random.Generator) -> np.ndarray:
    """Daleki grzmot (cała mapa): toczące się, stłumione dudnienie."""
    dur = 6.5
    t = tt(dur)
    n = len(t)
    out = np.zeros(n)
    for i in range(6):
        start = 0.15 + i * rng.uniform(0.35, 0.8)
        d = rng.uniform(1.2, 2.5)
        burst = fft_filter(rng.standard_normal(int(d * SR)), hi=rng.uniform(140, 320), order=3)
        burst *= np.minimum(1, tt(d) / rng.uniform(0.05, 0.25)) * np.exp(-tt(d) / (d * 0.35))
        mix_at(out, burst, start, rng.uniform(0.5, 1.0))
    crack = fft_filter(rng.standard_normal(n), lo=600, hi=2500) * decay(dur, 0.25, 0.01) * 0.25
    return out * np.exp(-t / 3.0) + crack


def rift_open(rng: np.random.Generator) -> np.ndarray:
    """Rozdarcie nieba: trzask elektryczny, rwanie materii, odwrócone narastanie, sub-uderzenie, sypiące się szkło."""
    dur = 4.5
    t = tt(dur)
    n = len(t)
    out = np.zeros(n)
    zap = fft_filter(rng.standard_normal(int(0.35 * SR)), lo=1800) * decay(0.35, 0.05, 0.0005)
    zap += crackles(rng, 0.35, 40, 2500, 12000)
    mix_at(out, zap, 0.0, 1.0)
    # rwanie: szum pasmowy z ziarnistą modulacją (szarpnięcia)
    rip_d = 1.6
    grain = (smooth_noise(rng, int(rip_d * SR), 60) > 0.45).astype(float)
    rip = fft_filter(rng.standard_normal(int(rip_d * SR)), lo=300, hi=4500) * (0.3 + grain)
    rip *= np.minimum(1, tt(rip_d) / 0.05) * np.exp(-tt(rip_d) / 0.9)
    mix_at(out, rip, 0.08, 0.8)
    swell_d = 0.9
    swell = fft_filter(rng.standard_normal(int(swell_d * SR)), lo=60, hi=900) * np.linspace(0, 1, int(swell_d * SR)) ** 3
    mix_at(out, swell, 0.0, 0.6)
    boom_t = tt(3.6)
    boom = np.sin(osc_phase(30 + 55 * np.exp(-boom_t / 0.25), len(boom_t))) * np.exp(-boom_t / 1.2)
    boom += fft_filter(rng.standard_normal(len(boom_t)), hi=110, order=3) * np.exp(-boom_t / 1.0) * 5
    mix_at(out, boom, 0.85, 1.0)
    for _ in range(26):  # odłamki nieba: szkliste dzwonienie
        mix_at(out, bell(rng.uniform(1800, 5200), 0.8, rng.uniform(0.08, 0.3)), rng.uniform(0.9, 2.4), rng.uniform(0.04, 0.12))
    mix_at(out, crackles(rng, 3.0, 120, 2000, 10000), 0.9, 0.35)
    return soft_clip(out, 1.6)


def rift_loop(rng: np.random.Generator) -> np.ndarray:
    """Pętla wyrwy: ciemny dron, wahający się wiatr i trzaski wyładowań."""
    dur = 6.0 + LOOP_XFADE
    t = tt(dur)
    n = len(t)
    drone = np.sin(2 * np.pi * 40 * t) + np.sin(2 * np.pi * 41.3 * t) + 0.6 * np.sin(2 * np.pi * 60.5 * t)
    growl = fft_filter(saw(55 + 3 * np.sin(2 * np.pi * 0.31 * t), n), hi=260, order=3)
    wind_cut = 400 + 1600 * smooth_noise(rng, n, 1.2)
    wind = sweep_lowpass(rng.standard_normal(n), wind_cut) * (0.5 + 0.5 * smooth_noise(rng, n, 0.8))
    zaps = crackles(rng, dur, 70, 2000, 11000) * (smooth_noise(rng, n, 3) > 0.55)
    x = drone * 0.35 + growl * 0.4 + wind * 1.4 + zaps * 0.6
    return make_loop(x)


def rift_close(rng: np.random.Generator) -> np.ndarray:
    """Zapadnięcie wyrwy: wsysanie (odwrócony szum), cięcie, sub-uderzenie, iskierki."""
    dur = 2.4
    t = tt(dur)
    n = len(t)
    suck_d = 1.2
    st = tt(suck_d)
    suck = sweep_lowpass(rng.standard_normal(len(st)), 200 + 5000 * (st / suck_d) ** 2) * (st / suck_d) ** 2.5
    out = np.zeros(n)
    mix_at(out, suck, 0.0, 1.2)
    thump = np.sin(osc_phase(40 + 70 * np.exp(-tt(1.2) / 0.06), int(1.2 * SR))) * decay(1.2, 0.35, 0.001)
    mix_at(out, thump, suck_d, 1.0)
    for i in range(5):
        mix_at(out, bell(2400 + i * 380, 0.9, 0.3), suck_d + 0.02 + i * 0.04, 0.08)
    return out


def emerge_roar(rng: np.random.Generator) -> np.ndarray:
    """Wylot gwiazdy z wyrwy: ryk ognia z niskim warczeniem."""
    dur = 2.2
    t = tt(dur)
    n = len(t)
    env = np.minimum(1, t / 0.12) * np.exp(-t / 0.9)
    roar = sweep_lowpass(rng.standard_normal(n), 300 + 3500 * np.exp(-t / 0.5)) * env
    growl = fft_filter(saw(48 + 20 * np.exp(-t / 0.4), n), hi=300) * env
    return roar * 1.5 + growl * 0.7 + crackles(rng, dur, 60, 1200, 6000) * env * 0.5


def fall_loop(rng: np.random.Generator) -> np.ndarray:
    """Pętla lotu: ryczący płomień z migotaniem i trzaskami (przypięta do gwiazdy, 3D)."""
    dur = 4.0 + LOOP_XFADE
    t = tt(dur)
    n = len(t)
    flicker = 0.55 + 0.45 * smooth_noise(rng, n, 18)
    body = fft_filter(rng.standard_normal(n), lo=40, hi=700, order=2) * flicker * 2.0
    hiss = fft_filter(rng.standard_normal(n), lo=1500, hi=6000) * (0.4 + 0.6 * smooth_noise(rng, n, 7)) * 0.3
    sub = np.sin(2 * np.pi * 38 * t) * 0.3
    return make_loop(body + hiss + sub + crackles(rng, dur, 140, 900, 5000) * 0.5)


def flyby(rng: np.random.Generator) -> np.ndarray:
    """Przelot obok: szum pasmowy ze spadającą częstotliwością (Doppler) i szczytem głośności w środku."""
    dur = 2.6
    t = tt(dur)
    n = len(t)
    centre = 1.1
    env = np.exp(-((t - centre) ** 2) / (2 * 0.32**2))
    cutoff = 600 + 4200 / (1 + np.exp((t - centre) * 6))
    whoosh = sweep_lowpass(rng.standard_normal(n), cutoff) * env * 2.2
    tone = np.sin(osc_phase(180 / (1 + 0.25 * np.tanh((t - centre) * 4)), n)) * env * 0.25
    return whoosh + tone


def sonic_boom(rng: np.random.Generator) -> np.ndarray:
    """Podwójny huk fali N (przód i tył), potem dudniący ogon."""
    dur = 2.0
    t = tt(dur)
    n = len(t)
    out = np.zeros(n)
    for start in (0.0, 0.11):
        d = 0.05
        st = tt(d)
        nwave = (1 - 2 * st / d) * (st < d)
        mix_at(out, fft_filter(np.concatenate([nwave, np.zeros(SR // 2)]), hi=900), start, 1.0)
    tail = fft_filter(rng.standard_normal(n), hi=180, order=3) * np.minimum(1, t / 0.05) * np.exp(-t / 0.6) * 4
    return soft_clip(out + tail, 1.4)


def impact(size: float) -> Callable[[np.random.Generator], np.ndarray]:
    """Uderzenie gwiazdy; size 0..1 (Small → Huge): niższy i dłuższy boom, więcej gruzu i chrzęstu."""

    def make(rng: np.random.Generator) -> np.ndarray:
        dur = 1.6 + 3.4 * size
        t = tt(dur)
        n = len(t)
        boom_f = (55 - 25 * size) + (110 - 40 * size) * np.exp(-t / (0.06 + 0.1 * size))
        boom = np.sin(osc_phase(boom_f, n)) * decay(dur, 0.35 + 0.9 * size, 0.002)
        body = fft_filter(rng.standard_normal(n), hi=300 + 200 * (1 - size), order=3) * decay(dur, 0.3 + 0.7 * size, 0.002) * 6
        crunch = fft_filter(rng.standard_normal(n), lo=900, hi=7000) * decay(dur, 0.04 + 0.05 * size, 0.0005)
        rumble = fft_filter(rng.standard_normal(n), hi=90, order=2) * np.exp(-t / (0.5 + 1.6 * size)) * (4 + 6 * size)
        out = boom + 0.8 * body + 0.6 * crunch + 0.5 * rumble
        mix_at(out, rubble(rng, dur * 0.8, int(40 + 160 * size)), 0.05, 0.45)
        for _ in range(int(4 + 14 * size)):  # krystaliczne odpryski gwiazdy
            mix_at(out, bell(rng.uniform(1500, 4800), 0.6, rng.uniform(0.05, 0.2)), rng.uniform(0.0, 0.4), 0.06)
        return soft_clip(out, 2.0 + size)

    return make


def shockwave(rng: np.random.Generator) -> np.ndarray:
    """Fala powietrza: ostry atak i opadający filtr (podmuch rozchodzący się od krateru)."""
    dur = 2.0
    t = tt(dur)
    cutoff = 200 + 5200 * np.exp(-t / 0.25)
    return sweep_lowpass(rng.standard_normal(len(t)), cutoff) * decay(dur, 0.55, 0.004) * 1.6


def debris_rain(rng: np.random.Generator) -> np.ndarray:
    dur = 3.4
    return rubble(rng, dur, 220, heavy=0.35) + fft_filter(rng.standard_normal(int(dur * SR)), lo=80, hi=1200) * decay(dur, 1.0, 0.1) * 0.3


def star_hum(rng: np.random.Generator) -> np.ndarray:
    """Pętla leżącej gwiazdy: krystaliczny akord z wolnym dudnieniem i migotaniem na górze."""
    dur = 6.0 + LOOP_XFADE
    t = tt(dur)
    n = len(t)
    chord = (110.0, 164.8, 220.0, 277.2, 329.6)
    pad = sum(np.sin(2 * np.pi * f * t) + 0.7 * np.sin(2 * np.pi * f * 1.003 * t + 1.0) for f in chord) / len(chord)
    pad *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.23 * t)
    shimmer = sum(np.sin(2 * np.pi * f * t) * smooth_noise(rng, n, 2.5) for f in (1318.5, 1760.0, 2217.5)) * 0.08
    fizz = fft_filter(rng.standard_normal(n), lo=4000, hi=11000) * smooth_noise(rng, n, 4) * 0.05
    return make_loop(pad + shimmer + fizz + crackles(rng, dur, 25, 3000, 10000) * 0.25)


def crater_sizzle(rng: np.random.Generator) -> np.ndarray:
    """Pętla krateru: skwierczenie żaru, ciche strzelanie i syk."""
    dur = 5.0 + LOOP_XFADE
    n = int(dur * SR)
    hiss = fft_filter(rng.standard_normal(n), lo=2500, hi=9000) * (0.3 + 0.7 * smooth_noise(rng, n, 5)) * 0.4
    pops = crackles(rng, dur, 160, 800, 6000)
    low = fft_filter(rng.standard_normal(n), lo=60, hi=300) * 0.3
    return make_loop(hiss + pops + low)


def star_crack(rng: np.random.Generator) -> np.ndarray:
    """Rozbicie gwiazdy: kryształowy trzask, boom, deszcz szklanych odłamków i opadające dzwonki."""
    dur = 3.2
    t = tt(dur)
    n = len(t)
    out = np.zeros(n)
    snap = fft_filter(rng.standard_normal(int(0.2 * SR)), lo=2500) * decay(0.2, 0.03, 0.0003)
    mix_at(out, snap, 0.0, 1.0)
    boom = np.sin(osc_phase(50 + 90 * np.exp(-t / 0.07), n)) * decay(dur, 0.5, 0.002)
    out += boom * 0.9
    for _ in range(60):
        mix_at(out, bell(rng.uniform(1200, 6000), 1.0, rng.uniform(0.05, 0.35)), rng.uniform(0.0, 1.4) ** 1.5, rng.uniform(0.05, 0.18))
    for i, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        mix_at(out, bell(f, 2.0, 0.9), 0.25 + i * 0.09, 0.22)
    return soft_clip(out, 1.5)


def star_fade(rng: np.random.Generator) -> np.ndarray:
    """Zgaśnięcie: dźwięk opada jak wyłączane zasilanie, gwiazda kruszy się i syczy."""
    dur = 3.0
    t = tt(dur)
    n = len(t)
    glide = 420 * np.exp(-t / 0.7) + 45
    tone = sweep_lowpass(saw(glide, n, 10), 300 + 3000 * np.exp(-t / 0.6)) * np.exp(-t / 1.4)
    crumble = rubble(rng, dur, 70, heavy=0.1) * 0.5
    hiss = fft_filter(rng.standard_normal(n), lo=3000) * np.exp(-t / 1.2) * 0.15
    return tone + crumble + hiss


SOUNDS: list[tuple[str, Callable[[np.random.Generator], np.ndarray]]] = [
    ("announce_sting", announce_sting),
    ("countdown_tick", countdown_tick),
    ("thunder_far", thunder_far),
    ("rift_open", rift_open),
    ("rift_loop", rift_loop),
    ("rift_close", rift_close),
    ("emerge_roar", emerge_roar),
    ("fall_loop", fall_loop),
    ("flyby", flyby),
    ("sonic_boom", sonic_boom),
    ("impact_s", impact(0.0)),
    ("impact_m", impact(0.33)),
    ("impact_l", impact(0.66)),
    ("impact_xl", impact(1.0)),
    ("shockwave", shockwave),
    ("debris_rain", debris_rain),
    ("star_hum", star_hum),
    ("crater_sizzle", crater_sizzle),
    ("star_crack", star_crack),
    ("star_fade", star_fade),
]


def write_wav(path: Path, x: np.ndarray) -> None:
    pcm = (np.clip(x, -1, 1) * 32767).round().astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"{'plik':<22}{'czas s':>8}{'pik dBFS':>10}{'RMS dBFS':>10}")
    for idx, (name, fn) in enumerate(SOUNDS):
        rng = np.random.default_rng([SEED, idx])
        x = fn(rng).astype(float)
        x = x - np.mean(x)
        x = x * (db(PEAK_DBFS) / (np.max(np.abs(x)) + 1e-12))
        write_wav(OUT_DIR / f"{name}.wav", x)
        rms = 20 * np.log10(np.sqrt(np.mean(x**2)) + 1e-12)
        print(f"{name + '.wav':<22}{len(x) / SR:>8.2f}{20 * np.log10(np.max(np.abs(x))):>10.2f}{rms:>10.1f}")
    print(f"Zapisano {len(SOUNDS)} plików w {OUT_DIR}")


if __name__ == "__main__":
    main()
