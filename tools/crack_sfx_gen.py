"""Własne dźwięki minigry rozbijania (T06 v2).

Uruchom z katalogu repo:  python tools/crack_sfx_gen.py
Wynik: art/audio/crack/*.wav (48 kHz, 16 bit PCM, mono, pik -1 dBFS). Deterministycznie (SEED).

- crack_spawn   — krótki kryształowy „szept” przy pojawieniu punktu,
- hit_perfect   — jasny kryształowy ding z migotaniem (wysokość rośnie z serią przez PlaybackSpeed),
- hit_good      — stuk kilofa w skałę + mały dzwoneczek,
- hit_miss      — głuchy stuk i puf pyłu,
- hit_weak      — akord dzwonków (słaby punkt),
- hit_crit      — chrupnięcie z basowym uderzeniem (krytyk),
- round_perfect — krótka fanfara-arpeggio (cała runda Perfect),
- round_end     — miękki szum zamknięcia rundy.
Głośności w grze: Shared/Config/SoundIds.luau.
"""

from __future__ import annotations

import sys
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sfx_gen import bell, decay, fft_filter, mix_at, tt  # noqa: E402

SR = 48_000
SEED = 606
PEAK_DBFS = -1.0
OUT_DIR = Path(__file__).resolve().parent.parent / "art" / "audio" / "crack"


def norm(x: np.ndarray) -> np.ndarray:
    x = x - np.mean(x)
    peak = np.max(np.abs(x)) or 1.0
    return x / peak * 10 ** (PEAK_DBFS / 20)


def fade_out(x: np.ndarray, seconds: float = 0.02) -> np.ndarray:
    n = min(len(x), int(seconds * SR))
    x[-n:] *= np.linspace(1, 0, n)
    return x


def shimmer(rng: np.random.Generator, dur: float, base: float, count: int) -> np.ndarray:
    """Migotanie: krótkie wysokie sinusy rozsypane w czasie (kryształki)."""
    out = np.zeros(int(dur * SR))
    for _ in range(count):
        f = base * rng.uniform(1.0, 2.2)
        d = rng.uniform(0.05, 0.18)
        t = tt(d)
        s = np.sin(2 * np.pi * f * t) * decay(d, d / 3, 0.001)
        mix_at(out, s, rng.uniform(0, dur * 0.7), rng.uniform(0.15, 0.5))
    return out


def thump(freq: float, dur: float, drop: float = 0.5) -> np.ndarray:
    """Uderzenie basowe z opadającą częstotliwością."""
    t = tt(dur)
    f = freq * (1 - drop * (1 - np.exp(-t / 0.04)))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * decay(dur, dur / 4, 0.001)


def noise_hit(rng: np.random.Generator, dur: float, lo: float, hi: float, tau: float) -> np.ndarray:
    return fft_filter(rng.standard_normal(int(dur * SR)), lo=lo, hi=hi) * decay(dur, tau, 0.0008)


def crack_spawn(rng: np.random.Generator) -> np.ndarray:
    dur = 0.35
    t = tt(dur)
    f = 1800 + 1400 * t / dur
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) * np.sin(np.pi * t / dur) ** 2 * 0.35
    air = fft_filter(rng.standard_normal(len(t)), lo=4000, hi=11000) * np.sin(np.pi * t / dur) ** 2 * 0.25
    return tone + air + shimmer(rng, dur, 3200, 5) * 0.4


def hit_perfect(rng: np.random.Generator) -> np.ndarray:
    dur = 0.9
    out = np.zeros(int(dur * SR))
    mix_at(out, bell(1568, dur, 0.35), 0, 0.8)  # G6
    mix_at(out, bell(2349, dur * 0.7, 0.22), 0.0, 0.4)  # D7 — kwinta
    mix_at(out, noise_hit(rng, 0.05, 3000, 12000, 0.008), 0, 0.6)  # klik kryształu
    mix_at(out, shimmer(rng, 0.6, 4200, 14), 0.02, 0.5)
    mix_at(out, thump(140, 0.15, 0.4), 0, 0.35)
    return fade_out(out)


def hit_good(rng: np.random.Generator) -> np.ndarray:
    dur = 0.5
    out = np.zeros(int(dur * SR))
    mix_at(out, noise_hit(rng, 0.12, 600, 4000, 0.02), 0, 1.0)  # stuk w skałę
    mix_at(out, thump(220, 0.18, 0.5), 0, 0.6)
    mix_at(out, bell(1175, 0.4, 0.15), 0.005, 0.35)  # D6
    for _ in range(5):  # okruchy
        mix_at(out, noise_hit(rng, 0.03, 2000, 7000, 0.006), rng.uniform(0.03, 0.2), rng.uniform(0.1, 0.3))
    return fade_out(out)


def hit_miss(rng: np.random.Generator) -> np.ndarray:
    dur = 0.45
    out = np.zeros(int(dur * SR))
    mix_at(out, thump(110, 0.2, 0.6), 0, 0.8)
    mix_at(out, noise_hit(rng, 0.08, 200, 1200, 0.02), 0, 0.7)
    puff = fft_filter(rng.standard_normal(int(0.35 * SR)), lo=500, hi=2500)
    puff *= np.sin(np.pi * tt(0.35) / 0.35) ** 2
    mix_at(out, puff, 0.04, 0.25)
    return fade_out(out)


def hit_weak(rng: np.random.Generator) -> np.ndarray:
    dur = 1.4
    out = np.zeros(int(dur * SR))
    for i, f in enumerate((1047, 1319, 1568, 2093)):  # C6 E6 G6 C7 — akord rozbity
        mix_at(out, bell(f, 1.1, 0.4), i * 0.035, 0.5)
    mix_at(out, noise_hit(rng, 0.06, 2500, 12000, 0.01), 0, 0.7)
    mix_at(out, shimmer(rng, 1.0, 3500, 30), 0.05, 0.55)
    mix_at(out, thump(90, 0.3, 0.5), 0, 0.5)
    return fade_out(out)


def hit_crit(rng: np.random.Generator) -> np.ndarray:
    dur = 1.0
    out = np.zeros(int(dur * SR))
    mix_at(out, thump(70, 0.6, 0.55), 0, 1.0)  # bas
    mix_at(out, noise_hit(rng, 0.25, 300, 6000, 0.05), 0, 0.9)  # chrupnięcie
    for _ in range(18):  # pękające kryształy
        mix_at(out, noise_hit(rng, 0.04, 2500, 9000, 0.007), rng.uniform(0, 0.25), rng.uniform(0.2, 0.6))
    mix_at(out, bell(784, 0.8, 0.3), 0.01, 0.35)  # G5
    mix_at(out, shimmer(rng, 0.7, 2600, 16), 0.05, 0.4)
    return fade_out(out)


def round_perfect(rng: np.random.Generator) -> np.ndarray:
    dur = 1.3
    out = np.zeros(int(dur * SR))
    for i, f in enumerate((1047, 1319, 1568, 2093, 2637)):  # C6 E6 G6 C7 E7
        mix_at(out, bell(f, 0.9, 0.3), i * 0.07, 0.45)
    mix_at(out, shimmer(rng, 1.0, 4000, 26), 0.25, 0.45)
    return fade_out(out)


def round_end(rng: np.random.Generator) -> np.ndarray:
    dur = 0.5
    t = tt(dur)
    whoosh = fft_filter(rng.standard_normal(len(t)), lo=800, hi=5000) * np.sin(np.pi * t / dur) ** 3
    return whoosh * 0.5 + bell(880, dur, 0.12) * 0.15


SOUNDS = {
    "crack_spawn": crack_spawn,
    "hit_perfect": hit_perfect,
    "hit_good": hit_good,
    "hit_miss": hit_miss,
    "hit_weak": hit_weak,
    "hit_crit": hit_crit,
    "round_perfect": round_perfect,
    "round_end": round_end,
}


def write_wav(path: Path, x: np.ndarray) -> None:
    pcm = (np.clip(x, -1, 1) * 32767).round().astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, fn in SOUNDS.items():
        rng = np.random.default_rng([SEED, sum(map(ord, name))])
        x = norm(fn(rng))
        write_wav(OUT_DIR / f"{name}.wav", x)
        print(f"  {name}.wav {len(x) / SR:.2f}s")


if __name__ == "__main__":
    main()
