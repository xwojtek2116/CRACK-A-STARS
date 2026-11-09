"""build_star_v2.py — wszystkie gwiazdy v2 (T40) na szkielecie Toxic v2.

Każdy rodzaj = ten sam szkielet części (jak Toxic, vault/02 Systemy/Toxic Star v2 - specyfikacja produkcyjna.md):
  Shell01..06 + CrackVeins01..06 (skorupa w 6 segmentach + świecące żyły), Core + CoreShell, kępy CrystalA/B/C/G01..G04,
  Slime (płyn, gdy rodzaj go ma), Crater + CraterVeins + GroundCracks, FloatingRock01..03 / FloatingCrystal01..02.
Różni się styl skorupy (płyty, głazy, lodowe słupy, pręty, korona kolców, pierścień…), kształt kryształów, rdzeń i kolory.
Dzięki temu StarVisual (klient) i import do Studio działają dla każdego rodzaju bez zmian.

Uruchom:
  E:\\blender\\blender.exe -b --factory-startup -P art/stars/build_star_v2.py -- [--types Iron,Lava] [--render]
Wyjście na rodzaj: art/stars/<rodzaj>/star_<rodzaj>_v2.fbx/.blend; wspólnie: art/stars/stars_v2_anchors.json,
  vault/_img/T40 gwiazdy v2.png (z --render, siatka Large wszystkich rodzajów) i T40 gwiazdy v2 sylwetki.png.
Toxic ma własny generator (art/stars/toxic/build_toxic_v2.py) — tu jest tylko dla kompletu renderu i kotwic.
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
OUT = ROOT / "art" / "stars"
IMG = ROOT / "vault" / "_img"
STARS = json.loads((DATA / "Stars.json").read_text(encoding="utf-8"))
THEMES = json.loads((DATA / "Themes.json").read_text(encoding="utf-8"))
SEG_N = 6

# Styl rodzaju. shell: plates | boulders | shards | rods | egg | low | corona; liczby w jednostkach modelu (szer. ~2,4–4).
STYLE = {
    "Iron": dict(seed=101, shell="boulders", rock="#4A4440", ground="#3E3A38", crystal="spike", cryScale=0.7, fluid=False,
                 core=(0.5, 1.05, 0.15), coreMat="Neon", shellMat="CorrodedMetal"),
    "Lava": dict(seed=202, shell="plates", hMul=0.85, wMul=1.2, rock="#2B211D", ground="#2A2220", crystal="hex", cryScale=0.8,
                 fluid=True, core=(0.55, 1.0, 0.2), shellMat="Basalt"),
    "Frost": dict(seed=303, shell="shards", rock="#A9D9F2", ground="#8FB4CC", crystal="hex", cryScale=1.0, fluid=True,
                  core=(0.5, 1.2, 0.15), shellMat="Ice", veinW=0.025),
    "Geode": dict(seed=404, shell="egg", rock="#5B4A3E", ground="#4E433B", crystal="hex", cryScale=1.25, fluid=False,
                  core=(0.45, 1.0, 0.35), shellMat="Rock"),
    "Comet": dict(seed=505, shell="boulders", hMul=0.75, rock="#4E6A80", ground="#3D4E5C", crystal="spike", cryScale=1.4,
                  tail=True, fluid=False, core=(0.6, 1.1, 0.1), shellMat="Glacier"),
    "Toxic": dict(seed=4040, shell="plates", rock="#3B3842", ground="#46434C", crystal="hex", cryScale=1.0, fluid=True,
                  core=(0.55, 1.15, 0.2), shellMat="Basalt"),
    "Electric": dict(seed=707, shell="rods", rock="#3A3F4C", ground="#34373F", crystal="spike", cryScale=0.8, fluid=False,
                     core=(0.65, 1.35, 0.0), shellMat="DiamondPlate"),
    "Nebula": dict(seed=808, shell="low", rock="#2A1F3D", ground="#2A2433", crystal="hex", cryScale=0.9, fluid=False,
                   core=(0.85, 1.35, 0.0), shellMat="Slate"),
    "Diamond": dict(seed=909, shell="shards", gemShell=True, hMul=1.15, rock="#CFEFFF", ground="#8FA6B8", crystal="gem", cryScale=1.1,
                    fluid=False, core=(0.5, 1.2, 0.15), shellMat="Glass"),
    "Ringed": dict(seed=1010, shell="low", ring=dict(radius=2.05, tilt=0.38, count=22, size=(0.16, 0.3)), rock="#6B4A35",
                   ground="#4F3B2E", crystal="hex", cryScale=0.7, fluid=False, core=(0.9, 1.45, 0.0), shellMat="Sandstone"),
    "Solar": dict(seed=1111, shell="corona", rock="#C99A2E", ground="#5A3A10", crystal="hex", cryScale=0.7, fluid=True,
                  core=(0.85, 1.45, 0.0), shellMat="Foil"),
    "Void": dict(seed=1212, shell="low", ring=dict(radius=1.75, tilt=0.22, count=30, size=(0.16, 0.32), flat=True),
                 rock="#1A1524", ground="#141019", crystal="spike", cryScale=0.9, fluid=False, core=(0.75, 1.4, 0.0),
                 shellMat="Basalt", coreColor="#120A1E"),
}

LOD = {
    "Large": dict(scale=1.0, bevel=0.014, veins=2, ground=4, core_sub=3, slabs=26, rubble=14, crack_depth=2, cracks=10,
                  rocks=3, fcrys=2, drips=5, budget=20000),
    "Small": dict(scale=0.65, bevel=0.0, veins=1, ground=2, core_sub=2, slabs=16, rubble=6, crack_depth=1, cracks=7,
                  rocks=2, fcrys=0, drips=3, budget=5000),
}


def V(x, up, front):
    return Vector((x, -front, up))


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


# ---------------------------------------------------------------- geometria (jak build_toxic_v2.py)

def hull_bm(points):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in points]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list({v for v in res["geom_interior"] + res["geom_unused"] if isinstance(v, bmesh.types.BMVert)})
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def plate_pts(rng, w, h, d):
    p = []
    for i in range(5):
        a = i / 5 * math.tau + rng.uniform(-0.3, 0.3)
        p.append(Vector((math.cos(a) * w * rng.uniform(0.7, 1), math.sin(a) * d * rng.uniform(0.7, 1), rng.uniform(-0.05, 0.1))))
    for i in range(4):
        a = i / 4 * math.tau + rng.uniform(-0.4, 0.4)
        p.append(Vector((math.cos(a) * w * rng.uniform(0.75, 0.95), math.sin(a) * d * rng.uniform(0.75, 0.95), h * rng.uniform(0.45, 0.65))))
    side = rng.choice((-1, 1))
    p.append(Vector((side * w * rng.uniform(0.15, 0.35), rng.uniform(-0.2, 0.2) * d, h)))
    p.append(Vector((-side * w * rng.uniform(0.3, 0.55), rng.uniform(-0.3, 0.3) * d, h * rng.uniform(0.7, 0.85))))
    p.append(Vector((rng.uniform(-0.2, 0.2) * w, d * rng.uniform(0.4, 0.7), h * rng.uniform(0.75, 0.9))))
    return p


def rock_pts(rng, r, squash=0.75, n=16):
    p = []
    for _ in range(n):
        u = rng.uniform(-1, 1)
        a = rng.uniform(0, math.tau)
        q = math.sqrt(1 - u * u)
        k = r * rng.uniform(0.75, 1.05)
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


def prism_pts(rng, r, h, tip, sides=6):
    """Słup z ostrym czubkiem (lód, diament, pręty) jako zbiór punktów do otoczki."""
    p = []
    rot = rng.uniform(0, math.tau)
    for hh, rr in ((0, r * 0.85), (h, r * rng.uniform(0.85, 1.05))):
        for i in range(sides):
            a = rot + i / sides * math.tau
            p.append(Vector((math.cos(a) * rr, math.sin(a) * rr, hh)))
    p.append(Vector((rng.uniform(-0.2, 0.2) * r, rng.uniform(-0.2, 0.2) * r, h + tip)))
    return p


def bipyr_pts(rng, r, h, sides=6):
    """Szlifowany klejnot: dwa ostrosłupy (Diamond)."""
    rot = rng.uniform(0, math.tau)
    p = [Vector((0, 0, 0)), Vector((rng.uniform(-0.1, 0.1) * r, rng.uniform(-0.1, 0.1) * r, h))]
    for i in range(sides):
        a = rot + i / sides * math.tau
        p.append(Vector((math.cos(a) * r, math.sin(a) * r, h * 0.38)))
    return p


def crystal_into(bm, base, direction, r, h, tip, rng, sides=6):
    z = direction.normalized()
    x = z.cross(Vector((0, 0, 1)) if abs(z.z) < 0.9 else Vector((1, 0, 0))).normalized()
    y = z.cross(x)
    rot = rng.uniform(0, math.tau)
    rings = [(r * 0.8, 0.0), (r, h * 0.12), (r * rng.uniform(0.9, 1.05), h)]
    loops = []
    for rad, hh in rings:
        loops.append([bm.verts.new(base + x * math.cos(rot + i / sides * math.tau) * rad + y * math.sin(rot + i / sides * math.tau) * rad + z * hh) for i in range(sides)])
    apex = bm.verts.new(base + z * (h + tip))
    bm.faces.new(list(reversed(loops[0])))
    for a, b in zip(loops, loops[1:]):
        for i in range(sides):
            bm.faces.new((a[i], a[(i + 1) % sides], b[(i + 1) % sides], b[i]))
    for i in range(sides):
        bm.faces.new((loops[-1][i], loops[-1][(i + 1) % sides], apex))


def gem_into(bm, base, direction, r, h, rng):
    """Szlifowany klejnot (ośmiościan wydłużony) dla Diamond."""
    z = direction.normalized()
    x = z.cross(Vector((0, 0, 1)) if abs(z.z) < 0.9 else Vector((1, 0, 0))).normalized()
    y = z.cross(x)
    mid = base + z * h * 0.35
    ring = [bm.verts.new(mid + x * math.cos(i / 6 * math.tau) * r + y * math.sin(i / 6 * math.tau) * r) for i in range(6)]
    top = bm.verts.new(base + z * h)
    bot = bm.verts.new(base)
    for i in range(6):
        bm.faces.new((ring[i], ring[(i + 1) % 6], top))
        bm.faces.new((ring[(i + 1) % 6], ring[i], bot))


def bm_append(dst, src, matrix=None):
    me = bpy.data.meshes.new("_tmp")
    src.to_mesh(me)
    if matrix is not None:
        me.transform(matrix)
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)


def ribbon_into(bm, pts, normal_of, w0, w1, lift):
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


def veins_on(bm_src, veins_bm, rng, count, width):
    bm_src.normal_update()
    faces = sorted([f for f in bm_src.faces if f.normal.z > -0.35], key=lambda f: -f.calc_area())[:count]
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
        pts = []
        for k in range(6):
            t = k / 5
            p = a.lerp(c, t * 2) if t < 0.5 else c.lerp(b, (t - 0.5) * 2)
            if 0 < k < 5:
                p = p + n.cross(b - a).normalized() * rng.uniform(-0.04, 0.04)
            pts.append(p)
        ribbon_into(veins_bm, pts, lambda _i: n, width, width * 0.5, 0.006)


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


def make_obj(name, bm, coll, mat, origin=None, bevel=0.0):
    if len(bm.verts) == 0:
        bm.free()
        return None
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
        m.surface_render_method = "BLENDED"
        m.use_backface_culling = False
    return m


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ---------------------------------------------------------------- skorupa wg stylu

def shell_pieces(st, rng, L):
    """Zwraca listę (theta, bmesh w układzie gwiazdy). theta = kąt do podziału na 6 segmentów."""
    out = []
    s = L["scale"]
    hM, wM = st.get("hMul", 1.0), st.get("wMul", 1.0)

    def place(theta, r, base, tilt, twist):
        return (Matrix.Translation((0, 0, base)) @ Matrix.Rotation(theta, 4, "Z") @ Matrix.Translation((0, -r, 0))
                @ Matrix.Rotation(tilt, 4, "X") @ Matrix.Rotation(twist, 4, "Z"))

    def add(theta, pts, mat):
        bm = hull_bm(pts)
        bmesh.ops.transform(bm, matrix=mat, verts=bm.verts)
        out.append((theta % math.tau, bm))

    kind = st["shell"]
    if kind == "plates":
        ring = 9 if s == 1 else 7
        for i in range(ring):
            th = i / ring * math.tau + rng.uniform(-0.15, 0.15)
            h, tilt = rng.uniform(1.5, 2.3) * hM, rng.uniform(0.25, 0.45)
            if math.cos(th) > 0.55:
                h, tilt = h * 0.5, tilt + 0.35
            add(th, plate_pts(rng, rng.uniform(0.45, 0.65) * wM, h, rng.uniform(0.3, 0.42)), place(th, rng.uniform(0.85, 1.0), 0.15, tilt, rng.uniform(-0.5, 0.5)))
        for k in (-0.35, 0.4):
            add(math.pi + k, plate_pts(rng, 0.55 * wM, rng.uniform(2.6, 3.0) * hM, 0.38), place(math.pi + k, 0.4, 0.3, 0.15, rng.uniform(-0.5, 0.5)))
        for k in ((-0.9, 0.0, 0.9) if s == 1 else (-0.5, 0.5)):
            add(math.pi + k, plate_pts(rng, 0.42, rng.uniform(1.1, 1.5) * hM, 0.3), place(math.pi + k, 0.32, 1.5 * hM, 0.4, rng.uniform(-0.5, 0.5)))
        spikes = 8 if s == 1 else 6
        for i in range(spikes):
            th = i / spikes * math.tau + 0.2
            add(th, plate_pts(rng, rng.uniform(0.4, 0.52) * wM, rng.uniform(0.8, 1.2), rng.uniform(0.28, 0.36)), place(th, 1.1, 0.02, rng.uniform(0.9, 1.1), rng.uniform(-0.5, 0.5)))
        for i in range(5 if s == 1 else 3):
            th = math.pi / 2 + i / (4 if s == 1 else 2) * math.pi
            add(th, plate_pts(rng, 0.5, rng.uniform(1.5, 1.9) * hM, 0.36), place(th, 0.55, 0.2, 0.2, rng.uniform(-0.5, 0.5)))
    elif kind == "boulders":
        n = 14 if s == 1 else 9
        for i in range(n):  # dolny pierścień leży na dnie, górny na nim
            th = i / n * math.tau + rng.uniform(-0.2, 0.2)
            front = math.cos(th) > 0.6
            upper = i % 2 == 1 and not front
            r = rng.uniform(0.45, 0.7) * (0.75 if front else 1.0)
            dist = rng.uniform(0.5, 0.75) if upper else rng.uniform(0.85, 1.15)
            z = (0.75 * hM + r * 0.5) if upper else r * 0.5
            add(th, rock_pts(rng, r, squash=rng.uniform(0.7, 0.95)), Matrix.Rotation(th, 4, "Z") @ Matrix.Translation((0, -dist, z)))
        for k in range(3 if s == 1 else 2):  # szczyt
            th = math.pi + rng.uniform(-1.0, 1.0)
            add(th, rock_pts(rng, rng.uniform(0.4, 0.55)), Matrix.Rotation(th, 4, "Z") @ Matrix.Translation((0, -0.3, 1.45 * hM + k * 0.3)))
    elif kind in ("shards", "rods"):
        n = 11 if s == 1 else 8
        rods = kind == "rods"
        for i in range(n):
            th = i / n * math.tau + rng.uniform(-0.12, 0.12)
            front = math.cos(th) > 0.6
            if rods:
                r, h, tilt = rng.uniform(0.09, 0.13), rng.uniform(2.2, 3.0), rng.uniform(0.05, 0.2)
                if front:
                    h *= 0.6
                add(th, prism_pts(rng, r, h, r * 2.5, sides=6), place(th, rng.uniform(1.0, 1.15), 0.0, tilt, 0))
            elif st.get("gemShell"):
                r, h, tilt = rng.uniform(0.32, 0.45), rng.uniform(1.3, 2.2) * hM, rng.uniform(0.2, 0.5)
                if front:
                    h, tilt = h * 0.55, tilt + 0.3
                add(th, bipyr_pts(rng, r, h), place(th, rng.uniform(0.6, 0.95), 0.0, tilt, rng.uniform(0, math.tau)))
            else:
                r, h, tilt = rng.uniform(0.2, 0.32), rng.uniform(1.4, 2.4) * hM, rng.uniform(0.2, 0.55)
                if front:
                    h, tilt = h * 0.55, tilt + 0.3
                add(th, prism_pts(rng, r, h, r * rng.uniform(1.6, 2.6)), place(th, rng.uniform(0.6, 0.95), 0.1, tilt, rng.uniform(0, math.tau)))
        for i in range(8 if s == 1 else 5):  # promieniste u podstawy
            th = i / (8 if s == 1 else 5) * math.tau + 0.3
            if rods:
                add(th, rock_pts(rng, rng.uniform(0.3, 0.45), 0.6), Matrix.Rotation(th, 4, "Z") @ Matrix.Translation((0, -1.15, 0.15)))
            else:
                r = rng.uniform(0.16, 0.24)
                add(th, prism_pts(rng, r, rng.uniform(0.8, 1.2), r * 2), place(th, 1.05, 0.0, rng.uniform(1.0, 1.25), 0))
        if rods:  # pierścienie-klatka: dwa poziome łuki z prętów
            for lvl, z in ((0, 1.0), (1, 2.1)):
                for i in range(6):
                    th = i / 6 * math.tau + lvl * 0.5
                    if math.cos(th) > 0.6 and lvl == 0:
                        continue
                    pts = prism_pts(rng, 0.06, 1.05, 0.0, sides=4)
                    m = Matrix.Rotation(th, 4, "Z") @ Matrix.Translation((0, -1.05, z)) @ Matrix.Rotation(math.pi / 2, 4, "Y") @ Matrix.Translation((0, 0, -0.52))
                    add(th, pts, m)
    elif kind == "egg":
        # skorupa rozbitego jaja: płyty na powierzchni elipsoidy, przód otwarty
        n = 44 if s == 1 else 26
        for i in range(n):
            u = rng.uniform(-0.9, 0.95)
            th = rng.uniform(0, math.tau)
            if math.cos(th) > 0.35 and u > -0.5:
                continue  # otwór z przodu
            q = math.sqrt(1 - u * u)
            nrm = Vector((math.sin(th) * q, -math.cos(th) * q, u))
            pos = Vector((nrm.x * 1.1, nrm.y * 1.1, 1.15 + u * 1.25))
            w = rng.uniform(0.45, 0.62)
            pts = slab_pts(rng, w, rng.uniform(0.2, 0.3), w * 0.85)
            m = Matrix.Translation(pos) @ nrm.to_track_quat("Z", "Y").to_matrix().to_4x4()
            add(th, pts, m)
        for i in range(6 if s == 1 else 4):  # postrzępiona krawędź otworu
            th = rng.uniform(-0.9, 0.9)
            add(th, plate_pts(rng, 0.3, rng.uniform(0.6, 1.0), 0.2), place(th, 0.95, rng.uniform(0.5, 1.6), rng.uniform(0.3, 0.7), 0))
    elif kind == "low":
        n = 12 if s == 1 else 8
        for i in range(n):
            th = i / n * math.tau + rng.uniform(-0.15, 0.15)
            h = rng.uniform(0.6, 1.1) * (0.7 if math.cos(th) > 0.6 else 1.0)
            add(th, plate_pts(rng, rng.uniform(0.35, 0.5), h, rng.uniform(0.25, 0.35)), place(th, rng.uniform(1.05, 1.25), 0.05, rng.uniform(0.35, 0.7), rng.uniform(-0.5, 0.5)))
    elif kind == "corona":
        n = 14 if s == 1 else 10
        core = V(*st["core"][1:2], 0) if False else V(0, st["core"][1], st["core"][2])
        for i in range(n):
            # kolce promieniście z rdzenia (golden-angle na sferze)
            u = 1 - (i + 0.5) / n * 1.7
            u = max(-0.6, min(0.95, u))
            th = i * 2.399963
            q = math.sqrt(max(0.0, 1 - u * u))
            d = Vector((math.sin(th) * q, -math.cos(th) * q, u)).normalized()
            if d.y < -0.75 and u < 0.4:
                continue  # przód: rdzeń widoczny
            r = rng.uniform(0.12, 0.2)
            pts = prism_pts(rng, r, rng.uniform(0.9, 1.5), r * 3, sides=5)
            m = Matrix.Translation(core + d * st["core"][0] * 0.8) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
            add(th, pts, m)
        for i in range(6 if s == 1 else 4):  # podstawa
            th = i / (6 if s == 1 else 4) * math.tau + 0.4
            add(th, rock_pts(rng, rng.uniform(0.35, 0.5), 0.6), Matrix.Rotation(th, 4, "Z") @ Matrix.Translation((0, -0.7, 0.2)))

    ring = st.get("ring")
    if ring:
        core = V(0, st["core"][1], st["core"][2])
        tiltm = Matrix.Rotation(ring["tilt"], 4, "X")
        cnt = ring["count"] if s == 1 else int(ring["count"] * 0.6)
        for i in range(cnt):
            a = i / cnt * math.tau + rng.uniform(-0.05, 0.05)
            rr = ring["radius"] * rng.uniform(0.9, 1.1)
            pos = core + (tiltm @ Vector((math.cos(a) * rr, math.sin(a) * rr, rng.uniform(-0.05, 0.05))))
            sz = rng.uniform(*ring["size"])
            pts = rock_pts(rng, sz, squash=0.35 if ring.get("flat") else 0.8, n=10)
            add(math.atan2(pos.x, -pos.y), pts, Matrix.Translation(pos) @ Matrix.Rotation(a, 4, "Z"))
    return out


# ---------------------------------------------------------------- wariant

def build_variant(type_id, var, coll, M, rng):
    st = STYLE[type_id]
    L = LOD[var]
    parts = {}
    core_r, core_up, core_front = st["core"]
    core = V(0, core_up, core_front)

    segs = [{"bm": bmesh.new(), "veins": bmesh.new(), "pts": []} for _ in range(SEG_N)]
    pieces = shell_pieces(st, rng, L)
    for th, bm in pieces:
        si = min(SEG_N - 1, int(th / (math.tau / SEG_N)))
        bm.verts.ensure_lookup_table()
        c = Vector()
        for v in bm.verts:
            c += v.co
        segs[si]["pts"].append(c / max(1, len(bm.verts)))
        veins_on(bm, segs[si]["veins"], rng, L["veins"], st.get("veinW", 0.035))
        bm_append(segs[si]["bm"], bm)
        bm.free()
    for i, s in enumerate(segs):
        n = f"{i + 1:02d}"
        origin = Vector()
        for p in s["pts"]:
            origin += p
        origin = origin / max(1, len(s["pts"]))
        if not s["pts"]:  # pusty segment: mała bryła, żeby szkielet był kompletny
            th = (i + 0.5) / SEG_N * math.tau
            origin = Vector((math.sin(th) * 1.1, -math.cos(th) * 1.1, 0.15))
            bm_append(s["bm"], (lambda b: (bmesh.ops.transform(b, matrix=Matrix.Translation(origin), verts=b.verts), b)[1])(hull_bm(rock_pts(rng, 0.3, 0.6))))
        parts[f"Shell{n}"] = make_obj(f"{var}_Shell{n}", s["bm"], coll, M["Rock"], origin=origin, bevel=L["bevel"])
        parts[f"CrackVeins{n}"] = make_obj(f"{var}_CrackVeins{n}", s["veins"], coll, M["Neon"], origin=origin)

    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=L["core_sub"], radius=core_r)
    bmesh.ops.translate(bm, vec=core, verts=bm.verts)
    parts["Core"] = make_obj(f"{var}_Core", bm, coll, M["Core"], origin=core.copy())
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=core_r * 1.2)
    bmesh.ops.translate(bm, vec=core, verts=bm.verts)
    parts["CoreShell"] = make_obj(f"{var}_CoreShell", bm, coll, M["CoreShell"], origin=core.copy())

    cs = st["cryScale"]
    groups = [("CrystalA", (-1.0, 0.05, 0.95), 5, (0.5, 1.1), (0.5, 0.9), 0.25),
              ("CrystalB", (1.05, 0.05, 0.8), 4, (0.45, 1.0), (0.5, 0.9), 0.22),
              ("CrystalC", (0.05, core_up + core_r + 0.35, -0.35), 5, (0.9, 1.5), (0.2, 0.5), 0.2)]
    for i, (x, f) in enumerate([(1.75, -0.3), (-1.9, 0.6), (0.4, 1.95), (-0.6, -1.85)][:L["ground"]]):
        groups.append((f"CrystalG{i + 1:02d}", (x, 0.02, -f), 2 + i % 2, (0.3, 0.6), (0.6, 1.1), 0.15))
    for name, (x, up, fr), n, hr, outr, spread in groups:
        pivot = V(x, up, fr)
        out = Vector((pivot.x, pivot.y, 0))
        out = out.normalized() if out.length > 1e-3 else Vector((0, 1, 0))
        bm = bmesh.new()
        for _ in range(max(2, round(n * (1.0 if var == "Large" else 0.6)))):
            h = rng.uniform(*hr) * cs
            r = h * rng.uniform(0.13, 0.18)
            d = out * rng.uniform(*outr) + Vector((rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), 1))
            if st.get("tail") and name in ("CrystalC", "CrystalA", "CrystalB"):
                d = Vector((rng.uniform(-0.25, 0.25), 1.0, rng.uniform(0.35, 0.7)))  # ogon komety do tyłu
                h *= 1.6
            base = pivot + Vector((rng.uniform(-1, 1) * spread, rng.uniform(-1, 1) * spread, -0.05))
            if st["crystal"] == "gem":
                gem_into(bm, base, d, r * 1.6, h * 0.8, rng)
            elif st["crystal"] == "spike":
                crystal_into(bm, base, d, r * 0.6, h, r * 3.0, rng, sides=5)
            else:
                crystal_into(bm, base, d, r, h, r * rng.uniform(1.6, 2.4), rng)
        parts[name] = make_obj(f"{var}_{name}", bm, coll, M["Crystal"], origin=pivot)

    drip_ends = []
    if st["fluid"]:
        bm = bmesh.new()
        bottom = core_up - core_r * 0.8
        drips = [(-0.16, bottom, core_front + 0.3, 0.28), (0.0, bottom - 0.04, core_front + 0.35, 0.46), (0.13, bottom - 0.01, core_front + 0.32, 0.32),
                 (-0.55, 1.15, 0.78, 0.3), (0.62, 0.98, 0.7, 0.36)][:L["drips"]]
        for x, up, fr, length in drips:
            length = min(length, max(0.12, up - 0.05))
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
    else:
        drip_ends = [V(-0.3, 0.6, 0.6), V(0.3, 0.6, 0.6), V(0, 0.5, 0.7)]

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
            veins_on(sb, cveins, rng, 1, 0.03)
        bm_append(bm, sb)
        sb.free()
    for _ in range(L["rubble"]):
        a, r = rng.uniform(0, math.tau), rng.uniform(1.4, 2.0)
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
    parts = {k: v for k, v in parts.items() if v is not None}

    anchors = {"ANCHOR_Core": core, "ANCHOR_Shockwave": Vector((0, 0, 0.06)), "ANCHOR_Particles": V(0, core_up + core_r + 0.4, 0)}
    for i, p in enumerate(drip_ends[:3]):
        anchors[f"ANCHOR_Drip_{i + 1:02d}"] = p
    hits = surface_points([parts[f"Shell{i + 1:02d}"] for i in range(SEG_N)], core, rng, 14)
    for i, p in enumerate(hits[:3]):
        anchors[f"ANCHOR_Cracks_{i + 1:02d}"] = p
    return parts, anchors, farthest(hits, 12) or [core]


def surface_points(obs, core, rng, n):
    bm = bmesh.new()
    for ob in obs:
        tmp = bmesh.new()
        tmp.from_mesh(ob.data)
        bm_append(bm, tmp, ob.matrix_world)
        tmp.free()
    tree = BVHTree.FromBMesh(bm)
    out = []
    tries = 0
    while len(out) < n and tries < 600:
        tries += 1
        a = rng.uniform(0, math.tau)
        el = rng.uniform(-0.1, 0.9)
        d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
        if d.y > 0.6:
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


def bbox_center(ob):
    ws = [ob.matrix_world @ v.co for v in ob.data.vertices]
    return Vector([(min(w[i] for w in ws) + max(w[i] for w in ws)) / 2 for i in range(3)])


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


def mats(type_id):
    st = STYLE[type_id]
    th = THEMES["themes"][type_id]
    neon_alpha = 0.55 if st.get("shellMat") in ("Glass", "Ice") else 1.0
    return {
        "Rock": material(f"{type_id}_Rock", st["rock"], rough=0.3 if neon_alpha < 1 else 0.85, alpha=neon_alpha),
        "Ground": material(f"{type_id}_Ground", st["ground"], rough=0.95),
        "Neon": material(f"{type_id}_Glow", th["color"], emission=6.0, neon=True),
        "Core": material(f"{type_id}_Core", st.get("coreColor", th["glow"]), emission=3.5 if "coreColor" not in st else 0.3, neon="coreColor" not in st),
        "CoreShell": material(f"{type_id}_CoreShell", th["color"], rough=0.1, emission=0.6, alpha=0.25),
        "Crystal": material(f"{type_id}_Crystal", th["color"], rough=0.12, emission=1.2, alpha=0.85),
        "Slime": material(f"{type_id}_Slime", th["color"], emission=5.0, neon=True),
    }


# ---------------------------------------------------------------- render siatki

def setup_render(silhouette):
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 2400, 1100
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1) if silhouette else (0.006, 0.007, 0.012, 1)
    sc.world = world
    for name, energy, loc in (("Key", 9000, (14, -22, 20)), ("Fill", 2500, (-20, -14, 6)), ("Rim", 7000, (-6, 24, 14))):
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
        for key, val in (("Type", "Bloom"), ("Threshold", 1.0), ("Strength", 1.0), ("Size", 7), ("Quality", "High")):
            try:
                gl.inputs[key].default_value = val
            except (TypeError, KeyError, AttributeError):
                pass
        ng.links.new(rl.outputs["Image"], gl.inputs["Image"])
        ng.links.new(gl.outputs[0], out.inputs[0])
        sc.compositing_node_group = ng


def render_grid(types, name, silhouette=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    black = material("_Black", "#000000", rough=1.0)
    gap = 7.0
    for idx, t in enumerate(types):
        coll = bpy.data.collections.new(t)
        bpy.context.scene.collection.children.link(coll)
        parts, _, _ = build_variant(t, "Large", coll, mats(t), random.Random(STYLE[t]["seed"]))
        col, row = idx % 6, idx // 6
        off = Vector(((col - 2.5) * gap, 0, -row * 6.8))
        for ob in parts.values():
            if ob.name.endswith(("Crater", "CraterVeins", "GroundCracks")) and silhouette:
                ob.hide_render = True
            ob.location += off
            if silhouette:
                ob.data.materials.clear()
                ob.data.materials.append(black)
    setup_render(silhouette)
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    cam.ortho_scale = 44
    ob = bpy.data.objects.new("Cam", cam)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = (0, -60, 12 if not silhouette else -1.0)
    target = Vector((0, 0, -1.2))
    ob.rotation_euler = (target - ob.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = ob
    bpy.context.scene.render.filepath = str(IMG / f"{name}.png")
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    types = [t for t in THEMES["order"] if t != "Toxic"]
    if "--types" in argv:
        types = argv[argv.index("--types") + 1].split(",")
    render = "--render" in argv
    anchors_path = OUT / "stars_v2_anchors.json"
    anchors_all = json.loads(anchors_path.read_text(encoding="utf-8")) if anchors_path.exists() else {}
    report = {}
    for t in types:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        M = mats(t)
        all_obs, per = [], {}
        for var in ("Large", "Small"):
            coll = bpy.data.collections.new(var)
            bpy.context.scene.collection.children.link(coll)
            parts, anchors, zones = build_variant(t, var, coll, M, random.Random(STYLE[t]["seed"]))
            total = sum(tris(ob) for k, ob in parts.items() if not k.startswith("Floating"))
            report.setdefault(t, {})[var] = {"tris": total, "ok": total <= LOD[var]["budget"]}
            core_c = bbox_center(parts["Core"])
            c_c = bbox_center(parts["CrystalC"])
            per[var] = {"anchors": {k: to_roblox(v) for k, v in anchors.items()}, "zones": [to_roblox(z) for z in zones],
                        "frame": {"core": to_roblox(core_c), "crystalC": to_roblox(c_c)}}
            all_obs += list(parts.values())
        uv_unwrap(all_obs)
        folder = OUT / t.lower()
        folder.mkdir(parents=True, exist_ok=True)
        export_fbx(folder / f"star_{t.lower()}_v2.fbx", all_obs)
        bpy.ops.wm.save_as_mainfile(filepath=str(folder / f"star_{t.lower()}_v2.blend"))
        anchors_all[t] = per
    anchors_all["zoneCounts"] = {k: v["zones"] for k, v in STARS["classes"].items()}
    anchors_path.write_text(json.dumps(anchors_all, indent=1), encoding="utf-8")
    print("STAR_V2_REPORT", json.dumps(report))
    if render:
        order = THEMES["order"]
        render_grid(order, "T40 gwiazdy v2")
        render_grid(order, "T40 gwiazdy v2 sylwetki", silhouette=True)
        print("RENDER done")


main()
