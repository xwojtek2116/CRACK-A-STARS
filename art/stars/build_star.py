"""build_star.py — proceduralne gwiazdy Crack a Stars (Blender 5.x, tryb w tle).

Uruchom:
  E:\\blender\\blender.exe -b --factory-startup -P art/stars/build_star.py -- [--types Iron,Lava] [--render]

Gwiazda = rodzaj (moduł niżej, sylwetka z pola `shape` w Themes.json) × rozmiar (Small/Medium/Large/Huge).
Rozmiar zmienia gęstość detali (siatka, płyty, kryształy, odłamki na orbicie); skalę do `size` z Stars.json
ustawia import w Studio. Każdy rozmiar to do 4 meshy (osobne MeshParty, kolor/materiał nadaje gra wg motywu):
  Shell  — bryła/skorupa (kolor `shell`)
  Core   — świecące wnętrze/żar (Neon, kolor `glow`)
  Accent — detal rodzaju: guzy, krople lawy, kolce lodu, ametysty (kolor `color`)
  Orbit  — odłamki krążące wokół (tylko Large/Huge)

Wyjście na rodzaj:  art/stars/<rodzaj>/star_<rodzaj>.fbx  (obiekty `<Rozmiar>_<Część>`, wszystkie w środku układu)
                    art/stars/<rodzaj>/star_<rodzaj>.blend
                    art/stars/zones.json  (kierunki stref rozbijania → Attachmenty w Studio)
                    vault/_img/star_<rodzaj>.png, vault/_img/star_silhouettes.png  (z --render)
"""

import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector, noise
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "game" / "src" / "shared" / "Config" / "Data"
OUT = ROOT / "art" / "stars"
IMG = ROOT / "vault" / "_img"

STARS = json.loads((DATA / "Stars.json").read_text(encoding="utf-8"))
THEMES = json.loads((DATA / "Themes.json").read_text(encoding="utf-8"))

SIZES = ["Small", "Medium", "Large", "Huge"]
# Gęstość detali na rozmiar: d = indeks 0..3, sub = podział ikosfery, orbit = liczba odłamków.
SIZE_CFG = {
    "Small": dict(d=0, sub=3, orbit=0),
    "Medium": dict(d=1, sub=3, orbit=0),
    "Large": dict(d=2, sub=4, orbit=6),
    "Huge": dict(d=3, sub=4, orbit=12),
}
# Budżet tris (Styl graficzny): Small ≤ 2k, Huge ≤ 8k; pośrednie liniowo.
BUDGET = {"Small": 2000, "Medium": 3500, "Large": 5500, "Huge": 8000}
SEED = {"Iron": 101, "Lava": 202, "Frost": 303, "Geode": 404, "Comet": 505, "Toxic": 606, "Electric": 707, "Nebula": 808}


# ---------------------------------------------------------------- wspólne

def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_lin(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def mesh_obj(name, bm, coll, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = smooth
    return ob


def solidify(ob, thickness, rim_mat=False):
    """Pogrubia skorupę do środka. rim_mat=True: ściany boczne płyt (szwy) dostają material_index 1 → split_rim."""
    if rim_mat:
        ob.data.materials.append(bpy.data.materials.new("tmp0"))
        ob.data.materials.append(bpy.data.materials.new("tmp1"))
    sol = ob.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = thickness
    sol.offset = -1
    if rim_mat:
        sol.material_offset_rim = 1
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Solidify")
    ob.select_set(False)


def split_rim(ob, drop_inner=True):
    """Odcina ściany boczne płyt (material_index 1) od Shell i zwraca je jako bmesh → doklejane do Core.
    Efekt: krawędzie każdej płyty świecą (rozżarzone szwy) bez poszerzania szczelin.
    drop_inner: usuń wewnętrzne ściany skorupy (niewidoczne z zewnątrz) — oszczędza ~1/3 tris."""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    rim = bm.copy()
    kill = [f for f in bm.faces if f.material_index == 1]
    if drop_inner:
        kill += [f for f in bm.faces if f.material_index == 0 and f.normal.dot(f.calc_center_median()) < 0]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    for f in bm.faces:
        f.material_index = 0
    bm.to_mesh(me)
    bm.free()
    me.materials.clear()
    bmesh.ops.delete(rim, geom=[f for f in rim.faces if f.material_index != 1], context="FACES")
    for f in rim.faces:
        f.material_index = 0
    return rim


def bm_add(dst, src):
    """Dokleja bmesh src do dst (src zostaje zwolniony)."""
    me = bpy.data.meshes.new("tmp")
    src.to_mesh(me)
    src.free()
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)


def fib_dirs(n, rng, jitter=0.0, min_z=-1.0):
    """Kierunki rozłożone złotą spiralą (równomiernie), z opcjonalnym szumem."""
    out = []
    for i in range(n):
        z = 1 - (i + 0.5) / n * (1 - min_z)
        r = math.sqrt(max(0.0, 1 - z * z))
        th = i * math.pi * (3 - math.sqrt(5)) + rng.uniform(-0.4, 0.4)
        d = Vector((math.cos(th) * r, math.sin(th) * r, z))
        if jitter:
            d += Vector(tuple(rng.uniform(-jitter, jitter) for _ in range(3)))
        out.append(d.normalized())
    return out


def rocky(v, seed, amp=1.0):
    p = v * 1.6 + Vector((seed, seed * 0.37, seed * 0.71))
    return 1.0 + amp * (0.16 * noise.noise(p) + 0.07 * noise.noise(p * 2.7) + 0.03 * noise.noise(p * 6.1))


def ico(radius, sub):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=radius)
    return bm


def voronoi_plates(bm, n_cells, gap, lift, rng):
    """Rozcina siatkę na płyty Voronoi i kurczy je do środka → sieć szczelin (pęknięć)."""
    seeds = fib_dirs(n_cells, rng)
    bm.faces.ensure_lookup_table()

    def cell(f):
        c = f.calc_center_median().normalized()
        return min(range(n_cells), key=lambda k: (seeds[k] - c).length_squared)

    cell_of = {f: cell(f) for f in bm.faces}
    border = [e for e in bm.edges if len(e.link_faces) == 2 and cell_of[e.link_faces[0]] != cell_of[e.link_faces[1]]]
    bmesh.ops.split_edges(bm, edges=border)
    bm.faces.ensure_lookup_table()
    cells = {}
    for f in bm.faces:
        cells.setdefault(cell(f), set()).update(f.verts)
    for verts in cells.values():
        centroid = sum((v.co for v in verts), Vector()) / len(verts)
        k = rng.uniform(*lift)
        for v in verts:
            v.co = (centroid + (v.co - centroid) * gap) * k


def crystal(bm, base, direction, length, radius, rng, sides=6, sink=0.25):
    """Graniastosłup z ostrym czubkiem (kryształ, kolec, odłamek)."""
    direction = direction.normalized()
    up = Vector((0, 0, 1)) if abs(direction.z) < 0.9 else Vector((1, 0, 0))
    s1 = direction.cross(up).normalized()
    s2 = direction.cross(s1).normalized()
    tw = rng.random() * math.tau
    r0, r1 = [], []
    for i in range(sides):
        a = tw + i * math.tau / sides
        off = s1 * math.cos(a) + s2 * math.sin(a)
        r0.append(bm.verts.new(base - direction * sink + off * radius * 0.85))
        r1.append(bm.verts.new(base + direction * length * 0.7 + off * radius))
    tip = bm.verts.new(base + direction * length)
    bm.faces.new(list(reversed(r0)))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
        bm.faces.new((r1[i], r1[j], tip))


def chunk(bm, center, radius, seed, squash=(1, 1, 1), sub=2):
    """Mały kamień (odłamek orbity, guz)."""
    tmp = ico(radius, sub)
    for v in tmp.verts:
        d = v.co.normalized()
        v.co = d * radius * rocky(d, seed, 1.6)
        v.co = Vector((v.co.x * squash[0], v.co.y * squash[1], v.co.z * squash[2])) + center
    me = bpy.data.meshes.new("tmp")
    tmp.to_mesh(me)
    tmp.free()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)


def orbit_ring(bm, n, rng, maker, rad=(1.9, 2.4)):
    tilt = Matrix.Rotation(math.radians(18), 3, "X")
    for k in range(n):
        a = k / max(1, n) * math.tau + rng.uniform(-0.15, 0.15)
        r = rng.uniform(*rad)
        c = tilt @ Vector((math.cos(a) * r, math.sin(a) * r, rng.uniform(-0.25, 0.25)))
        maker(bm, c, k)


def arc_tube(bm, a, b, radius, height, thick, rng, seg=10, sides=6):
    """Rozbłysk (protuberancja): łuk rurki z punktu a do b nad powierzchnią, gruby u podstawy, cieńszy u góry."""
    a, b = a.normalized(), b.normalized()
    phase = rng.random() * 6
    pts = []
    for i in range(seg + 1):
        t = i / seg
        dd = a.slerp(b, t)
        wob = 0.05 * math.sin(t * math.pi * 3 + phase)
        pts.append(dd * (radius - 0.08 + height * math.sin(math.pi * t) + wob))
    rings = []
    for i, p in enumerate(pts):
        t = i / seg
        tan = (pts[min(i + 1, seg)] - pts[max(i - 1, 0)]).normalized()
        nrm = p.normalized()
        s1 = tan.cross(nrm).normalized()
        s2 = tan.cross(s1).normalized()
        r = thick * (1.0 - 0.45 * math.sin(math.pi * t))
        rings.append([bm.verts.new(p + (s1 * math.cos(k * math.tau / sides) + s2 * math.sin(k * math.tau / sides)) * r)
                      for k in range(sides)])
    for i in range(seg):
        for k in range(sides):
            j = (k + 1) % sides
            bm.faces.new((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]))


def blob(bm, center, radius, seed, sub=2, amp=1.0):
    """Gładki, lekko falujący bąbel (magma, stopiony metal)."""
    tmp = ico(radius, sub)
    for v in tmp.verts:
        dd = v.co.normalized()
        v.co = dd * radius * (1 + 0.12 * amp * noise.noise(dd * 2.2 + Vector((seed, 0, 0)))) + center
    bm_add(bm, tmp)


def rand_dir(rng):
    return Vector(tuple(rng.uniform(-1, 1) for _ in range(3))).normalized()


def cube_at(bm, center, half, rng):
    cb = bmesh.new()
    bmesh.ops.create_cube(cb, size=half * 2)
    bmesh.ops.rotate(cb, verts=cb.verts, matrix=Matrix.Rotation(rng.uniform(0, math.tau), 3, rand_dir(rng)))
    bmesh.ops.translate(cb, verts=cb.verts, vec=center)
    bm_add(bm, cb)


def cluster(bm, base, direction, rng, n, length, radius, spread=0.45, sides=6):
    """Kępa kryształów z jednego punktu: główny długi + mniejsze rozchylone wokół."""
    crystal(bm, base, direction, length, radius, rng, sides=sides)
    for _ in range(n - 1):
        jit = Vector(tuple(rng.uniform(-1, 1) for _ in range(3))) * spread
        d2 = (direction + jit).normalized()
        crystal(bm, base + jit * radius * 0.8, d2, length * rng.uniform(0.45, 0.75), radius * rng.uniform(0.5, 0.75),
                rng, sides=sides)


# ---------------------------------------------------------------- rodzaje
# Każdy builder zwraca {"Shell", "Core", "Accent"}. Core = WSZYSTKO, co świeci kolorem `glow` (Neon w grze):
# wnętrze, rozżarzone krawędzie płyt (split_rim), świecące rdzenie kolców itd.

def build_iron(coll, cfg, rng, seed):
    """Iron Meteorite: rozżarzony żelazny meteoryt — wgniecenia (thumbprints), płyty z pomarańczowo
    świecącymi krawędziami, stopiony metal w wgnieceniach, kępy kubicznych kryształów żelaza."""
    d = cfg["d"]
    squash = Vector((1.28, 1.0, 0.86))

    def sq(v):
        return Vector((v.x * squash.x, v.y * squash.y, v.z * squash.z))

    bm = ico(1.0, cfg["sub"])
    dents = [(dd, rng.uniform(0.32, 0.5), rng.uniform(0.1, 0.17)) for dd in fib_dirs(5 + 4 * d, rng, 0.3)]

    def surf(n):
        r = rocky(n, seed, 0.8)
        for c, ang, depth in dents:
            a = n.angle(c)
            if a < ang:
                r -= depth * (1 - (a / ang) ** 2)
        return sq(n) * r

    for v in bm.verts:
        v.co = surf(v.co.normalized())
    voronoi_plates(bm, [7, 10, 14, 19][d], 0.968, (0.992, 1.025), rng)
    shell = mesh_obj("Shell", bm, coll)
    solidify(shell, 0.13, rim_mat=True)

    core = ico(0.9, 3)
    for v in core.verts:
        v.co = sq(v.co) * rocky(v.co.normalized(), seed + 3, 0.4)
    bm_add(core, split_rim(shell))
    # Stopiony metal na dnie największych wgnieceń (świecące „kałuże”).
    for c, ang, depth in sorted(dents, key=lambda x: -x[1])[: 2 + d]:
        if c.z < -0.3:
            continue
        blob(core, surf(c) * 0.985, ang * 0.3, seed + 11, sub=1, amp=0.4)
    parts = {"Shell": shell, "Core": mesh_obj("Core", core, coll)}

    acc = bmesh.new()
    for n in fib_dirs([3, 4, 6, 9][d], rng, 0.5, min_z=-0.2):
        base = surf(n) * 0.97
        for k in range(rng.randint(3, 4)):
            s = rng.uniform(0.13, 0.21) * (1.0 if k == 0 else 0.62)
            cube_at(acc, base + n * s * 0.5 + rand_dir(rng) * 0.13 * k, s, rng)
    parts["Accent"] = mesh_obj("Accent", acc, coll)
    return parts


def build_lava(coll, cfg, rng, seed):
    """Lava Star: czarne płyty bazaltu na kuli magmy — szerokie rzeki lawy, rozżarzone krawędzie płyt,
    bąble magmy spod płyt, a od Medium łuki rozbłysków (protuberancje) nad powierzchnią."""
    d = cfg["d"]
    bm = ico(1.05, cfg["sub"])
    for v in bm.verts:
        n = v.co.normalized()
        v.co = n * 1.05 * rocky(n, seed, 0.6)
    voronoi_plates(bm, [8, 12, 17, 24][d], 0.80, (1.0, 1.12), rng)
    shell = mesh_obj("Shell", bm, coll)
    solidify(shell, 0.17, rim_mat=True)

    core = ico(0.98, 3)
    for v in core.verts:
        n = v.co.normalized()
        v.co = n * 0.98 * rocky(n, seed + 5, 0.5)
    bm_add(core, split_rim(shell))
    parts = {"Shell": shell, "Core": mesh_obj("Core", core, coll, smooth=True)}

    # Accent (Neon, kolor `color` — głęboki pomarańcz): bąble magmy + łuki rozbłysków.
    acc = bmesh.new()
    for i, n in enumerate(fib_dirs([3, 5, 7, 10][d], rng, 0.35, min_z=-0.6)):
        blob(acc, n * 1.02, rng.uniform(0.17, 0.27), seed + i * 13, sub=2)
    n_arcs = [0, 1, 2, 3][d]
    for a in (fib_dirs(n_arcs, rng, 0.3, min_z=0.0) if n_arcs else []):
        side = a.cross(Vector((0.3, 0.2, 1.0))).normalized()
        b = (a + side * rng.uniform(0.75, 1.0)).normalized()
        arc_tube(acc, a, b, 1.0, rng.uniform(0.6, 0.85), rng.uniform(0.12, 0.16), rng, seg=12, sides=7)
    parts["Accent"] = mesh_obj("Accent", acc, coll, smooth=True)
    return parts


def spiky_star(bm, radius, spike, sub=1):
    """Świecąca gwiazda 3D: ikosfera, której 12 pierwotnych wierzchołków wyciągnięto w kolce."""
    tmp = ico(radius, sub)
    for v in tmp.verts:
        n = v.co.normalized()
        # 12 wierzchołków ikosaedru ma 5 sąsiadów, reszta 6 — to one stają się czubkami.
        v.co = n * (spike if len(v.link_edges) == 5 else radius)
    bm_add(bm, tmp)


def gem(rng, n_pts, radius, jitter, stretch=1.0):
    """Fasetowana bryła (otoczka wypukła losowych punktów na sferze) — duże płaskie ścianki jak klejnot."""
    bm = bmesh.new()
    for d in fib_dirs(n_pts, rng, jitter):
        r = radius * rng.uniform(0.9, 1.05)
        bm.verts.new(Vector((d.x * r, d.y * r, d.z * r * stretch)))
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def snowflake_dirs(d):
    """Ramiona płatka śniegu: 6 w płaszczyźnie pionowej XZ (co 60°, front = -Y) + 2 krótsze przód/tył
    (z boku wygląda jak 4-ramienny błysk), od Large 8 ukośnych. Zwraca (kierunek, skala długości, główne?)."""
    out = [(Vector((math.sin(k * math.tau / 6), 0.0, math.cos(k * math.tau / 6))), 1.0, True) for k in range(6)]
    out += [(Vector((0, -1, 0)), 0.6, False), (Vector((0, 1, 0)), 0.6, False)]
    if d >= 3:  # Huge: 6 krótszych ramion między głównymi (płatek „gwiaździsty”)
        out += [(Vector((math.sin((k + 0.5) * math.tau / 6), 0.0, math.cos((k + 0.5) * math.tau / 6))), 0.5, False)
                for k in range(6)]
    if d >= 2:
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    out.append((Vector((sx, sy * 0.9, sz)).normalized(), 0.42, False))
    return out


def build_frost(coll, cfg, rng, seed):
    """Frost Star: zamrożona gwiazda — w środku świeci kolczasta gwiazda, zamknięta w fasetowanym,
    półprzezroczystym klejnocie lodu; z bryły rosną grube kryształy lodu w układzie płatka śniegu
    (każdy ze świecącym rdzeniem). Rozmiar = więcej ścianek, kępy kryształów, ukośne promienie."""
    d = cfg["d"]
    shell = mesh_obj("Shell", gem(rng, [24, 32, 44, 56][d], 0.82, 0.18, stretch=0.95), coll)

    core = bmesh.new()
    spiky_star(core, 0.2, 0.52)
    acc = bmesh.new()
    for n, k, main in snowflake_dirs(d):
        n = (n + rand_dir(rng) * 0.03).normalized()
        length = (0.85 + 0.2 * d) * k * rng.uniform(0.95, 1.05)
        rad = (0.17 + 0.02 * d) * (0.7 + 0.3 * k)
        crystal(acc, n * 0.62, n, length, rad, rng, sides=6, sink=0.1)
        crystal(core, n * 0.62, n, length * 0.82, rad * 0.32, rng, sides=4, sink=0.1)  # świecący rdzeń
        if main and d >= 1:
            # Odgałęzienia płatka: pod 60° w płaszczyźnie płatka, 1 para (Medium) / 2 pary (Large+).
            side = n.cross(Vector((0, 1, 0))).normalized()
            for j, t in enumerate([0.55, 0.85][: 1 if d == 1 else 2]):
                base = n * (0.62 + length * 0.7 * t)
                for sgn in (-1, 1):
                    dirb = (n * 0.5 + side * sgn * 0.866).normalized()
                    bl = length * (0.42 - 0.12 * j)
                    crystal(acc, base, dirb, bl, rad * 0.45, rng, sides=6, sink=0.05)
                    crystal(core, base, dirb, bl * 0.75, rad * 0.16, rng, sides=4, sink=0.05)
    return {"Shell": shell, "Core": mesh_obj("Core", core, coll), "Accent": mesh_obj("Accent", acc, coll)}


GEODE_OPEN = Vector((0.35, -1.0, 0.45)).normalized()


def build_geode(coll, cfg, rng, seed):
    """Geode Star: kamienne jajo rozłupane z jednej strony; świecąca grota pełna kęp ametystów,
    krawędź otworu i pęknięcia skorupy świecą fioletem, od Large kryształy przebijają skorupę."""
    d = cfg["d"]

    def egg(n, r):
        x, y, z = n.x * r, n.y * r, n.z * r * 1.3
        k = 1.0 - 0.12 * n.z
        return Vector((x * k, y * k, z))

    bm = ico(1.0, cfg["sub"])
    for v in bm.verts:
        n = v.co.normalized()
        v.co = egg(n, rocky(n, seed, 1.0))
    lim = math.cos(math.radians(50))
    kill = []
    for f in bm.faces:
        n = f.calc_center_median().normalized()
        jag = 0.14 * noise.noise(n * 4.0 + Vector((seed, 0, 0)))
        if n.dot(GEODE_OPEN) > lim + jag:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    voronoi_plates(bm, [6, 8, 11, 15][d], 0.965, (0.995, 1.025), rng)
    shell = mesh_obj("Shell", bm, coll)
    solidify(shell, 0.24, rim_mat=True)

    core = ico(1.0, 3)
    for v in core.verts:
        v.co = egg(v.co.normalized(), 0.74)
    bm_add(core, split_rim(shell, drop_inner=False))  # wnętrze groty widać przez otwór — zostaw
    parts = {"Shell": shell, "Core": mesh_obj("Core", core, coll, smooth=True)}

    acc = bmesh.new()
    n_cl = [4, 6, 9, 13][d]
    placed = tries = 0
    while placed < n_cl and tries < 500:
        tries += 1
        n = rand_dir(rng)
        if n.dot(GEODE_OPEN) < 0.15:
            continue
        dirn = (-n * 0.3 + GEODE_OPEN * 0.9 + Vector(tuple(rng.uniform(-.3, .3) for _ in range(3)))).normalized()
        cluster(acc, egg(n, 0.76), dirn, rng, 3, rng.uniform(0.5, 0.85) * (1.0 + 0.1 * d), rng.uniform(0.1, 0.15))
        placed += 1
    # Korona: duże kryształy z krawędzi otworu na zewnątrz.
    side = GEODE_OPEN.cross(Vector((0, 0, 1))).normalized()
    up = side.cross(GEODE_OPEN).normalized()
    for i in range(3 + d):
        a = i / (3 + d) * math.tau + rng.uniform(-0.2, 0.2)
        n = (GEODE_OPEN * lim + (side * math.cos(a) + up * math.sin(a)) * math.sqrt(1 - lim * lim)).normalized()
        cluster(acc, egg(n, 0.93), (n + GEODE_OPEN * 0.7).normalized(), rng, 2, rng.uniform(0.5, 0.75), 0.12)
    # Od Large: kryształy przebijają skorupę z boków.
    for n in (fib_dirs([0, 0, 3, 5][d], rng, 0.4) if d >= 2 else []):
        if n.dot(GEODE_OPEN) > 0.3:
            continue
        cluster(acc, egg(n, 0.95), n, rng, 2, rng.uniform(0.35, 0.5), 0.1)
    parts["Accent"] = mesh_obj("Accent", acc, coll)
    return parts


# ---------------------------------------------------------------- rodzaje 5-8 (T33): pomocnicze

def sweep(bm, pts, radii, sides=6, flat=1.0, twist=0.0, ref=None):
    """Rurka/wstęga wzdłuż punktów pts o promieniach radii (zamknięta, z deklami).
    flat<1 spłaszcza przekrój w kierunku `ref` (wstęga leży prostopadle do ref)."""
    tmp = bmesh.new()
    n = len(pts)
    rings = []
    for i, p in enumerate(pts):
        tan = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        r_ = ref if ref is not None else Vector((0, 0, 1))
        if abs(tan.dot(r_)) > 0.97:
            r_ = Vector((1, 0, 0)) if abs(tan.x) < 0.9 else Vector((0, 1, 0))
        s1 = tan.cross(r_).normalized()
        s2 = tan.cross(s1).normalized()
        r = max(radii[i], 0.004)
        a0 = twist * i / max(1, n - 1)
        rings.append([tmp.verts.new(p + s1 * math.cos(a0 + k * math.tau / sides) * r
                                    + s2 * math.sin(a0 + k * math.tau / sides) * r * flat) for k in range(sides)])
    for i in range(n - 1):
        for k in range(sides):
            j = (k + 1) % sides
            tmp.faces.new((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]))
    tmp.faces.new(rings[0])
    tmp.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    bm_add(bm, tmp)


def bolt(bm, a, b, rng, segs=7, jag=0.08, radius=0.022):
    """Piorun: łamana z a do b z losowymi odchyleniami w poprzek."""
    axis = (b - a)
    side = axis.cross(rand_dir(rng)).normalized()
    up = axis.cross(side).normalized()
    pts = [a]
    for i in range(1, segs):
        t = i / segs
        k = jag * axis.length * math.sin(math.pi * t) ** 0.5
        pts.append(a.lerp(b, t) + side * rng.uniform(-k, k) + up * rng.uniform(-k, k))
    pts.append(b)
    sweep(bm, pts, [radius * (1.0 - 0.4 * i / segs) for i in range(segs + 1)], sides=4)


def star_at(bm, center, radius, spike):
    """Mała kolczasta gwiazdka (iskra) w punkcie center."""
    tmp = bmesh.new()
    spiky_star(tmp, radius, spike)
    bmesh.ops.translate(tmp, verts=tmp.verts, vec=center)
    bm_add(bm, tmp)


def append_bm(ob, bm):
    """Dokleja bmesh do istniejącego obiektu (np. trzonki grzybów do Shell po split_rim)."""
    cur = bmesh.new()
    cur.from_mesh(ob.data)
    bm_add(cur, bm)
    cur.to_mesh(ob.data)
    cur.free()


def frame(axis):
    axis = axis.normalized()
    up = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    s1 = axis.cross(up).normalized()
    return s1, axis.cross(s1).normalized()


def dome(bm, center, axis, radius, seed):
    """Kapelusz grzyba: spłaszczona półkula wzdłuż osi axis, lekko falująca krawędź."""
    s1, s2 = frame(axis)
    tmp = ico(1.0, 2)
    for v in tmp.verts:
        n = v.co.normalized()
        h = n.z * (0.62 if n.z > 0 else 0.16)
        w = 1 + 0.08 * noise.noise(n * 3 + Vector((seed, 0, 0)))
        v.co = center + (s1 * n.x + s2 * n.y) * radius * w + axis * h * radius
    bm_add(bm, tmp)


def plated_ball(coll, cfg, rng, seed, radius, cells, gap, lift, thick, amp=0.6, squash=(1, 1, 1), sub=None):
    """Kula z płyt Voronoi: Shell (płyty) + bmesh szwów (do Core). Wspólne dla Comet/Toxic/Storm."""
    bm = ico(radius, sub or cfg["sub"])
    for v in bm.verts:
        n = v.co.normalized()
        p = n * radius * rocky(n, seed, amp)
        v.co = Vector((p.x * squash[0], p.y * squash[1], p.z * squash[2]))
    voronoi_plates(bm, cells, gap, lift, rng)
    shell = mesh_obj("Shell", bm, coll)
    solidify(shell, thick, rim_mat=True)
    return shell, split_rim(shell)


# ---------------------------------------------------------------- rodzaje 5-8

COMET_TAIL = Vector((1.0, 0.45, 0.32)).normalized()


def build_comet(coll, cfg, rng, seed):
    """Comet: brudne lodowe jądro (płyty lodu ze świecącymi białymi szwami) i długi ogon z kilku
    świecących wstęg rozchodzących się stożkiem; od Medium iskry wzdłuż ogona. Ogon zawsze w +X."""
    d = cfg["d"]
    sq = (1.12, 0.95, 0.9)
    shell, rim = plated_ball(coll, cfg, rng, seed, 0.95, [7, 10, 13, 17][d], 0.955, (0.99, 1.04), 0.12,
                             amp=0.9, squash=sq)
    core = ico(0.86, 3)
    for v in core.verts:
        n = v.co.normalized()
        v.co = Vector((n.x * sq[0], n.y * sq[1], n.z * sq[2])) * 0.86
    bm_add(core, rim)

    tail_len = [1.7, 2.1, 2.5, 2.9][d]
    u, v_ = frame(COMET_TAIL)
    acc = bmesh.new()
    n_rib = [4, 5, 6, 8][d]
    for j in range(n_rib):
        phi = j / n_rib * math.tau + rng.uniform(-0.25, 0.25)
        radial = u * math.cos(phi) + v_ * math.sin(phi)
        length = tail_len * rng.uniform(0.75, 1.05)
        pts, radii = [], []
        for i in range(17):
            t = i / 16
            spread = 0.18 + 0.8 * t ** 1.3
            pts.append(COMET_TAIL * (0.55 + length * t) + radial * spread + u * 0.5 * t * t)
            radii.append((0.09 + 0.24 * t) * (1.0 if t < 0.7 else max(0.04, (1 - t) / 0.3)))
        sweep(acc, pts, radii, sides=4, flat=0.14, twist=rng.uniform(-1.2, 1.2), ref=radial)
    # Jasny środek ogona (Core) + iskry.
    pts = [COMET_TAIL * (0.5 + tail_len * 0.65 * i / 10) + u * 0.35 * (i / 10) ** 2 for i in range(11)]
    sweep(core, pts, [0.24 * (1 - i / 10) ** 1.3 + 0.01 for i in range(11)], sides=6)
    for _ in range([0, 4, 7, 10][d]):
        t = rng.uniform(0.25, 1.0)
        c = COMET_TAIL * (0.6 + tail_len * t) + (u * rng.uniform(-1, 1) + v_ * rng.uniform(-1, 1)) * (0.25 + 0.6 * t)
        star_at(core, c, 0.04, rng.uniform(0.1, 0.16))
    parts = {"Shell": shell, "Core": mesh_obj("Core", core, coll), "Accent": mesh_obj("Accent", acc, coll)}
    parts["_fx"] = {"tail": [COMET_TAIL * 0.6, COMET_TAIL]}
    return parts


def build_toxic(coll, cfg, rng, seed):
    """Toxic Star: skażona gwiazda — twarda, popękana skorupa, z szerokich pęknięć wylewa się świecąca
    maź (kałuże, zacieki, wiszące krople), na górze rosną kępy świecących grzybów z zarodnikami."""
    d = cfg["d"]
    shell, rim = plated_ball(coll, cfg, rng, seed, 1.0, [7, 10, 14, 18][d], 0.9, (0.99, 1.05), 0.15, amp=0.9)
    core = ico(0.93, 3)
    for v in core.verts:
        n = v.co.normalized()
        v.co = n * 0.93 * rocky(n, seed + 5, 0.5)
    bm_add(core, rim)

    def surf(n):
        return n * rocky(n, seed, 0.9)

    acc = bmesh.new()
    # Maź: kałuże wylewające się z pęknięć.
    for i, n in enumerate(fib_dirs([2, 3, 5, 7][d], rng, 0.4, min_z=-0.3)):
        blob(acc, surf(n) * 0.99, rng.uniform(0.14, 0.22), seed + 17 * i, sub=2, amp=1.4)
    # Zacieki z kroplą na końcu — po bokach, w dół.
    for n in fib_dirs([2, 3, 5, 7][d], rng, 0.5, min_z=-0.5)[:]:
        n = Vector((n.x, n.y, -abs(n.z) * 0.5)).normalized()
        p0 = surf(n) * 0.98
        down = (Vector((0, 0, -1)) - n * n.dot(Vector((0, 0, -1)))).normalized()
        ln = rng.uniform(0.35, 0.55)
        pts = [p0 + down * ln * t + n * (0.05 + 0.12 * t * t) for t in (0, 0.25, 0.5, 0.7, 0.82, 0.93, 1.0)]
        sweep(acc, pts, [0.09, 0.07, 0.055, 0.05, 0.085, 0.07, 0.01], sides=6)
    # Grzyby: trzonek ciemny (Shell), kapelusz świecący (Accent), zarodniki na kapeluszach (Core).
    stems = bmesh.new()
    n_cl = [1, 2, 4, 5][d]
    for c in fib_dirs(n_cl, rng, 0.35, min_z=0.15):
        for k in range([2, 2, 3, 3][d]):
            n = (c + rand_dir(rng) * (0.0 if k == 0 else 0.28)).normalized()
            base = surf(n) * 0.95
            h = rng.uniform(0.35, 0.55) * (1.0 if k == 0 else 0.7) * (1 + 0.1 * d)
            bend = rand_dir(rng) * 0.12
            pts = [base + n * h * t + bend * t * t for t in (0, 0.35, 0.7, 1.0)]
            rs = rng.uniform(0.05, 0.065) * (1.0 if k == 0 else 0.8)
            sweep(stems, pts, [rs * 1.3, rs, rs * 0.9, rs * 0.85], sides=6)
            top = pts[-1]
            axis = (pts[-1] - pts[-2]).normalized()
            rc = h * rng.uniform(0.38, 0.5)
            dome(acc, top, axis, rc, seed + k)
            s1, s2 = frame(axis)
            for _ in range(2):
                a = rng.uniform(0, math.tau)
                spot = top + axis * rc * 0.45 + (s1 * math.cos(a) + s2 * math.sin(a)) * rc * 0.55
                blob(core, spot, rc * 0.16, seed, sub=1)
    append_bm(shell, stems)
    return {"Shell": shell, "Core": mesh_obj("Core", core, coll), "Accent": mesh_obj("Accent", acc, coll, smooth=True)}


def build_electric(coll, cfg, rng, seed):
    """Storm Star: metalowa kula z płyt (cyjanowe szwy) w klatce pływających prętów-cewek ułożonych
    w walec, z pierścieniami nad i pod klatką (od Medium); żółte pioruny skaczą z kuli na pręty."""
    d = cfg["d"]
    shell, rim = plated_ball(coll, cfg, rng, seed, 0.64, [6, 8, 10, 12][d], 0.94, (0.995, 1.03), 0.09, amp=0.3,
                             sub=3)
    core = ico(0.59, 2)
    bm_add(core, rim)
    R, h = 0.98, 0.82 + 0.05 * d
    n_rods = [6, 8, 10, 12][d]
    tw = 0.22
    rods = bmesh.new()
    rod_mid = []
    for i in range(n_rods):
        a = i / n_rods * math.tau
        p0 = Vector((math.cos(a) * R, math.sin(a) * R, -h))
        p1 = Vector((math.cos(a + tw) * R, math.sin(a + tw) * R, h))
        r = 0.055 + 0.006 * d
        ts = (0, 0.07, 0.5, 0.93, 1.0)
        sweep(rods, [p0.lerp(p1, t) for t in ts], [0.012, r, r, r, 0.012], sides=6)
        ax = (p1 - p0).normalized()
        for t in ((0.5,) if d < 2 else (0.3, 0.7)):
            c = p0.lerp(p1, t)
            sweep(core, [c - ax * 0.045, c + ax * 0.045], [r * 1.7, r * 1.7], sides=6)  # świecąca cewka
        for p in (p0, p1):
            blob(core, p, 0.05, seed, sub=1)
        rod_mid.append((p0, p1))
    if d >= 1:  # pierścienie nad i pod klatką
        for z in (-h - 0.1, h + 0.1):
            pts = [Vector((math.cos(a) * R * 0.86, math.sin(a) * R * 0.86, z))
                   for a in (k / 24 * math.tau for k in range(25))]
            sweep(rods, pts, [0.03] * 25, sides=5)
    if d >= 3:  # zewnętrzny pierścień na równiku z węzłami
        pts = [Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, 0)) for a in (k / 32 * math.tau for k in range(33))]
        sweep(rods, pts, [0.026] * 33, sides=5)
        for k in range(6):
            a = k / 6 * math.tau + 0.3
            blob(core, Vector((math.cos(a) * 1.3, math.sin(a) * 1.3, 0)), 0.06, seed, sub=1)
    append_bm(shell, rods)

    def rod_pt(i, t):
        p0, p1 = rod_mid[i % n_rods]
        p = p0.lerp(p1, t)
        return p - Vector((p.x, p.y, 0)).normalized() * 0.05

    acc = bmesh.new()
    picks = rng.sample(range(n_rods), min(n_rods, [2, 3, 4, 6][d]))
    for i in picks:
        b = rod_pt(i, rng.uniform(0.3, 0.7))
        a = Vector((b.x, b.y, b.z * 0.5)).normalized() * 0.66
        bolt(acc, a, b, rng, radius=0.036)
    for i in rng.sample(range(n_rods), [0, 0, 2, 4][d]):
        bolt(acc, rod_pt(i, rng.uniform(0.2, 0.8)), rod_pt(i + 1, rng.uniform(0.2, 0.8)), rng, segs=5, jag=0.12,
             radius=0.026)
    # Pary punktów pod animowane Beamy w Studio (inne niż pioruny w siatce).
    beams = []
    for i in [k for k in range(n_rods) if k not in picks][: [2, 3, 4, 6][d]]:
        b = rod_pt(i, rng.uniform(0.3, 0.7))
        beams.append([Vector((b.x, b.y, b.z * 0.5)).normalized() * 0.66, b])
    parts = {"Shell": shell, "Core": mesh_obj("Core", core, coll), "Accent": mesh_obj("Accent", acc, coll)}
    parts["_fx"] = {"beams": beams}
    return parts


def spiral(bm, rot, r0, r1, turns, w0, w1, a0, rng, n=24, flat=0.22, wob=0.06):
    """Ramię spirali w płaszczyźnie rot (Matrix 3x3): promień r0→r1, szerokość w0→w1→0."""
    pts, radii = [], []
    for i in range(n + 1):
        t = i / n
        a = a0 + turns * math.tau * t
        r = r0 + (r1 - r0) * t
        pts.append(rot @ Vector((math.cos(a) * r, math.sin(a) * r, wob * math.sin(t * 7 + a0))))
        radii.append((w0 + (w1 - w0) * math.sin(math.pi * min(1.0, t * 1.15)) ) * (1.0 if t < 0.85 else (1 - t) / 0.15 + 0.03))
    sweep(bm, pts, radii, sides=4, flat=flat, ref=rot @ Vector((0, 0, 1)))


def build_nebula(coll, cfg, rng, seed):
    """Nebula Star: „galaktyka w butelce” — fasetowana szklana kula, w środku jasne jądro i wirujące
    wstęgi gazu w różnych płaszczyznach; od Medium gaz wylewa się na zewnątrz w płaski dysk spiralnych ramion."""
    d = cfg["d"]
    shell = mesh_obj("Shell", gem(rng, [28, 36, 48, 60][d], 1.0, 0.12), coll)
    core = ico(0.2, 2)
    acc = bmesh.new()
    for k in range([2, 3, 4, 5][d]):
        rot = Matrix.Rotation(rng.uniform(0, math.tau), 3, rand_dir(rng))
        spiral(core, rot, 0.12, 0.8, 0.85, 0.05, 0.15, rng.uniform(0, math.tau), rng)
    for k in range([1, 2, 2, 3][d]):
        rot = Matrix.Rotation(rng.uniform(0, math.tau), 3, rand_dir(rng))
        spiral(acc, rot, 0.25, 0.82, 0.6, 0.04, 0.12, rng.uniform(0, math.tau), rng)
    # Dysk spiralnych ramion na zewnątrz (pochylony) — sylwetka galaktyki.
    disk = Matrix.Rotation(math.radians(24), 3, "X") @ Matrix.Rotation(math.radians(-12), 3, "Y")
    n_arm = [0, 2, 3, 4][d]
    for k in range(n_arm):
        a0 = k / max(1, n_arm) * math.tau
        spiral(acc, disk, 0.85, 1.5 + 0.12 * d, 0.38, 0.07, 0.17, a0, rng, n=20, flat=0.2, wob=0.03)
        spiral(core, disk, 0.9, 1.25 + 0.1 * d, 0.3, 0.025, 0.06, a0 + 0.12, rng, n=14, flat=0.3, wob=0.03)
    return {"Shell": shell, "Core": mesh_obj("Core", core, coll), "Accent": mesh_obj("Accent", acc, coll)}


BUILDERS = {"Iron": build_iron, "Lava": build_lava, "Frost": build_frost, "Geode": build_geode,
            "Comet": build_comet, "Toxic": build_toxic, "Electric": build_electric, "Nebula": build_nebula}


def orbit_maker(type_id, rng, seed):
    if type_id == "Frost":
        def shard(bm, c, k):
            tan = Vector((-c.y, c.x, 0)).normalized()
            crystal(bm, c - tan * 0.15, (tan + rand_dir(rng) * 0.2).normalized(), rng.uniform(0.3, 0.45), 0.07, rng, sides=6,
                    sink=0.1)
        return shard
    if type_id == "Geode":
        return lambda bm, c, k: crystal(bm, c, rand_dir(rng), rng.uniform(0.25, 0.45), 0.08, rng, sides=5, sink=0.1)
    if type_id in ("Iron", "Electric"):
        return lambda bm, c, k: cube_at(bm, c, rng.uniform(0.07, 0.12), rng)
    if type_id == "Comet":  # okruchy lodu lecące za ogonem zamiast orbity
        u, v_ = frame(COMET_TAIL)

        def ice(bm, c, k):
            t = rng.uniform(0.2, 1.0)
            p = COMET_TAIL * (0.9 + 2.4 * t) + (u * rng.uniform(-1, 1) + v_ * rng.uniform(-1, 1)) * (0.3 + 0.5 * t)
            crystal(bm, p, (COMET_TAIL + rand_dir(rng) * 0.4).normalized(), rng.uniform(0.2, 0.32), 0.06, rng,
                    sides=5, sink=0.08)
        return ice
    if type_id == "Toxic":
        return lambda bm, c, k: blob(bm, c, rng.uniform(0.07, 0.12), seed + k, sub=1, amp=1.5)
    if type_id == "Nebula":
        return lambda bm, c, k: star_at(bm, c, 0.05, rng.uniform(0.14, 0.2))
    return lambda bm, c, k: chunk(bm, c, rng.uniform(0.1, 0.17), seed + 31 * k, (1, 1, 0.5))


# ---------------------------------------------------------------- strefy, materiały, eksport

def zones(parts, count, rng):
    """Strefy rozbijania: punkty na widocznej powierzchni (Shell, a w szczelinie/otworze — Core),
    górna półkula — dół gwiazdy siedzi w kraterze. Zwraca pozycje w układzie Blendera (Z w górę)."""
    def tree(key):
        me = parts[key].data
        return BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [list(p.vertices) for p in me.polygons])

    shell, core = tree("Shell"), tree("Core")
    out = []
    dirs = fib_dirs(count, rng, 0.0, min_z=-0.2) if count > 1 else [Vector((0.3, -0.6, 0.75)).normalized()]
    for n in dirs:
        # Najbliższe trafienie z obu: promień przez szczelinę nie może trafić w drugą stronę skorupy.
        hits = [h for h in (shell.ray_cast(n * 5.0, -n), core.ray_cast(n * 5.0, -n)) if h[0] is not None]
        p = min(hits, key=lambda h: h[3])[0] if hits else n
        out.append(p + n * 0.04)
    return out


def material(name, rgb, emission=0.0, rough=0.6, metal=0.0, alpha=1.0, emit_rgb=None, neon=False):
    """neon=True: czysta emisja (czarna baza) jak Neon w Roblox — kolor nie wybiela się od świateł."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    lin = srgb_to_lin(rgb)
    b.inputs["Base Color"].default_value = (0, 0, 0, 1) if neon else (*lin, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emission > 0:
        b.inputs["Emission Color"].default_value = (*srgb_to_lin(emit_rgb or rgb), 1)
        b.inputs["Emission Strength"].default_value = emission
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
        b.inputs["Coat Weight"].default_value = 1.0
        m.surface_render_method = "BLENDED"
        m.use_backface_culling = False
    return m


# Materiały podglądu = przybliżenie tego, co ustawia import w Studio (Neon świeci, Glass półprzezroczyste).
def theme_materials(type_id):
    t = THEMES["themes"][type_id]
    shell, glow, color = hex_rgb(t["shell"]), hex_rgb(t["glow"]), hex_rgb(t["color"])
    core = material(f"{type_id}_Core", glow, emission=1.0 if type_id == "Geode" else 1.8, neon=True)
    if type_id == "Iron":
        accent = material("Iron_Accent", color, rough=0.18, metal=1.0)
        orbit = material("Iron_Orbit", color, rough=0.25, metal=1.0)
        sh = material("Iron_Shell", shell, rough=0.4, metal=0.85)
    elif type_id == "Lava":
        accent = material("Lava_Accent", color, emission=2.2, neon=True)
        orbit = material("Lava_Orbit", shell, rough=0.9)
        sh = material("Lava_Shell", shell, rough=0.85)
    elif type_id == "Frost":
        accent = material("Frost_Accent", color, alpha=0.5, rough=0.05, emission=0.5)
        orbit = material("Frost_Orbit", color, alpha=0.6, rough=0.05, emission=1.2)
        sh = material("Frost_Shell", shell, alpha=0.6, rough=0.03)
    elif type_id == "Comet":
        accent = material("Comet_Accent", color, emission=1.8, neon=True)
        orbit = material("Comet_Orbit", color, alpha=0.6, rough=0.05, emission=0.8)
        sh = material("Comet_Shell", shell, rough=0.25, metal=0.1)
    elif type_id == "Toxic":
        accent = material("Toxic_Accent", color, emission=1.8, neon=True)
        orbit = material("Toxic_Orbit", color, emission=1.6, neon=True)
        sh = material("Toxic_Shell", shell, rough=0.85)
    elif type_id == "Electric":
        accent = material("Electric_Accent", color, emission=2.4, neon=True)
        orbit = material("Electric_Orbit", shell, rough=0.3, metal=1.0)
        sh = material("Electric_Shell", shell, rough=0.3, metal=0.9)
    elif type_id == "Nebula":
        accent = material("Nebula_Accent", color, emission=1.8, neon=True)
        orbit = material("Nebula_Orbit", glow, emission=1.6, neon=True)
        sh = material("Nebula_Shell", color, alpha=0.3, rough=0.03)
    else:
        accent = material(f"{type_id}_Accent", color, emission=1.5, neon=True)
        orbit = material(f"{type_id}_Orbit", color, emission=1.3, neon=True)
        sh = material(f"{type_id}_Shell", shell, rough=0.9)
    return {"Shell": sh, "Core": core, "Accent": accent, "Orbit": orbit}


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def build_type(type_id):
    mats = theme_materials(type_id)
    result = {}
    for size in SIZES:
        cfg = SIZE_CFG[size]
        rng = random.Random(SEED[type_id] * 10 + cfg["d"])
        coll = bpy.data.collections.new(f"{type_id}_{size}")
        bpy.context.scene.collection.children.link(coll)
        parts = BUILDERS[type_id](coll, cfg, rng, SEED[type_id] + cfg["d"])
        fx = parts.pop("_fx", {})
        if cfg["orbit"]:
            bm = bmesh.new()
            orbit_ring(bm, cfg["orbit"], rng, orbit_maker(type_id, rng, SEED[type_id]))
            parts["Orbit"] = mesh_obj("Orbit", bm, coll)
        zs = zones(parts, STARS["classes"][size]["zones"], rng)
        for key, ob in parts.items():
            ob.name = f"{size}_{key}"
            ob.data.name = ob.name
            ob.data.materials.clear()
            ob.data.materials.append(mats[key])
        for i, p in enumerate(zs):
            e = bpy.data.objects.new(f"{size}_Zone_{i + 1}", None)
            e.location = p
            e.empty_display_size = 0.12
            coll.objects.link(e)
        counts = {k: tris(o) for k, o in parts.items()}
        total = sum(counts.values())
        result[size] = {"coll": coll, "parts": parts, "zones": zs, "fx": fx, "tris": counts, "total": total,
                        "ok": total <= BUDGET[size]}
    return result


def export_fbx(path):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True,
                             axis_forward="-Z", axis_up="Y", add_leaf_bones=False, mesh_smooth_type="FACE")


# ---------------------------------------------------------------- render

def space_world(bg):
    """Tło: ciemny kosmos z mgławicą i gwiazdkami (tylko podgląd)."""
    world = bpy.data.worlds.new("Space")
    world.use_nodes = True
    nt = world.node_tree
    N = nt.nodes
    L = nt.links
    out_bg = N["Background"]
    tc = N.new("ShaderNodeTexCoord")
    vor = N.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 140.0
    L.new(tc.outputs["Generated"], vor.inputs["Vector"])
    rng_ = N.new("ShaderNodeMapRange")
    rng_.inputs["From Min"].default_value = 0.0
    rng_.inputs["From Max"].default_value = 0.045
    rng_.inputs["To Min"].default_value = 1.0
    rng_.inputs["To Max"].default_value = 0.0
    L.new(vor.outputs["Distance"], rng_.inputs["Value"])
    pw = N.new("ShaderNodeMath")
    pw.operation = "POWER"
    pw.inputs[1].default_value = 3.0
    L.new(rng_.outputs["Result"], pw.inputs[0])
    nz = N.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 1.6
    nz.inputs["Detail"].default_value = 6.0
    L.new(tc.outputs["Generated"], nz.inputs["Vector"])
    ramp = N.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.45
    ramp.color_ramp.elements[0].color = (*bg, 1)
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = (0.06, 0.02, 0.10, 1)
    L.new(nz.outputs["Fac"], ramp.inputs["Fac"])
    add = N.new("ShaderNodeMix")
    add.data_type = "RGBA"
    add.blend_type = "ADD"
    add.inputs["Factor"].default_value = 1.0
    L.new(ramp.outputs["Color"], add.inputs["A"])
    L.new(pw.outputs["Value"], add.inputs["B"])
    L.new(add.outputs["Result"], out_bg.inputs["Color"])
    return world


def bloom(strength=1.6, size=8):
    """Kompozytor Blendera 5.x: Render Layers → Glare (Bloom) → wyjście. Świecące części dostają poświatę."""
    sc = bpy.context.scene
    ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
    ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    rl = ng.nodes.new("CompositorNodeRLayers")
    gl = ng.nodes.new("CompositorNodeGlare")
    out = ng.nodes.new("NodeGroupOutput")
    for key, val in (("Type", "Bloom"), ("Threshold", 0.55), ("Strength", strength), ("Size", size), ("Quality", "High")):
        try:
            gl.inputs[key].default_value = val
        except (TypeError, KeyError, AttributeError) as e:
            print("GLARE skip", key, e)
    ng.links.new(rl.outputs["Image"], gl.inputs["Image"])
    ng.links.new(gl.outputs[0], out.inputs[0])
    sc.compositing_node_group = ng


def setup_render(w, h, bg=(0.008, 0.007, 0.022), space=True):
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = w, h
    # Standard (nie AgX): nasycone kolory poświaty jak Neon w Roblox; AgX wybiela mocną emisję.
    sc.view_settings.view_transform = "Standard"
    try:
        sc.view_settings.look = "Medium High Contrast"
    except TypeError:
        pass
    if space:
        sc.world = space_world(bg)
        bloom()
    else:
        world = bpy.data.worlds.new("Flat")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs["Color"].default_value = (*bg, 1)
        sc.world = world
    for name, energy, loc, col in (("Key", 2200, (6, -12, 9), (1, 0.97, 0.92)), ("Fill", 500, (-10, -8, 2), (0.7, 0.75, 1.0)),
                                   ("Rim", 2600, (-4, 12, 6), (0.55, 0.45, 1.0))):
        li = bpy.data.lights.new(name, "AREA")
        li.energy, li.size, li.color = energy, 10, col
        ob = bpy.data.objects.new(name, li)
        ob.location = loc
        ob.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(ob)


def camera(loc, target, lens=50):
    cam = bpy.data.cameras.new("Cam")
    cam.lens = lens
    ob = bpy.data.objects.new("Cam", cam)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = ob


# Skala w renderze (nie prawdziwa 6:12:24:45 — inaczej Small byłby kropką).
VIEW_SCALE = {"Small": 0.55, "Medium": 0.75, "Large": 1.0, "Huge": 1.3}


def x_extent(objs):
    xs = [v.co.x for ob in objs if ob.type == "MESH" for v in ob.data.vertices]
    return min(xs), max(xs)


def place_row(groups, gap=0.35):
    """groups: lista (obiekty, skala) — układa obok siebie wg prawdziwej szerokości (ogon Comet itd.).
    Zwraca szerokość rzędu; rząd wyśrodkowany w x=0."""
    x = 0.0
    for objs, s in groups:
        lo, hi = x_extent(objs)
        off = x - lo * s
        for ob in objs:
            ob.scale = (s, s, s)
            ob.location = ob.location * s + Vector((off, 0, 0))
        x += (hi - lo) * s + gap
    width = x - gap
    for objs, _ in groups:
        for ob in objs:
            ob.location.x -= width / 2
    return width


def frame_camera(width, height, aspect, lens=40, z=0.0):
    half = 18 / lens  # tan(fov/2) przy matrycy 36 mm (szerokość)
    dist = max(width * 1.08 / (2 * half), height * 1.15 * aspect / (2 * half))
    camera((0, -dist, z + dist * 0.12), (0, 0, z), lens=lens)


def render_type(type_id, result):
    width = place_row([(list(result[s]["coll"].objects), VIEW_SCALE[s]) for s in SIZES])
    setup_render(1920, 640)
    frame_camera(width, 3.6, 1920 / 640)
    bpy.context.scene.render.filepath = str(IMG / f"star_{type_id.lower()}.png")
    bpy.ops.render.render(write_still=True)


def render_grid(rows, name, silhouette=False):
    """Huge podanych rodzajów: rzędy (lista list) jeden pod drugim. silhouette=True: czarne na białym."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    black = material("Black", (0, 0, 0), rough=1.0) if silhouette else None
    widths = []
    for r, types in enumerate(rows):
        groups = []
        for t in types:
            res = build_type(t)
            for size in SIZES:
                if size != "Huge":
                    for ob in res[size]["coll"].objects:
                        ob.hide_render = True
            objs = list(res["Huge"]["coll"].objects)
            if black:
                for ob in objs:
                    if ob.type == "MESH":
                        ob.data.materials.clear()
                        ob.data.materials.append(black)
            groups.append((objs, 1.0))
        widths.append(place_row(groups, gap=0.8))
        for objs, _ in groups:
            for ob in objs:
                ob.location.z += ((len(rows) - 1) / 2 - r) * 4.4
    w, h = (1920, 560 * len(rows)) if silhouette else (1920, 700 * len(rows))
    if silhouette:
        setup_render(w, h, bg=(1, 1, 1), space=False)
    else:
        setup_render(w, h)
    frame_camera(max(widths), 4.4 * len(rows), w / h, lens=45)
    bpy.context.scene.render.filepath = str(IMG / f"{name}.png")
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- main

def to_roblox(v):
    # Eksport FBX (-Z forward, Y up) → po imporcie do Roblox: Blender (x, y, z) → Roblox (-x, z, y)
    # (zmierzone w Studio na otworze Geode — obrót 180° wokół osi pionowej względem (x, z, -y)).
    return [round(-v.x, 4), round(v.z, 4), round(v.y, 4)]


# Szablon skryptu importu do Studio (__ZONES__/__SIZES__/__THEMES__ podmieniane przy generowaniu).
IMPORT_TEMPLATE = (OUT / "import_stars.template.luau").read_text(encoding="utf-8")


def write_import_script(zones_all, fx_all):
    (OUT / "import_stars.luau").write_text((IMPORT_TEMPLATE.replace("__ZONES__", json.dumps(zones_all))
     .replace("__FX__", json.dumps(fx_all))
     .replace("__SIZES__", json.dumps({s: STARS["classes"][s]["size"] for s in SIZES}))
     .replace("__THEMES__", json.dumps({t: {k: THEMES["themes"][t][k] for k in ("shell", "glow", "color")}
                                        for t in zones_all}))), encoding="utf-8")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    types = list(BUILDERS)
    if "--types" in argv:
        types = argv[argv.index("--types") + 1].split(",")
    render = "--render" in argv
    lineup = argv[argv.index("--lineup") + 1] if "--lineup" in argv else "star_lineup"
    IMG.mkdir(parents=True, exist_ok=True)
    zones_path = OUT / "zones.json"
    zones_all = json.loads(zones_path.read_text(encoding="utf-8")) if zones_path.exists() else {}
    fx_path = OUT / "fx.json"
    fx_all = json.loads(fx_path.read_text(encoding="utf-8")) if fx_path.exists() else {}
    report = {}
    for t in types:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        res = build_type(t)
        folder = OUT / t.lower()
        folder.mkdir(parents=True, exist_ok=True)
        export_fbx(folder / f"star_{t.lower()}.fbx")
        report[t] = {s: {"total": res[s]["total"], "ok": res[s]["ok"], **res[s]["tris"]} for s in SIZES}
        # Strefy względem środka bryły Shell, znormalizowane przez największy wymiar Shell (Studio skaluje tak samo).
        zones_all[t] = {}
        for s in SIZES:
            sh = res[s]["parts"]["Shell"]
            xs = [v.co for v in sh.data.vertices]
            lo = Vector((min(v.x for v in xs), min(v.y for v in xs), min(v.z for v in xs)))
            hi = Vector((max(v.x for v in xs), max(v.y for v in xs), max(v.z for v in xs)))
            c, m = (lo + hi) / 2, max(hi - lo)
            zones_all[t][s] = [to_roblox((p - c) / m) for p in res[s]["zones"]]
            fx = res[s]["fx"]
            if fx:
                fx_all.setdefault(t, {})[s] = {
                    "beams": [[to_roblox((a - c) / m), to_roblox((b - c) / m)] for a, b in fx.get("beams", [])],
                    "tail": [to_roblox((fx["tail"][0] - c) / m), to_roblox(fx["tail"][1])] if "tail" in fx else None,
                }
        bpy.ops.wm.save_as_mainfile(filepath=str(folder / f"star_{t.lower()}.blend"))
        if render:
            render_type(t, res)
    zones_path.write_text(json.dumps(zones_all, indent=1), encoding="utf-8")
    fx_path.write_text(json.dumps(fx_all, indent=1), encoding="utf-8")
    write_import_script(zones_all, fx_all)
    if render and len(types) > 1:
        everything = list(BUILDERS)
        render_grid([everything[:4], everything[4:]], "star_silhouettes", silhouette=True)
        render_grid([types], lineup)
        if set(types) != set(everything[:4]):
            render_grid([everything[:4], everything[4:]], "star_lineup_all")
    print("STAR_REPORT", json.dumps(report))


main()
