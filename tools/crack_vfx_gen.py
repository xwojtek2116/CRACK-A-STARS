"""Własne tekstury minigry rozbijania (T06 v2).

Uruchom z katalogu repo:  python tools/crack_vfx_gen.py
Wynik: art/vfx/textures/*.png (RGBA, białe z alfą; kolor nadaje silnik — ImageColor3).

- target_ring — pierścień zbliżania: ostra krawędź, miękka poświata, 12 znaczników,
- target_core — „kryształ” punktu: fasety, jasny środek, poświata krawędzi,
- vignette    — winieta ekranu w trakcie rundy (alfa rośnie do brzegów).
Upload: Studio MCP upload_image, ID w Shared/Config/VfxIds.luau.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from vfx_gen import grid, save, smoothstep  # noqa: E402


def target_ring() -> None:
    size = 256
    x, y = grid(size, size)
    r = np.sqrt(x * x + y * y)
    a = np.arctan2(y, x)
    edge = np.exp(-(((r - 0.86) / 0.035) ** 2))  # ostra linia
    glow = np.exp(-(((r - 0.84) / 0.12) ** 2)) * 0.45  # poświata do środka
    ticks = (np.cos(a * 12) > 0.93) * smoothstep(0.9, 0.94, r) * (1 - smoothstep(0.97, 0.995, r))
    alpha = np.clip(edge + glow + ticks, 0, 1) * (1 - smoothstep(0.98, 1.0, r))
    save("target_ring", np.ones_like(alpha), alpha)


def target_core() -> None:
    size = 256
    x, y = grid(size, size)
    r = np.sqrt(x * x + y * y)
    a = np.arctan2(y, x)
    # Fasety: 8 klinów o różnej jasności.
    facet = 0.72 + 0.28 * np.cos(np.floor((a + np.pi) / (np.pi / 4)) * 2.3) ** 2
    body = (1 - smoothstep(0.62, 0.66, r)) * facet
    rim = np.exp(-(((r - 0.64) / 0.04) ** 2))
    halo = np.exp(-(((r - 0.66) / 0.18) ** 2)) * 0.55 * smoothstep(0.6, 0.7, r)
    # Jasny środek i 4-ramienny błysk.
    center = np.exp(-((r / 0.18) ** 2))
    star = (np.exp(-((x / 0.04) ** 2)) * np.exp(-((y / 0.45) ** 2)) + np.exp(-((y / 0.04) ** 2)) * np.exp(-((x / 0.45) ** 2)))
    alpha = np.clip(body * 0.85 + rim + halo + center * 0.5 + star * 0.6, 0, 1) * (1 - smoothstep(0.97, 1.0, r))
    shade = np.clip(0.65 + 0.35 * (body * facet) + rim + center + star, 0, 1)
    save("target_core", shade, alpha)


def vignette() -> None:
    w, h = 512, 288
    x, y = grid(h, w)
    r = np.sqrt((x * 1.0) ** 2 + (y * 1.15) ** 2)
    alpha = smoothstep(0.55, 1.45, r) ** 1.4
    save("vignette", np.ones_like(alpha), alpha)


def main() -> None:
    target_ring()
    target_core()
    vignette()


if __name__ == "__main__":
    main()
