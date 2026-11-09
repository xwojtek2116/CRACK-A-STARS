"""Własne dźwięki narzędzi (T09).

Uruchom z katalogu repo:  python tools/tool_sfx_gen.py
Wynik: art/audio/tools/*.wav (48 kHz, 16 bit PCM, mono, pik -1 dBFS). Deterministycznie (SEED).

Zamachy (whoosh, 3D przy narzędziu — słyszą też inni gracze), po jednym na „materiał” narzędzia:
- swing_stone   — ciężki, niski szum powietrza (kamienny kilof),
- swing_metal   — szum + metaliczny dźwięczący ogon (młot),
- swing_crystal — szum + kryształowe dzwoneczki (topór, Comet Blade),
- swing_plasma  — warkot piły: brzęczący piłokształtny ton z vibrato,
- swing_laser   — klasyczny „vwoom” miecza świetlnego (opadający buczek),
- swing_gravity — głęboki basowy „wub” z dudnieniem (Gravity/Galaxy Hammer),
- swing_cannon  — wystrzał działa: huk + świst pocisku,
- swing_legend  — szum + chór dzwonów i iskry (Starbreaker).
UI / ekwipunek:
- tool_equip    — krótki metaliczny „szczęk” wyjęcia narzędzia (2D),
- tool_unlock   — fanfara odblokowania nowego narzędzia (2D, ekran „NEW TOOL!”).
Głośności w grze: Shared/Config/SoundIds.luau.
"""

from __future__ import annotations

import sys
import wave
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sfx_gen import bell, decay, fft_filter, mix_at, saw, tt  # noqa: E402

SR = 48_000
SEED = 909
PEAK_DBFS = -1.0
OUT_DIR = Path(__file__).resolve().parent.parent / "art" / "audio" / "tools"


def norm(x: np.ndarray) -> np.ndarray:
    x = x - np.mean(x)
    peak = np.max(np.abs(x)) or 1.0
    return x / peak * 10 ** (PEAK_DBFS / 20)


def fade(x: np.ndarray, fin: float = 0.004, fout: float = 0.03) -> np.ndarray:
    a, b = int(fin * SR), int(fout * SR)
    x[:a] *= np.linspace(0, 1, a)
    x[-b:] *= np.linspace(1, 0, b)
    return x


def whoosh(rng: np.random.Generator, dur: float, lo: float, hi: float, peak: float = 0.45) -> np.ndarray:
    """Szum powietrza: obwiednia narasta do `peak` (ułamek czasu) i opada; pasmo przesuwa się w górę i w dół."""
    n = int(dur * SR)
    t = np.linspace(0, 1, n)
    env = np.where(t < peak, (t / peak) ** 2, np.exp(-(t - peak) / (1 - peak) * 4))
    noise = rng.standard_normal(n)
    # Trzy pasma miksowane w czasie = przesuw filtra (tani „sweep”).
    low = fft_filter(noise, lo=lo, hi=lo * 2.5)
    mid = fft_filter(noise, lo=(lo + hi) / 3, hi=hi)
    w = np.sin(np.pi * np.clip(t / (peak * 1.6), 0, 1)) ** 2
    return (low * (1 - w) + mid * w * 1.3) * env


def tone_sweep(f0: float, f1: float, dur: float, kind: str = "sin") -> np.ndarray:
    n = int(dur * SR)
    f = np.geomspace(f0, f1, n)
    phase = 2 * np.pi * np.cumsum(f) / SR
    if kind == "saw":
        return 2 * ((phase / (2 * np.pi)) % 1.0) - 1
    return np.sin(phase)


def swing_stone(rng: np.random.Generator) -> np.ndarray:
    return fade(whoosh(rng, 0.42, 120, 900, 0.5) * 1.0)


def swing_metal(rng: np.random.Generator) -> np.ndarray:
    out = whoosh(rng, 0.45, 180, 1800, 0.45)
    ring = sum(np.sin(2 * np.pi * f * tt(0.45)) * np.exp(-tt(0.45) / 0.18) for f in (1320, 2130, 3410))
    mix_at(out, ring * 0.06, 0.0)
    return fade(out)


def swing_crystal(rng: np.random.Generator) -> np.ndarray:
    out = whoosh(rng, 0.5, 300, 3500, 0.4)
    for i, f in enumerate((1568, 2093, 2637, 3136)):
        mix_at(out, bell(f, 0.3, 0.12), 0.12 + i * 0.045, 0.12)
    return fade(out)


def swing_plasma(rng: np.random.Generator) -> np.ndarray:
    d = 0.5
    t = tt(d)
    vib = 1 + 0.04 * np.sin(2 * np.pi * 28 * t)
    buzz = saw(np.full(len(t), 110.0) * vib, len(t), harmonics=24) * 0.5
    buzz += saw(np.full(len(t), 220.0) * vib, len(t), harmonics=12) * 0.3
    env = np.minimum(t / 0.08, 1) * np.exp(-np.maximum(t - 0.2, 0) / 0.12)
    out = fft_filter(buzz, lo=80, hi=4000) * env * 0.6
    out += whoosh(rng, d, 400, 5000, 0.35) * 0.7
    return fade(out)


def swing_laser(rng: np.random.Generator) -> np.ndarray:
    d = 0.5
    t = tt(d)
    hum = tone_sweep(420, 140, d, "saw") * 0.4 + tone_sweep(840, 280, d) * 0.3
    env = np.minimum(t / 0.05, 1) * np.exp(-t / 0.22)
    out = fft_filter(hum, hi=3500) * env
    out += whoosh(rng, d, 500, 4000, 0.3) * 0.35
    return fade(out)


def swing_gravity(rng: np.random.Generator) -> np.ndarray:
    d = 0.65
    t = tt(d)
    wub = np.sin(2 * np.pi * np.cumsum(55 + 30 * np.sin(2 * np.pi * 6 * t)) / SR)
    wub += 0.5 * np.sin(2 * np.pi * np.cumsum(110 + 60 * np.sin(2 * np.pi * 6 * t)) / SR)
    env = np.minimum(t / 0.1, 1) * np.exp(-np.maximum(t - 0.25, 0) / 0.15)
    out = wub * env * 0.9
    out += whoosh(rng, d, 100, 1200, 0.45) * 0.6
    return fade(out)


def swing_cannon(rng: np.random.Generator) -> np.ndarray:
    d = 0.8
    out = np.zeros(int(d * SR))
    # Huk: basowy spadający ton + krótki trzask szumu.
    boom = tone_sweep(140, 38, 0.5) * np.exp(-tt(0.5) / 0.14)
    crack = fft_filter(rng.standard_normal(int(0.08 * SR)), lo=600, hi=7000) * decay(0.08, 0.02, 0.0005)
    mix_at(out, boom, 0.0, 1.0)
    mix_at(out, crack, 0.0, 0.8)
    # Świst pocisku oddalający się.
    zip_ = tone_sweep(2400, 900, 0.5) * np.exp(-tt(0.5) / 0.18) * 0.15
    mix_at(out, zip_, 0.05)
    mix_at(out, whoosh(rng, 0.6, 200, 3000, 0.15) * 0.4, 0.03)
    return fade(out, 0.001)


def swing_legend(rng: np.random.Generator) -> np.ndarray:
    d = 0.8
    out = np.zeros(int(d * SR))
    mix_at(out, whoosh(rng, 0.55, 150, 2500, 0.45), 0.0, 1.0)
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5)):
        mix_at(out, bell(f, 0.6, 0.25), 0.2 + i * 0.03, 0.1)
    sparks = np.zeros(int(0.5 * SR))
    for _ in range(25):
        dd = rng.uniform(0.004, 0.02)
        p = fft_filter(rng.standard_normal(int(dd * SR)), lo=3000, hi=10000) * decay(dd, dd / 4, 0.0002)
        mix_at(sparks, p, rng.uniform(0, 0.45), rng.uniform(0.1, 0.3))
    mix_at(out, sparks, 0.22, 0.6)
    return fade(out)


def tool_equip(rng: np.random.Generator) -> np.ndarray:
    d = 0.35
    out = np.zeros(int(d * SR))
    clank = fft_filter(rng.standard_normal(int(0.03 * SR)), lo=1500, hi=8000) * decay(0.03, 0.006, 0.0003)
    mix_at(out, clank, 0.0, 0.8)
    mix_at(out, clank * 0.6, 0.06, 0.6)
    ring = sum(np.sin(2 * np.pi * f * tt(0.3)) * np.exp(-tt(0.3) / 0.09) for f in (1760, 2640, 3960))
    mix_at(out, ring * 0.12, 0.06)
    mix_at(out, whoosh(rng, 0.12, 800, 6000, 0.6) * 0.3, 0.0)
    return fade(out, 0.001)


def tool_unlock(rng: np.random.Generator) -> np.ndarray:
    d = 2.2
    out = np.zeros(int(d * SR))
    # Narastający świst, uderzenie, arpeggio C-dur w górę i akord z dzwonami.
    riser = whoosh(rng, 0.45, 300, 6000, 0.95) * 0.5
    mix_at(out, riser, 0.0)
    boom = tone_sweep(110, 45, 0.6) * np.exp(-tt(0.6) / 0.2)
    mix_at(out, boom, 0.42, 0.9)
    notes = (523.25, 659.25, 783.99, 1046.5, 1318.5)
    for i, f in enumerate(notes):
        t = tt(1.2)
        brass = saw(np.full(len(t), f), len(t), harmonics=10) * np.exp(-t / 0.5) * np.minimum(t / 0.01, 1)
        mix_at(out, fft_filter(brass, hi=5000) * 0.12, 0.45 + i * 0.075)
    for f in (1046.5, 1318.5, 1568.0, 2093.0):
        mix_at(out, bell(f, 1.6, 0.6), 0.85, 0.12)
    sparkle = np.zeros(int(1.3 * SR))
    for _ in range(40):
        f = rng.uniform(2500, 6000)
        dd = rng.uniform(0.05, 0.15)
        mix_at(sparkle, np.sin(2 * np.pi * f * tt(dd)) * decay(dd, dd / 3, 0.001), rng.uniform(0, 1.1), 0.08)
    mix_at(out, sparkle, 0.85)
    return fade(out, 0.002, 0.15)


SOUNDS = {
    "swing_stone": swing_stone,
    "swing_metal": swing_metal,
    "swing_crystal": swing_crystal,
    "swing_plasma": swing_plasma,
    "swing_laser": swing_laser,
    "swing_gravity": swing_gravity,
    "swing_cannon": swing_cannon,
    "swing_legend": swing_legend,
    "tool_equip": tool_equip,
    "tool_unlock": tool_unlock,
}


def write_wav(path: Path, x: np.ndarray) -> None:
    pcm = np.clip(x * 32767, -32768, 32767).astype(np.int16)
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
