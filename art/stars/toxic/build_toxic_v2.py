"""build_toxic_v2.py — Toxic Star v2 (T40): skalna korona z płyt bazaltu wokół świecącego rdzenia.

Źródło wyglądu: vault/_ref/toxic_user_3.png. Specyfikacja: vault/02 Systemy/Toxic Star v2 - specyfikacja produkcyjna.md.
Układ i proporcje są te same co w prototypie art/stars/toxic/viewer/ToxicStarLab.html (ten sam podział na części).

Uruchom (Blender 5.x w tle):
  E:\\blender\\blender.exe -b --factory-startup -P art/stars/toxic/build_toxic_v2.py -- [--render]

Wyjście:
  art/stars/toxic/star_toxic_v2.fbx    obiekty <Wariant>_<Część>, warianty Large (też Medium/Huge) i Small
  art/stars/toxic/star_toxic_v2.blend
  art/stars/toxic/toxic_v2_anchors.json  ANCHOR_* i Zone_N w układzie Roblox (−x, z, y), jednostki modelu
  vault/_img/T40 toxic v2 studio.png, vault/_img/T40 toxic v2 noc.png  (z --render)

Części (osobne MeshParty w Roblox, rola → materiał w imporcie):
  Shell01..06      skorupa w 6 segmentach (MAT_Rock, SurfaceAppearance)       — ruchome
  CrackVeins01..06 świecące żyły na segmentach (Neon)                         — przyspawane do Shell
  Core, CoreShell  rdzeń (Neon) i otoczka (Glass/ForceField)
  CrystalA/B/C/G01..G04  kępy kryształów, origin u podstawy (Glass)           — ruchome
  Slime            zacieki i kałuża (Neon)
  Crater, CraterVeins, GroundCracks   krater (MAT_Ground), żyły i pęknięcia dna (Neon)
  FloatingRock01..03, FloatingCrystal01..02   szablony gruzu dla klienta
Układ: Blender Z w górę, przód gwiazdy = −Y (w Roblox −Z, LookVector). Origin całości = środek dna krateru.
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

ROOT = Path(__file__).resolve().parents[3]
DATA = ROOT / "game" / "src" / "shared" / "Config" / "Data"
OUT = ROOT / "art" / "stars" / "toxic"
IMG = ROOT / "vault" / "_img"

STARS = json.loads((DATA / "Stars.json").read_text(encoding="utf-8"))
THEME = json.loads((DATA / "Themes.json").read_text(encoding="utf-8"))["themes"]["Toxic"]
SEED = 4040

# Bazalt z referencji v2 (szary z fioletem). Themes.json `shell` Toxic (#1B2A14) jest jeszcze z v1 — do zmiany przy imporcie v2.
ROCK_RGB = "#3B3842"
GROUND_RGB = "#46434C"
CORE = (0.0, 1.15, 0.2)  # (x, góra, przód) jak w prototypie; przód → −Y w Blenderze

# Gęstość na wariant. Large służy też jako Medium i Huge (Model:ScaleTo w Studio).
LOD = {
    "Large": dict(ring=9, back=2, top=3, spikes=8, inner=5, bevel=0.014, veins=2, cry=1.0, ground=4, core_sub=3,
                  slabs=26, rubble=14, crack_depth=2, cracks=10, rocks=3, fcrys=2, drips=5, budget=20000),
    "Small": dict(ring=7, back=2, top=2, spikes=6, inner=3, bevel=0.0, veins=1, cry=0.6, ground=2, core_sub=2,
                  slabs=16, rubble=6, crack_depth=1, cracks=7, rocks=2, fcrys=0, drips=3, budget=5000),
}
SEG_N = 6


def V(x, up, front):
    """Współrzędne prototypu (x, góra, przód) → Blender (x, −przód, góra)."""
    return Vector((x, -front, up))


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


# ---------------------------------------------------------------- geometria

def hull_bm(points):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in points]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list({v for v in res["geom_interior"] + res["geom_unused"] if isinstance(v, bmesh.types.BMVert)})
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def shard_pts(rng, w, h, d):
    p = []
    for i in range(5):
        a = i / 5 * math.tau + rng.uniform(-0.3, 0.3)
        p.append(Vector((math.cos(a) * w * rng.uniform(0.7, 1), math.sin(a) * d * rng.uniform(0.7, 1), rng.uniform(-0.05, 0.1))))
    for i in range(4):
        a = i / 4 * math.tau + rng.uniform(-0.4, 0.4)
        p.append(Vector((math.cos(a) * w * rng.uniform(0.75, 0.95), math.sin(a) * d * rng.uniform(0.75, 0.95), h * rng.uniform(0.45, 0.65))))
    # ścięty, złamany szczyt (grube płyty bazaltu z referencji, nie igły)
    side = rng.choice((-1, 1))
    p.append(Vector((side * w * rng.uniform(0.15, 0.35), rng.uniform(-0.2, 0.2) * d, h)))
    p.append(Vector((-side * w * rng.uniform(0.3, 0.55), rng.uniform(-0.3, 0.3) * d, h * rng.uniform(0.7, 0.85))))
    p.append(Vector((rng.uniform(-0.2, 0.2) * w, d * rng.uniform(0.4, 0.7), h * rng.uniform(0.75, 0.9))))
    return p


def rock_pts(rng, r, squash=0.75):
    p = []
    for _ in range(16):
        u = rng.uniform(-1, 1)
        a = rng.uniform(0, math.tau)
        q = math.sqrt(1 - u * u)
        k = r * rng.uniform(0.7, 1.05)
        p.append(Vector((q * math.cos(a) * k, q * math.sin(a) * k, u * k * squash)))
    return p


def slab_pts(rng, w, h, d):
    p = []
    for i in range(6):
        a = i / 6 * math.tau + rng.uniform(-0.3, 0.3)
        p.append(Vector((math.cos(a) * w * rng.uniform(0.75, 1), math.sin(a) * d * rng.uniform(0.75, 1), 0)))
    for i in range(4):
        a = i / 4 * math.tau + rng.uniform(-0.4, 0.4)
        p.append(Vector((math.cos(a) * w * rng.uniform(0.45, 0.75), math.sin(a) * d * rng.uniform(0.45, 0.75), h * rng.uniform(0.7, 1))))
    return p


def crystal_into(bm, base, direction, r, h, tip, rng, sides=6):
    """Heksagonalny słup z czubkiem (jak LatheGeometry w prototypie)."""
    z = direction.normalized()
    x = z.cross(Vector((0, 0, 1)) if abs(z.z) < 0.9 else Vector((1, 0, 0))).normalized()
    y = z.cross(x)
    rot = rng.uniform(0, math.tau)
    rings = [(r * 0.8, 0.0), (r, h * 0.12), (r * rng.uniform(0.9, 1.05), h)]
    loops = []
    for rad, hh in rings:
        loop = []
        for i in range(sides):
            a = rot + i / sides * math.tau
            loop.append(bm.verts.new(base + x * math.cos(a) * rad + y * math.sin(a) * rad + z * hh))
        loops.append(loop)
    apex = bm.verts.new(base + z * (h + tip))
    bm.faces.new(list(reversed(loops[0])))
    for a, b in zip(loops, loops[1:]):
        for i in range(sides):
            bm.faces.new((a[i], a[(i + 1) % sides], b[(i + 1) % sides], b[i]))
    for i in range(sides):
        bm.faces.new((loops[-1][i], loops[-1][(i + 1) % sides], apex))


def bm_append(dst, src, matrix=None):
    """Dokleja geometrię src do dst (opcjonalnie z transformacją)."""
    me = bpy.data.meshes.new("_tmp")
    src.to_mesh(me)
    if matrix is not None:
        me.transform(matrix)
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)


def ribbon_into(bm, pts, normal_of, w0, w1, lift):
    """Płaska wstęga (żyła/pęknięcie) wzdłuż łamanej; normal_of(i) → normalna powierzchni pod punktem i."""
    left, right = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        nn = normal_of(i)
        side = nn.cross(d).normalized()
        w = (w0 + (w1 - w0) * i / max(1, n - 1)) / 2
        left.append(bm.verts.new(p + side * w + nn * lift))
        right.append(bm.verts.new(p - side * w + nn * lift))
    for i in range(n - 1):
        bm.faces.new((left[i], right[i], right[i + 1], left[i + 1]))


def veins_on(bm_src, veins_bm, rng, count, width, matrix_inv):
    """Żyły na największych ścianach bryły: łamana przez ścianę od krawędzi do krawędzi."""
    bm_src.normal_update()
    faces =sorted([f for f in bm_src.faces if f.normal.z > -0.35], key=lambda f: -f.calc_area())[:count]
    for f in faces:
        vs = [v.co.copy() for v in f.verts]
        if len(vs) < 3:
            continue
        i = rng.randrange(len(vs))
        j = (i + rng.randint(1, len(vs) - 1)) % len(vs)
        a = vs[i].lerp(vs[(i + 1) % len(vs)], rng.uniform(0.3, 0.7))
        b = vs[j].lerp(vs[(j + 1) % len(vs)], rng.uniform(0.3, 0.7))
        c = f.calc_center_median()
        n = f.normal.copy()
        seg = 5
        pts = []
        for k in range(seg + 1):
            t = k / seg
            p = a.lerp(c, t * 2) if t < 0.5 else c.lerp(b, (t - 0.5) * 2)
            if 0 < k < seg:
                side = n.cross(b - a).normalized()
                p = p + side * rng.uniform(-0.04, 0.04)
            pts.append(matrix_inv @ p)
        nl = (matrix_inv.to_3x3() @ n).normalized()
        ribbon_into(veins_bm, pts, lambda _i: nl, width, width * 0.5, 0.006)


def ground_crack(bm, rng, start, ang, length, w, depth, z):
    pts = [start.copy()]
    p = start.copy()
    total = 0.0
    while total < length:
        st = rng.uniform(0.12, 0.26)
        ang += rng.uniform(-0.45, 0.45)
        p = p + Vector((math.cos(ang), math.sin(ang), 0)) * st
        pts.append(p.copy())
        total += st
        if depth > 0 and rng.random() < 0.16:
            ground_crack(bm, rng, p, ang + rng.uniform(-1.3, 1.3), length * 0.4, w * 0.6, depth - 1, z)
    for q in pts:
        q.z = z
    ribbon_into(bm, pts, lambda _i: Vector((0, 0, 1)), w, w * 0.3, 0.0)


# ---------------------------------------------------------------- obiekty i materiały

def make_obj(name, bm, coll, mat, origin=None, bevel=0.0):
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    if origin is not None:
        me.transform(Matrix.Translation(-origin))
        ob.location = origin
    coll.objects.link(ob)
    me.materials.append(mat)
    for p in me.polygons:
        p.use_smooth = False
    return ob


def material(name, rgb, rough=0.6, emission=0.0, neon=False, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    c = lin(hex_rgb(rgb))
    b.inputs["Base Color"].default_value = (0, 0, 0, 1) if neon else (*c, 1)
    b.inputs["Roughness"].default_value = rough
    if emission > 0:
        b.inputs["Emission Color"].default_value = (*c, 1)
        b.inputs["Emission Strength"].default_value = emission
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
        b.inputs["Coat Weight"].default_value = 1.0
        m.surface_render_method = "BLENDED"
        m.use_backface_culling = False
    return m


def mats():
    return {
        "Rock": material("MAT_Rock", ROCK_RGB, rough=0.85),
        "Ground": material("MAT_Ground", GROUND_RGB, rough=0.95),
        "Neon": material("MAT_GroundGlow", THEME["color"], emission=6.0, neon=True),
        "Core": material("MAT_Core", THEME["glow"], emission=3.5, neon=True),
        "CoreShell": material("MAT_CoreShell", THEME["color"], rough=0.1, emission=0.6, alpha=0.25),
        "Crystal": material("MAT_ToxicCrystal", THEME["color"], rough=0.12, emission=1.2, alpha=0.82),
        "Slime": material("MAT_Slime", THEME["color"], emission=5.0, neon=True),
    }


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ---------------------------------------------------------------- budowa wariantu

def build_variant(var, coll, M, rng):
    L = LOD[var]
    parts = {}
    core = V(*CORE)

    # ---- skorupa: rozmieszczenie płyt jak w prototypie, przypisanie do 6 segmentów wg kąta
    places = []

    def add(theta, r, base, h, w, d, tilt):
        # skręt mały: szeroka ściana płyty patrzy na zewnątrz, jak w referencji
        places.append((theta % math.tau, r, base, h, w, d, tilt, rng.uniform(-0.5, 0.5)))

    for i in range(L["ring"]):
        th = i / L["ring"] * math.tau + rng.uniform(-0.15, 0.15)
        h, tilt = rng.uniform(1.5, 2.3), rng.uniform(0.25, 0.45)
        if math.cos(th) > 0.55:  # przód: niżej i mocniej odchylone, rdzeń widoczny
            h, tilt = h * 0.5, tilt + 0.35
        add(th, rng.uniform(0.85, 1.0), 0.15, h, rng.uniform(0.45, 0.65), rng.uniform(0.3, 0.42), tilt)
    for k in (-0.35, 0.4)[:L["back"]]:
        add(math.pi + k, 0.4, 0.3, rng.uniform(2.6, 3.0), 0.55, 0.38, 0.15)
    for k in (-0.9, 0.0, 0.9)[:L["top"]]:
        add(math.pi + k, 0.32, 1.5, rng.uniform(1.1, 1.5), 0.42, 0.3, 0.4)
    for i in range(L["spikes"]):
        add(i / L["spikes"] * math.tau + 0.2, 1.1, 0.02, rng.uniform(0.8, 1.2), rng.uniform(0.4, 0.52), rng.uniform(0.28, 0.36), rng.uniform(0.9, 1.1))
    for i in range(L["inner"]):
        add(math.pi / 2 + i / max(1, L["inner"] - 1) * math.pi, 0.55, 0.2, rng.uniform(1.5, 1.9), 0.5, 0.36, 0.2)

    segs = [{"bm": bmesh.new(), "veins": bmesh.new(), "pts": []} for _ in range(SEG_N)]
    shard_bms = []
    for th, r, base, h, w, d, tilt, twist in places:
        si = min(SEG_N - 1, int(th / (math.tau / SEG_N)))
        mat = (Matrix.Translation((0, 0, base)) @ Matrix.Rotation(th, 4, "Z") @ Matrix.Translation((0, -r, 0))
               @ Matrix.Rotation(tilt, 4, "X") @ Matrix.Rotation(twist, 4, "Z"))
        bm = hull_bm(shard_pts(rng, w, h, d))
        bmesh.ops.transform(bm, matrix=mat, verts=bm.verts)
        shard_bms.append((si, bm))
        segs[si]["pts"].append(mat @ Vector((0, 0, h * 0.45)))
    for s in segs:
        c = Vector()
        for p in s["pts"]:
            c += p
        s["origin"] = c / max(1, len(s["pts"]))
    for si, bm in shard_bms:
        veins_on(bm, segs[si]["veins"], rng, L["veins"], 0.035, Matrix.Identity(4))
        bm_append(segs[si]["bm"], bm)
        bm.free()
    for i, s in enumerate(segs):
        n = f"{i + 1:02d}"
        parts[f"Shell{n}"] = make_obj(f"{var}_Shell{n}", s["bm"], coll, M["Rock"], origin=s["origin"], bevel=L["bevel"])
        parts[f"CrackVeins{n}"] = make_obj(f"{var}_CrackVeins{n}", s["veins"], coll, M["Neon"], origin=s["origin"])

    # ---- rdzeń
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=L["core_sub"], radius=0.55)
    bmesh.ops.translate(bm, vec=core, verts=bm.verts)
    parts["Core"] = make_obj(f"{var}_Core", bm, coll, M["Core"], origin=core.copy())
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.66)
    bmesh.ops.translate(bm, vec=core, verts=bm.verts)
    parts["CoreShell"] = make_obj(f"{var}_CoreShell", bm, coll, M["CoreShell"], origin=core.copy())

    # ---- kryształy (kępa = jeden obiekt, origin u podstawy)
    groups = [("CrystalA", (-1.0, 0.05, 0.95), 5, (0.5, 1.1), (0.5, 0.9), 0.25),
              ("CrystalB", (1.05, 0.05, 0.8), 4, (0.45, 1.0), (0.5, 0.9), 0.22),
              ("CrystalC", (0.05, 2.05, -0.35), 5, (0.9, 1.5), (0.2, 0.5), 0.2)]
    for i, (x, f) in enumerate([(1.75, -0.3), (-1.9, 0.6), (0.4, 1.95), (-0.6, -1.85)][:L["ground"]]):
        groups.append((f"CrystalG{i + 1:02d}", (x, 0.02, -f), 2 + i % 2, (0.3, 0.6), (0.6, 1.1), 0.15))
    for name, (x, up, fr), n, hr, outr, spread in groups:
        pivot = V(x, up, fr)
        out = Vector((pivot.x, pivot.y, 0)).normalized()
        bm = bmesh.new()
        for _ in range(max(2, round(n * L["cry"]))):
            h = rng.uniform(*hr)
            r = h * rng.uniform(0.13, 0.18)
            d = out * rng.uniform(*outr) + Vector((rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), 1))
            base = pivot + Vector((rng.uniform(-1, 1) * spread, rng.uniform(-1, 1) * spread, -0.05))
            crystal_into(bm, base, d, r, h, r * rng.uniform(1.6, 2.4), rng)
        parts[name] = make_obj(f"{var}_{name}", bm, coll, M["Crystal"], origin=pivot)

    # ---- maź: zacieki pod rdzeniem i na przednich płytach + kałuża
    bm = bmesh.new()
    drips = [(-0.16, 0.74, 0.5, 0.28), (0.0, 0.7, 0.55, 0.46), (0.13, 0.73, 0.52, 0.32), (-0.55, 1.15, 0.78, 0.3), (0.62, 0.98, 0.7, 0.36)][:L["drips"]]
    drip_ends = []
    for x, up, fr, length in drips:
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=6, v_segments=5, radius=1.0)
        bmesh.ops.transform(tmp, matrix=Matrix.Translation(V(x, up - length / 2, fr)) @ Matrix.Diagonal((0.04, 0.04, length / 2 + 0.02, 1)), verts=tmp.verts)
        bm_append(bm, tmp)
        tmp.free()
        drip_ends.append(V(x, up - length - 0.04, fr))
    ring = []
    for i in range(12):
        a = i / 12 * math.tau
        rr = rng.uniform(0.8, 1.1)
        ring.append(bm.verts.new(V(math.cos(a) * 0.5 * rr, 0.012, 0.72 + math.sin(a) * 0.3 * rr)))
    bm.faces.new(ring)
    parts["Slime"] = make_obj(f"{var}_Slime", bm, coll, M["Slime"])

    # ---- krater: dno, pierścień płyt, gruz, żyły, pęknięcia dna
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=32 if var == "Large" else 20, radius1=2.95, radius2=2.7, depth=0.2)
    bmesh.ops.translate(bm, vec=Vector((0, 0, -0.1)), verts=bm.verts)
    cveins = bmesh.new()
    for i in range(L["slabs"]):
        a = i / L["slabs"] * math.tau + rng.uniform(-0.08, 0.08)
        r = rng.uniform(2.2, 2.65)
        mat = (Matrix.Rotation(a, 4, "Z") @ Matrix.Translation((0, -r, -0.02))
               @ Matrix.Rotation(rng.uniform(0.15, 0.45), 4, "X") @ Matrix.Rotation(rng.uniform(0, math.tau), 4, "Z"))
        sb = hull_bm(slab_pts(rng, rng.uniform(0.35, 0.55), rng.uniform(0.22, 0.5), rng.uniform(0.28, 0.45)))
        bmesh.ops.transform(sb, matrix=mat, verts=sb.verts)
        if rng.random() < 0.6:
            veins_on(sb, cveins, rng, 1, 0.03, Matrix.Identity(4))
        bm_append(bm, sb)
        sb.free()
    for _ in range(L["rubble"]):
        a, r = rng.uniform(0, math.tau), rng.uniform(1.2, 1.95)
        rb = hull_bm(rock_pts(rng, rng.uniform(0.08, 0.18)))
        bmesh.ops.transform(rb, matrix=Matrix.Translation((math.sin(a) * r, math.cos(a) * r, 0.04)), verts=rb.verts)
        bm_append(bm, rb)
        rb.free()
    parts["Crater"] = make_obj(f"{var}_Crater", bm, coll, M["Ground"], bevel=L["bevel"] * 0.7)
    parts["CraterVeins"] = make_obj(f"{var}_CraterVeins", cveins, coll, M["Neon"])
    gc = bmesh.new()
    for i in range(L["cracks"]):
        a = i / L["cracks"] * math.tau + rng.uniform(-0.2, 0.2)
        ground_crack(gc, rng, Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 0)), a, rng.uniform(1.4, 2.1), 0.07, L["crack_depth"], 0.008)
    parts["GroundCracks"] = make_obj(f"{var}_GroundCracks", gc, coll, M["Neon"])

    # ---- szablony latającego gruzu (klient klonuje i rozmieszcza)
    for i in range(L["rocks"]):
        rb = hull_bm(rock_pts(rng, 0.24, squash=rng.uniform(0.6, 0.9)))
        pos = V(-2.4 + i * 0.4, 2.6 + i * 0.3, -0.8)
        bmesh.ops.translate(rb, vec=pos, verts=rb.verts)
        parts[f"FloatingRock{i + 1:02d}"] = make_obj(f"{var}_FloatingRock{i + 1:02d}", rb, coll, M["Rock"], origin=pos, bevel=L["bevel"])
    for i in range(L["fcrys"]):
        cb = bmesh.new()
        pos = V(2.2 - i * 0.5, 2.9 - i * 0.4, 0.3)
        crystal_into(cb, pos, Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 1)), 0.05, 0.28, 0.1, rng)
        parts[f"FloatingCrystal{i + 1:02d}"] = make_obj(f"{var}_FloatingCrystal{i + 1:02d}", cb, coll, M["Crystal"], origin=pos)

    # ---- punkty zaczepienia i strefy minigry
    anchors = {"ANCHOR_Core": core, "ANCHOR_Shockwave": Vector((0, 0, 0.06)), "ANCHOR_Particles": V(0, 1.7, 0)}
    for i, p in enumerate(drip_ends[:3]):
        anchors[f"ANCHOR_Drip_{i + 1:02d}"] = p
    shell_obs = [parts[f"Shell{i + 1:02d}"] for i in range(SEG_N)]
    hits = surface_points(shell_obs, core, rng, 14)
    for i, p in enumerate(hits[:3]):
        anchors[f"ANCHOR_Cracks_{i + 1:02d}"] = p
    zones = farthest(hits, 12)
    return parts, anchors, zones


def surface_points(obs, core, rng, n):
    """Punkty na skorupie widoczne z zewnątrz: promienie z zewnątrz do rdzenia (górna i przednia półkula)."""
    bm = bmesh.new()
    for ob in obs:
        tmp = bmesh.new()
        tmp.from_mesh(ob.data)
        bm_append(bm, tmp, ob.matrix_world)
        tmp.free()
    tree = BVHTree.FromBMesh(bm)
    out = []
    tries = 0
    while len(out) < n and tries < 400:
        tries += 1
        a = rng.uniform(0, math.tau)
        el = rng.uniform(-0.1, 0.9)
        d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
        if d.y > 0.6:  # tył mniej widoczny dla gracza
            continue
        hit = tree.ray_cast(core + d * 6, -d)
        if hit[0] is not None:
            out.append(hit[0] + hit[1] * 0.02)
    bm.free()
    return out


def farthest(pts, k):
    if not pts:
        return []
    chosen = [max(pts, key=lambda p: p.z)]
    while len(chosen) < min(k, len(pts)):
        chosen.append(max(pts, key=lambda p: min((p - c).length for c in chosen)))
    return chosen


def to_roblox(v):
    return [round(-v.x, 4), round(v.z, 4), round(v.y, 4)]


def uv_unwrap(obs):
    for ob in obs:
        try:
            bpy.ops.object.select_all(action="DESELECT")
            bpy.context.view_layer.objects.active = ob
            ob.select_set(True)
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
            bpy.ops.object.mode_set(mode="OBJECT")
        except RuntimeError as e:
            print("UV skip", ob.name, e)


def export_fbx(path, obs):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True,
                             axis_forward="-Z", axis_up="Y", add_leaf_bones=False, mesh_smooth_type="FACE")


# ---------------------------------------------------------------- render

def setup_render(night):
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 1600, 1200
    sc.view_settings.view_transform = "Standard"
    try:
        sc.view_settings.look = "Medium High Contrast"
    except TypeError:
        pass
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    bg = (0.004, 0.006, 0.005) if night else (0.42, 0.43, 0.45)
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (*bg, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    sc.world = world
    # tło-podłoga (tylko render)
    bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, -0.21))
    fl = bpy.context.active_object
    fl.name = "_Floor"
    fm = material("_FloorMat", "#0B0F0C" if night else "#C9CACD", rough=1.0)
    fl.data.materials.append(fm)
    k = 0.15 if night else 1.0
    for name, energy, loc, col in (("Key", 2600 * k, (7, -10, 11), (1, 0.97, 0.92)), ("Fill", 700 * k, (-10, -6, 3), (0.8, 0.85, 1.0)),
                                   ("Rim", 2400 * (0.6 if night else 1.0), (-4, 11, 7), (0.6, 0.7, 1.0) if night else (1, 1, 1))):
        li = bpy.data.lights.new(name, "AREA")
        li.energy, li.size, li.color = energy, 8, col
        ob = bpy.data.objects.new(name, li)
        ob.location = loc
        ob.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(ob)
    # poświata: tylko Neon (próg nad jasnością oświetlonej skały)
    ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
    ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    rl = ng.nodes.new("CompositorNodeRLayers")
    gl = ng.nodes.new("CompositorNodeGlare")
    out = ng.nodes.new("NodeGroupOutput")
    for key, val in (("Type", "Bloom"), ("Threshold", 1.2 if not night else 0.8), ("Strength", 0.8 if not night else 1.2), ("Size", 7), ("Quality", "High")):
        try:
            gl.inputs[key].default_value = val
        except (TypeError, KeyError, AttributeError) as e:
            print("GLARE skip", key, e)
    ng.links.new(rl.outputs["Image"], gl.inputs["Image"])
    ng.links.new(gl.outputs[0], out.inputs[0])
    sc.compositing_node_group = ng


def camera(loc, target, lens):
    cam = bpy.data.cameras.new("Cam")
    cam.lens = lens
    ob = bpy.data.objects.new("Cam", cam)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = ob


def preview_debris(src_obs, rng, n):
    """Kopie szablonów gruzu na orbicie — tylko do renderu, nie do FBX."""
    for i in range(n):
        src = src_obs[i % len(src_obs)]
        ob = src.copy()
        ob.name = f"_Preview_{i}"
        a = rng.uniform(0, math.tau)
        r = rng.uniform(1.9, 3.0)
        ob.location = (math.sin(a) * r, -math.cos(a) * r, rng.uniform(0.5, 3.4))
        ob.rotation_euler = (rng.uniform(0, 3), rng.uniform(0, 3), rng.uniform(0, 3))
        ob.scale = (rng.uniform(0.6, 1.2),) * 3
        bpy.context.scene.collection.objects.link(ob)


# ---------------------------------------------------------------- main

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    render = "--render" in argv
    bpy.ops.wm.read_factory_settings(use_empty=True)
    M = mats()
    report, anchors_all, all_obs = {}, {}, []
    for var in ("Large", "Small"):
        coll = bpy.data.collections.new(var)
        bpy.context.scene.collection.children.link(coll)
        parts, anchors, zones = build_variant(var, coll, M, random.Random(SEED))
        t = {k: tris(ob) for k, ob in parts.items()}
        total = sum(v for k, v in t.items() if not k.startswith("Floating"))
        debris = sum(v for k, v in t.items() if k.startswith("Floating"))
        report[var] = {"total": total, "debrisTemplates": debris, "budget": LOD[var]["budget"], "ok": total + debris * 3 <= LOD[var]["budget"], "parts": t}
        xs = [ob.matrix_world @ v.co for ob in parts.values() for v in ob.data.vertices]
        extent = max(max(p[i] for p in xs) - min(p[i] for p in xs) for i in range(3))
        anchors_all[var] = {"extent": round(extent, 4), "anchors": {k: to_roblox(v) for k, v in anchors.items()}, "zones": [to_roblox(z) for z in zones]}
        all_obs += list(parts.values())
        if var == "Small":
            coll.hide_render = True
    uv_unwrap(all_obs)
    OUT.mkdir(parents=True, exist_ok=True)
    export_fbx(OUT / "star_toxic_v2.fbx", all_obs)
    zone_counts = {k: v["zones"] for k, v in STARS["classes"].items()}
    (OUT / "toxic_v2_anchors.json").write_text(json.dumps({"note": "Roblox (−x, z, y), jednostki modelu; Zone_N: pierwsze N wg rozmiaru",
                                                           "zoneCounts": zone_counts, **anchors_all}, indent=1, ensure_ascii=False), encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "star_toxic_v2.blend"))
    print("TOXIC_V2_REPORT", json.dumps(report))
    if render:
        IMG.mkdir(parents=True, exist_ok=True)
        large_debris = [ob for ob in all_obs if ob.name.startswith("Large_Floating")]
        preview_debris(large_debris, random.Random(7), 9)
        camera((6.6, -9.0, 4.6), (0, 0, 1.25), 42)
        for night, name in ((False, "T40 toxic v2 studio"), (True, "T40 toxic v2 noc")):
            for ob in [o for o in bpy.data.objects if o.type == "LIGHT" or o.name == "_Floor"]:
                bpy.data.objects.remove(ob)
            setup_render(night)
            bpy.context.scene.render.filepath = str(IMG / f"{name}.png")
            bpy.ops.render.render(write_still=True)
            print("RENDER", name)


main()
