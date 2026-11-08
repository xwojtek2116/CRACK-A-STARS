"""Synteza dźwięków interfejsu (T13): klik, otwarcie okna (pop), zamknięcie (świst), moneta.

Uruchom z katalogu repo:  python tools/ui_sfx_gen.py
Wynik: art/audio/ui/*.wav (48 kHz, 16 bit PCM, mono, pik -3 dBFS). Głośności w grze: Shared/Config/SoundIds.luau.
"""

from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

SR = 48_000
SEED = 13
PEAK_DBFS = -3.0
OUT_DIR = Path(__file__).resolve().parent.parent / "art" / "audio" / "ui"


def tt(dur: float) -> np.ndarray:
    return np.arange(int(SR * dur)) / SR


def env(dur: float, tau: float, attack: float = 0.002) -> np.ndarray:
    t = tt(dur)
    return np.minimum(t / attack, 1.0) * np.exp(-t / tau)


def sine_sweep(f0: float, f1: float, dur: float) -> np.ndarray:
    t = tt(dur)
    freq = f0 * (f1 / f0) ** (t / dur)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def ui_click(rng: np.random.Generator) -> np.ndarray:
    """Krótki „tuk” z miękkim tonem — przycisk."""
    dur = 0.09
    tone = sine_sweep(1400, 700, dur) * env(dur, 0.018)
    noise = rng.standard_normal(len(tone)) * env(dur, 0.004) * 0.25
    return tone + noise


def ui_pop(rng: np.random.Generator) -> np.ndarray:
    """Bąbelkowy pop z rosnącą wysokością — otwarcie okna."""
    dur = 0.22
    body = sine_sweep(320, 980, dur) * env(dur, 0.06, 0.004)
    sparkle = np.sin(2 * np.pi * 2400 * tt(dur)) * env(dur, 0.03) * 0.18
    return body + sparkle + rng.standard_normal(len(body)) * env(dur, 0.003) * 0.1


def ui_close(rng: np.random.Generator) -> np.ndarray:
    """Szybki świst w dół — zamknięcie okna."""
    dur = 0.18
    t = tt(dur)
    noise = rng.standard_normal(len(t))
    # prosty rezonans: szum przez średnią ruchomą o malejącej szerokości → opadająca barwa
    spec = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(len(noise), 1 / SR)
    spec *= np.exp(-((freqs - 1800) / 1200) ** 2)
    whoosh = np.fft.irfft(spec, len(noise)) * np.sin(np.pi * t / dur) ** 2
    tone = sine_sweep(900, 260, dur) * env(dur, 0.07) * 0.35
    return whoosh * 3 + tone


def ui_coin(rng: np.random.Generator) -> np.ndarray:
    """Dwa jasne dzwonki (kwinta w górę) — wpływ kasy."""
    dur = 0.35
    out = np.zeros(int(SR * dur))
    for start, f in ((0.0, 1568.0), (0.06, 2349.0)):
        seg = tt(dur - start)
        tone = (np.sin(2 * np.pi * f * seg) + 0.35 * np.sin(2 * np.pi * f * 2.76 * seg)) * env(dur - start, 0.09)
        i = int(SR * start)
        out[i:i + len(tone)] += tone
    return out + rng.standard_normal(len(out)) * env(dur, 0.002) * 0.05


SOUNDS = {"ui_click": ui_click, "ui_pop": ui_pop, "ui_close": ui_close, "ui_coin": ui_coin}


def write(path: Path, x: np.ndarray) -> None:
    x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (PEAK_DBFS / 20)
    fade = min(len(x), int(SR * 0.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, fn in SOUNDS.items():
        rng = np.random.default_rng(SEED + len(name))
        write(OUT_DIR / f"{name}.wav", fn(rng))
        print("ok", name)


if __name__ == "__main__":
    main()
