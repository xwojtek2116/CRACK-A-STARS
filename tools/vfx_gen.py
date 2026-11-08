"""Własne tekstury VFX spadku gwiazdy (T38).

Uruchom z katalogu repo:  python tools/vfx_gen.py
Wynik: art/vfx/textures/*.png (RGBA). Wszystko z numpy + PIL, deterministycznie (SEED).

Tekstury są białe/szare z kanałem alfa — kolor nadaje silnik (ParticleEmitter.Color, Beam.Color,
Decal.Color3), więc jedna tekstura służy wszystkim rodzajom gwiazd.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

SEED = 38
OUT_DIR = Path(__file__).resolve().parent.parent / "art" / "vfx" / "textures"


# ---------------------------------------------------------------- narzędzia


def spectral_noise(rng: np.random.Generator, h: int, w: int, beta: float) -> np.ndarray:
    """Bezszwowy szum fraktalny (amplituda 1/f^beta, losowa faza) znormalizowany do 0..1."""
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / f**beta
    amp[0, 0] = 0.0
    phase = rng.uniform(0, 2 * np.pi, (h, w))
    field = np.real(np.fft.ifft2(amp * np.exp(1j * phase)))
    field -= field.min()
    return field / field.max()


def grid(h: int, w: int) -> tuple[np.ndarray, np.ndarray]:
    """Współrzędne -1..1 (środek = 0)."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    return (x + 0.5) / w * 2 - 1, (y + 0.5) / h * 2 - 1


def smoothstep(a: float, b: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def save(name: str, rgb: np.ndarray, alpha: np.ndarray) -> None:
    rgb = np.clip(rgb, 0, 1)
    alpha = np.clip(alpha, 0, 1)
    if rgb.ndim == 2:
        rgb = np.stack([rgb] * 3, axis=-1)
    img = np.dstack([rgb, alpha[..., None]])
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    Image.fromarray((img * 255).round().astype(np.uint8), "RGBA").save(OUT_DIR / f"{name}.png", optimize=True)
    print(f"  {name}.png {img.shape[1]}x{img.shape[0]}")


def segment_distance(px: np.ndarray, py: np.ndarray, a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Odległość każdego piksela od odcinka a–b (w pikselach)."""
    ab = b - a
    denom = max(float(ab @ ab), 1e-9)
    t = np.clip(((px - a[0]) * ab[0] + (py - a[1]) * ab[1]) / denom, 0, 1)
    dx = px - (a[0] + t * ab[0])
    dy = py - (a[1] + t * ab[1])
    return np.sqrt(dx * dx + dy * dy)


def polyline_distance(px: np.ndarray, py: np.ndarray, points: list[np.ndarray]) -> np.ndarray:
    d = np.full(px.shape, 1e9)
    for a, b in zip(points[:-1], points[1:]):
        d = np.minimum(d, segment_distance(px, py, a, b))
    return d


def midpoint_bolt(rng: np.random.Generator, a: np.ndarray, b: np.ndarray, depth: int, rough: float) -> list[np.ndarray]:
    """Błyskawica: rekurencyjne przemieszczenie punktu środkowego prostopadle do odcinka."""
    points = [a, b]
    offset = rough
    for _ in range(depth):
        new = [points[0]]
        for p, q in zip(points[:-1], points[1:]):
            mid = (p + q) / 2
            d = q - p
            normal = np.array([-d[1], d[0]]) / max(np.linalg.norm(d), 1e-9)
            new += [mid + normal * rng.uniform(-offset, offset), q]
        points = new
        offset *= 0.55
    return points


# ---------------------------------------------------------------- tekstury


def nebula(rng: np.random.Generator) -> None:
    """Wnętrze wyrwy: chmury mgławicy z włóknami i gwiazdami (bezszwowa, do przesuwania UV)."""
    n = 512
    soft = spectral_noise(rng, n, n, 2.4)
    fine = spectral_noise(rng, n, n, 1.6)
    ridge = 1 - np.abs(2 * spectral_noise(rng, n, n, 2.0) - 1)
    cloud = np.clip((soft * 0.65 + fine * 0.35 - 0.3) * 1.9, 0, 1)
    filaments = np.clip((ridge - 0.72) * 3.5, 0, 1) * cloud
    stars = np.zeros((n, n))
    for _ in range(260):
        x, y = rng.integers(0, n, 2)
        stars[y, x] = rng.uniform(0.4, 1.0)
    stars = np.maximum(stars, np.roll(stars, 1, 0) * 0.35)
    stars = np.maximum(stars, np.roll(stars, 1, 1) * 0.35)
    lum = np.clip(0.18 + cloud * 0.6 + filaments * 0.9 + stars, 0, 1)
    alpha = np.clip(0.55 + cloud * 0.45 + stars, 0, 1)
    save("nebula", lum, alpha)


def swirl(rng: np.random.Generator) -> None:
    """Wir w głębi wyrwy: spiralne ramiona z jasnym środkiem, miękka krawędź (dysk obracany w silniku)."""
    n = 512
    x, y = grid(n, n)
    r = np.sqrt(x * x + y * y)
    theta = np.arctan2(y, x)
    noise = spectral_noise(rng, n, n, 2.0)
    twist = theta + 4.5 * (1 - r)
    arms = 0.5 + 0.5 * np.cos(4 * twist)
    sx = ((np.cos(twist) * r * 0.5 + 0.5) * (n - 1)).astype(int) % n
    sy = ((np.sin(twist) * r * 0.5 + 0.5) * (n - 1)).astype(int) % n
    detail = noise[sy, sx]
    core = np.exp(-(r**2) / (2 * 0.12**2))
    body = arms**2 * (0.4 + 0.8 * detail) * (1 - smoothstep(0.55, 1.0, r))
    lum = np.clip(body * 0.85 + core * 1.2 + 0.1, 0, 1)
    alpha = np.clip((body * 0.9 + core + 0.25 * (1 - r)) * (1 - smoothstep(0.85, 1.0, r)), 0, 1)
    save("swirl", lum, alpha)


def rift_glow() -> None:
    """Pas poświaty (Beam wzdłuż krawędzi rozdarcia): jasna linia z miękką aurą."""
    h, w = 64, 256
    _, y = grid(h, w)
    core = np.exp(-(y**2) / (2 * 0.06**2))
    aura = np.exp(-(y**2) / (2 * 0.32**2))
    save("rift_glow", np.clip(0.75 + core, 0, 1), np.clip(core + aura * 0.55, 0, 1))


def lightning(rng: np.random.Generator, index: int) -> None:
    """Błyskawica z odgałęzieniami (Beam, TextureMode Stretch, losowo podmieniana co klatkę)."""
    h, w = 128, 512
    py, px = np.mgrid[0:h, 0:w].astype(np.float64)
    main = midpoint_bolt(rng, np.array([0.0, h / 2]), np.array([w - 1.0, h / 2]), 7, h * 0.32)
    d = polyline_distance(px, py, main)
    for _ in range(3):
        start = main[rng.integers(len(main) // 5, len(main) * 4 // 5)]
        end = start + np.array([rng.uniform(60, 160), rng.uniform(-50, 50)])
        branch = midpoint_bolt(rng, start, end, 5, 18)
        d = np.minimum(d, polyline_distance(px, py, branch) + 1.2)
    core = np.exp(-(d**2) / (2 * 1.3**2))
    glow = np.exp(-(d**2) / (2 * 7.0**2))
    save(f"lightning_{index}", np.clip(0.7 + core, 0, 1), np.clip(core + glow * 0.6, 0, 1))


def spark() -> None:
    """Iskra-gwiazdka: 4 długie promienie + 4 krótkie skośne + jasny środek."""
    n = 128
    x, y = grid(n, n)
    rays = np.exp(-np.abs(x) / 0.025) * np.exp(-np.abs(y) / 0.35)
    rays += np.exp(-np.abs(y) / 0.025) * np.exp(-np.abs(x) / 0.35)
    u, v = (x + y) / np.sqrt(2), (x - y) / np.sqrt(2)
    rays += 0.5 * (np.exp(-np.abs(u) / 0.02) * np.exp(-np.abs(v) / 0.15) + np.exp(-np.abs(v) / 0.02) * np.exp(-np.abs(u) / 0.15))
    r = np.sqrt(x * x + y * y)
    core = np.exp(-(r**2) / (2 * 0.08**2))
    a = np.clip(rays + core, 0, 1) * (1 - smoothstep(0.9, 1.0, r))
    save("spark", np.ones_like(a), a)


def ember() -> None:
    n = 64
    x, y = grid(n, n)
    r = np.sqrt(x * x + y * y)
    core = np.exp(-(r**2) / (2 * 0.18**2))
    halo = np.exp(-(r**2) / (2 * 0.45**2)) * 0.5
    save("ember", np.clip(0.8 + core * 0.4, 0, 1), np.clip(core + halo, 0, 1) * (1 - smoothstep(0.9, 1, r)))


def smoke_sheet(rng: np.random.Generator) -> None:
    """Dym jako flipbook 4×4 (128 px na klatkę): kłąb rośnie, rzednie i się rozwiewa."""
    cell, frames = 128, 16
    sheet_rgb = np.zeros((cell * 4, cell * 4))
    sheet_a = np.zeros((cell * 4, cell * 4))
    base = spectral_noise(rng, cell * 2, cell * 2, 2.1)
    x, y = grid(cell, cell)
    r = np.sqrt(x * x + y * y)
    for i in range(frames):
        t = i / (frames - 1)
        ox, oy = int(t * cell * 0.6), int(t * cell * 0.25)
        noise = base[oy : oy + cell, ox : ox + cell]
        radius = 0.7 + 0.28 * t
        shape = 1 - smoothstep(0.1, radius, r * (0.7 + 0.6 * noise))
        density = shape * (0.45 + 0.9 * noise) * (1 - t) ** 0.9
        shade = 0.55 + 0.45 * noise - 0.15 * (y + 1) / 2
        gy, gx = divmod(i, 4)
        sheet_rgb[gy * cell : (gy + 1) * cell, gx * cell : (gx + 1) * cell] = shade
        sheet_a[gy * cell : (gy + 1) * cell, gx * cell : (gx + 1) * cell] = np.clip(density, 0, 1)
    save("smoke_sheet", sheet_rgb, sheet_a)


def dust(rng: np.random.Generator) -> None:
    n = 128
    x, y = grid(n, n)
    r = np.sqrt(x * x + y * y)
    noise = spectral_noise(rng, n, n, 2.0)
    shape = 1 - smoothstep(0.25, 0.95, r * (0.8 + 0.5 * noise))
    save("dust", 0.7 + 0.3 * noise, np.clip(shape * (0.5 + 0.6 * noise), 0, 1))


def shock_ring() -> None:
    """Fala uderzeniowa: ostra jasna krawędź zewnętrzna, miękki ogon do środka."""
    n = 512
    x, y = grid(n, n)
    r = np.sqrt(x * x + y * y)
    edge = np.exp(-((r - 0.9) ** 2) / (2 * 0.012**2))
    tail = np.where(r < 0.9, np.exp(-(0.9 - r) / 0.12), 0) * 0.65
    a = np.clip(edge + tail, 0, 1) * (1 - smoothstep(0.93, 0.97, r))
    save("shock_ring", np.clip(0.8 + edge, 0, 1), a)


def warn_ring() -> None:
    """Pierścień ostrzegawczy na ziemi: obwódka, przerywany pierścień z runami, strzałki do środka."""
    n = 512
    x, y = grid(n, n)
    r = np.sqrt(x * x + y * y)
    theta = np.arctan2(y, x)
    outer = np.exp(-((r - 0.93) ** 2) / (2 * 0.01**2))
    dashes = (np.cos(theta * 24) > 0.15).astype(float)
    inner = np.exp(-((r - 0.82) ** 2) / (2 * 0.018**2)) * dashes
    runes = (np.abs(np.sin(theta * 48)) > 0.85) * np.exp(-((r - 0.875) ** 2) / (2 * 0.012**2))
    sector = np.cos(theta * 8)
    arrows = (sector > 0.97 - (0.76 - r) * 1.6) * (r > 0.6) * (r < 0.76)
    fill = smoothstep(0.2, 0.93, r) * 0.18 * (r < 0.93)
    a = np.clip(outer + inner + runes * 0.8 + arrows * 0.9 + fill, 0, 1)
    save("warn_ring", np.ones_like(a), a)


def flare() -> None:
    """Rozbłysk: rdzeń, halo, 6 promieni i długa pozioma smuga anamorficzna."""
    n = 256
    x, y = grid(n, n)
    r = np.sqrt(x * x + y * y)
    theta = np.arctan2(y, x)
    core = np.exp(-(r**2) / (2 * 0.07**2))
    glow = np.exp(-(r**2) / (2 * 0.25**2)) * 0.45
    halo = np.exp(-((r - 0.62) ** 2) / (2 * 0.02**2)) * 0.25
    rays = np.abs(np.cos(theta * 3)) ** 60 * np.exp(-r / 0.35) * 0.9
    streak = np.exp(-np.abs(y) / 0.012) * np.exp(-np.abs(x) / 0.6) * 0.8
    a = np.clip(core + glow + halo + rays + streak, 0, 1) * (1 - smoothstep(0.95, 1, r))
    save("flare", np.ones_like(a), a)


def fire_trail(rng: np.random.Generator) -> None:
    """Smuga ognia do Trail (U = wiek śladu): biały żar na początku, poszarpane płomienie dalej."""
    h, w = 64, 256
    x, y = grid(h, w)
    u = (x + 1) / 2
    noise = spectral_noise(rng, h, w, 1.7)
    width = 0.95 - 0.55 * u
    body = np.exp(-(y**2) / (2 * (width * 0.45) ** 2))
    flames = np.clip(body * (0.55 + 0.9 * noise) - u * 0.35, 0, 1)
    heat = np.clip(1.1 - u * 1.4, 0, 1) * np.exp(-(y**2) / (2 * 0.18**2))
    save("fire_trail", np.clip(0.75 + heat, 0, 1), np.clip((flames + heat) * (1 - u) ** 0.5, 0, 1))


def energy(rng: np.random.Generator) -> None:
    """Pas energii (Beam z TextureSpeed): poziomo bezszwowe włókna."""
    h, w = 64, 256
    noise = spectral_noise(rng, h, w, 1.4)
    ridge = 1 - np.abs(2 * noise - 1)
    _, y = grid(h, w)
    fall = np.exp(-(y**2) / (2 * 0.35**2))
    a = np.clip((ridge - 0.55) * 2.6, 0, 1) * fall
    save("energy", np.ones_like(a), a)


def cracks(rng: np.random.Generator) -> None:
    """Świecące pęknięcia gruntu wokół krateru (Decal), grubsze przy środku."""
    n = 512
    py, px = np.mgrid[0:n, 0:n].astype(np.float64)
    c = np.array([n / 2, n / 2])
    d = np.full(px.shape, 1e9)
    weight = np.full(px.shape, 0.0)
    for k in range(11):
        ang = k / 11 * 2 * np.pi + rng.uniform(-0.2, 0.2)
        length = rng.uniform(0.32, 0.48) * n
        end = c + np.array([np.cos(ang), np.sin(ang)]) * length
        line = midpoint_bolt(rng, c, end, 6, length * 0.12)
        dl = polyline_distance(px, py, line)
        d = np.minimum(d, dl)
        for _ in range(2):
            start = line[rng.integers(len(line) // 3, len(line) - 2)]
            b_ang = ang + rng.choice([-1, 1]) * rng.uniform(0.4, 0.9)
            b_end = start + np.array([np.cos(b_ang), np.sin(b_ang)]) * rng.uniform(0.08, 0.16) * n
            d = np.minimum(d, polyline_distance(px, py, midpoint_bolt(rng, start, b_end, 4, 10)) + 0.8)
    r = np.sqrt((px - c[0]) ** 2 + (py - c[1]) ** 2) / (n / 2)
    thick = 2.6 * (1 - r) + 0.6
    core = np.exp(-(d**2) / (2 * thick**2))
    glow = np.exp(-(d**2) / (2 * (thick * 4) ** 2)) * 0.45
    burn = np.exp(-(r**2) / (2 * 0.22**2)) * 0.6
    a = np.clip((core + glow) * (1 - smoothstep(0.75, 1.0, r)) + burn, 0, 1)
    save("cracks", np.clip(0.7 + core, 0, 1), a)


def main() -> None:
    rng = np.random.default_rng(SEED)
    print(f"Tekstury -> {OUT_DIR}")
    nebula(rng)
    swirl(rng)
    rift_glow()
    for i in range(1, 4):
        lightning(rng, i)
    spark()
    ember()
    smoke_sheet(rng)
    dust(rng)
    shock_ring()
    warn_ring()
    flare()
    fire_trail(rng)
    energy(rng)
    cracks(rng)


# ---------------------------------------------------------------- T39


def anisotropic_noise(rng: np.random.Generator, h: int, w: int, beta: float, stretch: float) -> np.ndarray:
    """Szum fraktalny rozciągnięty wzdłuż X (smugi, włókna plazmy); bezszwowy."""
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.fftfreq(w)[None, :] * stretch
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = 1.0 / f**beta
    amp[0, 0] = 0.0
    phase = rng.uniform(0, 2 * np.pi, (h, w))
    field = np.real(np.fft.ifft2(amp * np.exp(1j * phase)))
    field -= field.min()
    return field / field.max()


def light_shaft(rng: np.random.Generator) -> None:
    """Snop światła (Beam z wyrwy / słup nad gwiazdą): U = długość, jasny początek, smugi wzdłuż, miękkie brzegi."""
    h, w = 128, 512
    x, y = grid(h, w)
    u = (x + 1) / 2
    streaks = anisotropic_noise(rng, h, w, 1.6, 8.0)
    across = np.exp(-(y**2) / (2 * 0.38**2))
    core = np.exp(-(y**2) / (2 * 0.1**2))
    along = (1 - u) ** 0.7 * smoothstep(0.0, 0.04, u)
    a = np.clip((across * (0.45 + 0.75 * streaks) + core * 0.6) * along, 0, 1)
    save("light_shaft", np.clip(0.8 + core * 0.3, 0, 1), a)


def plasma(rng: np.random.Generator) -> None:
    """Ogon plazmy (Beam z TextureSpeed): poziomo bezszwowe włókna, gorący rdzeń w środku szerokości."""
    h, w = 128, 512
    _, y = grid(h, w)
    fil = anisotropic_noise(rng, h, w, 1.5, 6.0)
    ridge = 1 - np.abs(2 * anisotropic_noise(rng, h, w, 1.7, 5.0) - 1)
    body = np.exp(-(y**2) / (2 * 0.33**2))
    core = np.exp(-(y**2) / (2 * 0.09**2))
    a = np.clip(body * (0.35 + 0.8 * fil) + ridge**4 * body * 0.8 + core * 0.7, 0, 1)
    save("plasma", np.clip(0.75 + core * 0.4 + ridge**6 * 0.3, 0, 1), a)


def heat_ring(rng: np.random.Generator) -> None:
    """Pierścień przyspieszenia / fala energii: podwójna obwódka z przerwami i poświatą."""
    n = 512
    x, y = grid(n, n)
    r = np.sqrt(x * x + y * y)
    theta = np.arctan2(y, x)
    breaks = 0.6 + 0.4 * np.cos(theta * 7 + 1.3) * np.cos(theta * 3)
    ring1 = np.exp(-((r - 0.86) ** 2) / (2 * 0.018**2)) * breaks
    ring2 = np.exp(-((r - 0.74) ** 2) / (2 * 0.01**2)) * (1 - breaks * 0.5)
    glow = np.exp(-((r - 0.82) ** 2) / (2 * 0.08**2)) * 0.35
    a = np.clip(ring1 + ring2 * 0.7 + glow, 0, 1) * (1 - smoothstep(0.95, 1.0, r))
    save("heat_ring", np.clip(0.85 + ring1 * 0.3, 0, 1), a)


def energy_wave(rng: np.random.Generator) -> None:
    """Fala energii po ziemi wokół leżącej gwiazdy: cienki pierścień, promieniste smugi, delikatne zmarszczki."""
    n = 512
    x, y = grid(n, n)
    r = np.sqrt(x * x + y * y)
    theta = np.arctan2(y, x)
    ring = np.exp(-((r - 0.9) ** 2) / (2 * 0.012**2))
    rays = (np.abs(np.sin(theta * 18)) ** 30) * smoothstep(0.55, 0.88, r) * (r < 0.9) * 0.6
    ripple = (0.5 + 0.5 * np.cos(r * 60)) * smoothstep(0.4, 0.88, r) * (r < 0.9) * 0.15
    a = np.clip(ring + rays + ripple, 0, 1) * (1 - smoothstep(0.93, 0.97, r))
    save("energy_wave", np.ones_like(a), a)


def glint() -> None:
    """Błysk: 4 ostre promienie, długa smuga pozioma, pierścień dyfrakcyjny."""
    n = 256
    x, y = grid(n, n)
    r = np.sqrt(x * x + y * y)
    rays = np.exp(-np.abs(x) / 0.012) * np.exp(-np.abs(y) / 0.45) + np.exp(-np.abs(y) / 0.012) * np.exp(-np.abs(x) / 0.45)
    streak = np.exp(-np.abs(y) / 0.008) * np.exp(-np.abs(x) / 0.9) * 0.7
    core = np.exp(-(r**2) / (2 * 0.06**2))
    ring = np.exp(-((r - 0.35) ** 2) / (2 * 0.01**2)) * 0.25
    a = np.clip(rays + streak + core + ring, 0, 1) * (1 - smoothstep(0.92, 1.0, r))
    save("glint", np.ones_like(a), a)


def main_t39() -> None:
    rng = np.random.default_rng(SEED + 1)
    light_shaft(rng)
    plasma(rng)
    heat_ring(rng)
    energy_wave(rng)
    glint()


if __name__ == "__main__":
    import sys

    if "--t39" in sys.argv:
        main_t39()
    else:
        main()
        main_t39()
