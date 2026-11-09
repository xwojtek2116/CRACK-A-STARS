"""build_props.py — propsy biomów i punkty orientacyjne Crack a Stars (T15) (Blender 5.x, tryb w tle).

Uruchom:
  E:\\blender\\blender.exe -b --factory-startup -P art/map/props/build_props.py -- [--only Lava_Arch,...] [--render]

Decyzja 9.11: kształty „bardziej realistyczne” (skały z fraktalnego szumu, cięte płaszczyznami, warstwy, kolumny
bazaltu), ale materiały = wbudowane materiały Roblox na MeshPart (Basalt, Rock, Ice, Glacier, Snow, Sandstone, Salt…)
— to PBR bez własnych tekstur, więc pamięć telefonu nie rośnie. UV box-projection 8 studs/kafel.
Części wg roli: Rock (bryła, kolizja dla dużych), Detail (drugi materiał: śnieg, warstwa), Crystal (Glass), Glow (Neon).
Jednostki = studs; pivot = środek podstawy (z = 0 = powierzchnia terenu; dno lekko zakopane).
Wyjście: art/map/props/props.fbx, props.blend, props_meta.json (części, rozmiary, kategoria: small/medium/large/landmark,
biom), z --render: vault/_img/T15 propsy.png
"""

import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from maplib import (Asset, box, dome, export_fbx, frame_camera, hull, ico, loft, merge, rock, setup_render,  # noqa: E402
                    torus, zcyl)

ROOT = HERE.parents[2]
IMG = ROOT / "vault" / "_img"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
BUDGET = {"small": 800, "medium": 2500, "large": 4000, "landmark": 8000}

PAL = {
    # Lava Fields
    "basalt": ("#3A2E31", "Basalt", 0), "basalt_lt": ("#5A4648", "Basalt", 0), "obsidian": ("#160E1C", "Glass", 0),
    "magma": ("#FF6A1F", "Neon", 0), "ash": ("#4A3E44", "Slate", 0),
    # Frost Crater
    "frost_rock": ("#5E6E96", "Rock", 0), "snow": ("#E4ECFF", "Snow", 0), "ice": ("#A8DCFF", "Ice", 0.15),
    "glacier": ("#8EC4EE", "Glacier", 0), "ice_glow": ("#9FE6FF", "Neon", 0),
    # Crystal Canyon
    "canyon_rock": ("#3E4C6E", "Rock", 0), "canyon_lt": ("#4F8C9C", "Limestone", 0),
    "crystal": ("#5AFFDC", "Glass", 0.35), "crystal_core": ("#3CFFD8", "Neon", 0),
    # Nebula Plateau
    "sand": ("#8A5FB8", "Sandstone", 0), "salt": ("#CDAAEC", "Salt", 0), "spore": ("#E07BFF", "Neon", 0),
    "nebula_glow": ("#B48CFF", "Neon", 0),
    # wspólne
    "slate": ("#5C5874", "Slate", 0), "metal": ("#7A7F9C", "Metal", 0), "metal_dk": ("#30344C", "Metal", 0),
    "rust": ("#6B4A5A", "CorrodedMetal", 0), "beacon": ("#FFFFFF", "Neon", 0), "beacon_c": ("#7CF2FF", "Neon", 0),
    "shield": ("#7CC8FF", "Neon", 0),
}


def rng_for(name):
    return random.Random(sum(ord(c) * (i + 1) for i, c in enumerate(name)))


def tilt(bm, rng, deg):
    M = Matrix.Rotation(math.radians(rng.uniform(-deg, deg)), 4, "X") @ Matrix.Rotation(math.radians(rng.uniform(-deg, deg)), 4, "Y")
    bm.transform(M)
    return bm


def move(bm, v):
    bmesh.ops.translate(bm, vec=Vector(v), verts=bm.verts)
    return bm


def spin(bm, deg):
    bm.transform(Matrix.Rotation(math.radians(deg), 4, "Z"))
    return bm


def cap_top(bm_src, frac=0.55, thick=1.04):
    """Czapa (śnieg/warstwa): kopia skały powiększona i przycięta do górnej części."""
    bm = bm_src.copy()
    zs = [v.co.z for v in bm.verts]
    z0 = min(zs) + (max(zs) - min(zs)) * frac
    c = Vector((0, 0, z0))
    for v in bm.verts:
        v.co = c + (v.co - c) * thick
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-4, plane_co=(0, 0, z0),
                           plane_no=(0, 0, -1), clear_outer=True)
    edges = [e for e in bm.edges if e.is_boundary]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    return bm


def prism(r, h, sides=6, tip=0.35, c=(0, 0, 0)):
    """Kryształ: graniastosłup z ostrym czubkiem (h = całkowita wysokość)."""
    hb = h * (1 - tip)
    path = [(0, 0, 0), (0, 0, hb), (0, 0, h)]
    bm = loft(path, [r, r * 0.92, 0.0], sides=sides, ref=Vector((1, 0, 0)))
    move(bm, c)
    return bm


def crystal_group(a, rng, n, base_r, h_range, spread, key_glass="crystal", key_core="crystal_core", c=(0, 0, 0)):
    for i in range(n):
        ang = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0, spread) if i else 0
        h = rng.uniform(*h_range) * (1.0 if i == 0 else rng.uniform(0.5, 0.9))
        r = base_r * rng.uniform(0.6, 1.0) * (h / h_range[1]) ** 0.5
        bm = prism(r, h, sides=6)
        bm.transform(Matrix.Rotation(math.radians(rng.uniform(0, 60)), 4, "Z"))
        lean = 0 if i == 0 else rng.uniform(12, 38)
        bm.transform(Matrix.Rotation(math.radians(lean), 4, "Y"))
        bm.transform(Matrix.Rotation(ang, 4, "Z"))
        move(bm, (c[0] + math.cos(ang) * d, c[1] + math.sin(ang) * d, c[2] - h * 0.08))
        a.add("Crystal", key_glass, bm)
        core = prism(r * 0.45, h * 0.86, sides=6)
        core.transform(Matrix.Rotation(math.radians(lean), 4, "Y"))
        core.transform(Matrix.Rotation(ang, 4, "Z"))
        move(core, (c[0] + math.cos(ang) * d, c[1] + math.sin(ang) * d, c[2] - h * 0.08))
        a.add("Glow", key_core, core)


def arch_path(span, height, n=24):
    return [(span / 2 * math.cos(math.pi * i / (n - 1)), 0, height * math.sin(math.pi * i / (n - 1))) for i in range(n)]


def noisy_arch(a, rng, key, span, height, thick, part="Rock"):
    path = arch_path(span, height)
    off = rng.uniform(0, 100)
    radii = []
    for i, p in enumerate(path):
        t = i / (len(path) - 1)
        base = thick * (1.6 - 0.7 * math.sin(math.pi * t))  # nogi grubsze
        n = noise.noise(Vector((t * 4 + off, off, 0)))
        radii.append((base * (1 + 0.25 * n), base * 0.8 * (1 + 0.2 * n)))
    bm = loft(path, radii, sides=14, ref=Vector((0, 1, 0)))
    for v in bm.verts:
        v.co += Vector((noise.noise(v.co * 0.15 + Vector((off, 0, 0))),
                        noise.noise(v.co * 0.15 + Vector((0, off, 0))),
                        noise.noise(v.co * 0.15 + Vector((0, 0, off))) * 0.6)) * thick * 0.35
    move(bm, (0, 0, -thick * 0.6))
    a.add(part, key, bm, collide=True)
    return bm


# ---------------------------------------------------------------- Lava Fields

def lava_boulder(a, rng):
    a.add("Rock", "basalt", rock(rng, (7, 5.5, 5), detail=3, rough=0.32, cuts=4), collide=True)


def lava_columns(a, rng):
    """Kępa sześciokątnych kolumn bazaltu różnej wysokości (bardzo charakterystyczny kształt wulkaniczny)."""
    pts = []
    for ring_i, cnt in ((0, 1), (1, 6), (2, 9)):
        for k in range(cnt):
            ang = 2 * math.pi * k / max(cnt, 1) + ring_i * 0.4
            pts.append((math.cos(ang) * ring_i * 3.6, math.sin(ang) * ring_i * 3.6, ring_i))
    for x, y, ring_i in pts:
        if ring_i == 2 and rng.random() < 0.3:
            continue
        h = max(2.5, 18 - ring_i * 5 + rng.uniform(-3, 3))
        col = zcyl(-1.0, h, 1.9 + rng.uniform(-0.15, 0.15), 6)
        top = [v for v in col.verts if v.co.z > h - 0.01]
        dz = rng.uniform(-0.6, 0.6)
        for v in top:
            v.co.z += v.co.x * dz * 0.25
        move(col, (x, y, 0))
        lt = rng.random() >= 0.7
        a.add("Rock2" if lt else "Rock", "basalt_lt" if lt else "basalt", col, collide=True)
    a.add("Detail", "ash", rock(rng, (8, 8, 2.0), detail=2, rough=0.3, sink=0.5))


def lava_spire(a, rng):
    path = [(0, 0, -2)]
    radii = [6.5]
    for i in range(1, 17):
        t = i / 16
        path.append((math.sin(t * 5 + 1) * 1.2 * t, math.cos(t * 4) * 1.0 * t, 30 * t))
        radii.append((6.5 * (1 - t) ** 1.2 + 0.4, 5.6 * (1 - t) ** 1.2 + 0.3))
    path.append((0.5, 0.2, 33))
    radii.append(0)
    bm = loft(path, radii, sides=12, ref=Vector((1, 0, 0)))
    off = rng.uniform(0, 50)
    for v in bm.verts:
        v.co += Vector((noise.noise(v.co * 0.2 + Vector((off, 0, 0))), noise.noise(v.co * 0.2 + Vector((0, off, 0))), 0)) * 1.4
    a.add("Rock", "basalt", bm, collide=True)
    a.add("Rock", "basalt", rock(rng, (7, 6, 3), detail=2, rough=0.35, cuts=2))


def lava_obsidian(a, rng):
    for i in range(5):
        h = rng.uniform(4, 9) * (1.3 if i == 0 else 1)
        w = rng.uniform(0.8, 1.6)
        pts = [(rng.uniform(-w, w), rng.uniform(-w, w), 0) for _ in range(5)] + [(rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), h)]
        bm = hull(pts)
        tilt(bm, rng, 25)
        move(bm, (rng.uniform(-3, 3), rng.uniform(-3, 3), -0.5))
        a.add("Rock", "obsidian", bm, collide=i == 0)
    a.add("Detail", "basalt", rock(rng, (5, 5, 1.6), detail=2, rough=0.3, sink=0.5))


def lava_vent(a, rng):
    """Komin wulkaniczny: stożek z kraterem i świecącą magmą w środku (miejsce na cząsteczki dymu)."""
    path = [(0, 0, -1.5), (0, 0, 2), (0, 0, 5.5), (0, 0, 6.6), (0, 0, 5.8)]
    radii = [10, 8, 4.6, 3.6, 2.4]
    bm = loft(path, radii, sides=12, ref=Vector((1, 0, 0)), cap=False)
    off = rng.uniform(0, 40)
    for v in bm.verts:
        r = Vector((v.co.x, v.co.y, 0)).length
        v.co += Vector((v.co.x, v.co.y, 0)).normalized() * noise.noise(v.co * 0.35 + Vector((off, 0, 0))) * 0.9 if r > 0.1 else Vector()
    a.add("Rock", "basalt", bm, collide=True)
    a.add("Glow", "magma", zcyl(4.6, 5.9, 2.5, 12))
    for k in range(5):
        ang = k * 2 * math.pi / 5 + rng.uniform(-0.3, 0.3)
        crack = box(0.35, rng.uniform(3, 5), 0.25)
        crack.transform(Matrix.Rotation(ang, 4, "Z"))
        move(crack, (math.cos(ang + math.pi / 2) * -6.0, math.sin(ang + math.pi / 2) * -6.0, 1.9))
        a.add("Glow", "magma", crack)
    a.extra["fx"] = {"smoke": [0, 6.2, 0]}


def lava_arch(a, rng):
    noisy_arch(a, rng, "basalt", 56, 34, 5.5)
    for sx in (-1, 1):
        a.add("Rock", "basalt", move(rock(rng, (9, 8, 6), detail=2, rough=0.35, cuts=2), (sx * 28, 0, 0)))
    # żyły magmy na łuku
    path = [(p[0] * 0.98, -3.6, p[2] - 1.5) for p in arch_path(56, 34, 12)[2:-2]]
    a.add("Glow", "magma", loft(path, [0.35] * len(path), sides=4))


def lava_pebbles(a, rng):
    for _ in range(5):
        r = rng.uniform(0.8, 2.0)
        a.add("Rock", "basalt", move(rock(rng, (r, r * 0.8, r * 0.7), detail=1, rough=0.35),
                                    (rng.uniform(-5, 5), rng.uniform(-5, 5), 0)))


# ---------------------------------------------------------------- Frost Crater

def frost_spikes(a, rng):
    for i in range(7):
        h = rng.uniform(8, 16) * (1.3 if i == 0 else 1)
        bm = loft([(0, 0, -1), (0, 0, h * 0.5), (0, 0, h)], [h * 0.14, h * 0.09, 0], sides=5, ref=Vector((1, 0, 0)))
        lean = 0 if i == 0 else rng.uniform(15, 40)
        ang = rng.uniform(0, 2 * math.pi)
        bm.transform(Matrix.Rotation(math.radians(lean), 4, "Y"))
        bm.transform(Matrix.Rotation(ang, 4, "Z"))
        d = 0 if i == 0 else rng.uniform(1.5, 4)
        move(bm, (math.cos(ang) * d, math.sin(ang) * d, 0))
        a.add("Crystal", "ice", bm, collide=i == 0)
    a.add("Detail", "snow", rock(rng, (6, 6, 1.8), detail=2, rough=0.25, sink=0.5))


def frost_boulder(a, rng):
    base = rock(rng, (8, 6.5, 5.5), detail=3, rough=0.3, cuts=2)
    snow = cap_top(base, frac=0.55, thick=1.05)
    a.add("Rock", "frost_rock", base, collide=True)
    a.add("Detail", "snow", snow)


def frost_iceblock(a, rng):
    for i in range(3):
        s = rng.uniform(3, 6) * (1.4 if i == 0 else 1)
        bm = rock(rng, (s, s * 0.8, s * 0.9), detail=1, rough=0.15, cuts=5)
        spin(bm, rng.uniform(0, 360))
        move(bm, (rng.uniform(-4, 4) if i else 0, rng.uniform(-4, 4) if i else 0, 0))
        a.add("Crystal", "ice", bm, collide=i == 0)


def frost_pillar(a, rng):
    path, radii = [], []
    for i in range(9):
        t = i / 8
        path.append((math.sin(t * 2.5) * 1.2, 0, 26 * t))
        radii.append((4.2 * (1 - 0.75 * t) + 0.3) * (1 + 0.12 * math.sin(t * 17)))
    radii[-1] = 0
    bm = loft(path, radii, sides=8, ref=Vector((1, 0, 0)))
    a.add("Crystal", "glacier", bm, collide=True)
    a.add("Glow", "ice_glow", loft(path[:-2], [r * 0.35 for r in radii[:-2]], sides=6, ref=Vector((1, 0, 0))))
    a.add("Detail", "snow", rock(rng, (7, 7, 2.2), detail=2, rough=0.25, sink=0.5))


def frost_drift(a, rng):
    a.add("Detail", "snow", rock(rng, (12, 7, 2.6), detail=2, rough=0.22, sink=0.4), collide=True)
    a.add("Rock", "frost_rock", move(rock(rng, (2.5, 2.2, 2.0), detail=2, rough=0.3), (5, 1, 0.6)))


def frost_arch(a, rng):
    noisy_arch(a, rng, "glacier", 50, 30, 4.8, part="Crystal")
    for sx in (-1, 1):
        a.add("Detail", "snow", move(rock(rng, (8, 7, 3), detail=2, rough=0.25, sink=0.4), (sx * 25, 0, 0)))
    for i in range(6):
        h = rng.uniform(3, 7)
        ic = loft([(0, 0, 0), (0, 0, -h)], [0.6, 0], sides=4)
        p = arch_path(50, 30, 12)[2 + i]
        move(ic, (p[0], 0, p[2] - 4.5))
        a.add("Ice", "ice", ic)


def frost_pebbles(a, rng):
    for _ in range(5):
        r = rng.uniform(0.8, 2.0)
        a.add("Rock", "frost_rock", move(rock(rng, (r, r * 0.8, r * 0.7), detail=1, rough=0.3),
                                         (rng.uniform(-5, 5), rng.uniform(-5, 5), 0)))
    a.add("Detail", "snow", rock(rng, (6, 5, 0.8), detail=1, rough=0.2, sink=0.5))


# ---------------------------------------------------------------- Crystal Canyon

def crystal_cluster(a, rng):
    crystal_group(a, rng, 8, 2.2, (8, 15), 3.5)
    a.add("Rock", "canyon_rock", rock(rng, (5, 5, 2.2), detail=2, rough=0.35, sink=0.4), collide=True)


def crystal_big(a, rng):
    crystal_group(a, rng, 3, 4.5, (24, 30), 3.0)
    a.add("Rock", "canyon_rock", rock(rng, (7, 6.5, 3), detail=2, rough=0.35, cuts=2, sink=0.4), collide=True)
    a.collide.add("Crystal")


def crystal_rock(a, rng):
    base = rock(rng, (8, 7, 6), detail=3, rough=0.3, cuts=3)
    a.add("Rock", "canyon_rock", base, collide=True)
    zs = max(v.co.z for v in base.verts)
    crystal_group(a, rng, 5, 1.4, (5, 9), 3.0, c=(1, 0, zs - 1.5))


def crystal_geode(a, rng):
    shell = rock(rng, (7, 7, 6), detail=3, rough=0.25)
    bmesh.ops.bisect_plane(shell, geom=shell.verts[:] + shell.edges[:] + shell.faces[:], dist=1e-4,
                           plane_co=(0, -1.5, 0), plane_no=(0, -0.6, 0.8), clear_outer=True)
    inner = shell.copy()
    c = Vector((0, 0, 2.5))
    for v in inner.verts:
        v.co = c + (v.co - c) * 0.8
    bmesh.ops.reverse_faces(inner, faces=inner.faces[:])
    a.add("Rock", "canyon_rock", merge(shell, inner), collide=True)
    crystal_group(a, rng, 9, 1.0, (3.5, 6), 3.0, c=(0, 0.5, 1.2))


def crystal_shards(a, rng):
    for i in range(6):
        h = rng.uniform(1.5, 4)
        bm = prism(rng.uniform(0.3, 0.6), h)
        tilt(bm, rng, 35)
        move(bm, (rng.uniform(-4, 4), rng.uniform(-4, 4), -0.3))
        a.add("Crystal", "crystal", bm)
    a.add("Rock", "canyon_lt", rock(rng, (2, 1.8, 1.2), detail=1, rough=0.3))


def crystal_spire(a, rng):
    """Punkt orientacyjny: wielka iglica kryształu (~60 studs) na skalnej podstawie."""
    a.add("Rock", "canyon_rock", rock(rng, (16, 14, 7), detail=3, rough=0.32, cuts=3, sink=0.3), collide=True)
    crystal_group(a, rng, 6, 7.5, (52, 62), 7.0, c=(0, 0, 3))
    a.collide.add("Crystal")


def crystal_boulder(a, rng):
    base = rock(rng, (7, 5.5, 4.8), detail=3, rough=0.33, cuts=3)
    a.add("Rock", "canyon_rock", base, collide=True)
    a.add("Detail", "canyon_lt", cap_top(base, frac=0.75, thick=1.03))


# ---------------------------------------------------------------- Nebula Plateau

def nebula_hoodoo(a, rng):
    h = 0
    key = ["sand", "salt"]
    for i in range(4):
        s = 3.4 - i * 0.35 + rng.uniform(-0.3, 0.3)
        bm = rock(rng, (s, s * 0.9, 2.2), detail=2, rough=0.2, sink=0.0)
        move(bm, (rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), h))
        a.add("Rock" if i % 2 == 0 else "Detail", key[i % 2], bm, collide=i == 0)
        h += 3.4
    cap = rock(rng, (6.5, 5.5, 2.4), detail=2, rough=0.3, cuts=2, sink=0.0)
    move(cap, (0.5, 0, h))
    a.add("Rock", "sand", cap)
    a.add("Glow", "spore", move(ico(0.6, (0, 0, 0), sub=1), (2.5, -4.6, h + 0.4)))


def nebula_mesa(a, rng):
    h = 0
    for i in range(5):
        s = 12 - i * 2.0
        bm = rock(rng, (s, s * 0.8, 1.9), detail=2, rough=0.18, sink=0.0, flat=1.0)
        move(bm, (rng.uniform(-1, 1), rng.uniform(-1, 1), h))
        a.add("Rock" if i % 2 == 0 else "Detail", "sand" if i % 2 == 0 else "salt", bm, collide=i < 2)
        h += 3.2
    a.collide.add("Detail")


def nebula_spores(a, rng):
    for i in range(7):
        h = rng.uniform(2, 6)
        ang = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0, 4)
        x, y = math.cos(ang) * d, math.sin(ang) * d
        tx, ty = x + rng.uniform(-0.6, 0.6), y + rng.uniform(-0.6, 0.6)
        stalk = loft([(x, y, -0.3), (tx, ty, h)], [0.35, 0.2], sides=5)
        a.add("Rock", "sand", stalk)
        a.add("Glow", "spore", ico(rng.uniform(0.6, 1.1), (tx, ty, h + 0.5), sub=1))
    a.add("Detail", "salt", rock(rng, (5, 5, 1.0), detail=1, rough=0.25, sink=0.5))


def nebula_floatrock(a, rng):
    """Lewitująca skała nad świecącym pierścieniem (kotwiczona — efekt wizualny)."""
    r = rock(rng, (6, 5, 4), detail=3, rough=0.3, cuts=2, sink=0.0)
    for v in r.verts:  # spód zwężony w szpic
        if v.co.z < 2:
            f = max(0.25, v.co.z / 2)
            v.co.x *= f
            v.co.y *= f
    move(r, (0, 0, 9))
    a.add("Rock", "sand", r)
    a.add("Glow", "nebula_glow", torus(4.2, 0.28, Matrix.Translation((0, 0, 1.0)), seg=24, sides=4))
    a.add("Detail", "salt", rock(rng, (5.5, 5.5, 1.0), detail=2, rough=0.2, sink=0.4), collide=True)
    for k in range(3):
        ang = k * 2 * math.pi / 3
        a.add("Rock", "sand", move(rock(rng, (0.9, 0.8, 0.7), detail=1, rough=0.3, sink=0), (math.cos(ang) * 6.5, math.sin(ang) * 6.5, 6 + k)))


def nebula_boulder(a, rng):
    base = rock(rng, (7, 6, 4.5), detail=3, rough=0.28, cuts=2)
    a.add("Rock", "sand", base, collide=True)
    a.add("Detail", "salt", cap_top(base, frac=0.6, thick=1.03))


def nebula_monolith(a, rng):
    """Punkt orientacyjny: pierścień z monolitów z runami Neon (~45 studs)."""
    a.add("Detail", "salt", rock(rng, (24, 24, 2.5), detail=2, rough=0.15, sink=0.5), collide=True)
    for k in range(7):
        ang = k * 2 * math.pi / 7
        h = rng.uniform(20, 30) if k else 44
        R = 15 if k else 0
        pts = []
        for dz, s in ((0, 1.0), (h, 0.7)):
            for sx, sy in ((-2.6, -1.4), (2.6, -1.4), (2.6, 1.4), (-2.6, 1.4)):
                pts.append((sx * s + rng.uniform(-0.3, 0.3), sy * s, dz))
        pts.append((0, 0, h + 3))
        m = hull(pts)
        m.transform(Matrix.Rotation(ang + math.pi / 2, 4, "Z"))
        move(m, (math.cos(ang) * R, math.sin(ang) * R, -1))
        a.add("Rock", "sand", m, collide=True)
        for j in range(3):
            rune = box(0.4, 0.3, 2.2)
            rune.transform(Matrix.Rotation(ang + math.pi / 2, 4, "Z"))
            n = Vector((math.cos(ang), math.sin(ang), 0)) if k else Vector((0, -1, 0))
            move(rune, Vector((math.cos(ang) * R, math.sin(ang) * R, h * (0.3 + j * 0.2))) - n * (1.5 if k else 1.6))
            a.add("Glow", "nebula_glow", rune)


def nebula_pebbles(a, rng):
    for _ in range(5):
        r = rng.uniform(0.8, 2.0)
        a.add("Rock", "sand", move(rock(rng, (r, r * 0.8, r * 0.7), detail=1, rough=0.3),
                                   (rng.uniform(-5, 5), rng.uniform(-5, 5), 0)))


# ---------------------------------------------------------------- wspólne / orientacja / granica

def common_rock(a, rng):
    a.add("Rock", "slate", rock(rng, (6, 5, 4), detail=3, rough=0.3, cuts=3), collide=True)


def common_rockpile(a, rng):
    for i in range(4):
        s = rng.uniform(2.5, 4.5)
        a.add("Rock", "slate", move(rock(rng, (s, s * 0.8, s * 0.7), detail=2, rough=0.3, cuts=1),
                                    (rng.uniform(-5, 5), rng.uniform(-5, 5), 0)), collide=i == 0)


def beacon_tower(a, rng):
    """Wieża-latarnia (punkt orientacyjny między biomami, ~70 studs): kratownica + Neon na szczycie."""
    H = 64
    a.add("Rock", "slate", rock(rng, (9, 9, 2.5), detail=2, rough=0.2, sink=0.4), collide=True)
    legs = [(-4, -4), (4, -4), (4, 4), (-4, 4)]
    for (x, y) in legs:
        a.add("Frame", "metal_dk", loft([(x, y, 0), (x * 0.3, y * 0.3, H)], [0.6, 0.4], sides=6), collide=True)
    for k in range(8):
        z0, z1 = H * k / 8, H * (k + 1) / 8
        s0, s1 = 1 - 0.7 * k / 8, 1 - 0.7 * (k + 1) / 8
        for i in range(4):
            p0 = Vector((*legs[i], 0)) * 1
            p1 = Vector((*legs[(i + 1) % 4], 0))
            a0 = Vector((p0.x * s0, p0.y * s0, z0))
            b1 = Vector((p1.x * s1, p1.y * s1, z1))
            a.add("Frame2", "metal", loft([a0, b1], [0.22, 0.22], sides=4))
            a.add("Frame2", "metal", loft([Vector((p0.x * s1, p0.y * s1, z1)), Vector((p1.x * s1, p1.y * s1, z1))], [0.25, 0.25], sides=4))
    a.add("Frame", "metal_dk", zcyl(H, H + 1.2, 2.6, 10))
    a.add("Glow", "beacon", ico(1.8, (0, 0, H + 3.2), sub=2))
    a.add("Glow2", "beacon_c", torus(2.8, 0.25, Matrix.Translation((0, 0, H + 1.4)), seg=16, sides=4))
    for k in range(3):
        a.add("Glow2", "beacon_c", torus(4 * (1 - 0.7 * (k * 2 + 1) / 8) + 0.6, 0.15,
                                        Matrix.Translation((0, 0, H * (k * 2 + 1) / 8)), seg=12, sides=4))
    a.extra["light"] = [0, H + 3.2, 0]


def wreck(a, rng):
    """Wrak statku zbieracza (punkt orientacyjny, ~50 studs): kadłub wbity w ziemię, skrzydło, gruz."""
    path, radii = [], []
    for i in range(9):
        t = i / 8
        path.append((0, -24 + 48 * t, 1.5 + 9 * t * (1 - t) * 0.5))
        radii.append((5.5 * math.sin(math.pi * (0.15 + 0.7 * t)) + 0.8, 4.2 * math.sin(math.pi * (0.15 + 0.7 * t)) + 0.6))
    hull_bm = loft(path, radii, sides=10, ref=Vector((1, 0, 0)))
    hull_bm.transform(Matrix.Rotation(math.radians(-14), 4, "X") @ Matrix.Rotation(math.radians(8), 4, "Y"))
    move(hull_bm, (0, 0, 1.5))
    # rozdarcie: odcinamy kawałek kadłuba
    bmesh.ops.bisect_plane(hull_bm, geom=hull_bm.verts[:] + hull_bm.edges[:] + hull_bm.faces[:], dist=1e-4,
                           plane_co=(0, 14, 0), plane_no=(0.3, 1, 0.2), clear_outer=True)
    a.add("Rock", "rust", hull_bm, collide=True)
    wing = hull([(0, -6, 2), (0, 6, 2.5), (18, -2, 0.5), (18, 2, 0.8), (0, -6, 3), (0, 6, 3.4), (18, -2, 1.2), (18, 2, 1.4)])
    wing.transform(Matrix.Rotation(math.radians(-12), 4, "Y"))
    move(wing, (3, -4, 0.5))
    a.add("Frame2", "metal", wing, collide=True)
    a.add("Frame", "metal_dk", zcyl(-1, 0, 3.2, 10))
    _ = [a.add("Frame", "metal_dk", move(box(rng.uniform(1, 3), rng.uniform(1, 4), rng.uniform(0.4, 1.2)),
                                         (rng.uniform(-14, 14), rng.uniform(-20, 20), 0.2))) for _ in range(7)]
    eng = zcyl(-2.4, 2.4, 2.6, 12)
    eng.transform(Matrix.Rotation(math.pi / 2, 4, "X"))
    move(eng, (-5.5, -20, 3.5))
    a.add("Frame", "metal_dk", eng)
    a.add("Glow2", "beacon_c", move(zcyl(-0.2, 0.2, 2.0, 12).copy(), (0, 0, 0)))
    last = a.parts["Glow2"][1][-1]
    last.transform(Matrix.Rotation(math.pi / 2, 4, "X"))
    move(last, (-5.5, -22.5, 3.5))
    a.add("Detail", "slate", rock(rng, (10, 6, 2.0), detail=2, rough=0.3, sink=0.6))
    a.extra["fx"] = {"spark": [5.5, 3.5, -22.5]}


def shield_pylon(a, rng):
    """Pylon pola siłowego na granicy (r = 2000): kolumna, żebra, emiter Neon u góry."""
    a.add("Rock", "slate", rock(rng, (8, 8, 2.4), detail=2, rough=0.2, sink=0.4), collide=True)
    a.add("Frame", "metal_dk", zcyl(0, 36, 2.6, 8, r_top=1.6), collide=True)
    for k in range(5):
        a.add("Frame2", "metal", zcyl(4 + k * 6.5, 5 + k * 6.5, 3.0 - k * 0.22, 8))
        a.add("Glow", "shield", zcyl(5 + k * 6.5, 5.4 + k * 6.5, 2.85 - k * 0.22, 8))
    a.add("Frame2", "metal", zcyl(36, 38, 3.2, 8))
    a.add("Glow", "shield", ico(2.0, (0, 0, 40.5), sub=2))
    a.add("Glow", "shield", torus(3.4, 0.25, Matrix.Translation((0, 0, 40.5)), seg=16, sides=4))
    a.extra["light"] = [0, 40.5, 0]


# kategoria: small (bez kolizji), medium, large, landmark; biom (None = wspólny)
PROPS = {
    "Lava_Boulder": (lava_boulder, "medium", "LavaFields"), "Lava_Columns": (lava_columns, "large", "LavaFields"),
    "Lava_Spire": (lava_spire, "large", "LavaFields"), "Lava_Obsidian": (lava_obsidian, "medium", "LavaFields"),
    "Lava_Vent": (lava_vent, "medium", "LavaFields"), "Lava_Arch": (lava_arch, "landmark", "LavaFields"),
    "Lava_Pebbles": (lava_pebbles, "small", "LavaFields"),
    "Frost_Spikes": (frost_spikes, "medium", "FrostCrater"), "Frost_Boulder": (frost_boulder, "medium", "FrostCrater"),
    "Frost_IceBlock": (frost_iceblock, "medium", "FrostCrater"), "Frost_Pillar": (frost_pillar, "large", "FrostCrater"),
    "Frost_Drift": (frost_drift, "small", "FrostCrater"), "Frost_Arch": (frost_arch, "landmark", "FrostCrater"),
    "Frost_Pebbles": (frost_pebbles, "small", "FrostCrater"),
    "Crystal_Cluster": (crystal_cluster, "medium", "CrystalCanyon"), "Crystal_Big": (crystal_big, "large", "CrystalCanyon"),
    "Crystal_Rock": (crystal_rock, "medium", "CrystalCanyon"), "Crystal_Geode": (crystal_geode, "medium", "CrystalCanyon"),
    "Crystal_Shards": (crystal_shards, "small", "CrystalCanyon"), "Crystal_Spire": (crystal_spire, "landmark", "CrystalCanyon"),
    "Crystal_Boulder": (crystal_boulder, "medium", "CrystalCanyon"),
    "Nebula_Hoodoo": (nebula_hoodoo, "large", "NebulaPlateau"), "Nebula_Mesa": (nebula_mesa, "large", "NebulaPlateau"),
    "Nebula_Spores": (nebula_spores, "small", "NebulaPlateau"), "Nebula_FloatRock": (nebula_floatrock, "medium", "NebulaPlateau"),
    "Nebula_Boulder": (nebula_boulder, "medium", "NebulaPlateau"), "Nebula_Monolith": (nebula_monolith, "landmark", "NebulaPlateau"),
    "Nebula_Pebbles": (nebula_pebbles, "small", "NebulaPlateau"),
    "Common_Rock": (common_rock, "medium", None), "Common_RockPile": (common_rockpile, "medium", None),
    "Beacon_Tower": (beacon_tower, "landmark", None), "Wreck": (wreck, "landmark", None),
    "Shield_Pylon": (shield_pylon, "landmark", None),
}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    only = None
    for arg in ARGS:
        if arg.startswith("--only="):
            only = arg.split("=", 1)[1].split(",")
    names = [n for n in PROPS if only is None or n in only]
    meta, all_obs, layout = {}, [], {}
    for i, name in enumerate(names):
        fn, cat, biome = PROPS[name]
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
        a = Asset(name, PAL)
        fn(a, rng_for(name))
        if cat == "small":
            a.collide.clear()
        obs = a.build(coll, tile=8.0)
        m = a.meta(obs)
        m["category"], m["biome"] = cat, biome
        m["ok"] = m["tris"] <= BUDGET[cat]
        meta[name] = m
        all_obs += list(obs.values())
        layout[name] = list(obs.values())
        print(f"{name}: {m['tris']} tris ok={m['ok']}")
    export_fbx(HERE / "props.fbx", all_obs)
    (HERE / "props_meta.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "props.blend"))
    if "--render" in ARGS:
        # siatka podglądu: wiersz = biom
        rows = {"LavaFields": 0, "FrostCrater": 1, "CrystalCanyon": 2, "NebulaPlateau": 3, None: 4}
        col_i = {k: 0 for k in rows}
        for name, obs in layout.items():
            b = PROPS[name][2]
            for ob in obs:
                ob.location = (col_i[b] * 70, rows[b] * 75, 0)
            col_i[b] += 1
        setup_render(1920, 1200)
        frame_camera(all_obs, direction=(0.0, -0.8, 1.0), lens=35, margin=0.78)
        bpy.context.scene.render.filepath = str(IMG / "T15 propsy.png")
        bpy.ops.render.render(write_still=True)
    print("PROPS_DONE")


main()
