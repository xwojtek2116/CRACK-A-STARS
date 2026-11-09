"""Synteza muzyki w tle (T41): spokojny kosmiczny ambient na całą rozgrywkę.

Uruchom z katalogu repo:  python tools/music_gen.py
Wynik: art/audio/music/music_ambient.wav (48 kHz, 16 bit PCM, mono, pik -1 dBFS).

- Deterministycznie (SEED), narzędzia z tools/sfx_gen.py.
- Pętla idealna: wszystkie zdarzenia i pogłos liczone „po okręgu” (ogon za końcem wraca na początek),
  stałe tony i LFO mają częstotliwości będące wielokrotnością 1/LOOP — brak szwu przy zapętleniu.
- Pady D-dur (Dmaj9 → Bm9 → Gmaj9 → Asus), dron basu, rzadkie dzwoneczki pentatoniki, cichy „wiatr kosmosu”.
- Głośność w grze: Shared/Config/SoundIds.luau (musicAmbient).
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sfx_gen import SR, PEAK_DBFS, db, fft_filter, saw, write_wav  # noqa: E402

SEED = 41
LOOP = 96.0  # s
CHORD_LEN = LOOP / 4
CHORD_FADE = 7.0  # s przenikania akordów
OUT = Path(__file__).resolve().parent.parent / "art" / "audio" / "music" / "music_ambient.wav"

N = int(LOOP * SR)
T = np.arange(N) / SR

CHORDS = [
    [146.83, 220.00, 277.18, 329.63, 369.99],  # Dmaj9
    [123.47, 185.00, 220.00, 293.66, 329.63],  # Bm9 (bez prymy u góry)
    [98.00, 196.00, 246.94, 293.66, 369.99],  # Gmaj9
    [110.00, 164.81, 246.94, 293.66, 329.63],  # Asus2/4
]
BELLS = [587.33, 659.26, 739.99, 880.00, 987.77, 1174.66]  # pentatonika D


def loop_freq(f: float) -> float:
    """Zaokrągla częstotliwość do wielokrotności 1/LOOP (ciągła faza na styku pętli)."""
    return round(f * LOOP) / LOOP


def mix_wrap(out: np.ndarray, x: np.ndarray, start: float, gain: float = 1.0) -> None:
    idx = (int(start * SR) + np.arange(len(x))) % N
    np.add.at(out, idx, x * gain)


def fade_window(n: int, fade: float) -> np.ndarray:
    t = np.arange(n) / SR
    dur = n / SR
    w = np.ones(n)
    w = np.where(t < fade, 0.5 - 0.5 * np.cos(np.pi * t / fade), w)
    w = np.where(t > dur - fade, 0.5 - 0.5 * np.cos(np.pi * (dur - t) / fade), w)
    return w


def pads(rng: np.random.Generator) -> np.ndarray:
    out = np.zeros(N)
    seg = CHORD_LEN + CHORD_FADE
    n = int(seg * SR)
    t = np.arange(n) / SR
    for i, chord in enumerate(CHORDS):
        pad = np.zeros(n)
        for f in chord:
            breathe = 0.8 + 0.2 * np.sin(2 * np.pi * rng.uniform(0.05, 0.12) * t + rng.uniform(0, 6.3))
            voice = sum(saw(f * (1 + d), n, 6) for d in (-0.004, 0.0, 0.004)) / 3
            pad += (voice * 0.6 + np.sin(2 * np.pi * f * t) * 0.6) * breathe
        pad = fft_filter(pad / len(chord), hi=900, order=2)
        mix_wrap(out, pad * fade_window(n, CHORD_FADE), i * CHORD_LEN - CHORD_FADE / 2)
    return out


def drone() -> np.ndarray:
    lfo = 0.75 + 0.25 * np.sin(2 * np.pi * loop_freq(1 / 24) * T)
    d = np.sin(2 * np.pi * loop_freq(73.42) * T) + 0.35 * np.sin(2 * np.pi * loop_freq(110.0) * T)
    return d * lfo


def bell(f: float, dur: float = 6.0) -> np.ndarray:
    t = np.arange(int(dur * SR)) / SR
    att = np.minimum(1, t / 0.006)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / 1.9)
    x += 0.3 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t / 0.6)
    x += 0.12 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t / 0.25)
    return x * att


def bells(rng: np.random.Generator) -> np.ndarray:
    out = np.zeros(N)
    t = rng.uniform(1.0, 3.0)
    while t < LOOP - 1:
        f = BELLS[rng.integers(len(BELLS))]
        mix_wrap(out, bell(f), t, rng.uniform(0.12, 0.26))
        if rng.random() < 0.3:  # czasem echo kwintę niżej
            mix_wrap(out, bell(f * 2 / 3), t + rng.uniform(0.3, 0.6), 0.08)
        t += rng.uniform(3.0, 7.0)
    return out


def space_wind(rng: np.random.Generator) -> np.ndarray:
    noise = fft_filter(rng.standard_normal(N), lo=2500, hi=6000, order=2)
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * loop_freq(1 / 32) * T + 1.0)
    return noise * lfo / (np.std(noise) + 1e-12)


def reverb(x: np.ndarray, rng: np.random.Generator, decay: float = 1.6, length: float = 5.0) -> np.ndarray:
    """Pogłos splotem kołowym (FFT długości pętli) — ogon zawija się na początek."""
    m = int(length * SR)
    t = np.arange(m) / SR
    ir = rng.standard_normal(m) * np.exp(-t / decay)
    ir = fft_filter(ir, hi=4500)
    ir[: int(0.02 * SR)] *= np.linspace(0, 1, int(0.02 * SR))
    ir_full = np.zeros(N)
    ir_full[:m] = ir
    wet = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir_full), N)
    return wet / (np.std(wet) + 1e-12) * np.std(x)


def main() -> None:
    rng = np.random.default_rng(SEED)
    p = pads(rng)
    b = bells(rng)
    dry = p * 1.0 + drone() * 0.22 + b * 0.9 + space_wind(rng) * 0.012
    x = dry * 0.65 + reverb(p + b * 1.4, rng) * 0.55
    x = np.tanh(x * 1.1)
    x -= np.mean(x)
    x *= db(PEAK_DBFS) / (np.max(np.abs(x)) + 1e-12)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    write_wav(OUT, x)
    rms = 20 * np.log10(np.sqrt(np.mean(x**2)) + 1e-12)
    seam = abs(x[0] - x[-1])
    print(f"{OUT.name}: {LOOP:.0f} s, RMS {rms:.1f} dBFS, skok na styku {seam:.4f}, {OUT.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
