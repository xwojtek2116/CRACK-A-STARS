"""build_item.py — modele łupu (T21: Iron, Lava, Frost, Geode; T22/T23 dopisują kolejne moduły rodzajów).

Uruchom:
  E:\\blender\\blender.exe -b --factory-startup -P art/items/build_item.py -- [--themes Iron,Lava] [--only iron_core]
      [--render] [--sketch] [--icons] [--no-export]

Szkielet rzadkości (Styl graficzny, decyzje T21): Common kamyk → Uncommon odłamek → Rare klaster → Epic rdzeń w klatce →
Legendary kula z pierścieniami → Mythic serce z odłamkami. Każdy przedmiot ma akcent z nazwy (sztabka, magnes, …).
Styl: chunky, fazy, flat shading, dużo emisji. Kolory zapieczone (paleta motywu z Themes.json + dodatki modułu).

Układ: środek przedmiotu = (0, 0, 0), Z w górę, największy wymiar ≈ 2 (gra i tak skaluje do ITEM_MAX_SIZE × rzadkość).
Blender (x, y, z) → Roblox (−x, z, y).
Części = osobne meshe `<itemId>_<Część>`, jeden materiał na część. Role animacji (klient, ItemFx):
  Spin*  — obrót wokół własnego środka (oś + stopnie/s w meta),
  Orbit* — obrót wokół środka przedmiotu (pionowa oś, odłamki krążą),
  Pulse* — pulsowanie skali i jasności (serca Mythic).
Wyjście: art/items/<theme>/items_<theme>.fbx + .blend, art/items/items_meta.json,
  vault/_img/T21 lup <Theme>.png (--render), T21 lup <Theme> sylwetki.png (--sketch), art/ui/items/<id>.png (--icons).
"""

import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "game" / "src" / "shared" / "Config" / "Data"
OUT = ROOT / "art" / "items"
IMG = ROOT / "vault" / "_img"
ICONS = ROOT / "art" / "ui" / "items"
ITEMS = json.loads((DATA / "Items.json").read_text(encoding="utf-8"))["items"]
THEMES = json.loads((DATA / "Themes.json").read_text(encoding="utf-8"))["themes"]
RAR = json.loads((DATA / "Rarities.json").read_text(encoding="utf-8"))
BUDGET = 2000
# Rozmiar na postumencie względem ITEM_MAX_SIZE (decyzja T21) — w grze: BaseConfig.ITEM_RARITY_SCALE.
SIZE = {"Common": 0.6, "Uncommon": 0.72, "Rare": 0.85, "Epic": 1.0, "Legendary": 1.15, "Mythic": 1.3}
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def to_roblox(v):
    return [round(-v[0], 4), round(v[2], 4), round(v[1], 4)]


# ---------------------------------------------------------------- palety motywów
# klucz → (kolor, materiał Roblox). Neon = świeci (emisja, Tint w grze). body/dark/glow z Themes.json.

def theme_pal(theme):
    t = THEMES[theme]
    pal = {"body": (t["color"], "Metal"), "dark": (t["shell"], "Metal"), "glow": (t["glow"], "Neon")}
    pal.update(EXTRA_PAL.get(theme, {}))
    return pal


EXTRA_PAL = {
    "Iron": {
        "body": ("#9A9AA6", "Metal"), "dark": ("#3A3A40", "Metal"), "steel": ("#C4CAD6", "Metal"),
        "rust": ("#8A4B2A", "CorrodedMetal"), "rust_lt": ("#B5672F", "CorrodedMetal"),
        "magnet": ("#D23A3A", "SmoothPlastic"), "glow": ("#FF9A3C", "Neon"), "hot": ("#FFD27A", "Neon"),
        "field": ("#FF6A2A", "Neon"),
    },
    "Lava": {
        "basalt": ("#1C1412", "Basalt"), "basalt_lt": ("#3A2A26", "Basalt"), "obsidian": ("#2A0E14", "Glass"),
        "ember": ("#C8401A", "SmoothPlastic"), "magma": ("#FF5A1F", "Neon"), "glow": ("#FFB347", "Neon"),
        "hot": ("#FFE08A", "Neon"),
    },
    "Frost": {
        "ice": ("#B9D4E6", "Ice"), "ice_dk": ("#7FB6DA", "Ice"), "snow": ("#F4FAFF", "Snow"),
        "glow": ("#E6FBFF", "Neon"), "cyan": ("#7FD8FF", "Neon"), "aurora_g": ("#6CFFB8", "Neon"),
        "aurora_v": ("#B98CFF", "Neon"),
    },
    "Geode": {
        "rock": ("#5B4A3E", "Rock"), "rock_dk": ("#3E322A", "Rock"), "amethyst": ("#B06BFF", "Glass"),
        "amethyst_dk": ("#7A3CC8", "Glass"), "quartz": ("#EDE4FA", "Glass"), "glow": ("#E3C4FF", "Neon"),
        "violet": ("#B06BFF", "Neon"),
    },
}


# ---------------------------------------------------------------- geometria (wzorzec: art/tools/build_tools.py)

def bev(bm, off, angle=30):
    bm.normal_update()
    edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0) > math.radians(angle)]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=off, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)
    return bm


def cyl(r1, r2, depth, seg, M=Matrix()):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth, matrix=M)
    return bm


def box(sx, sy, sz, c=(0, 0, 0), rot=None):
    bm = bmesh.new()
    M = Matrix.Translation(c) @ (rot or Matrix()) @ Matrix.Diagonal((sx, sy, sz, 1))
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    return bm


def ico(r, c=(0, 0, 0), sub=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r, matrix=Matrix.Translation(c))
    return bm


def hull(points):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in points]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list({v for v in res["geom_interior"] + res["geom_unused"] if isinstance(v, bmesh.types.BMVert)})
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def loft(path, radii, sides=6, ref=X, cap=True, closed=False, phase=0.0):
    bm = bmesh.new()
    rings = []
    n = len(path)
    pts = [Vector(p) for p in path]
    for i, p in enumerate(pts):
        if closed:
            t = (pts[(i + 1) % n] - pts[i - 1]).normalized()
        else:
            t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        a = ref - t * ref.dot(t)
        if a.length < 1e-5:
            a = Z - t * t.z
            if a.length < 1e-5:
                a = Y - t * t.y
        a.normalize()
        b = t.cross(a)
        r = radii[i]
        rx, ry = (r, r) if not isinstance(r, (tuple, list)) else r
        if max(rx, ry) < 1e-4:
            rings.append([bm.verts.new(p)])
            continue
        rings.append([bm.verts.new(p + a * math.cos(2 * math.pi * k / sides + phase) * rx
                                   + b * math.sin(2 * math.pi * k / sides + phase) * ry) for k in range(sides)])
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for r0, r1 in pairs:
        if len(r0) == 1 and len(r1) == 1:
            continue
        if len(r0) == 1:
            for k in range(sides):
                bm.faces.new((r0[0], r1[k], r1[(k + 1) % sides]))
        elif len(r1) == 1:
            for k in range(sides):
                bm.faces.new((r0[(k + 1) % sides], r0[k], r1[0]))
        else:
            for k in range(sides):
                k1 = (k + 1) % sides
                bm.faces.new((r0[k], r0[k1], r1[k1], r1[k]))
    if cap and not closed:
        if len(rings[0]) > 1:
            bm.faces.new(rings[0][::-1])
        if len(rings[-1]) > 1:
            bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def torus(R, r, M=Matrix(), seg=32, sides=6, a0=0.0, a1=2 * math.pi):
    full = abs(a1 - a0 - 2 * math.pi) < 1e-6
    n = seg if full else max(4, seg)
    step = (a1 - a0) / (n if full else n - 1)
    pts = [(R * math.cos(a0 + step * i), R * math.sin(a0 + step * i), 0) for i in range(n)]
    bm = loft(pts, [r] * len(pts), sides=sides, ref=Z, closed=full)
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm


def plate(pts, th, x=0.0):
    """Płyta z obrysu w płaszczyźnie Y-Z, grubość (połowa) wzdłuż X."""
    bm = bmesh.new()
    L = [bm.verts.new((x - t, y, z)) for (y, z), t in zip(pts, th)]
    R = [bm.verts.new((x + t, y, z)) for (y, z), t in zip(pts, th)]
    n = len(pts)
    bm.faces.new(L[::-1])
    bm.faces.new(R)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((L[i], L[j], R[j], R[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def star_pts(r_out, r_in, n=5, rot=math.pi / 2):
    return [((r_out if i % 2 == 0 else r_in) * math.cos(rot + math.pi * i / n),
             (r_out if i % 2 == 0 else r_in) * math.sin(rot + math.pi * i / n)) for i in range(n * 2)]


def spiky(r, c=(0, 0, 0), spike=1.6, sub=2):
    bm = ico(r, (0, 0, 0), sub=sub)
    for v in bm.verts:
        if len(v.link_edges) == 5:
            v.co *= spike
    bmesh.ops.translate(bm, vec=c, verts=bm.verts)
    return bm


def rock(r, rng, c=(0, 0, 0), sub=1, jit=0.18, scale=(1, 1, 1)):
    """Bryła skały: icosphere z losowym promieniem wierzchołków."""
    bm = ico(1.0, (0, 0, 0), sub=sub)
    for v in bm.verts:
        v.co *= r * (1 + rng.uniform(-jit, jit))
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
    bmesh.ops.translate(bm, vec=c, verts=bm.verts)
    return bm


def xform(bm, M):
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm


def align(n):
    return Z.rotation_difference(Vector(n).normalized()).to_matrix().to_4x4()


def surf(bm, d, c=(0, 0, 0)):
    """Punkt i normalna powierzchni bryły w kierunku d od punktu c."""
    bm.normal_update()
    tree = BVHTree.FromBMesh(bm)
    d = Vector(d).normalized()
    loc, n, _, _ = tree.ray_cast(Vector(c) + d * 20, -d)
    if loc is None:
        return Vector(c), d
    return loc, n


def bm_append(dst, src):
    me = bpy.data.meshes.new("_tmp")
    src.to_mesh(me)
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)


def dirs_on_sphere(n, rng, z_min=-1.0, z_max=1.0):
    out = []
    for i in range(n):
        z = z_min + (z_max - z_min) * (i + 0.5) / n
        a = i * 2.39996 + rng.uniform(-0.3, 0.3)
        s = math.sqrt(max(0.0, 1 - z * z))
        out.append(Vector((s * math.cos(a), s * math.sin(a), z)))
    return out


# ---------------------------------------------------------------- budowniczy przedmiotu

class Item:
    def __init__(self, item):
        self.id = item["id"]
        self.name = item["name"]
        self.theme = item["theme"]
        self.rarity = item["rarity"]
        self.pal = theme_pal(self.theme)
        self.parts = {}  # część → [klucz palety, [bmesh…]]
        self.anim = {}  # część → {"type": spin|orbit|pulse, ...}
        self.particles = []
        self.rng = random.Random(sum(map(ord, self.id)) * 7919)

    def add(self, part, key, bm, bevel=0.0, angle=30):
        if bevel:
            bev(bm, bevel, angle)
        if part in self.parts and self.parts[part][0] != key:  # inny materiał → osobna część (Glow + GlowHot)
            assert not part.startswith(("Spin", "Orbit", "Pulse")), f"{self.id}_{part}: dwa materiały w animowanej części"
            part = part + key[:1].upper() + key[1:].replace("_", "")
        slot = self.parts.setdefault(part, [key, []])
        slot[1].append(bm)
        return bm

    def spin(self, part, axis, speed):
        self.anim[part] = {"type": "spin", "axis": Vector(axis).normalized(), "speed": speed}

    def orbit(self, part, speed, bob=0.0):
        self.anim[part] = {"type": "orbit", "axis": Z, "speed": speed, "bob": bob}

    def pulse(self, part, amount=0.08, rate=1.2):
        self.anim[part] = {"type": "pulse", "amount": amount, "rate": rate}

    # --- detale wspólne dla rodzajów
    def dents(self, part, key, target, n, size, z_min=-0.6, z_max=0.9, depth=0.05):
        """Okrągłe wgniecenia/łaty na powierzchni bryły (ciemniejsze dyski)."""
        for d in dirs_on_sphere(n, self.rng, z_min, z_max):
            loc, nn = surf(target, d)
            s = size * self.rng.uniform(0.75, 1.2)
            disc = cyl(s, s * 0.8, depth, 7, Matrix.Translation(loc - nn * depth * 0.2) @ align(nn))
            self.add(part, key, disc)

    def seam(self, part, key, target, d0, d1, r=0.035, steps=7, zig=0.12, lift=0.006):
        """Świecąca szczelina po powierzchni od kierunku d0 do d1, zygzakiem."""
        d0, d1 = Vector(d0).normalized(), Vector(d1).normalized()
        pts = []
        for i in range(steps):
            u = i / (steps - 1)
            d = d0.lerp(d1, u).normalized()
            if 0 < i < steps - 1:
                side = d.cross(d1 - d0)
                if side.length > 1e-5:
                    d = (d + side.normalized() * zig * (1 if i % 2 else -1) * self.rng.uniform(0.5, 1.0)).normalized()
            loc, nn = surf(target, d)
            pts.append(loc + nn * lift)
        rad = [r * (0.35 + 0.65 * math.sin(math.pi * (i / (steps - 1)) * 0.98 + 0.02)) for i in range(steps)]
        rad[0] = rad[-1] = 0.0
        self.add(part, key, loft(pts, rad, sides=4))

    def rivets(self, part, key, pts_normals, r=0.05):
        for loc, nn in pts_normals:
            self.add(part, key, xform(ico(r, (0, 0, 0), sub=1), Matrix.Translation(loc) @ Matrix.Diagonal((1, 1, 0.6, 1)) @ align(nn)))

    def shards_orbit(self, part, key, n, R, size, z=0.0, glow_part=None, glow_key=None, speed=30, tilt=0.12):
        """Odłamki skały krążące wokół przedmiotu (rola Orbit), opcjonalnie z żarzącym się rdzeniem."""
        for i in range(n):
            a = 2 * math.pi * i / n + self.rng.uniform(-0.2, 0.2)
            c = Vector((R * math.cos(a), R * math.sin(a), z + math.sin(a * 2) * R * tilt))
            s = size * self.rng.uniform(0.75, 1.25)
            pts = [c + Vector((self.rng.uniform(-1, 1) * s, self.rng.uniform(-1, 1) * s * 0.7,
                               self.rng.uniform(-1, 1) * s * 1.2)) for _ in range(9)]
            self.add(part, key, hull(pts), bevel=s * 0.12)
            if glow_part:
                self.add(glow_part, glow_key, ico(s * 0.42, c, sub=1))
        self.orbit(part, speed, bob=0.05)
        if glow_part:
            self.orbit(glow_part, speed, bob=0.05)

    def build(self, coll):
        obs = {}
        for part, (key, bms) in self.parts.items():
            dst = bmesh.new()
            for b in bms:
                bm_append(dst, b)
                b.free()
            bmesh.ops.remove_doubles(dst, verts=dst.verts[:], dist=1e-5)
            bmesh.ops.triangulate(dst, faces=dst.faces[:])
            name = f"{self.id}_{part}"
            me = bpy.data.meshes.new(name)
            dst.to_mesh(me)
            dst.free()
            ob = bpy.data.objects.new(name, me)
            coll.objects.link(ob)
            me.materials.append(material(self.theme, key, self.pal))
            for p in me.polygons:
                p.use_smooth = False
            obs[part] = ob
        return obs


_MATS = {}


def material(theme, key, pal):
    mk = f"{theme}_{key}"
    if mk in _MATS:
        return _MATS[mk]
    hx, rbx = pal[key]
    m = bpy.data.materials.new(mk)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    c = lin(hex_rgb(hx))
    if rbx == "Neon":
        b.inputs["Base Color"].default_value = (0, 0, 0, 1)
        b.inputs["Emission Color"].default_value = (*c, 1)
        b.inputs["Emission Strength"].default_value = 6.0
    else:
        b.inputs["Base Color"].default_value = (*c, 1)
        b.inputs["Roughness"].default_value = {"Metal": 0.34, "SmoothPlastic": 0.3, "Glass": 0.08,
                                               "Ice": 0.2}.get(rbx, 0.8)
        b.inputs["Metallic"].default_value = 0.85 if rbx in ("Metal",) else (0.4 if rbx == "CorrodedMetal" else 0.0)
        if rbx in ("Glass", "Ice"):
            b.inputs["Emission Color"].default_value = (*c, 1)
            b.inputs["Emission Strength"].default_value = 0.35 if rbx == "Glass" else 0.15
    _MATS[mk] = m
    return m


# ---------------------------------------------------------------- IRON (Iron Meteorite: metal, wgniecenia, pomarańczowe szwy)

def iron_pebble(t):
    """Rusty Nugget — gruby, pordzewiały samorodek z jedną żarzącą się szczeliną."""
    rng = t.rng
    body = t.add("Body", "body", rock(0.85, rng, sub=1, jit=0.16, scale=(1.18, 0.95, 0.78)), bevel=0.09, angle=20)
    for d in ((0.6, -0.5, 0.6), (-0.7, 0.2, 0.5), (0.1, 0.8, -0.2)):
        loc, nn = surf(body, d)
        s = rng.uniform(0.2, 0.28)
        M = Matrix.Translation(loc - nn * 0.02) @ align(nn)
        patch = [M @ Vector((rng.uniform(-1, 1) * s, rng.uniform(-1, 1) * s, rng.uniform(0, 1) * 0.06)) for _ in range(8)]
        t.add("Rust", "rust", hull(patch), bevel=0.015)
    t.seam("Glow", "glow", body, (0.9, -0.4, 0.3), (0.1, -0.9, -0.1), r=0.05, steps=6)


def iron_shard(t):
    """Iron Chunk — kanciasty odłamek meteorytu z wgnieceniami i rozżarzoną szczeliną."""
    rng = t.rng
    pts = []
    for i in range(16):
        a = 2 * math.pi * i / 8 + rng.uniform(-0.25, 0.25)
        z = (-0.55 if i < 8 else 0.25) + rng.uniform(-0.15, 0.15)
        r = (0.62 if i < 8 else 0.5) * rng.uniform(0.8, 1.1)
        pts.append((r * math.cos(a) * 1.1, r * math.sin(a) * 0.8, z))
    pts += [(0.12, 0.05, 1.0), (-0.18, -0.06, 0.82), (0.05, 0.0, -0.85)]
    body = t.add("Body", "body", hull(pts), bevel=0.06, angle=25)
    t.dents("Dents", "dark", body, 6, 0.17, z_min=-0.5, z_max=0.7)
    t.seam("Glow", "glow", body, (0.8, -0.6, -0.4), (0.15, -0.9, 0.75), r=0.055, steps=8, zig=0.18)
    t.seam("Glow", "glow", body, (-0.7, 0.5, 0.2), (-0.2, 0.9, -0.6), r=0.04, steps=5)
    for k in range(2):  # odpryski u podstawy
        c = Vector((0.75 * (1 if k else -1), 0.35 * (1 if k else -0.5), -0.5))
        t.add("Rust", "rust", hull([c + Vector((rng.uniform(-1, 1) * 0.16, rng.uniform(-1, 1) * 0.14,
                                                rng.uniform(-1, 1) * 0.13)) for _ in range(8)]), bevel=0.02)


def ingot(sx, sy, sz, c, rot=0.0):
    """Sztabka: ścięty prostopadłościan (trapez), fazowany."""
    pts = []
    for zz, k in ((-sz / 2, 1.0), (sz / 2, 0.78)):
        for xs in (-1, 1):
            for ys in (-1, 1):
                pts.append((xs * sx / 2 * k, ys * sy / 2 * (k * 0.92 if zz > 0 else 1), zz))
    bm = hull(pts)
    bev(bm, 0.045, 20)
    return xform(bm, Matrix.Translation(c) @ Matrix.Rotation(rot, 4, "Z"))


def iron_crystal(t):
    """Meteor Ingot — stos trzech sztabek z meteorytu, górna rozgrzana z wybitą gwiazdą."""
    rng = t.rng
    t.add("Dark", "dark", ingot(1.5, 0.62, 0.42, (0, -0.36, -0.34), 0.03))
    t.add("Dark", "dark", ingot(1.5, 0.62, 0.42, (0.04, 0.36, -0.34), -0.04))
    top = t.add("Body", "body", ingot(1.5, 0.66, 0.46, (0, 0, 0.1), 0.0))
    # wybita gwiazda na wierzchu górnej sztabki
    sp = star_pts(0.22, 0.1)
    st = plate(sp, [0.03] * len(sp))
    xform(st, Matrix.Translation((0, 0, 0.335)) @ Matrix.Rotation(math.pi / 2, 4, "Y"))
    t.add("Glow", "glow", st)
    # rozżarzone krawędzie górnej sztabki + żyłki na dolnych
    for ys in (-1, 1):
        t.add("Glow", "glow", loft([(-0.58, ys * 0.255, 0.33), (0, ys * 0.265, 0.335), (0.58, ys * 0.255, 0.33)],
                                   [0.0, 0.03, 0.0], sides=4))
    for y in (-0.36, 0.36):
        t.add("Glow", "glow", loft([(-0.6, y - 0.32, -0.3), (-0.1, y - 0.325, -0.36), (0.45, y - 0.32, -0.28)],
                                   [0.0, 0.028, 0.0], sides=4))
    # samorodki obok stosu (klaster)
    for c in ((0.95, -0.25, -0.42), (-0.92, 0.3, -0.45), (0.7, 0.55, -0.48)):
        t.add("Rust", "rust", rock(0.17, rng, c, sub=1, jit=0.2), bevel=0.03, angle=20)
    # stempel: sylwetka meteoru z boku (żarząca się kreska)
    t.add("Glow", "glow", loft([(0.15, -0.34, 0.05), (-0.05, -0.345, 0.15), (-0.3, -0.34, 0.2)], [0.045, 0.02, 0.0],
                               sides=4))


def horseshoe(R, r, M, legs=0.35, sides=6):
    """Magnes podkowa: łuk 180° + proste ramiona w płaszczyźnie XZ (otwarty w −Z). Zwraca (korpus, końcówki)."""
    pts = [(R * math.cos(a), 0, R * math.sin(a)) for a in [math.pi * i / 10 for i in range(11)]]
    path = [(R, 0, -legs)] + pts + [(-R, 0, -legs)]
    body = loft(path, [r] * len(path), sides=sides, ref=Y)
    tips = bmesh.new()
    for xs in (-1, 1):
        bm_append(tips, bev(box(r * 2.25, r * 2.25, 0.2, (xs * R, 0, -legs - 0.1)), 0.02))
    return xform(body, M), xform(tips, M)


def iron_core(t):
    """Magnet Core — rozżarzony rdzeń meteorytu w żelaznych płytach, w klatce z dwóch magnesów podków (Spin)."""
    rng = t.rng
    t.add("Core", "glow", spiky(0.4, spike=1.35))
    # skorupa rdzenia: 6 płyt z przerwami (widać żar)
    for d in [Vector(v) for v in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1))]:
        M = Matrix.Translation(d * 0.36) @ align(d)
        t.add("Shell", "dark", xform(rock(0.2, rng, sub=1, jit=0.12, scale=(1.25, 1.25, 0.45)), M), bevel=0.03, angle=20)
    for a in range(4):  # nity w szczelinach
        d = Vector((math.cos(a * math.pi / 2 + math.pi / 4), math.sin(a * math.pi / 2 + math.pi / 4), 0.55)).normalized()
        t.add("Steel", "steel", ico(0.06, d * 0.47, sub=1))
    # klatka: dwie podkowy skrzyżowane pod kątem prostym
    for rot in (0.0, math.pi / 2):
        M = Matrix.Rotation(rot, 4, "Z") @ Matrix.Translation((0, 0, 0.12))
        body, tips = horseshoe(0.8, 0.12, M, legs=0.45)
        t.add("SpinCage", "magnet", body)
        t.add("SpinTips", "steel", tips)
    # łuki pola magnetycznego (pomarańczowe)
    for rot in (math.pi / 4, 3 * math.pi / 4):
        M = Matrix.Rotation(rot, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X")
        t.add("SpinField", "field", torus(0.98, 0.014, M, seg=10, sides=4, a0=math.radians(215), a1=math.radians(325)))
        t.add("SpinField", "field", torus(0.98, 0.014, M, seg=10, sides=4, a0=math.radians(35), a1=math.radians(145)))
    for p in ("SpinCage", "SpinTips", "SpinField"):
        t.spin(p, Z, 35)


def iron_orb(t):
    """Titan Alloy — kula ze stopu z nitowanymi pasami i świecącymi szwami, dwa pierścienie i krążące odłamki."""
    rng = t.rng
    t.add("Body", "steel", ico(0.62, sub=2))
    for z, s in ((0.0, 1.0),):
        t.add("Band", "dark", cyl(0.645 * s, 0.645 * s, 0.17, 16, Matrix.Translation((0, 0, z))), bevel=0.02)
    t.add("Band", "dark", cyl(0.645, 0.645, 0.15, 16, Matrix.Rotation(math.pi / 2, 4, "X")), bevel=0.02)
    pn = []
    for a in range(8):
        ang = a * math.pi / 4 + math.pi / 8
        d = Vector((math.cos(ang), math.sin(ang), 0))
        pn.append((d * 0.66, d))
    for a in range(6):
        ang = a * math.pi / 3 + math.pi / 6
        d = Vector((math.cos(ang), 0, math.sin(ang)))
        pn.append((d * 0.66, d))
    t.rivets("Rivets", "body", pn, r=0.045)
    for zz in (0.36, -0.36):  # świecące szwy (zwrotniki)
        rr = math.sqrt(0.62 ** 2 - zz ** 2) + 0.01
        t.add("Glow", "glow", torus(rr, 0.025, Matrix.Translation((0, 0, zz)), seg=20, sides=4))
    t.add("Glow", "glow", ico(0.13, (0, -0.62, 0.0), sub=1))  # „oko” rdzenia
    t.add("Glow", "glow", ico(0.13, (0, 0.62, 0.0), sub=1))
    # dwa przechylone pierścienie z węzłami (obracają się w przeciwne strony)
    for name, tilt, R, speed in (("SpinRingA", 38, 0.98, 45), ("SpinRingB", -44, 1.08, -32)):
        M = Matrix.Rotation(math.radians(tilt), 4, "X") @ Matrix.Rotation(math.radians(tilt * 0.6), 4, "Y")
        t.add(name, "body", torus(R, 0.06, M, seg=28, sides=4))
        for k in range(3):
            a = 2 * math.pi * k / 3
            c = M @ Vector((R * math.cos(a), R * math.sin(a), 0))
            t.add(name + "Glow", "hot", ico(0.085, c, sub=1))
        t.spin(name, M @ Z, speed)
        t.spin(name + "Glow", M @ Z, speed)
    t.shards_orbit("Orbit", "dark", 3, 1.22, 0.12, z=-0.15, glow_part="OrbitGlow", glow_key="glow", speed=24)
    t.particles.append({"part": "Body", "color": t.pal["glow"][0], "rate": 4, "size": 0.18, "speed": 0.4,
                        "tex": "spark", "life": 1.2})


def heart_shape(rng, sx=1.0, sub=2):
    """Stylizowane serce: dwa płaty (otoczki wypukłe) zbiegające się w szpic — wcięcie u góry zostaje."""
    bm = bmesh.new()
    for xs in (-1, 1):
        lobe = ico(1.0, sub=sub)
        pts = [Vector((v.co.x * 0.46 + xs * 0.3, v.co.y * 0.4, v.co.z * 0.44 + 0.22)) for v in lobe.verts]
        lobe.free()
        pts += [Vector((0, 0, -0.82)), Vector((xs * 0.05, 0.08, -0.74)), Vector((xs * 0.05, -0.08, -0.74))]
        bm_append(bm, hull([p * sx for p in pts]))
    return bm


def iron_heart(t):
    """Ironheart Relic — żelazne serce-relikwia: płyty, nity, rozżarzone szwy, pulsujący klejnot,
    rury tętnic, przechylona aureola i krążące meteoryty z żarem."""
    rng = t.rng
    heart = t.add("Body", "body", heart_shape(rng))
    # pas przez serce z nitami
    for zz, w in ((-0.05, 0.13),):
        band = heart_shape(rng, 1.035)
        cut = bmesh.ops.bisect_plane(band, geom=band.verts[:] + band.edges[:] + band.faces[:], plane_co=(0, 0, zz + w),
                                     plane_no=(0, 0, 1), clear_outer=True)
        bmesh.ops.bisect_plane(band, geom=band.verts[:] + band.edges[:] + band.faces[:], plane_co=(0, 0, zz - w),
                               plane_no=(0, 0, -1), clear_outer=True)
        t.add("Band", "dark", band)
    pn = []
    for k in range(7):
        a = -math.pi / 2 + (k - 3) * 0.33
        d = Vector((math.cos(a), math.sin(a), 0.0))
        loc, nn = surf(heart, Vector((d.x, d.y, -0.05)), (0, 0, -0.05))
        pn.append((loc + nn * 0.03, nn))
    t.rivets("Rivets", "steel", pn, r=0.045)
    # rozżarzone szwy na przodzie (−Y) i z tyłu
    t.seam("Glow", "glow", heart, (-0.6, -0.8, 0.6), (-0.1, -1, -0.45), r=0.045, steps=8, zig=0.1)
    t.seam("Glow", "glow", heart, (0.65, -0.75, 0.55), (0.2, -1, 0.15), r=0.04, steps=6, zig=0.1)
    t.seam("Glow", "glow", heart, (0.5, 0.8, 0.5), (0.0, 1, -0.5), r=0.045, steps=7, zig=0.12)
    t.seam("Glow", "glow", heart, (-0.55, 0.8, 0.2), (-0.2, 1, -0.4), r=0.035, steps=5)
    # pulsujący klejnot w centrum (wystaje z przodu i z tyłu)
    gem = ico(0.2, sub=1)
    xform(gem, Matrix.Translation((0, 0, 0.1)) @ Matrix.Diagonal((1.0, 2.6, 1.2, 1)))
    t.add("PulseCore", "hot", gem)
    t.pulse("PulseCore", 0.12, 1.1)
    for d in ((0, -1, 0.15), (0, 1, 0.15)):  # oprawa klejnotu: pierścień, klejnot wystaje
        loc, nn = surf(heart, d)
        t.add("Socket", "dark", torus(0.21, 0.045, Matrix.Translation(loc) @ align(nn), seg=10, sides=4))
    # tętnice: trzy rury na szczycie z żarzącymi się wylotami
    for x, h, lean in ((-0.22, 0.42, -0.25), (0.08, 0.5, 0.05), (0.32, 0.34, 0.3)):
        path = [(x, 0.0, 0.45), (x + lean * 0.4, 0.02, 0.45 + h * 0.6), (x + lean, 0.0, 0.45 + h)]
        t.add("Pipes", "dark", loft(path, [0.1, 0.09, 0.09], sides=8, ref=Y))
        t.add("Pipes", "dark", cyl(0.12, 0.12, 0.06, 8, Matrix.Translation(path[-1])), bevel=0.015)
        t.add("Glow", "glow", cyl(0.07, 0.07, 0.02, 8, Matrix.Translation(Vector(path[-1]) + Vector((0, 0, 0.031)))))
    # aureola za sercem: przechylony pierścień z przerwami (Spin)
    M = Matrix.Translation((0, 0.05, 0.02)) @ Matrix.Rotation(math.radians(90), 4, "X")
    for k in range(6):
        a0 = k * math.pi / 3 + 0.12
        t.add("SpinHalo", "hot", torus(0.98, 0.03, M, seg=6, sides=4, a0=a0, a1=a0 + math.pi / 3 - 0.24))
        c = M @ Vector((0.98 * math.cos(a0 - 0.12), 0.98 * math.sin(a0 - 0.12), 0))
        t.add("SpinHalo", "hot", spiky(0.05, c, spike=1.8, sub=1))
    t.spin("SpinHalo", Y, 22)
    # krążące meteoryty z żarem
    t.shards_orbit("Orbit", "dark", 5, 1.15, 0.12, z=-0.3, glow_part="OrbitGlow", glow_key="glow", speed=36, tilt=0.15)
    t.particles.append({"part": "PulseCore", "color": t.pal["glow"][0], "rate": 12, "size": 0.3, "speed": 0.8,
                        "tex": "spark", "life": 1.4, "aura": True})
    t.particles.append({"part": "Body", "color": "#FFD27A", "rate": 6, "size": 0.16, "speed": 0.3, "tex": "glint",
                        "life": 1.6})


# ---------------------------------------------------------------- wspólne bryły (Lava, Frost, Geode)

def hex_crystal(c, d, L, r, tip=0.32, sides=6, base=0.9):
    """Kryształ: graniastosłup z ostrym szczytem wzdłuż kierunku d."""
    pts = []
    for z, rr in ((0.0, r * base), (L * (1 - tip), r)):
        for k in range(sides):
            a = 2 * math.pi * k / sides
            pts.append((rr * math.cos(a), rr * math.sin(a), z))
    pts.append((0, 0, L))
    return xform(hull(pts), Matrix.Translation(c) @ align(d))


def bipyramid(L, r, sides=6, mid=0.5):
    pts = [(r * math.cos(2 * math.pi * k / sides), r * math.sin(2 * math.pi * k / sides), z)
           for z in (-L * mid * 0.35, L * mid * 0.35) for k in range(sides)]
    pts += [(0, 0, -L * 0.5), (0, 0, L * 0.5)]
    return hull(pts)


def cracked(bm, normals, gap=0.06, center=(0, 0, 0)):
    """Rozbija bryłę płaszczyznami przez środek na kawałki i rozsuwa je na zewnątrz (szczeliny pokazują żar)."""
    import itertools
    pieces = []
    for signs in itertools.product((1, -1), repeat=len(normals)):
        p = bm.copy()
        for n, s in zip(normals, signs):
            bmesh.ops.bisect_plane(p, geom=p.verts[:] + p.edges[:] + p.faces[:], plane_co=center,
                                   plane_no=Vector(n).normalized() * s, clear_outer=True)
        if len(p.faces) < 3:
            p.free()
            continue
        bmesh.ops.holes_fill(p, edges=p.edges[:], sides=0)
        cen = sum((v.co for v in p.verts), Vector()) / len(p.verts)
        push = cen - Vector(center)
        if push.length > 1e-5:
            bmesh.ops.translate(p, vec=push.normalized() * gap, verts=p.verts)
        pieces.append((p, cen))
    bm.free()
    return pieces


def flame(base, h, w, lean, rng, sides=5):
    """Język ognia: zwężająca się, falująca rura."""
    pts, rad = [], []
    n = 6
    for i in range(n):
        u = i / (n - 1)
        pts.append((base[0] + lean * u ** 1.5 + math.sin(u * 5 + rng.uniform(0, 1)) * w * 0.25 * u,
                    base[1], base[2] + h * u))
        rr = w * (1 - u) ** 0.8 * (0.6 + 0.4 * math.sin(math.pi * min(1, u * 1.6)))
        rad.append((rr, rr * 0.65) if i < n - 1 else 0.0)
    return loft(pts, rad, sides=sides, ref=Y)


def drip(c, L, r):
    """Kropla magmy/lodu: kula zwężająca się w dół."""
    pts = [(c[0], c[1], c[2] - L * u) for u in (0, 0.35, 0.7, 1.0)]
    return loft(pts, [r * 0.7, r, r * 0.6, 0.0], sides=6, ref=X)


def ring_nodes(t, part, key, M, R, n, size, spiky_nodes=False):
    for k in range(n):
        a = 2 * math.pi * k / n
        c = M @ Vector((R * math.cos(a), R * math.sin(a), 0))
        t.add(part, key, spiky(size, c, spike=1.8, sub=1) if spiky_nodes else ico(size, c, sub=1))


def snowflake(c, R, th, M=Matrix()):
    """Płaska śnieżynka (6 ramion z gałązkami) w płaszczyźnie XY."""
    bm = bmesh.new()
    for k in range(6):
        a = k * math.pi / 3
        d = Vector((math.cos(a), math.sin(a), 0))
        bm_append(bm, loft([d * 0.0, d * R], [th, th * 0.6], sides=4, ref=Z))
        for s in (-1, 1):
            p0 = d * R * 0.55
            q = Vector((math.cos(a + s * 0.7), math.sin(a + s * 0.7), 0))
            bm_append(bm, loft([p0, p0 + q * R * 0.35], [th * 0.7, 0.0], sides=4, ref=Z))
    return xform(bm, Matrix.Translation(c) @ M)


def add_pieces(t, part, key, pieces, bevel=0.0):
    for p, _ in pieces:
        t.add(part, key, p, bevel=bevel)


# ---------------------------------------------------------------- LAVA (bazalt na magmie, żyły, kapiąca lawa)

def lava_pebble(t):
    """Magma Pebble — bazaltowy kamyk poprzecinany siecią żarzących się szczelin, kropla magmy."""
    body = t.add("Body", "basalt", rock(0.85, t.rng, sub=1, jit=0.2, scale=(1.12, 1.0, 0.78)), bevel=0.08, angle=20)
    t.seam("Glow", "magma", body, (0.9, -0.5, 0.4), (-0.2, -0.9, -0.3), r=0.05, steps=7, zig=0.16)
    t.seam("Glow", "magma", body, (0.2, -0.7, 0.7), (-0.6, 0.2, 0.75), r=0.04, steps=6, zig=0.14)
    t.seam("Glow", "magma", body, (-0.8, 0.3, 0.1), (-0.1, 0.9, -0.2), r=0.04, steps=5)
    loc, nn = surf(body, (0.5, -0.4, -0.75))
    t.add("Glow", "magma", drip(loc + Vector((0, 0, 0.05)), 0.32, 0.09))


def lava_shard(t):
    """Ember Shard — klinga z obsydianu na bazaltowym okruchu, żyła magmy i rozżarzony szpic."""
    rng = t.rng
    pts = [(xs * 0.3, ys * 0.15, -0.55) for xs in (-1, 1) for ys in (-1, 1)]
    pts += [(xs * 0.42 + rng.uniform(-0.05, 0.05), ys * 0.19, 0.15) for xs in (-1, 1) for ys in (-1, 1)]
    pts += [(0.12, 0.0, 1.05), (-0.1, 0.0, 0.62)]
    tilt = Matrix.Rotation(math.radians(-12), 4, "Y")
    shard = t.add("Body", "obsidian", xform(hull(pts), tilt), bevel=0.04, angle=25)
    tip = [tilt @ Vector(p) for p in ((0.12, 0.0, 1.07), (0.0, 0.08, 0.8), (0.0, -0.08, 0.8), (0.2, 0.0, 0.8), (-0.06, 0, 0.72))]
    t.add("Glow", "hot", hull(tip))
    t.seam("Glow", "magma", shard, tilt @ Vector((0.1, -1, -0.5)), tilt @ Vector((0.0, -1, 0.75)), r=0.05, steps=7, zig=0.1)
    t.seam("Glow", "magma", shard, tilt @ Vector((-0.1, 1, -0.4)), tilt @ Vector((0.05, 1, 0.7)), r=0.04, steps=6)
    t.add("Base", "basalt", rock(0.4, rng, (0.0, 0.0, -0.72), sub=1, jit=0.2, scale=(1.4, 1.1, 0.6)), bevel=0.05, angle=20)
    for c in ((0.5, -0.2, -0.82), (-0.45, 0.25, -0.8)):
        t.add("Glow", "magma", ico(0.08, c, sub=1))


def lava_crystal(t):
    """Cinder Crystal — klaster żarzących się kryształów wyrastających z bazaltu."""
    rng = t.rng
    base = t.add("Base", "basalt", rock(0.62, rng, (0, 0, -0.55), sub=1, jit=0.18, scale=(1.3, 1.05, 0.5)), bevel=0.06,
                 angle=20)
    spec = [((0, 0, -0.35), (0.05, 0, 1), 1.35, 0.24, "Crystal", "ember"),
            ((0.32, -0.12, -0.38), (0.55, -0.2, 1), 0.95, 0.18, "Crystal", "ember"),
            ((-0.3, 0.1, -0.38), (-0.6, 0.15, 1), 1.0, 0.18, "Crystal", "ember"),
            ((0.1, 0.32, -0.4), (0.15, 0.7, 1), 0.7, 0.13, "Glow", "magma"),
            ((-0.15, -0.3, -0.4), (-0.25, -0.75, 1), 0.65, 0.12, "Glow", "magma"),
            ((0.5, 0.25, -0.45), (0.8, 0.4, 0.8), 0.45, 0.1, "Glow", "magma")]
    for c, d, L, r, part, key in spec:
        t.add(part, key, hex_crystal(Vector(c), d, L, r))
    for c, d, L, r, part, key in spec[:3]:  # rozżarzone szpice dużych kryształów
        d = Vector(d).normalized()
        t.add("Tips", "hot", hex_crystal(Vector(c) + d * L * 0.7, d, L * 0.31, r * 0.72, tip=0.95))
    t.seam("Glow", "magma", base, (0.8, -0.6, 0.2), (-0.3, -0.9, -0.2), r=0.04, steps=6)


def lava_core(t):
    """Molten Core — kula magmy w popękanej skorupie bazaltu, w obracającej się klatce z bazaltowych żeber; kapie lawa."""
    rng = t.rng
    t.add("Core", "magma", ico(0.46, sub=2))
    t.add("CoreHot", "hot", spiky(0.3, spike=1.5))
    shell = rock(0.5, rng, sub=2, jit=0.06)
    add_pieces(t, "Shell", "basalt", cracked(shell, [(1, 0.2, 0.3), (-0.2, 1, 0.1), (0.3, -0.1, 1)], gap=0.12))
    for x, y in ((0.12, -0.1), (-0.2, 0.15), (0.05, 0.25)):
        t.add("Drips", "magma", drip((x, y, -0.48), rng.uniform(0.3, 0.45), 0.07))
    for k in range(3):  # klatka: 3 południki + równik z kolcami
        M = Matrix.Rotation(k * math.pi / 3, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X")
        t.add("SpinCage", "basalt_lt", torus(0.86, 0.05, M, seg=18, sides=5, a0=math.radians(-80), a1=math.radians(260)),
              bevel=0.0)
    t.add("SpinCage", "basalt_lt", torus(0.88, 0.07, Matrix(), seg=18, sides=5))
    t.add("SpinSeam", "magma", torus(0.88, 0.025, Matrix.Translation((0, 0, 0.065)), seg=18, sides=4))
    t.spin("SpinSeam", Z, 30)
    for k in range(6):
        a = k * math.pi / 3
        d = Vector((math.cos(a), math.sin(a), 0))
        t.add("SpinCage", "basalt_lt", hex_crystal(d * 0.9, d, 0.28, 0.07, tip=0.7, sides=4))
        t.add("SpinGlow", "glow", ico(0.06, d * 0.88 + Vector((0, 0, 0.09)), sub=1))
    t.add("SpinCage", "basalt_lt", ico(0.1, (0, 0, 0.88), sub=1))
    t.spin("SpinCage", Z, 30)
    t.spin("SpinGlow", Z, 30)


def lava_orb(t):
    """Phoenix Ember — żarzące się pióro feniksa w pierścieniu lawy z bazaltowymi okruchami."""
    rng = t.rng
    n = 9
    rach = []
    rotZ = Matrix.Rotation(math.radians(90), 4, "Z")
    for i in range(n):
        u = i / (n - 1)
        rach.append((0.2 * math.sin(u * math.pi * 0.9), 0, -0.7 + 1.68 * u))
    # wachlarz: segmenty (pęki promieni) po obu stronach osi z nacięciami — czytelna sylwetka pióra
    for side, wmax, key, part in ((-1, 0.46, "magma", "Feather"), (1, 0.38, "glow", "FeatherB")):
        for i in range(n - 2):
            u0, u1 = i / (n - 1), (i + 1.6) / (n - 1)
            x0, _, z0 = rach[i]
            x1, _, z1 = rach[min(i + 1, n - 1)]
            w = wmax * math.sin(math.pi * min(1.0, (u0 + 0.06) * 1.05)) ** 0.6 + 0.04
            tipz = z0 + (z1 - z0) * 1.9 + 0.08
            seg_pts = [(x0, z0 - 0.02), (x0 + side * w, tipz - 0.05), (x0 + side * w * 0.82, tipz + 0.06), (x1, z1 + 0.04)]
            if side > 0:
                seg_pts = seg_pts[::-1]
            t.add(part, key, xform(plate(seg_pts, [0.03] * 4), rotZ))
    t.add("FeatherTip", "hot", xform(plate([(rach[-1][0] - 0.12, rach[-1][2] - 0.1), (rach[-1][0] + 0.1, rach[-1][2] + 0.18),
                                             (rach[-1][0] + 0.1, rach[-1][2] - 0.12)], [0.035] * 3), rotZ))
    t.add("FeatherCore", "hot", xform(loft([(0, p[0], p[2]) for p in rach], [0.04] * (n - 1) + [0.0], sides=4), rotZ))
    left = [(p[0] - 0.4, p[2]) for p in rach]
    right = [(p[0] + 0.33, p[2]) for p in rach]
    t.add("Quill", "basalt", xform(loft([(0, 0.0, -0.75), (0, -0.02, -0.95), (0, -0.05, -1.08)], [0.05, 0.04, 0.0],
                                       sides=5), rotZ))
    for k in range(4):  # płomyki na końcach promieni
        i = 2 + k * 2
        x, z = (left if k % 2 else right)[i]
        t.add("Feather", "magma", xform(flame((0, x, z), 0.22, 0.06, 0.08 * (-1 if k % 2 else 1), rng), rotZ))
    M = Matrix.Rotation(math.radians(14), 4, "X") @ Matrix.Rotation(math.radians(-8), 4, "Y")
    t.add("SpinRing", "magma", torus(1.0, 0.07, M, seg=30, sides=5))
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.3
        c = M @ Vector((math.cos(a), math.sin(a), 0))
        t.add("SpinRingRock", "basalt", rock(0.11, rng, c, sub=1, jit=0.25, scale=(1.4, 1, 0.8)), bevel=0.02, angle=20)
    t.spin("SpinRing", M @ Z, 40)
    t.spin("SpinRingRock", M @ Z, 40)
    for k in range(3):
        a = 2 * math.pi * k / 3
        t.add("OrbitSparks", "hot", spiky(0.06, (1.25 * math.cos(a), 1.25 * math.sin(a), 0.35 * math.sin(a * 2)),
                                           spike=2.0, sub=1))
    t.orbit("OrbitSparks", -26, bob=0.08)
    t.particles.append({"part": "FeatherCore", "color": "#FFB347", "rate": 10, "size": 0.22, "speed": 0.9,
                        "tex": "spark", "life": 1.0, "up": True})


def lava_heart(t):
    """Inferno Heart — serce z popękanych płyt bazaltu na pulsującej magmie, korona płomieni, kapiąca lawa."""
    rng = t.rng
    t.add("PulseCore", "magma", heart_shape(rng, 0.93, sub=1))
    t.pulse("PulseCore", 0.07, 1.3)
    add_pieces(t, "Body", "basalt", cracked(heart_shape(rng), [(1, 0, 0.35), (0.15, 1, -0.1), (0.25, 0, 1)], gap=0.05),)
    for x, h, lean in ((-0.32, 0.55, -0.12), (0.0, 0.72, 0.04), (0.33, 0.5, 0.14), (-0.15, 0.4, -0.05),
                       (0.17, 0.45, 0.06)):
        t.add("Flames", "glow", flame((x, 0, 0.5 + (0.05 if abs(x) > 0.2 else -0.02)), h, 0.13, lean, rng))
    for x in (-0.08, 0.1):
        t.add("Drips", "magma", drip((x, 0, -0.72), 0.35, 0.07))
    M = Matrix.Translation((0, 0.05, 0.02)) @ Matrix.Rotation(math.radians(90), 4, "X")
    for k in range(8):
        a = 2 * math.pi * k / 8
        c = M @ Vector((1.0 * math.cos(a), 1.0 * math.sin(a), 0))
        out = (c - M @ Vector((0, 0, 0))).normalized()
        t.add("SpinHalo", "magma", torus(1.0, 0.03, M, seg=4, sides=4, a0=a + 0.1, a1=a + 2 * math.pi / 8 - 0.1))
        t.add("SpinHalo", "magma", hex_crystal(c, out, 0.2, 0.05, tip=0.8, sides=4))
    t.spin("SpinHalo", Y, -20)
    t.shards_orbit("Orbit", "basalt", 5, 1.18, 0.12, z=-0.3, glow_part="OrbitGlow", glow_key="magma", speed=34, tilt=0.15)
    t.particles.append({"part": "PulseCore", "color": "#FF7A2A", "rate": 14, "size": 0.32, "speed": 1.0, "tex": "spark",
                        "life": 1.2, "aura": True, "up": True})


# ---------------------------------------------------------------- FROST (lód nieprzezroczysty, świecące wnętrze, śnieg)

def frost_pebble(t):
    """Frost Pebble — gładki lodowy kamyk z czapą śniegu i błękitną szczeliną."""
    body = t.add("Body", "ice", rock(0.85, t.rng, sub=1, jit=0.12, scale=(1.15, 1.0, 0.74)), bevel=0.09, angle=20)
    loc, _ = surf(body, (0, 0, 1))
    t.add("Snow", "snow", rock(0.62, t.rng, loc + Vector((0, 0, -0.08)), sub=1, jit=0.1, scale=(1.15, 1.0, 0.3)),
          bevel=0.05, angle=20)
    t.seam("Glow", "cyan", body, (0.9, -0.5, 0.0), (0.0, -1, -0.35), r=0.045, steps=6, zig=0.15)
    t.seam("Glow", "cyan", body, (-0.7, -0.6, -0.1), (-0.3, -0.9, 0.3), r=0.035, steps=4)


def frost_shard(t):
    """Icicle Shard — bryła lodu z trzema zwisającymi soplami; najdłuższy świeci od środka."""
    rng = t.rng
    t.add("Body", "ice", rock(0.55, rng, (0, 0, 0.55), sub=1, jit=0.15, scale=(1.3, 1.0, 0.6)), bevel=0.06, angle=20)
    t.add("Snow", "snow", rock(0.5, rng, (0, 0, 0.82), sub=1, jit=0.1, scale=(1.3, 1.0, 0.3)), bevel=0.04, angle=20)
    for (x, y, L, r) in ((0.0, 0.0, 1.45, 0.22), (0.42, 0.1, 0.9, 0.15), (-0.4, -0.08, 1.0, 0.16), (0.15, 0.3, 0.6, 0.1)):
        pts = [(x + 0.04 * math.sin(u * 3), y, 0.45 - L * u) for u in (0, 0.3, 0.6, 0.85, 1.0)]
        rad = [r, r * 0.8, r * 0.5, r * 0.25, 0.0]
        t.add("Icicles", "ice_dk", loft(pts, rad, sides=6, ref=X), bevel=0.0)
    t.add("Glow", "glow", loft([(0, -0.02, 0.4), (0.03, -0.02, -0.3), (0.0, 0.0, -0.85)], [0.07, 0.05, 0.0], sides=5))
    t.add("Glow", "glow", ico(0.06, (0, 0, -1.05), sub=1))


def frost_crystal(t):
    """Glacier Crystal — klaster lodowych kryształów na śnieżnym kopczyku, końce świecą."""
    rng = t.rng
    t.add("Base", "snow", rock(0.62, rng, (0, 0, -0.55), sub=1, jit=0.12, scale=(1.35, 1.1, 0.45)), bevel=0.06, angle=20)
    spec = [((0, 0, -0.38), (0, 0.05, 1), 1.4, 0.25), ((0.33, -0.1, -0.4), (0.6, -0.25, 1), 1.0, 0.18),
            ((-0.32, 0.12, -0.4), (-0.6, 0.2, 1), 1.05, 0.19), ((0.05, 0.35, -0.42), (0.1, 0.75, 1), 0.7, 0.14),
            ((-0.2, -0.32, -0.42), (-0.35, -0.7, 1), 0.68, 0.13)]
    for i, (c, d, L, r) in enumerate(spec):
        t.add("Crystal" if i < 3 else "CrystalDk", "ice" if i < 3 else "ice_dk", hex_crystal(Vector(c), d, L, r))
        d = Vector(d).normalized()
        t.add("TipsA" if i % 2 else "Tips", "cyan" if i % 2 else "glow", hex_crystal(Vector(c) + d * L * 0.7, d, L * 0.31, r * 0.72, tip=0.95))


def frost_core(t):
    """Frozen Core — zamrożona gwiazda w popękanej lodowej skorupie, w klatce ze śnieżynkowych obręczy."""
    rng = t.rng
    t.add("Core", "glow", spiky(0.36, spike=1.45))
    shell = rock(0.52, rng, sub=2, jit=0.05)
    add_pieces(t, "Shell", "ice", cracked(shell, [(1, 0.1, 0.25), (-0.1, 1, 0.2), (0.2, -0.2, 1)], gap=0.07))
    for k in range(3):
        M = Matrix.Rotation(k * math.pi / 3, 4, "Z") @ Matrix.Rotation(math.pi / 2, 4, "X")
        t.add("SpinCage", "ice_dk", torus(0.86, 0.055, M, seg=20, sides=5))
        for j in range(4):  # kolce na obręczy
            a = j * math.pi / 2 + math.pi / 4
            c = M @ Vector((0.86 * math.cos(a), 0.86 * math.sin(a), 0))
            t.add("SpinCage", "ice_dk", hex_crystal(c, c, 0.22, 0.06, tip=0.75, sides=4))
    t.add("SpinGlow", "cyan", snowflake((0, 0, 0.9), 0.22, 0.035))
    t.add("SpinGlow", "cyan", snowflake((0, 0, -0.9), 0.22, 0.035))
    t.spin("SpinCage", Z, 28)
    t.spin("SpinGlow", Z, 28)


def frost_orb(t):
    """Aurora Prism — lodowy pryzmat (bipiramida) ze świecącym rdzeniem, dwa pierścienie zorzy, krążące śnieżynki."""
    t.add("Body", "ice", xform(bipyramid(1.6, 0.42), Matrix.Rotation(math.radians(8), 4, "Y")), bevel=0.03, angle=20)
    t.add("Glow", "glow", xform(bipyramid(1.75, 0.16, sides=6), Matrix.Rotation(math.radians(8), 4, "Y")))
    for name, key, tilt, R, speed in (("SpinRingA", "aurora_g", 30, 0.95, 40), ("SpinRingB", "aurora_v", -38, 1.08, -30)):
        M = Matrix.Rotation(math.radians(tilt), 4, "X") @ Matrix.Rotation(math.radians(tilt * 0.5), 4, "Y")
        for k in range(3):  # wstęga z przerwami
            a0 = k * 2 * math.pi / 3
            t.add(name, key, torus(R, 0.05, M, seg=10, sides=4, a0=a0, a1=a0 + 2 * math.pi / 3 - 0.35))
        ring_nodes(t, name, key, M, R, 3, 0.07, spiky_nodes=True)
        t.spin(name, M @ Z, speed)
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        c = (1.28 * math.cos(a), 1.28 * math.sin(a), 0.3 * math.sin(2 * a))
        t.add("Orbit", "snow", snowflake(c, 0.13, 0.03, Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Rotation(a, 4, "Y")))
    t.orbit("Orbit", 22, bob=0.06)
    t.particles.append({"part": "Body", "color": "#BFF4FF", "rate": 6, "size": 0.18, "speed": 0.3, "tex": "glint",
                        "life": 1.6})


def frost_heart(t):
    """Blizzard Heart — serce z pękniętego lodu nad pulsującym błękitnym żarem, korona sopli, śnieżna aureola."""
    rng = t.rng
    t.add("PulseCore", "cyan", heart_shape(rng, 0.93, sub=1))
    t.pulse("PulseCore", 0.07, 1.0)
    add_pieces(t, "Body", "ice", cracked(heart_shape(rng), [(1, 0, 0.3), (0.1, 1, -0.15), (0.2, 0.1, 1)], gap=0.05),)
    for x, L, lean in ((-0.3, 0.55, -0.35), (0.0, 0.75, 0.0), (0.3, 0.5, 0.35), (-0.15, 0.38, -0.15), (0.16, 0.42, 0.15)):
        t.add("Crown", "ice_dk", hex_crystal(Vector((x, 0, 0.45)), (lean, 0, 1), L, 0.1, tip=0.45))
    t.add("Snow", "snow", rock(0.3, rng, (-0.32, 0.02, 0.6), sub=1, jit=0.1, scale=(1.3, 1.1, 0.35)), bevel=0.03, angle=20)
    M = Matrix.Translation((0, 0.05, 0.02)) @ Matrix.Rotation(math.radians(90), 4, "X")
    for k in range(6):
        a0 = k * math.pi / 3 + 0.14
        t.add("SpinHalo", "glow", torus(1.0, 0.028, M, seg=5, sides=4, a0=a0, a1=a0 + math.pi / 3 - 0.28))
        c = M @ Vector((math.cos(a0 - 0.14), math.sin(a0 - 0.14), 0))
        t.add("SpinHalo", "glow", spiky(0.05, c, spike=2.0, sub=1))
    t.spin("SpinHalo", Y, 18)
    t.shards_orbit("Orbit", "ice", 5, 1.18, 0.12, z=-0.3, glow_part="OrbitGlow", glow_key="cyan", speed=30, tilt=0.15)
    t.particles.append({"part": "PulseCore", "color": "#E6FBFF", "rate": 14, "size": 0.25, "speed": 0.6, "tex": "glint",
                        "life": 1.6, "aura": True})


# ---------------------------------------------------------------- GEODE (skalne jajo, ametystowa jaskinia)

def geode_pebble(t):
    """Quartz Pebble — obtoczony mleczny kwarc z dwoma ametystowymi szpicami i iskrą w środku."""
    body = t.add("Body", "quartz", rock(0.82, t.rng, sub=1, jit=0.14, scale=(1.15, 0.95, 0.78)), bevel=0.08, angle=20)
    for d, L in (((0.5, -0.4, 0.75), 0.4), ((-0.6, -0.3, 0.6), 0.3)):
        loc, nn = surf(body, d)
        t.add("Crystal", "amethyst", hex_crystal(loc - nn * 0.08, nn, L, 0.1, tip=0.4))
    t.seam("Glow", "violet", body, (0.9, -0.5, -0.1), (0.0, -1, -0.4), r=0.035, steps=5)


def geode_shard(t):
    """Amethyst Shard — wielki ametystowy szpic wyrastający z okruchu skały, dwa mniejsze obok."""
    rng = t.rng
    t.add("Base", "rock", rock(0.45, rng, (0, 0, -0.62), sub=1, jit=0.2, scale=(1.4, 1.15, 0.6)), bevel=0.05, angle=20)
    d = Vector((0.18, -0.05, 1))
    t.add("Crystal", "amethyst", hex_crystal(Vector((0, 0, -0.55)), d, 1.65, 0.3, tip=0.3))
    t.add("CrystalDk", "amethyst_dk", hex_crystal(Vector((0.3, 0.12, -0.55)), (0.75, 0.2, 1), 0.65, 0.13))
    t.add("CrystalDk", "amethyst_dk", hex_crystal(Vector((-0.28, -0.1, -0.55)), (-0.7, -0.2, 1), 0.55, 0.12))
    d = d.normalized()
    t.add("Glow", "glow", loft([Vector((0, 0, -0.5)) + d * 0.1, Vector((0, 0, -0.5)) + d * 1.5], [0.06, 0.0], sides=5))
    t.add("GlowTip", "violet", hex_crystal(Vector((0, 0, -0.55)) + d * 1.12, d, 0.52, 0.22, tip=0.95))


def geode_crystal(t):
    """Geode Cluster — przecięta połówka geody: skalna miska, w środku ametystowa jaskinia i świecący brzeg."""
    rng = t.rng
    tilt = Matrix.Rotation(math.radians(48), 4, "X")  # otwarta strona do przodu (−Y) i w górę
    shell = rock(0.82, rng, sub=2, jit=0.08, scale=(1.1, 1.0, 1.0))
    bmesh.ops.bisect_plane(shell, geom=shell.verts[:] + shell.edges[:] + shell.faces[:], plane_co=(0, 0, 0.12),
                           plane_no=(0, 0, 1), clear_outer=True)
    bmesh.ops.holes_fill(shell, edges=shell.edges[:], sides=0)
    t.add("Body", "rock", xform(shell, tilt))
    t.add("Rim", "quartz", xform(torus(0.8, 0.07, Matrix.Translation((0, 0, 0.12)) @ Matrix.Diagonal((1.08, 0.98, 1, 1)),
                                       seg=20, sides=4), tilt))
    for i in range(16):
        a = i * 2.39996
        r = 0.66 * math.sqrt((i + 0.5) / 16)
        c = Vector((r * math.cos(a) * 1.05, r * math.sin(a), 0.05))
        d = Vector((c.x * 0.6, c.y * 0.6, 1)) if r > 0.2 else Vector((0, 0, 1))
        L = 0.42 - r * 0.32 + rng.uniform(-0.04, 0.06)
        part, key = ("Crystal", "amethyst") if i % 3 else ("CrystalDk", "amethyst_dk")
        t.add(part, key, xform(hex_crystal(c, d, L, 0.085 + 0.04 * (1 - r), tip=0.45), tilt))
    t.add("Glow", "violet", xform(spiky(0.12, (0, 0, 0.18), spike=1.6, sub=1), tilt))


def geode_core(t):
    """Crystal Egg — skalne jajo pęknięte na kawałki, które krążą wokół świecącej ametystowej gwiazdy."""
    rng = t.rng
    egg = rock(0.62, rng, sub=2, jit=0.05, scale=(0.95, 0.95, 1.28))
    add_pieces(t, "SpinShell", "rock", cracked(egg, [(1, 0.15, 0.3), (-0.15, 1, 0.2), (0.25, -0.1, 1)], gap=0.2),
               bevel=0.02)
    t.spin("SpinShell", Z, 18)
    t.add("Core", "violet", spiky(0.24, spike=1.5))
    for k, d in enumerate(dirs_on_sphere(10, rng)):
        t.add("Crystal" if k % 2 else "CrystalDk", "amethyst" if k % 2 else "amethyst_dk",
              hex_crystal(d * 0.1, d, rng.uniform(0.38, 0.55), rng.uniform(0.07, 0.1), tip=0.45))
    t.particles.append({"part": "Core", "color": "#E3C4FF", "rate": 5, "size": 0.16, "speed": 0.3, "tex": "glint",
                        "life": 1.2})


def geode_orb(t):
    """Prism Geode — szlifowana ametystowa kula w skalnym pasie, pierścień z kryształków i świecący pierścień."""
    rng = t.rng
    t.add("Body", "amethyst", ico(0.6, sub=1))
    t.add("Glow", "glow", spiky(0.26, spike=1.4, sub=1))  # wystaje przez ściany kuli (iskra wewnątrz)
    t.add("Band", "rock", rock(0.66, rng, sub=2, jit=0.04, scale=(1.0, 1.0, 0.28)), bevel=0.02, angle=20)
    M = Matrix.Rotation(math.radians(32), 4, "X") @ Matrix.Rotation(math.radians(14), 4, "Y")
    for k in range(10):
        a = 2 * math.pi * k / 10
        c = M @ Vector((1.0 * math.cos(a), 1.0 * math.sin(a), 0))
        t.add("SpinRingA", "quartz", xform(bipyramid(0.3, 0.07), Matrix.Translation(c) @ align(M.to_3x3() @ Vector(
            (-math.sin(a), math.cos(a), 0)))))
    t.add("SpinRingA", "quartz", torus(1.0, 0.02, M, seg=24, sides=4))
    t.spin("SpinRingA", M @ Z, 35)
    M2 = Matrix.Rotation(math.radians(-40), 4, "X") @ Matrix.Rotation(math.radians(-20), 4, "Y")
    for k in range(3):
        a0 = k * 2 * math.pi / 3
        t.add("SpinRingB", "violet", torus(1.12, 0.04, M2, seg=10, sides=4, a0=a0, a1=a0 + 2 * math.pi / 3 - 0.4))
    ring_nodes(t, "SpinRingB", "violet", M2, 1.12, 3, 0.07, spiky_nodes=True)
    t.spin("SpinRingB", M2 @ Z, -28)
    t.shards_orbit("Orbit", "rock_dk", 3, 1.3, 0.11, z=-0.2, glow_part="OrbitGlow", glow_key="violet", speed=22)


def geode_heart(t):
    """Heart of Amethyst — szlifowane ametystowe serce (pulsuje) w resztkach skalnej łupiny, korona kryształów."""
    rng = t.rng
    t.add("PulseHeart", "amethyst", heart_shape(rng))
    t.pulse("PulseHeart", 0.05, 1.0)
    t.add("Glow", "violet", heart_shape(rng, 0.5))  # świecący środek widoczny przez szkło w grze
    husk = cracked(heart_shape(rng, 1.07), [(1, 0, 0.35), (0.1, 1, 0), (0.3, 0, 1)], gap=0.1)
    for p, cen in husk:  # zostają kawałki z tyłu i u dołu — serce „wykluwa się” z geody
        if cen.y > 0.02 or cen.z < -0.1:
            t.add("Husk", "rock", p, bevel=0.015)
        else:
            p.free()
    for x, L, lean in ((-0.3, 0.5, -0.4), (0.0, 0.62, 0.0), (0.3, 0.48, 0.4), (-0.12, 0.35, -0.1), (0.14, 0.38, 0.12)):
        t.add("Crown", "amethyst_dk", hex_crystal(Vector((x, 0, 0.42)), (lean, 0, 1), L, 0.09, tip=0.45))
    M = Matrix.Translation((0, 0.05, 0.02)) @ Matrix.Rotation(math.radians(90), 4, "X")
    for k in range(6):
        a0 = k * math.pi / 3 + 0.14
        t.add("SpinHalo", "glow", torus(1.0, 0.028, M, seg=5, sides=4, a0=a0, a1=a0 + math.pi / 3 - 0.28))
        c = M @ Vector((math.cos(a0 - 0.14), math.sin(a0 - 0.14), 0))
        t.add("SpinHalo", "glow", xform(bipyramid(0.2, 0.05), Matrix.Translation(c) @ align(c - M @ Vector())))
    t.spin("SpinHalo", Y, 20)
    for k in range(5):
        a = 2 * math.pi * k / 5
        c = Vector((1.15 * math.cos(a), 1.15 * math.sin(a), -0.3 + 0.15 * math.sin(2 * a)))
        t.add("Orbit", "amethyst_dk", hex_crystal(c - Vector((0, 0, 0.12)), (0.2 * math.cos(a), 0.2 * math.sin(a), 1),
                                                  0.3, 0.07, tip=0.4))
    t.orbit("Orbit", 30, bob=0.05)
    t.particles.append({"part": "PulseHeart", "color": "#E3C4FF", "rate": 14, "size": 0.25, "speed": 0.6,
                        "tex": "glint", "life": 1.5, "aura": True})


BUILDERS = {f.__name__: f for f in (
    iron_pebble, iron_shard, iron_crystal, iron_core, iron_orb, iron_heart,
    lava_pebble, lava_shard, lava_crystal, lava_core, lava_orb, lava_heart,
    frost_pebble, frost_shard, frost_crystal, frost_core, frost_orb, frost_heart,
    geode_pebble, geode_shard, geode_crystal, geode_core, geode_orb, geode_heart)}


# ---------------------------------------------------------------- meta, eksport

def bbox(ob):
    ws = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector([min(w[i] for w in ws) for i in range(3)])
    hi = Vector([max(w[i] for w in ws) for i in range(3)])
    return lo, hi


def bbox_all(obs):
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for ob in obs:
        a, b = bbox(ob)
        lo = Vector([min(p, q) for p, q in zip(lo, a)])
        hi = Vector([max(p, q) for p, q in zip(hi, b)])
    return lo, hi


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def meta_for(t, obs):
    parts = {}
    for part, ob in obs.items():
        lo, hi = bbox(ob)
        key = t.parts[part][0]
        hx, rbx = t.pal[key]
        size = hi - lo
        p = {"material": rbx, "color": hx, "tint": rbx == "Neon", "center": to_roblox((lo + hi) / 2),
             "size": [round(size.x, 4), round(size.z, 4), round(size.y, 4)], "tris": tris(ob)}
        if part in t.anim:
            a = dict(t.anim[part])
            if "axis" in a:
                a["axis"] = to_roblox(a["axis"])
            p["anim"] = a
        parts[part] = p
    total = sum(p["tris"] for p in parts.values())
    lo, hi = bbox_all(obs.values())
    return {"name": t.name, "theme": t.theme, "rarity": t.rarity, "scale": SIZE[t.rarity], "parts": parts,
            "particles": t.particles, "tris": total, "ok": total <= BUDGET,
            "extent": round(max(hi - lo), 3)}


def select_items(themes, only):
    out = []
    for it in ITEMS:
        if only and it["id"] not in only:
            continue
        if themes and it["theme"] not in themes:
            continue
        if it["id"] in BUILDERS:
            out.append(it)
    return out


def build_all(items):
    built = {}
    for it in items:
        c = bpy.data.collections.new(it["id"])
        bpy.context.scene.collection.children.link(c)
        t = Item(it)
        BUILDERS[it["id"]](t)
        built[it["id"]] = (t, t.build(c), c)
    return built


def export_fbx(path, obs):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True,
                             axis_forward="-Z", axis_up="Y", add_leaf_bones=False, mesh_smooth_type="FACE")


# ---------------------------------------------------------------- render

def flat_mat(name, rgb, emission=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = 1.0
    try:
        b.inputs["Specular IOR Level"].default_value = 0.0
    except KeyError:
        pass
    if emission:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emission
    return m


def setup_render(silhouette, w, h, lights=True):
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (1, 1, 1, 1) if silhouette else (0.012, 0.01, 0.03, 1)
    bg.inputs["Strength"].default_value = 1.0
    sc.world = world
    if lights and not silhouette:
        for name, energy, loc in (("Key", 5000, (12, -20, 18)), ("Fill", 1600, (-20, -12, 4)), ("Rim", 4500, (-4, 22, 12))):
            add_light(name, energy, loc, 20)
    if not silhouette:
        ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
        ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        rl = ng.nodes.new("CompositorNodeRLayers")
        gl = ng.nodes.new("CompositorNodeGlare")
        out = ng.nodes.new("NodeGroupOutput")
        for key, val in (("Type", "Bloom"), ("Threshold", 1.0), ("Strength", 0.9), ("Size", 6), ("Quality", "High")):
            try:
                gl.inputs[key].default_value = val
            except (TypeError, KeyError, AttributeError):
                pass
        ng.links.new(rl.outputs["Image"], gl.inputs["Image"])
        ng.links.new(gl.outputs[0], out.inputs[0])
        sc.compositing_node_group = ng


def add_light(name, energy, loc, size, color=(1, 1, 1), target=(0, 0, 0)):
    li = bpy.data.lights.new(name, "AREA")
    li.energy, li.size, li.color = energy, size, color
    ob = bpy.data.objects.new(name, li)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(ob)
    return ob


def label(text, loc, size, mat, rot):
    cu = bpy.data.curves.new(f"L_{text}", "FONT")
    cu.body = text
    cu.align_x = "CENTER"
    cu.size = size
    ob = bpy.data.objects.new(f"L_{text}", cu)
    ob.location = loc
    ob.rotation_euler = rot
    ob.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def ortho_cam(elev, w, h, obs, pad=1.12):
    """Kamera ortho z przodu (−Y) pod kątem elev, dopasowana do obiektów."""
    sc = bpy.context.scene
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    cob = bpy.data.objects.new("Cam", cam)
    sc.collection.objects.link(cob)
    R = Matrix.Rotation(math.radians(90 - elev), 4, "X")
    cob.rotation_euler = R.to_euler()
    Ri = R.to_3x3().inverted()
    bpy.context.view_layer.update()
    xs, ys = [], []
    for ob in obs:
        for v in ob.data.vertices:
            p = Ri @ (ob.matrix_world @ v.co)
            xs.append(p.x)
            ys.append(p.y)
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    ww, hh = (max(xs) - min(xs)) * pad, (max(ys) - min(ys)) * pad
    cam.ortho_scale = max(ww, hh * w / h) if w >= h else max(hh, ww * h / w)
    cob.location = R.to_3x3() @ Vector((cx, cy, 60))
    sc.camera = cob
    return cob


def place_row(built, ids, turn, silhouette, black):
    """Przedmioty w rzędzie, skala wg rzadkości, wyrównane środkiem do z = 0."""
    x = 0.0
    gap = 0.7
    placed = []
    for iid in ids:
        t, obs, c = built[iid]
        root = bpy.data.objects.new(iid + "_Root", None)
        bpy.context.scene.collection.objects.link(root)
        lo, hi = bbox_all(obs.values())
        ext = max(hi - lo)
        s = 2.0 * SIZE[t.rarity] / ext
        for ob in obs.values():
            ob.parent = root
            if silhouette:
                ob.data.materials.clear()
                ob.data.materials.append(black)
        root.scale = (s, s, s)
        root.rotation_euler = (0, 0, math.radians(turn))
        bpy.context.view_layer.update()
        lo, hi = bbox_all(obs.values())
        root.location.x = x - lo.x
        root.location.z = -(lo.z + hi.z) / 2
        bpy.context.view_layer.update()
        placed.append((iid, x + (hi.x - lo.x) / 2))
        x += (hi.x - lo.x) + gap
    return placed


def render_row(items, theme, silhouette=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    built = build_all(items)
    ids = [it["id"] for it in items]
    black = flat_mat("_Black", (0, 0, 0))
    placed = place_row(built, ids, -30, silhouette, black)
    elev = 16
    rot = (math.radians(90 - elev), 0, 0)
    for iid, cx in placed:
        t = built[iid][0]
        col = hex_rgb(RAR["tiers"][t.rarity]["color"])
        mat = black if silhouette else flat_mat(f"_Lab{iid}", lin(col), 2.0)
        label(t.name, (cx, -1.6, -1.45), 0.26, mat, rot)
        label(t.rarity, (cx, -1.6, -1.8), 0.2, mat, rot)
    setup_render(silhouette, 3000, 1100)
    obs = [o for o in bpy.context.scene.objects if o.type in ("MESH",)]
    for o in bpy.context.scene.objects:
        if o.type == "FONT":
            me = bpy.data.meshes.new_from_object(o.evaluated_get(bpy.context.evaluated_depsgraph_get()))
            tmp = bpy.data.objects.new("_tmp_" + o.name, me)
            tmp.matrix_world = o.matrix_world
            obs.append(tmp)
    ortho_cam(elev, 3000, 1100, obs, pad=1.06)
    name = f"T21 lup {theme}" + (" sylwetki" if silhouette else "")
    bpy.context.scene.render.filepath = str(IMG / f"{name}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDER", name)


def render_icons(items, res=512, elev=24, turn=-32):
    """Ikony karty łupu: hero 3/4, przezroczyste tło, obrys, światło konturowe w kolorze rzadkości → art/ui/items/<id>.png."""
    ICONS.mkdir(parents=True, exist_ok=True)
    for it in items:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        _MATS.clear()
        built = build_all([it])
        t, obs, c = built[it["id"]]
        setup_render(False, res, res, lights=False)
        sc = bpy.context.scene
        sc.render.film_transparent = True
        sc.render.image_settings.file_format = "PNG"
        sc.render.image_settings.color_mode = "RGBA"
        rc = lin(hex_rgb(RAR["tiers"][t.rarity]["color"]))
        add_light("Key", 4200, (10, -18, 16), 16)
        add_light("Fill", 1000, (-18, -10, 2), 16)
        add_light("RimA", 9000, (-12, 16, 8), 10, color=rc)
        add_light("RimB", 7000, (14, 14, -4), 10, color=rc)
        ink = flat_mat("_Ink", (0.004, 0.002, 0.008))
        ink.use_backface_culling = True
        rot = Matrix.Rotation(math.radians(turn), 4, "Z")
        lo, hi = bbox_all(obs.values())
        ext = max(hi - lo)
        for part, ob in obs.items():
            ob.matrix_world = rot @ ob.matrix_world
            if t.pal[t.parts[part][0]][1] != "Neon":
                ob.data.materials.append(ink)
                so = ob.modifiers.new("Outline", "SOLIDIFY")
                so.thickness, so.offset, so.use_flip_normals = 0.018 * ext, 1.0, True
                so.material_offset = len(ob.data.materials) - 1
                so.use_rim = False
        ortho_cam(elev, res, res, list(obs.values()), pad=1.1)
        path = ICONS / f"{it['id']}.png"
        sc.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        glow_alpha(path)
    print("ICONS_DONE", [it["id"] for it in items])


def glow_alpha(path, lo=0.5, hi=0.9):
    """EEVEE przy przezroczystym tle daje czystej emisji alfa 0 (świecące pierścienie znikają z ikony).
    Krycie = max(alfa, jasność emisji) — Neon i poświata zostają, ciemne tło bloom znika."""
    import numpy as np
    img = bpy.data.images.load(str(path))
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    lum = px[:, :3].max(axis=1)
    px[:, 3] = np.maximum(px[:, 3], np.clip((lum - lo) / (hi - lo), 0, 1))
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = str(path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    themes = argv[argv.index("--themes") + 1].split(",") if "--themes" in argv else None
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else None
    items = select_items(themes, only)
    meta_path = OUT / "items_meta.json"
    if "--no-export" not in argv:
        meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() else {}
        for theme in sorted({it["theme"] for it in items}):
            bpy.ops.wm.read_factory_settings(use_empty=True)
            _MATS.clear()
            group = [it for it in items if it["theme"] == theme]
            built = build_all(group)
            all_obs = []
            for iid, (t, obs, c) in built.items():
                meta[iid] = meta_for(t, obs)
                all_obs += list(obs.values())
            d = OUT / theme.lower()
            d.mkdir(parents=True, exist_ok=True)
            export_fbx(d / f"items_{theme.lower()}.fbx", all_obs)
            bpy.ops.wm.save_as_mainfile(filepath=str(d / f"items_{theme.lower()}.blend"))
        order = [it["id"] for it in ITEMS]
        meta_path.write_text(json.dumps({k: meta[k] for k in order if k in meta}, indent=1), encoding="utf-8")
        print("ITEMS_REPORT", json.dumps({k: {"tris": v["tris"], "ok": v["ok"], "parts": len(v["parts"])}
                                          for k, v in meta.items() if k in {it["id"] for it in items}}))
    for theme in sorted({it["theme"] for it in items}):
        group = [it for it in items if it["theme"] == theme]
        if "--sketch" in argv:
            render_row(group, theme, silhouette=True)
        if "--render" in argv:
            render_row(group, theme)
    if "--icons" in argv:
        render_icons(items)
    print("ITEMS_DONE")


main()
