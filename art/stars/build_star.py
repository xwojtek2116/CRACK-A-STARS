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
SEED = {"Iron": 101, "Lava": 202, "Frost": 303, "Geode": 404}


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


BUILDERS = {"Iron": build_iron, "Lava": build_lava, "Frost": build_frost, "Geode": build_geode}


def orbit_maker(type_id, rng, seed):
    if type_id == "Frost":
        def shard(bm, c, k):
            tan = Vector((-c.y, c.x, 0)).normalized()
            crystal(bm, c - tan * 0.15, (tan + rand_dir(rng) * 0.2).normalized(), rng.uniform(0.3, 0.45), 0.07, rng, sides=6,
                    sink=0.1)
        return shard
    if type_id == "Geode":
        return lambda bm, c, k: crystal(bm, c, rand_dir(rng), rng.uniform(0.25, 0.45), 0.08, rng, sides=5, sink=0.1)
    if type_id == "Iron":
        return lambda bm, c, k: cube_at(bm, c, rng.uniform(0.07, 0.12), rng)
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
        result[size] = {"coll": coll, "parts": parts, "zones": zs, "tris": counts, "total": total,
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


def layout_row(result, gap=1.15):
    x = 0.0
    xs = {}
    for size in SIZES:
        s = VIEW_SCALE[size]
        span = (2.6 if SIZE_CFG[size]["orbit"] else 1.7) * s
        x += span * gap
        xs[size] = x
        x += span * gap
        for ob in result[size]["coll"].objects:
            ob.scale = (s, s, s)
            ob.location = ob.location * s + Vector((xs[size], 0, 0))
    mid = x / 2
    for size in SIZES:
        for ob in result[size]["coll"].objects:
            ob.location.x -= mid
    return x


def render_type(type_id, result):
    width = layout_row(result)
    setup_render(1920, 640)
    camera((0, -width * 1.15, width * 0.22), (0, 0, 0), lens=40)
    bpy.context.scene.render.filepath = str(IMG / f"star_{type_id.lower()}.png")
    bpy.ops.render.render(write_still=True)


def render_lineup(types):
    """Huge wszystkich rodzajów obok siebie, w kolorze, z bloomem — główny podgląd do akceptacji."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for i, t in enumerate(types):
        res = build_type(t)
        for size in SIZES:
            for ob in res[size]["coll"].objects:
                if size != "Huge":
                    ob.hide_render = True
                    continue
                ob.location.x += (i % 2 - 0.5) * 5.4
                ob.location.z += (0.5 - i // 2) * 4.6
    setup_render(1600, 1500)
    camera((0, -15.5, 2.0), (0, 0, 0), lens=42)
    bpy.context.scene.render.filepath = str(IMG / "star_lineup.png")
    bpy.ops.render.render(write_still=True)


def render_silhouettes(types):
    """Sylwetki Huge wszystkich rodzajów: czarne na białym — test „rozpoznawalny bez koloru”."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    black = material("Black", (0, 0, 0), rough=1.0)
    for i, t in enumerate(types):
        res = build_type(t)
        for size in SIZES:
            for ob in res[size]["coll"].objects:
                if size != "Huge":
                    ob.hide_render = True
                    continue
                ob.location.x += (i - (len(types) - 1) / 2) * 6.2
                if ob.type == "MESH":
                    ob.data.materials.clear()
                    ob.data.materials.append(black)
    setup_render(1920, 560, bg=(1, 1, 1), space=False)
    bpy.context.scene.view_settings.view_transform = "Standard"
    camera((0, -30, 1.5), (0, 0, 0), lens=45)
    bpy.context.scene.render.filepath = str(IMG / "star_silhouettes.png")
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- main

def to_roblox(v):
    # Eksport FBX (-Z forward, Y up) → po imporcie do Roblox: Blender (x, y, z) → Roblox (-x, z, y)
    # (zmierzone w Studio na otworze Geode — obrót 180° wokół osi pionowej względem (x, z, -y)).
    return [round(-v.x, 4), round(v.z, 4), round(v.y, 4)]


# Szablon skryptu importu do Studio (__ZONES__/__SIZES__/__THEMES__ podmieniane przy generowaniu).
IMPORT_TEMPLATE = (OUT / "import_stars.template.luau").read_text(encoding="utf-8")


def write_import_script(zones_all):
    (OUT / "import_stars.luau").write_text((IMPORT_TEMPLATE.replace("__ZONES__", json.dumps(zones_all))
     .replace("__SIZES__", json.dumps({s: STARS["classes"][s]["size"] for s in SIZES}))
     .replace("__THEMES__", json.dumps({t: {k: THEMES["themes"][t][k] for k in ("shell", "glow", "color")}
                                        for t in zones_all}))), encoding="utf-8")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    types = list(BUILDERS)
    if "--types" in argv:
        types = argv[argv.index("--types") + 1].split(",")
    render = "--render" in argv
    IMG.mkdir(parents=True, exist_ok=True)
    zones_path = OUT / "zones.json"
    zones_all = json.loads(zones_path.read_text(encoding="utf-8")) if zones_path.exists() else {}
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
        bpy.ops.wm.save_as_mainfile(filepath=str(folder / f"star_{t.lower()}.blend"))
        if render:
            render_type(t, res)
    zones_path.write_text(json.dumps(zones_all, indent=1), encoding="utf-8")
    write_import_script(zones_all)
    if render and len(types) > 1:
        render_silhouettes(types)
        render_lineup(types)
    print("STAR_REPORT", json.dumps(report))


main()
