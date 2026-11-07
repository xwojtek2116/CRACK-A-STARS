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


def solidify(ob, thickness):
    sol = ob.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = thickness
    sol.offset = -1
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Solidify")
    ob.select_set(False)


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


# ---------------------------------------------------------------- rodzaje

def build_iron(coll, cfg, rng, seed):
    """Iron Meteorite: spłaszczony „ziemniak” z wgnieceniami (thumbprints), wąskie żarzące się szwy, guzy."""
    d = cfg["d"]
    squash = Vector((1.28, 1.0, 0.86))
    bm = ico(1.0, cfg["sub"])
    dents = [(dd, rng.uniform(0.32, 0.5), rng.uniform(0.09, 0.15)) for dd in fib_dirs(5 + 4 * d, rng, 0.3)]
    for v in bm.verts:
        n = v.co.normalized()
        r = rocky(n, seed, 0.8)
        for c, ang, depth in dents:
            a = n.angle(c)
            if a < ang:
                r -= depth * (1 - (a / ang) ** 2)
        v.co = Vector((n.x * squash.x, n.y * squash.y, n.z * squash.z)) * r
    voronoi_plates(bm, [6, 9, 13, 18][d], 0.955, (0.99, 1.03), rng)
    shell = mesh_obj("Shell", bm, coll)
    solidify(shell, 0.12)

    core = ico(0.86, 3)
    for v in core.verts:
        v.co = Vector((v.co.x * squash.x, v.co.y * squash.y, v.co.z * squash.z))
    parts = {"Shell": shell, "Core": mesh_obj("Core", core, coll, smooth=True)}

    acc = bmesh.new()
    for i, n in enumerate(fib_dirs([2, 3, 5, 7][d], rng, 0.5, min_z=-0.2)):
        p = Vector((n.x * squash.x, n.y * squash.y, n.z * squash.z)) * 0.95
        chunk(acc, p, rng.uniform(0.18, 0.28), seed + i * 7, (1, 1, 0.8))
    parts["Accent"] = mesh_obj("Accent", acc, coll)
    return parts


def build_lava(coll, cfg, rng, seed):
    """Lava Star: czarne płyty bazaltu unoszące się na kuli magmy (szerokie świecące szczeliny), kapiące krople."""
    d = cfg["d"]
    bm = ico(1.05, cfg["sub"])
    for v in bm.verts:
        n = v.co.normalized()
        v.co = n * 1.05 * rocky(n, seed, 0.6)
    voronoi_plates(bm, [8, 12, 17, 24][d], 0.80, (1.0, 1.13), rng)
    shell = mesh_obj("Shell", bm, coll)
    solidify(shell, 0.17)

    core = ico(0.97, 3 if d < 3 else 4)
    for v in core.verts:
        n = v.co.normalized()
        v.co = n * 0.97 * rocky(n, seed + 5, 0.5)
    parts = {"Shell": shell, "Core": mesh_obj("Core", core, coll, smooth=True)}

    # Krople: łza = stożek w dół + kulka na końcu, z boków i spodu.
    acc = bmesh.new()
    n_drips = [3, 5, 7, 10][d]
    for i in range(n_drips):
        a = i / n_drips * math.tau + rng.uniform(-0.3, 0.3)
        z = rng.uniform(-0.55, 0.35)
        rr = math.sqrt(1 - z * z)
        base = Vector((math.cos(a) * rr, math.sin(a) * rr, z)) * 0.98
        length = rng.uniform(0.3, 0.55) * (1.0 + 0.12 * d)
        rad = rng.uniform(0.13, 0.19)
        down = (Vector((0, 0, -1)) * 0.6 + base * 0.6).normalized()
        crystal(acc, base, down, length, rad, rng, sides=6, sink=0.1)
        chunk(acc, base + down * length * 0.95, rad * 1.35, seed + i, sub=1)
    parts["Accent"] = mesh_obj("Accent", acc, coll, smooth=True)
    return parts


def build_frost(coll, cfg, rng, seed):
    """Frost Star: gęsty klaster długich kolców lodu na śnieżnej, gładkiej skorupie (sylwetka „jeżowca”)."""
    d = cfg["d"]
    bm = ico(0.72, cfg["sub"])
    for v in bm.verts:
        n = v.co.normalized()
        v.co = n * 0.72 * rocky(n, seed, 0.5)
    shell = mesh_obj("Shell", bm, coll, smooth=True)

    # Core = krótkie, świecące kryształki między kolcami (zimny blask).
    core = bmesh.new()
    for n in fib_dirs([6, 9, 14, 20][d], rng, 0.4):
        crystal(core, n * 0.68, n, rng.uniform(0.22, 0.38), 0.06, rng, sides=5)
    parts = {"Shell": shell, "Core": mesh_obj("Core", core, coll)}

    acc = bmesh.new()
    for n in fib_dirs([10, 15, 22, 32][d], rng, 0.25):
        length = rng.uniform(0.95, 1.55) * (0.65 if n.z < -0.4 else 1.0)
        crystal(acc, n * 0.66, n, length, rng.uniform(0.085, 0.13), rng, sides=6)
    parts["Accent"] = mesh_obj("Accent", acc, coll)
    return parts


GEODE_OPEN = Vector((0.35, -1.0, 0.45)).normalized()


def build_geode(coll, cfg, rng, seed):
    """Geode Star: chropowate kamienne jajo pęknięte z jednej strony, w środku grota ametystów."""
    d = cfg["d"]

    def egg(n, r):
        # jajo: wydłużone w Z, węższe u góry
        x, y, z = n.x * r, n.y * r, n.z * r * 1.3
        k = 1.0 - 0.12 * n.z
        return Vector((x * k, y * k, z))

    bm = ico(1.0, cfg["sub"])
    for v in bm.verts:
        n = v.co.normalized()
        v.co = egg(n, rocky(n, seed, 1.0))
    # Otwór: usuń ściany w stożku wokół GEODE_OPEN, z poszarpaną krawędzią.
    lim = math.cos(math.radians(48))
    kill = []
    for f in bm.faces:
        n = f.calc_center_median().normalized()
        jag = 0.12 * noise.noise(n * 4.0 + Vector((seed, 0, 0)))
        if n.dot(GEODE_OPEN) > lim + jag:
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    if d >= 2:  # większe: dodatkowe pęknięcie skorupy na płyty
        voronoi_plates(bm, [0, 0, 10, 15][d], 0.985, (0.995, 1.02), rng)
    shell = mesh_obj("Shell", bm, coll)
    solidify(shell, 0.24)

    core = ico(1.0, 3)
    for v in core.verts:
        n = v.co.normalized()
        v.co = egg(n, 0.74)
    parts = {"Shell": shell, "Core": mesh_obj("Core", core, coll, smooth=True)}

    # Ametysty rosną ze ścianki groty do środka/na zewnątrz otworu.
    acc = bmesh.new()
    n_cr = [7, 11, 16, 24][d]
    placed = 0
    tries = 0
    while placed < n_cr and tries < 500:
        tries += 1
        n = Vector(tuple(rng.uniform(-1, 1) for _ in range(3))).normalized()
        if n.dot(GEODE_OPEN) < 0.1:
            continue
        base = egg(n, 0.76)
        dirn = (-n * 0.35 + GEODE_OPEN * 0.9 + Vector(tuple(rng.uniform(-.3, .3) for _ in range(3)))).normalized()
        length = rng.uniform(0.35, 0.75) * (1.0 + 0.12 * d)
        crystal(acc, base, dirn, length, rng.uniform(0.08, 0.14), rng)
        placed += 1
    # Kilka kryształów wyrasta z krawędzi otworu na zewnątrz — sylwetka „korony”.
    for i in range(2 + d):
        a = i / (2 + d) * math.tau
        side = GEODE_OPEN.cross(Vector((0, 0, 1))).normalized()
        up = side.cross(GEODE_OPEN).normalized()
        n = (GEODE_OPEN * lim + (side * math.cos(a) + up * math.sin(a)) * math.sqrt(1 - lim * lim)).normalized()
        crystal(acc, egg(n, 0.95), (n + GEODE_OPEN * 0.6).normalized(), rng.uniform(0.4, 0.6), 0.1, rng)
    parts["Accent"] = mesh_obj("Accent", acc, coll)
    return parts


BUILDERS = {"Iron": build_iron, "Lava": build_lava, "Frost": build_frost, "Geode": build_geode}


def orbit_maker(type_id, rng, seed):
    if type_id in ("Frost", "Geode"):
        return lambda bm, c, k: crystal(bm, c, Vector(tuple(rng.uniform(-1, 1) for _ in range(3))), rng.uniform(0.25, 0.45),
                                        0.08, rng, sides=5, sink=0.1)
    squash = (1, 1, 0.5) if type_id == "Lava" else (1, 1, 1)
    return lambda bm, c, k: chunk(bm, c, rng.uniform(0.1, 0.17), seed + 31 * k, squash)


# ---------------------------------------------------------------- strefy, materiały, eksport

def zones(parts, count, rng):
    """Strefy rozbijania: punkty na powierzchni (Shell+Core), górna półkula — dół gwiazdy siedzi w kraterze.
    Zwraca pozycje w układzie Blendera (Z w górę)."""
    verts, polys, off = [], [], 0
    for key in ("Shell", "Core"):
        me = parts[key].data
        verts += [v.co.copy() for v in me.vertices]
        polys += [[i + off for i in p.vertices] for p in me.polygons]
        off += len(me.vertices)
    tree = BVHTree.FromPolygons(verts, polys)
    out = []
    dirs = fib_dirs(count, rng, 0.0, min_z=-0.2) if count > 1 else [Vector((0.3, -0.6, 0.75)).normalized()]
    for n in dirs:
        hit = tree.ray_cast(n * 5.0, -n)
        p = hit[0] if hit[0] is not None else n
        out.append(p + n * 0.04)
    return out


def material(name, rgb, emission=0.0, rough=0.6, metal=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    lin = srgb_to_lin(rgb)
    b.inputs["Base Color"].default_value = (*lin, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emission > 0:
        b.inputs["Emission Color"].default_value = (*lin, 1)
        b.inputs["Emission Strength"].default_value = emission
    return m


def theme_materials(type_id):
    t = THEMES["themes"][type_id]
    metal = 0.35 if type_id == "Iron" else 0.0
    return {
        "Shell": material(f"{type_id}_Shell", hex_rgb(t["shell"]), rough=0.75 if type_id != "Frost" else 0.5, metal=metal),
        "Core": material(f"{type_id}_Core", hex_rgb(t["glow"]), emission=2.0),
        "Accent": material(f"{type_id}_Accent", hex_rgb(t["color"]),
                           emission=0.0 if type_id == "Iron" else 0.8, rough=0.25, metal=metal),
        "Orbit": material(f"{type_id}_Orbit", hex_rgb(t["color"] if type_id in ("Frost", "Geode") else t["shell"]),
                          emission=0.6 if type_id in ("Frost", "Geode") else 0.0, rough=0.5),
    }


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

def setup_render(w, h, bg=(0.012, 0.010, 0.03)):
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = w, h
    try:
        sc.view_settings.view_transform = "AgX"
        sc.view_settings.look = "AgX - Punchy"
    except TypeError:
        pass
    world = bpy.data.worlds.new("Space")
    world.use_nodes = True
    node = world.node_tree.nodes["Background"]
    node.inputs["Color"].default_value = (*bg, 1)
    sc.world = world
    for name, energy, loc, col in (("Key", 3000, (6, -12, 9), (1, 1, 1)), ("Fill", 900, (-10, -8, 2), (0.8, 0.85, 1.0)), ("Rim", 1500, (-6, 10, 5), (0.6, 0.5, 1.0))):
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


def render_silhouettes(types):
    """Sylwetki Huge wszystkich rodzajów: czarne na białym — test „rozpoznawalny bez koloru”."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    black = material("Black", (0, 0, 0), rough=1.0)
    black.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0, 0, 0, 1)
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
    setup_render(1920, 560, bg=(1, 1, 1))
    bpy.context.scene.view_settings.view_transform = "Standard"
    camera((0, -30, 1.5), (0, 0, 0), lens=45)
    bpy.context.scene.render.filepath = str(IMG / "star_silhouettes.png")
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- main

def to_roblox(v):
    # Eksport FBX: Blender (x, y, z) Z-up → Roblox (x, z, -y) Y-up.
    return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


IMPORT_TEMPLATE = """--!strict
-- WYGENEROWANE przez art/stars/build_star.py — nie edytuj ręcznie.
-- Uruchom w Studio (execute_luau, Edit) po wstawieniu modeli FBX (insert_asset) jako
-- ServerStorage.StarImport.<Rodzaj> (Model z MeshPartami `<Rozmiar>_<Część>`).
-- Wynik: ServerStorage.Stars/<Rodzaj>/<Rozmiar> (Model, PrimaryPart = Shell, Attachmenty Zone_N na Shell).
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

-- Dane wbudowane przy generowaniu (Stars.json → size, Themes.json → kolory), bo Config w Studio może być nieświeży.
local ZONES = HttpService:JSONDecode([==[__ZONES__]==])
local STAR_SIZE = HttpService:JSONDecode([==[__SIZES__]==])
local THEMES = HttpService:JSONDecode([==[__THEMES__]==])
local SIZES = { "Small", "Medium", "Large", "Huge" }

local MATERIAL = {
\tIron = Enum.Material.CorrodedMetal,
\tLava = Enum.Material.Basalt,
\tFrost = Enum.Material.Snow,
\tGeode = Enum.Material.Rock,
}
local ACCENT_MATERIAL = {
\tIron = Enum.Material.DiamondPlate,
\tLava = Enum.Material.Neon,
\tFrost = Enum.Material.Glass,
\tGeode = Enum.Material.Neon,
}

local import = ServerStorage:FindFirstChild("StarImport")
assert(import, "Brak ServerStorage.StarImport — najpierw insert_asset modeli FBX")
local root = ServerStorage:FindFirstChild("Stars") or Instance.new("Folder")
root.Name = "Stars"
root.Parent = ServerStorage

local report = {}
for typeId, zonesBySize in ZONES do
\tlocal src = import:FindFirstChild(typeId)
\tif not src then
\t\ttable.insert(report, typeId .. ": brak modelu")
\t\tcontinue
\tend
\tlocal theme = THEMES[typeId]
\tlocal folder = root:FindFirstChild(typeId) or Instance.new("Folder")
\tfolder.Name = typeId
\tfolder.Parent = root
\tfor _, size in SIZES do
\t\tlocal old = folder:FindFirstChild(size)
\t\tif old then
\t\t\told:Destroy()
\t\tend
\t\tlocal model = Instance.new("Model")
\t\tmodel.Name = size
\t\tfor _, part in src:GetDescendants() do
\t\t\tif part:IsA("MeshPart") and string.sub(part.Name, 1, #size + 1) == size .. "_" then
\t\t\t\tlocal role = string.sub(part.Name, #size + 2)
\t\t\t\tlocal p = part:Clone()
\t\t\t\tp.Name = role
\t\t\t\tp.Anchored = true
\t\t\t\tp.CanCollide = role == "Shell"
\t\t\t\tp.CanQuery = role == "Shell" or role == "Core"
\t\t\t\tp.CastShadow = role ~= "Core"
\t\t\t\tif role == "Shell" then
\t\t\t\t\tp.Material = MATERIAL[typeId]
\t\t\t\t\tp.Color = Color3.fromHex(theme.shell)
\t\t\t\telseif role == "Core" then
\t\t\t\t\tp.Material = Enum.Material.Neon
\t\t\t\t\tp.Color = Color3.fromHex(theme.glow)
\t\t\t\telseif role == "Accent" then
\t\t\t\t\tp.Material = ACCENT_MATERIAL[typeId]
\t\t\t\t\tp.Color = Color3.fromHex(theme.color)
\t\t\t\telse
\t\t\t\t\tp.Material = ACCENT_MATERIAL[typeId]
\t\t\t\t\tp.Color = Color3.fromHex(theme.color)
\t\t\t\tend
\t\t\t\tp.Parent = model
\t\t\tend
\t\tend
\t\tlocal shell = model:FindFirstChild("Shell") :: MeshPart?
\t\tif not shell then
\t\t\ttable.insert(report, typeId .. "/" .. size .. ": brak Shell")
\t\t\tmodel:Destroy()
\t\t\tcontinue
\t\tend
\t\tmodel.PrimaryPart = shell
\t\tlocal ext = shell.Size
\t\tlocal target = STAR_SIZE[size]
\t\tmodel:ScaleTo(model:GetScale() * target / math.max(ext.X, ext.Y, ext.Z))
\t\tmodel:PivotTo(CFrame.new(shell.Position))
\t\tlocal m = math.max(shell.Size.X, shell.Size.Y, shell.Size.Z)
\t\tfor i, v in zonesBySize[size] do
\t\t\tlocal a = Instance.new("Attachment")
\t\t\ta.Name = "Zone_" .. i
\t\t\ta.Parent = shell
\t\t\ta.WorldPosition = shell.Position + Vector3.new(v[1], v[2], v[3]) * m
\t\tend
\t\tmodel:SetAttribute("Type", typeId)
\t\tmodel:SetAttribute("Size", size)
\t\tmodel.Parent = folder
\t\ttable.insert(report, string.format("%s/%s: %d czesci, %d stref", typeId, size, #model:GetChildren(), #zonesBySize[size]))
\tend
end
return report
"""


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
    print("STAR_REPORT", json.dumps(report))


main()
