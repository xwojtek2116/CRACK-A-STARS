"""build_tools.py — modele narzędzi (T11): 8 tierów z Tools.json + 2 ekskluzywy z Monetization.json (exclusives).

Uruchom:
  E:\\blender\\blender.exe -b --factory-startup -P art/tools/build_tools.py -- [--only a,b] [--sketch] [--render] [--no-export]

Układ w Blenderze: trzonek wzdłuż +Z, punkt chwytu dłoni = (0, 0, 0), strona uderzenia = −Y, grubość ostrza = X.
W Roblox (Blender (x, y, z) → Roblox (−x, z, y)): +Y wzdłuż trzonka, uderzenie w −Z → Tool.Grip bez obrotu.
1 jednostka = 1 stud (import w Studio i tak mierzy Handle i skaluje).

Części = osobne meshe wg materiału (`<id>_<Część>`): Handle (trzonek, Handle Toola), Grip, Body, Accent, Glow (Neon)…,
Spin* = części kręcone przez klienta (ToolFxController).
Wyjście: art/tools/tools.fbx + tools.blend, art/tools/tools_meta.json (materiały Roblox, chwyt, smuga, cząsteczki, Spin),
  vault/_img/T11 narzedzia sylwetki.png (--sketch), T11 narzedzia.png i T11 skala.png (--render).
"""

import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "game" / "src" / "shared" / "Config" / "Data"
OUT = ROOT / "art" / "tools"
IMG = ROOT / "vault" / "_img"
TOOLS = json.loads((DATA / "Tools.json").read_text(encoding="utf-8"))
MON = json.loads((DATA / "Monetization.json").read_text(encoding="utf-8"))
EXCL = {e["id"]: e for e in MON["exclusives"] if e.get("type") == "tool"}
IDS = TOOLS["order"] + list(EXCL)
BUDGET = 3000
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))

# Paleta: klucz → (kolor, materiał Roblox, przezroczystość). Neon = świecące części.
PAL = {
    "wood": ("#8A5530", "Wood", 0), "wood_dk": ("#5C3519", "Wood", 0), "rope": ("#C9A66B", "Fabric", 0),
    "leather": ("#5A3420", "Leather", 0), "leather_bk": ("#24202C", "Leather", 0),
    "stone": ("#8C8798", "Slate", 0), "stone_dk": ("#5E5A6E", "Slate", 0),
    "iron": ("#A7B0C0", "Metal", 0), "iron_dk": ("#4E576A", "Metal", 0), "steel": ("#C9D2DE", "Metal", 0),
    "gunmetal": ("#2C3142", "Metal", 0), "gunmetal_dk": ("#1C2030", "Metal", 0),
    "violet_metal": ("#3A2466", "Metal", 0), "purple_metal": ("#4B2A8C", "Metal", 0), "gold": ("#FFC23D", "Metal", 0),
    "navy": ("#1F2A4A", "Metal", 0), "silver": ("#DDE8FF", "Metal", 0), "night": ("#1A1530", "Metal", 0),
    "grip_violet": ("#5A2EA6", "Fabric", 0), "grip_ice": ("#6FB6FF", "Fabric", 0), "grip_purple": ("#3B1A6E", "Fabric", 0),
    "crystal": ("#4FC8FF", "Glass", 0.15), "ice": ("#BDEBFF", "Glass", 0.25), "glass_amber": ("#FFD9A0", "Glass", 0.55),
    "glass_galaxy": ("#BFD4FF", "Glass", 0.6), "violet_crystal": ("#7A35F0", "Glass", 0.0),
    "glow_crystal": ("#8FEAFF", "Neon", 0), "glow_cyan": ("#3DF2FF", "Neon", 0), "glow_beam": ("#E8FFFF", "Neon", 0),
    "beam_shell": ("#3DF2FF", "Neon", 0.6), "glow_violet": ("#B45CFF", "Neon", 0), "glow_ring": ("#E08BFF", "Neon", 0),
    "glow_nova": ("#FF8A1E", "Neon", 0), "glow_star": ("#FFE27A", "Neon", 0), "glow_sb": ("#D07CFF", "Neon", 0),
    "glow_comet": ("#9FF6FF", "Neon", 0), "glow_galaxy": ("#FF5CE1", "Neon", 0), "glow_galaxy2": ("#7A8CFF", "Neon", 0),
    "glow_white": ("#FFFFFF", "Neon", 0),
}


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def to_roblox(v):
    return [round(-v[0], 4), round(v[2], 4), round(v[1], 4)]


# ---------------------------------------------------------------- geometria

def bev(bm, off, angle=35):
    """Faza tylko na ostrych krawędziach (cylindry nie dostają faz na bokach)."""
    bm.normal_update()
    edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0) > math.radians(angle)]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=off, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)
    return bm


def cyl(r1, r2, depth, seg, M=Matrix()):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth, matrix=M)
    return bm


def zcyl(z0, z1, r, seg=8, r_top=None):
    """Walec wzdłuż Z od z0 do z1."""
    return cyl(r, r if r_top is None else r_top, z1 - z0, seg, Matrix.Translation((0, 0, (z0 + z1) / 2)))


def ycyl(y0, y1, r, z, seg=8, r_end=None, x=0.0):
    """Walec wzdłuż Y (głowice młotów), środek w (x, ·, z)."""
    M = Matrix.Translation((x, (y0 + y1) / 2, z)) @ Matrix.Rotation(-math.pi / 2, 4, "X")
    return cyl(r, r if r_end is None else r_end, y1 - y0, seg, M)


def xcyl(x0, x1, r, y, z, seg=8):
    M = Matrix.Translation(((x0 + x1) / 2, y, z)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
    return cyl(r, r, x1 - x0, seg, M)


def box(sx, sy, sz, c=(0, 0, 0), rot=None):
    bm = bmesh.new()
    M = Matrix.Translation(c) @ (rot or Matrix()) @ Matrix.Diagonal((sx, sy, sz, 1))
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    return bm


def sphere(r, c, u=12, v=8):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r, matrix=Matrix.Translation(c))
    return bm


def ico(r, c, sub=1):
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


def loft(path, radii, sides=8, ref=X, cap=True, closed=False, phase=0.0):
    """Rura po ścieżce. radius = r albo (r_ref, r_drugi); r = 0 → szpic."""
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
        a.normalize()
        b = t.cross(a)
        r = radii[i]
        rx, ry = (r, r) if not isinstance(r, (tuple, list)) else r
        if max(rx, ry) < 1e-4:
            rings.append([bm.verts.new(p)])
            continue
        ring = []
        for k in range(sides):
            ang = 2 * math.pi * k / sides + phase
            ring.append(bm.verts.new(p + a * math.cos(ang) * rx + b * math.sin(ang) * ry))
        rings.append(ring)
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


def arc_pts(R, a0, a1, n):
    return [(R * math.cos(a0 + (a1 - a0) * i / (n - 1)), R * math.sin(a0 + (a1 - a0) * i / (n - 1)), 0) for i in range(n)]


def torus(R, r, M=Matrix(), seg=32, sides=6, a0=0.0, a1=2 * math.pi):
    """Pierścień wokół osi Z (M obraca/przesuwa). a0..a1 < 2π → łuk z zaślepkami."""
    full = abs(a1 - a0 - 2 * math.pi) < 1e-6
    pts = arc_pts(R, a0, a1 - (a1 - a0) / seg if full else a1, seg if full else max(4, seg))
    bm = loft(pts, [r] * len(pts), sides=sides, ref=Z, closed=full)
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm


def plate(pts, th, x=0.0):
    """Płyta z obrysu w płaszczyźnie Y-Z, grubość (połowa) per wierzchołek wzdłuż X — ostrza i klingi."""
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


def star_pts(r_out, r_in, n=5, cy=0.0, cz=0.0, rot=math.pi / 2):
    out = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + math.pi * i / n
        out.append((cy + r * math.cos(a), cz + r * math.sin(a)))
    return out


def spiky(r, c, spike=1.9):
    """Kolczasta kula (gwiezdny rdzeń): icosphere, 12 wierzchołków o 5 krawędziach wypchnięte."""
    bm = ico(r, (0, 0, 0), sub=2)
    for v in bm.verts:
        if len(v.link_edges) == 5:
            v.co *= spike
    bmesh.ops.translate(bm, vec=c, verts=bm.verts)
    return bm


def jitter(bm, rng, amt):
    for v in bm.verts:
        v.co += Vector((rng.uniform(-amt, amt), rng.uniform(-amt, amt), rng.uniform(-amt, amt)))
    return bm


def mirror_x(bm):
    out = bm.copy()
    bmesh.ops.scale(out, vec=(-1, 1, 1), verts=out.verts)
    bmesh.ops.reverse_faces(out, faces=out.faces[:])
    return out


def bm_append(dst, src):
    me = bpy.data.meshes.new("_tmp")
    src.to_mesh(me)
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)


# ---------------------------------------------------------------- budowniczy narzędzia

class Tool:
    def __init__(self, tid):
        self.tid = tid
        self.parts = {}  # część → [klucz palety, [bmesh…]]
        self.spin = {}  # część → (oś Blender, stopnie/s)
        self.trail = None  # (punkt A, punkt B, kolory, czas, szerokość)
        self.particles = []  # dicts
        self.rng = random.Random(sum(map(ord, tid)))

    def add(self, part, key, bm, bevel=0.0):
        if bevel:
            bev(bm, bevel)
        slot = self.parts.setdefault(part, [key, []])
        assert slot[0] == key, f"{self.tid}_{part}: dwa materiały ({slot[0]}, {key})"
        slot[1].append(bm)

    def build(self, coll):
        obs = {}
        for part, (key, bms) in self.parts.items():
            dst = bmesh.new()
            for b in bms:
                bm_append(dst, b)
                b.free()
            bmesh.ops.remove_doubles(dst, verts=dst.verts[:], dist=1e-5)
            bmesh.ops.triangulate(dst, faces=dst.faces[:])
            me = bpy.data.meshes.new(f"{self.tid}_{part}")
            dst.to_mesh(me)
            dst.free()
            ob = bpy.data.objects.new(f"{self.tid}_{part}", me)
            coll.objects.link(ob)
            me.materials.append(material(key))
            for p in me.polygons:
                p.use_smooth = False
            obs[part] = ob
        return obs


_MATS = {}


def material(key):
    if key in _MATS:
        return _MATS[key]
    hx, rbx, tr = PAL[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    c = lin(hex_rgb(hx))
    if rbx == "Neon":
        b.inputs["Base Color"].default_value = (0, 0, 0, 1)
        b.inputs["Emission Color"].default_value = (*c, 1)
        b.inputs["Emission Strength"].default_value = 5.0 * (1 - tr * 0.7)
    else:
        b.inputs["Base Color"].default_value = (*c, 1)
        b.inputs["Roughness"].default_value = {"Metal": 0.32, "Glass": 0.08}.get(rbx, 0.75)
        b.inputs["Metallic"].default_value = 0.85 if rbx == "Metal" else 0.0
        if rbx == "Glass":
            b.inputs["Emission Color"].default_value = (*c, 1)
            b.inputs["Emission Strength"].default_value = 0.35
    if tr > 0:
        b.inputs["Alpha"].default_value = 1 - tr * (0.8 if rbx == "Glass" else 1.0)
        m.surface_render_method = "BLENDED"
        m.use_backface_culling = False
    _MATS[key] = m
    return m


def grip_rings(t, part, key, z0, z1, r, n):
    for i in range(n):
        z = z0 + (z1 - z0) * (i + 0.5) / n
        t.add(part, key, zcyl(z - 0.035, z + 0.035, r, 8))


# ---------------------------------------------------------------- 10 narzędzi

def stone_pickaxe(t):
    t.add("Handle", "wood", zcyl(-0.45, 2.45, 0.13, 8, r_top=0.11), bevel=0.02)
    t.add("Handle", "wood", zcyl(-0.58, -0.42, 0.17, 8), bevel=0.03)  # gałka
    t.add("Grip", "leather", zcyl(-0.3, 0.5, 0.15, 8))
    grip_rings(t, "Grip", "leather", -0.3, 0.5, 0.165, 3)
    rng = t.rng
    # kamienna głowica: bryła + zakrzywiony szpic do przodu + krótkie dłuto do tyłu
    core = [(sx * rng.uniform(0.19, 0.24), sy * rng.uniform(0.22, 0.28), 2.42 + sz * rng.uniform(0.2, 0.26))
            for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    t.add("HeadCore", "stone_dk", hull(core + [(0, 0, 2.72), (0, 0, 2.12)]), bevel=0.03)
    path = [(0, -0.18 - 1.1 * u, 2.45 + 0.12 * math.sin(u * 1.4) - 0.5 * u ** 2.2) for u in [i / 6 for i in range(7)]]
    rad = [(0.19 * (1 - u) ** 0.8 + 0.0, 0.21 * (1 - u) ** 0.9) for u in [i / 6 for i in range(7)]]
    rad[-1] = 0.0
    t.add("Head", "stone", jitter(loft(path, rad, sides=6), rng, 0.02))
    path = [(0, 0.18 + 0.7 * u, 2.45 - 0.22 * u ** 1.6) for u in [i / 4 for i in range(5)]]
    rad = [(0.18 - 0.02 * u, 0.2 - 0.13 * u) for u in [i / 4 for i in range(5)]]
    t.add("Head", "stone", jitter(loft(path, rad, sides=6), rng, 0.015))
    # sznurek: dwa pasy przez bryłę + owijka pod głowicą
    for y in (-0.11, 0.11):
        t.add("Wrap", "rope", box(0.5, 0.08, 0.56, (0, y, 2.42)), bevel=0.02)
    t.add("Wrap", "rope", zcyl(2.0, 2.12, 0.15, 8))
    t.add("Wrap", "rope", zcyl(1.84, 1.94, 0.145, 8))


def iron_hammer(t):
    t.add("Handle", "wood_dk", zcyl(-0.45, 2.6, 0.12, 8, r_top=0.115), bevel=0.02)
    t.add("Grip", "leather", zcyl(-0.35, 0.55, 0.15, 8))
    grip_rings(t, "Grip", "leather", -0.35, 0.55, 0.165, 4)
    t.add("Accent", "iron_dk", zcyl(-0.6, -0.42, 0.17, 8), bevel=0.03)  # okucie
    for y in (-0.12, 0.12):  # langety wzdłuż trzonka
        t.add("Accent", "iron_dk", box(0.09, 0.05, 0.8, (0, y, 2.2)), bevel=0.015)
    hz = 2.88
    t.add("Head", "iron", box(0.64, 1.3, 0.72, (0, 0, hz)), bevel=0.08)
    for y in (-0.7, 0.7):  # obuchy
        t.add("Accent", "iron_dk", ycyl(y - 0.08, y + 0.08, 0.45, hz, seg=8), bevel=0.03)
    for y in (-0.36, 0.36):  # obręcze
        t.add("Accent", "iron_dk", box(0.7, 0.11, 0.78, (0, y, hz)), bevel=0.02)
    for sx in (-1, 1):  # nity
        for y in (-0.36, 0.36):
            for z in (hz - 0.24, hz + 0.24):
                t.add("Accent", "iron_dk", sphere(0.055, (sx * 0.35, y, z), 6, 4))
        for z in (hz - 0.2, hz + 0.2):
            t.add("Accent", "iron_dk", sphere(0.06, (sx * 0.32, 0, z), 6, 4))


def crystal_axe(t):
    t.add("Handle", "violet_metal", zcyl(-0.5, 3.25, 0.11, 8), bevel=0.015)
    t.add("Grip", "gunmetal", zcyl(-0.4, 0.55, 0.14, 8))
    grip_rings(t, "Grip", "gunmetal", -0.4, 0.55, 0.155, 4)
    for z in (0.75, 1.6, 2.45):
        t.add("Accent", "steel", zcyl(z - 0.045, z + 0.045, 0.135, 8))
    t.add("Accent", "steel", box(0.3, 0.44, 0.66, (0, 0, 3.02)), bevel=0.05)  # tuleja
    t.add("Crystal", "crystal", hull([(0, 0, -0.95), (0.13, 0, -0.62), (-0.13, 0, -0.62), (0, 0.13, -0.62),
                                     (0, -0.13, -0.62), (0, 0, -0.45)]))  # kryształ w głowni
    pts = [(-0.14, 3.3), (-0.6, 3.5), (-1.22, 3.92), (-1.44, 3.56), (-1.52, 3.2), (-1.44, 2.84), (-1.2, 2.48),
           (-0.62, 2.74), (-0.14, 2.82)]
    th = [0.13, 0.1, 0.03, 0.025, 0.02, 0.025, 0.03, 0.1, 0.13]
    t.add("Crystal", "crystal", plate(pts, th))
    t.add("Crystal", "crystal", hull([(0, 0.15, 3.15), (0, 0.15, 2.9), (0.1, 0.15, 3.02), (-0.1, 0.15, 3.02),
                                     (0, 0.82, 3.0)]))  # kolec z tyłu
    t.add("Crystal", "crystal", hull([(0.1, 0, 3.32), (-0.1, 0, 3.32), (0, 0.1, 3.32), (0, -0.1, 3.32),
                                     (0, -0.03, 3.85)]))  # kryształ na szczycie
    edge = [(0, -1.24, 3.95), (0, -1.48, 3.57), (0, -1.57, 3.2), (0, -1.48, 2.83), (0, -1.22, 2.44)]
    t.add("Glow", "glow_crystal", loft(edge, [0.0, 0.05, 0.055, 0.05, 0.0], sides=6))
    t.add("Glow", "glow_crystal", loft([(0, -0.2, 3.06), (0, -0.7, 3.12), (0, -1.2, 3.2)], [0.035, 0.03, 0.0], sides=5))


def plasma_saw(t):
    t.add("Handle", "gunmetal", zcyl(-0.5, 0.62, 0.14, 8), bevel=0.02)
    t.add("Grip", "leather_bk", zcyl(-0.35, 0.5, 0.155, 8))
    grip_rings(t, "Grip", "leather_bk", -0.35, 0.5, 0.17, 4)
    t.add("Accent", "gunmetal_dk", zcyl(-0.62, -0.48, 0.18, 8), bevel=0.03)
    t.add("Body", "steel", zcyl(0.6, 2.35, 0.23, 8, r_top=0.2), bevel=0.03)  # obudowa
    t.add("Accent", "gunmetal_dk", zcyl(0.58, 0.72, 0.26, 8), bevel=0.02)
    t.add("Accent", "gunmetal_dk", zcyl(2.25, 2.42, 0.25, 8), bevel=0.02)
    for sx in (-1, 1):  # ogniwa plazmy
        t.add("Glow", "glow_cyan", zcyl(1.0, 1.75, 0.07, 6), )
        bmesh.ops.translate(t.parts["Glow"][1][-1], vec=(sx * 0.22, 0, 0), verts=t.parts["Glow"][1][-1].verts)
    t.add("Accent", "gunmetal_dk", box(0.12, 0.1, 0.42, (0, 0.2, 0.85)), bevel=0.02)  # spust
    # ramię do osi tarczy (z boku +X), tarcza w płaszczyźnie Y-Z
    hz, R = 3.33, 0.86
    t.add("Accent", "gunmetal_dk", box(0.14, 0.26, 1.2, (0.16, 0.05, 2.78)), bevel=0.03)
    t.add("Accent", "gunmetal_dk", xcyl(0.08, 0.28, 0.24, 0, hz, seg=8), bevel=0.02)
    teeth = []
    n = 24
    for i in range(n):
        a = 2 * math.pi * i / n
        a2 = 2 * math.pi * (i + 0.45) / n
        teeth += [(R * 0.9 * math.cos(a), hz + R * 0.9 * math.sin(a)), (R * math.cos(a2), hz + R * math.sin(a2))]
    t.add("SpinDisc", "steel", plate(teeth, [0.03] * len(teeth)))
    t.add("SpinDisc", "steel", xcyl(-0.1, 0.1, 0.2, 0, hz, seg=6))
    for i in range(3):  # wycięcia tarczy (widać obrót)
        a = 2 * math.pi * i / 3
        t.add("SpinDisc", "steel", box(0.08, 0.1, 0.36, (0, 0.42 * math.cos(a), hz + 0.42 * math.sin(a)),
                                       rot=Matrix.Rotation(-a + math.pi / 2, 4, "X")))
    t.spin["SpinDisc"] = (X, 420)
    t.add("Glow", "glow_cyan", torus(R + 0.04, 0.045, Matrix.Translation((0, 0, hz)) @ Matrix.Rotation(math.pi / 2, 4, "Y"),
                                     seg=36, sides=5))
    # osłona: łuk po stronie trzonka (+Y), z płytą boczną
    shroud = torus(R + 0.13, 0.08, Matrix.Translation((0, 0, hz)) @ Matrix.Rotation(math.pi / 2, 4, "Y"), seg=14, sides=4,
                   a0=math.radians(30), a1=math.radians(210))  # torus po obrocie: kąt a = b + 90° w (y, z)
    t.add("Accent", "gunmetal_dk", shroud)
    angs = [math.radians(-60 + 18 * i) for i in range(11)]  # tył (+Y) i góra, pierścień — tarcza widoczna
    side = [((R + 0.12) * math.cos(b), hz + (R + 0.12) * math.sin(b)) for b in angs] +            [(0.62 * math.cos(b), hz + 0.62 * math.sin(b)) for b in angs[::-1]]
    t.add("Accent", "gunmetal_dk", plate(side, [0.025] * len(side), x=0.2))


def laser_sword(t):
    t.add("Handle", "steel", zcyl(-0.55, 0.75, 0.13, 10), bevel=0.02)
    grip_rings(t, "Grip", "gunmetal", -0.4, 0.6, 0.15, 6)
    t.add("Accent", "gunmetal", zcyl(-0.72, -0.53, 0.16, 8, r_top=0.14), bevel=0.03)  # głowica
    t.add("Glow", "glow_cyan", ico(0.075, (0, 0, -0.78)))
    t.add("Accent", "gunmetal", zcyl(0.73, 1.02, 0.18, 10, r_top=0.16), bevel=0.03)  # emiter
    wing = [(-0.12, 0.8), (-0.48, 0.92), (-0.52, 1.02), (-0.12, 0.98)]
    t.add("Accent", "gunmetal", plate(wing, [0.06, 0.04, 0.04, 0.06]), bevel=0.01)
    t.add("Accent", "gunmetal", plate([(-y, z) for y, z in wing], [0.06, 0.04, 0.04, 0.06]), bevel=0.01)
    t.add("Glow", "glow_cyan", torus(0.15, 0.035, Matrix.Translation((0, 0, 1.03)), seg=12, sides=4))
    zs = [1.0, 1.6, 2.6, 3.6, 4.05, 4.3]
    rs = [(0.08, 0.15), (0.08, 0.16), (0.077, 0.155), (0.07, 0.14), (0.055, 0.1), 0.0]
    t.add("Beam", "glow_beam", loft([(0, 0, z) for z in zs], rs, sides=6))
    rs2 = [(r[0] * 1.9, r[1] * 1.7) if r else 0.0 for r in rs]
    t.add("BeamGlow", "beam_shell", loft([(0, 0, z) for z in [0.98] + zs[1:4] + [4.12, 4.42]], rs2, sides=6))
    t.trail = ((0, 0, 1.3), (0, 0, 4.15), ["#E8FFFF", "#3DF2FF"], 0.16, 1.0)


def gravity_hammer(t):
    t.add("Handle", "gunmetal", zcyl(-0.55, 3.75, 0.13, 8), bevel=0.02)
    t.add("Grip", "grip_violet", zcyl(-0.45, 0.65, 0.16, 8))
    grip_rings(t, "Grip", "grip_violet", -0.45, 0.65, 0.175, 4)
    t.add("Accent", "gunmetal_dk", zcyl(-0.72, -0.5, 0.19, 8), bevel=0.03)
    t.add("Glow", "glow_violet", ico(0.09, (0, 0, -0.8)))
    for y in (-0.135, 0.135):  # przewody energii wzdłuż trzonka
        t.add("Glow", "glow_violet", box(0.05, 0.035, 2.4, (0, y, 2.2)))
    hz = 4.28
    t.add("Accent", "gunmetal_dk", zcyl(3.5, 3.78, 0.21, 8), bevel=0.03)
    t.add("Body", "purple_metal", ycyl(-0.86, 0.86, 0.64, hz, seg=8), bevel=0.06)
    for y in (-0.55, 0.55):
        t.add("Accent", "gunmetal_dk", ycyl(y - 0.09, y + 0.09, 0.7, hz, seg=8), bevel=0.02)
    for y in (-0.92, 0.92):
        t.add("Accent", "gunmetal_dk", ycyl(y - 0.07, y + 0.07, 0.56, hz, seg=8), bevel=0.02)
        M = Matrix.Translation((0, y * 1.085, hz)) @ Matrix.Rotation(math.pi / 2, 4, "X")
        t.add("Glow", "glow_violet", torus(0.34, 0.05, M, seg=20, sides=4))
        t.add("Glow", "glow_violet", ycyl(y * 1.085 - 0.03, y * 1.085 + 0.03, 0.14, hz, seg=8))
    t.add("Glow", "glow_violet", xcyl(-0.67, 0.67, 0.26, 0, hz, seg=6))  # okno rdzenia
    # pływające pierścienie z przerwami (obrót widać), przeciwnie do siebie
    for name, y, R, speed, ph in (("SpinA", -0.34, 1.0, 80, 0.0), ("SpinB", 0.34, 1.06, -110, 0.6)):
        M = Matrix.Translation((0, y, hz)) @ Matrix.Rotation(math.pi / 2, 4, "X")
        for k in range(3):
            a0 = ph + 2 * math.pi * k / 3
            t.add(name, "glow_ring", torus(R, 0.05, M, seg=10, sides=5, a0=a0, a1=a0 + math.radians(95)))
            c = Vector((R * math.cos(a0), R * math.sin(a0), 0))
            node = ico(0.09, (0, 0, 0))
            bmesh.ops.translate(node, vec=c, verts=node.verts)
            bmesh.ops.transform(node, matrix=M, verts=node.verts)
            t.add(name, "glow_ring", node)
        t.spin[name] = (Y, speed)
    t.trail = ((0, 0, 3.0), (0, 0, 4.8), ["#E08BFF", "#6A2FD0"], 0.18, 1.2)
    t.particles.append({"part": "Body", "color": "#C77BFF", "rate": 6, "size": 0.25, "speed": 0.6, "tex": "spark",
                        "life": 1.0})


def nova_cannon(t):
    t.add("Handle", "gunmetal", zcyl(-0.55, 4.5, 0.13, 8), bevel=0.02)
    t.add("Grip", "leather_bk", zcyl(-0.45, 0.65, 0.16, 8))
    grip_rings(t, "Grip", "leather_bk", -0.45, 0.65, 0.175, 4)
    t.add("Accent", "gold", zcyl(-0.72, -0.5, 0.19, 8), bevel=0.03)
    for z in (1.3, 2.5, 3.6):
        t.add("Accent", "gold", zcyl(z - 0.06, z + 0.06, 0.16, 8))
    hz = 4.97
    t.add("Accent", "gold", zcyl(4.25, 4.55, 0.22, 8), bevel=0.03)
    t.add("Body", "gunmetal_dk", box(0.72, 0.5, 0.82, (0, -0.08, hz)), bevel=0.07)  # blok łączący
    t.add("Body", "gunmetal_dk", ycyl(-1.32, -0.3, 0.43, hz, seg=12, r_end=0.4), bevel=0.02)  # lufa = obuch
    for y in (-0.55, -0.76, -0.97):  # żeberka chłodzące
        t.add("Body", "gunmetal_dk", ycyl(y - 0.04, y + 0.04, 0.5, hz, seg=12))
    t.add("Accent", "gold", ycyl(-1.52, -1.3, 0.52, hz, seg=12), bevel=0.03)  # wylot
    t.add("Glow", "glow_nova", ycyl(-1.55, -1.5, 0.33, hz, seg=12))
    t.add("Glass", "glass_amber", sphere(0.56, (0, 0.5, hz), 16, 10))  # komora gwiezdnego rdzenia
    t.add("Core", "glow_star", spiky(0.2, (0, 0.5, hz), 1.9))
    for k in range(4):  # złota klatka
        a = math.pi / 4 + k * math.pi / 2
        path = [(0.6 * math.sin(u * math.pi) * math.cos(a), 0.5 - 0.6 * math.cos(u * math.pi),
                 hz + 0.6 * math.sin(u * math.pi) * math.sin(a)) for u in [i / 8 for i in range(9)]]
        t.add("Accent", "gold", loft(path, [0.04] * 9, sides=4, ref=Y))
    t.add("Accent", "gold", ycyl(1.08, 1.2, 0.2, hz, seg=8), bevel=0.02)
    t.add("Accent", "gold", ycyl(-0.13, -0.05, 0.5, hz, seg=12))
    t.trail = ((0, 0, 3.6), (0, -1.4, hz), ["#FFE27A", "#FF8A1E"], 0.2, 1.2)
    t.particles.append({"part": "Glow", "color": "#FFB23D", "rate": 8, "size": 0.22, "speed": 0.8, "tex": "spark",
                        "life": 0.8})


def starbreaker(t):
    t.add("Handle", "gold", zcyl(-0.6, 4.4, 0.14, 8), bevel=0.02)
    t.add("Grip", "grip_purple", zcyl(-0.48, 0.7, 0.17, 8))
    grip_rings(t, "Grip", "grip_purple", -0.48, 0.7, 0.185, 5)
    t.add("Grip", "grip_purple", zcyl(2.3, 2.7, 0.165, 8))
    t.add("Accent", "gold", plate(star_pts(0.22, 0.1, cz=-0.75), [0.07] * 10), bevel=0.015)  # gwiazda w głowicy
    t.add("Core", "glow_star", ico(0.07, (0, 0, -0.75)))
    hz = 4.75
    t.add("Accent", "gold", box(0.36, 0.5, 0.95, (0, 0, hz)), bevel=0.06)  # oprawa
    t.add("Accent", "gold", hull([(0.14, 0.14, hz + 0.45), (-0.14, 0.14, hz + 0.45), (0.14, -0.14, hz + 0.45),
                                 (-0.14, -0.14, hz + 0.45), (0, 0, hz + 1.25)]), bevel=0.02)  # szpic
    for side, s in ((-1, 1.0), (1, 0.78)):  # ostrza: przód duże, tył mniejsze
        pts = [(0.2, 0.42), (0.7, 0.62), (1.35, 1.12), (1.62, 0.6), (1.72, 0.0), (1.62, -0.6), (1.35, -1.12),
               (0.95, -0.7), (0.7, -0.5), (0.2, -0.36)]
        pts = [(side * y * s, hz + z * s) for y, z in pts]
        th = [0.14, 0.11, 0.035, 0.03, 0.025, 0.03, 0.035, 0.07, 0.1, 0.14]
        t.add("Blade", "violet_crystal", plate(pts, th))
        rim_back = [(0, side * y * s, hz + z * s) for y, z in [(0.7, 0.66), (1.0, 0.86), (1.36, 1.17)]]
        t.add("Accent", "gold", loft(rim_back, [0.06, 0.06, 0.0], sides=5))
        edge = [(0, side * y * s, hz + z * s) for y, z in [(1.38, 1.17), (1.68, 0.6), (1.79, 0.0), (1.68, -0.6),
                                                            (1.38, -1.17)]]
        t.add("Glow", "glow_sb", loft(edge, [0.0, 0.06, 0.065, 0.06, 0.0], sides=6))
    t.add("Core", "glow_star", plate(star_pts(0.4, 0.18, cz=hz), [0.22] * 10))  # gwiazda w środku głowicy
    t.trail = ((0, 0, 3.6), (0, 0, 5.9), ["#FFD45C", "#D07CFF"], 0.22, 1.4)
    t.particles.append({"part": "Core", "color": "#FFE27A", "rate": 10, "size": 0.25, "speed": 1.0, "tex": "glint",
                        "life": 1.0})


def comet_blade(t):
    t.add("Handle", "navy", zcyl(-0.5, 0.75, 0.13, 8), bevel=0.02)
    t.add("Grip", "grip_ice", zcyl(-0.38, 0.6, 0.145, 8))
    grip_rings(t, "Grip", "grip_ice", -0.38, 0.6, 0.16, 5)
    t.add("Glow", "glow_comet", ico(0.11, (0, 0, -0.62)))
    t.add("Accent", "silver", zcyl(0.72, 0.86, 0.2, 8), bevel=0.02)
    t.add("Glow", "glow_comet", ico(0.2, (0, -0.05, 0.98), sub=2))  # głowa komety = jelec
    for k, (dx, ang) in enumerate(((0.0, 0.0), (0.12, 0.35), (-0.12, -0.35))):  # ogon komety z jelca
        path = [(dx * u * 2, 0.1 + 0.85 * u, 0.95 - 0.55 * u ** 1.4 + 0.05 * k) for u in [i / 5 for i in range(6)]]
        rad = [(0.07 * (1 - u), 0.12 * (1 - u) ** 0.7) for u in [i / 5 for i in range(6)]]
        rad[-1] = 0.0
        t.add("Blade", "ice", loft(path, rad, sides=5))
    # zakrzywiona klinga: ostrze z przodu (−Y), wygięta do tyłu przy szpicu
    n = 9
    spine, edge, core = [], [], []
    for i in range(n):
        u = i / (n - 1)
        z = 1.05 + 3.1 * u
        cy = 0.5 * u ** 2.2
        w = 0.42 * (1 - u ** 3) + 0.16 * math.sin(u * math.pi)
        spine.append((cy + w * 0.35, z))
        edge.append((cy - w * 0.65, z))
        core.append((0, cy - w * 0.1, z))
    tip = (0.62, 4.32)
    pts = spine + [tip] + edge[::-1]
    th = [0.085] * n + [0.01] + [0.016] * n
    t.add("Blade", "ice", plate(pts, th))
    t.add("Glow", "glow_comet", loft(core[:-1] + [(0, 0.6, 4.25)], [0.035] * (n - 1) + [0.0], sides=5))
    t.trail = ((0, 0, 1.3), (0, 0.5, 4.1), ["#FFFFFF", "#9FF6FF"], 0.35, 1.3)
    t.particles.append({"part": "Blade", "color": "#CFF8FF", "rate": 8, "size": 0.2, "speed": 0.4, "tex": "glint",
                        "life": 1.2})


def galaxy_hammer(t):
    t.add("Handle", "night", zcyl(-0.55, 3.9, 0.13, 8), bevel=0.02)
    t.add("Grip", "grip_purple", zcyl(-0.45, 0.65, 0.16, 8))
    grip_rings(t, "Grip", "grip_purple", -0.45, 0.65, 0.175, 4)
    t.add("Accent", "gold", zcyl(-0.72, -0.5, 0.19, 8), bevel=0.03)
    t.add("Glow", "glow_white", ico(0.08, (0, 0, -0.8)))
    for z in (1.4, 2.7):
        t.add("Accent", "gold", zcyl(z - 0.06, z + 0.06, 0.16, 8))
    hz = 4.45
    t.add("Accent", "gold", zcyl(3.62, 3.92, 0.22, 8), bevel=0.03)
    t.add("Glass", "glass_galaxy", sphere(0.68, (0, 0, hz), 16, 10))  # szklana kula z galaktyką
    for y in (-1, 1):
        t.add("Accent", "gold", ycyl(y * 0.62, y * 0.98, 0.44, hz, seg=8, r_end=0.5) if y > 0 else
              ycyl(-0.98, -0.62, 0.5, hz, seg=8, r_end=0.44), bevel=0.03)  # złote obuchy
        t.add("Body", "night", ycyl(y * 1.0 - 0.05, y * 1.0 + 0.05, 0.4, hz, seg=8), bevel=0.02)
        t.add("Glow", "glow_white", ycyl(y * 1.05 - 0.02, y * 1.05 + 0.02, 0.16, hz, seg=8))
    for k in range(4):  # złote żebra po kuli (obręcz)
        a = math.pi / 4 + k * math.pi / 2
        path = [(0.71 * math.sin(u * math.pi) * math.cos(a), -0.71 * math.cos(u * math.pi),
                 hz + 0.71 * math.sin(u * math.pi) * math.sin(a)) for u in [i / 8 for i in range(9)]]
        t.add("Accent", "gold", loft(path, [0.04] * 9, sides=4, ref=Y))
    t.add("Accent", "gold", torus(0.72, 0.045, Matrix.Translation((0, 0, hz)), seg=24, sides=4))  # równik
    t.add("Body", "night", box(0.42, 0.42, 0.22, (0, 0, hz - 0.7)), bevel=0.04)  # mocowanie
    # galaktyka w płaszczyźnie Y-Z (widoczna z boku przez szkło), kręci się wokół X
    for arm in range(2):
        path, rad = [], []
        for i in range(12):
            u = i / 11
            a = arm * math.pi + u * 3.6
            r = 0.06 + 0.5 * u
            path.append((0, r * math.cos(a), hz + r * math.sin(a)))
            rad.append((0.02, 0.07 * (1 - u) + 0.015) if i < 11 else 0.0)
        t.add("SpinArms", "glow_galaxy", loft(path, rad, sides=4))
    rng = t.rng
    for i in range(16):
        a, r = rng.uniform(0, 2 * math.pi), rng.uniform(0.15, 0.58)
        t.add("SpinStars", "glow_galaxy2", ico(rng.uniform(0.022, 0.04), (rng.uniform(-0.05, 0.05), r * math.cos(a),
                                                                            hz + r * math.sin(a))))
    t.add("Glow", "glow_white", ico(0.11, (0, 0, hz), sub=2))
    t.spin["SpinArms"] = (X, 60)
    t.spin["SpinStars"] = (X, 60)
    t.trail = ((0, 0, 3.3), (0, 0, 5.0), ["#FF5CE1", "#7A8CFF"], 0.2, 1.2)
    t.particles.append({"part": "Glass", "color": "#FFB8F5", "rate": 6, "size": 0.18, "speed": 0.3, "tex": "glint",
                        "life": 1.4})


BUILDERS = {f.__name__: f for f in (stone_pickaxe, iron_hammer, crystal_axe, plasma_saw, laser_sword, gravity_hammer,
                                     nova_cannon, starbreaker, comet_blade, galaxy_hammer)}


# ---------------------------------------------------------------- meta, eksport

def bbox(ob):
    ws = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector([min(w[i] for w in ws) for i in range(3)])
    hi = Vector([max(w[i] for w in ws) for i in range(3)])
    return lo, hi


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def tool_info(tid):
    if tid in TOOLS["tools"]:
        d = TOOLS["tools"][tid]
        return d["name"], d["tier"], False
    return EXCL[tid]["name"], None, True


def meta_for(t, obs):
    parts = {}
    lo_all = Vector((1e9,) * 3)
    hi_all = Vector((-1e9,) * 3)
    for part, ob in obs.items():
        lo, hi = bbox(ob)
        lo_all = Vector([min(a, b) for a, b in zip(lo_all, lo)])
        hi_all = Vector([max(a, b) for a, b in zip(hi_all, hi)])
        hx, rbx, tr = PAL[t.parts[part][0]]
        size = hi - lo
        parts[part] = {"material": rbx, "color": hx, "transparency": tr, "center": to_roblox((lo + hi) / 2),
                       "size": [round(size.x, 4), round(size.z, 4), round(size.y, 4)], "tris": tris(ob)}
        if part in t.spin:
            axis, speed = t.spin[part]
            parts[part]["spin"] = {"axis": [abs(a) for a in to_roblox(axis)], "speed": speed}
    name, tier, excl = tool_info(t.tid)
    total = sum(p["tris"] for p in parts.values())
    m = {"name": name, "tier": tier, "exclusive": excl, "grip": [0, 0, 0], "parts": parts, "tris": total,
         "ok": total <= BUDGET, "length": round(hi_all.z - lo_all.z, 3)}
    if t.trail:
        a, b, cols, life, width = t.trail
        m["trail"] = {"a": to_roblox(a), "b": to_roblox(b), "colors": cols, "lifetime": life, "width": width}
    if t.particles:
        m["particles"] = t.particles
    return m


def build_all(ids, coll_root=None):
    tools = {}
    for tid in ids:
        c = bpy.data.collections.new(tid)
        bpy.context.scene.collection.children.link(c)
        t = Tool(tid)
        BUILDERS[tid](t)
        tools[tid] = (t, t.build(c), c)
    return tools


def export_fbx(path, obs):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True,
                             axis_forward="-Z", axis_up="Y", add_leaf_bones=False, mesh_smooth_type="FACE")


# ---------------------------------------------------------------- render

def setup_render(silhouette, w, h):
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1) if silhouette else (0.012, 0.01, 0.03, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    sc.world = world
    for name, energy, loc in (("Key", 6000, (14, -22, 20)), ("Fill", 2000, (-20, -14, 6)), ("Rim", 5000, (-6, 24, 14))):
        li = bpy.data.lights.new(name, "AREA")
        li.energy, li.size = (0, 20) if silhouette else (energy, 20)
        ob = bpy.data.objects.new(name, li)
        ob.location = loc
        ob.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(ob)
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


def label(text, loc, size, mat):
    cu = bpy.data.curves.new(f"L_{text}", "FONT")
    cu.body = text
    cu.align_x = "CENTER"
    cu.size = size
    ob = bpy.data.objects.new(f"L_{text}", cu)
    ob.location = loc
    ob.rotation_euler = (math.radians(90), 0, 0)
    ob.data.materials.append(mat)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def mannequin(x, mat):
    """Prosta postać 5 studs (proporcje awatara R15) do porównania skali."""
    obs = []
    for name, (sx, sy, sz), (cx, cz) in (("Leg", (0.95, 0.95, 2.0), (-0.48, 1.0)), ("Leg2", (0.95, 0.95, 2.0), (0.48, 1.0)),
                                         ("Torso", (1.95, 0.95, 2.0), (0, 3.0)), ("Head", (1.15, 1.15, 1.15), (0, 4.6)),
                                         ("Arm", (0.95, 0.95, 2.0), (-1.45, 3.0)), ("Arm2", (0.95, 0.95, 2.0), (1.45, 3.0))):
        bm = box(sx, sy, sz, (x + cx, 0.3, cz))
        bev(bm, 0.1)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(name, me)
        me.materials.append(mat)
        bpy.context.scene.collection.objects.link(ob)
        obs.append(ob)
    return obs


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


def render_row(ids, name, silhouette=False, turn=0.0, scale_ref=False):
    """Narzędzia w rzędzie (profil Y-Z obrócony do kamery, uderzenie w prawo), kamera z przodu."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    tools = build_all(ids)
    black = flat_mat("_Black", (0, 0, 0))
    gap = 0.6
    x = 0.0
    lo_z, hi_z = 1e9, -1e9
    placed = []
    for tid in ids:
        t, obs, c = tools[tid]
        root = bpy.data.objects.new(tid + "_Root", None)
        bpy.context.scene.collection.objects.link(root)
        for ob in obs.values():
            ob.parent = root
            if silhouette:
                ob.data.materials.clear()
                ob.data.materials.append(black)
        root.rotation_euler = (0, 0, math.radians(90 + turn))
        bpy.context.view_layer.update()
        lo = Vector((1e9,) * 3)
        hi = Vector((-1e9,) * 3)
        for ob in obs.values():
            a, b = bbox(ob)
            lo = Vector([min(p, q) for p, q in zip(lo, a)])
            hi = Vector([max(p, q) for p, q in zip(hi, b)])
        root.location.x = x - lo.x
        root.location.z = 0.0 if not scale_ref else 3.0  # w skali: chwyt na wysokości dłoni (~3 studs)
        placed.append((tid, x + (hi.x - lo.x) / 2))
        x += (hi.x - lo.x) + gap
        lo_z, hi_z = min(lo_z, lo.z + root.location.z), max(hi_z, hi.z + root.location.z)
    width = x - gap
    lab = flat_mat("_Lab", (0, 0, 0)) if silhouette else flat_mat("_LabW", (0.85, 0.85, 0.95), 1.5)
    ground_z = lo_z - 0.55
    if scale_ref:
        dummy = flat_mat("_Dummy", (0.25, 0.25, 0.3)) if not silhouette else flat_mat("_DummyG", (0.6, 0.6, 0.6))
        mannequin(-2.2, dummy)
        ground_z = -0.6
        lo_z = 0.0
    for tid, cx in placed:
        name_, tier, excl = tool_info(tid)
        label(f"{tier}" if tier else "R$", (cx, -2, ground_z), 0.42, lab)
    setup_render(silhouette, 3000, 1000 if not scale_ref else 1100)
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    left = -4.0 if scale_ref else -0.3
    cam.ortho_scale = (width - left + 0.3)
    ob = bpy.data.objects.new("Cam", cam)
    bpy.context.scene.collection.objects.link(ob)
    zc = (min(lo_z, ground_z) + hi_z) / 2 - 0.1
    ob.location = ((left + width + 0.3) / 2, -60, zc)
    ob.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.scene.camera = ob
    bpy.context.scene.render.filepath = str(IMG / f"{name}.png")
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ids = argv[argv.index("--only") + 1].split(",") if "--only" in argv else IDS
    if "--no-export" not in argv:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        tools = build_all(ids)
        meta_path = OUT / "tools_meta.json"
        meta = json.loads(meta_path.read_text(encoding="utf-8")) if meta_path.exists() and "--only" in argv else {}
        all_obs = []
        for tid, (t, obs, c) in tools.items():
            meta[tid] = meta_for(t, obs)
            all_obs += list(obs.values())
        OUT.mkdir(parents=True, exist_ok=True)
        export_fbx(OUT / "tools.fbx", all_obs)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "tools.blend"))
        meta_path.write_text(json.dumps({k: meta[k] for k in IDS if k in meta}, indent=1), encoding="utf-8")
        print("TOOLS_REPORT", json.dumps({k: {"tris": v["tris"], "ok": v["ok"], "length": v["length"],
                                              "parts": len(v["parts"])} for k, v in meta.items()}))
    if "--sketch" in argv:
        render_row(ids, "T11 narzedzia sylwetki", silhouette=True)
    if "--render" in argv:
        render_row(ids, "T11 narzedzia", turn=-28)
        render_row(ids, "T11 skala", scale_ref=True, turn=-15)
    print("TOOLS_DONE")


main()
