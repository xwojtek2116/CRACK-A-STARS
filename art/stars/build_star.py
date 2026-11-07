"""build_star.py — proceduralne gwiazdy Crack a Stars (Blender 5.x, tryb w tle).

Uruchom:  E:\\blender\\blender.exe -b --factory-startup -P art/stars/build_star.py -- [--render] [--lineup]

Gwiazda = 3 meshe (osobne MeshParty w Roblox, kolor/materiał nadaje gra wg motywu):
  Shell    — skalista skorupa z dziurami-pęknięciami (Roblox: Basalt/Slate/Glacier, kolor motywu ciemny)
  Core     — świecące wnętrze widoczne przez pęknięcia (Roblox: Neon, kolor `glow`)
  Crystals — wystające kryształy (Roblox: Neon/Glass, kolor `color`)
Promień ≈ 1 m; skala do `size` z Stars.json robi gra. Strefy rozbijania = empties `Zone_N` (→ Attachmenty).
"""

import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector, noise

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "game" / "src" / "shared" / "Config" / "Data"
OUT = ROOT / "art" / "stars"
IMG = ROOT / "vault" / "_img"

STARS = json.loads((DATA / "Stars.json").read_text(encoding="utf-8"))
THEMES = json.loads((DATA / "Themes.json").read_text(encoding="utf-8"))

# Kształt na klasę: liczba kryształów, długość, dziury w skorupie, gęstość siatki, pływające odłamki.
SHAPE = {
    "Dust":      dict(crystals=5,  length=(0.45, 0.8), cells=10, gap=0.90, subdiv=3, shards=0,  seed=11),
    "Bright":    dict(crystals=7,  length=(0.55, 1.0), cells=14, gap=0.91, subdiv=3, shards=0,  seed=23),
    "Nova":      dict(crystals=10, length=(0.65, 1.2), cells=20, gap=0.92, subdiv=4, shards=6,  seed=37),
    "Giant":     dict(crystals=14, length=(0.75, 1.4), cells=28, gap=0.93, subdiv=4, shards=10, seed=41),
    "Supernova": dict(crystals=18, length=(0.85, 1.7), cells=36, gap=0.93, subdiv=4, shards=16, seed=53),
}
# Motyw do podglądu klasy w vaulcie (różne, żeby było widać paletę).
PREVIEW_THEME = {"Dust": "Lava", "Bright": "Frost", "Nova": "Nebula", "Giant": "Diamond", "Supernova": "Void"}
SHELL_DARK = {"Lava": "#1C1412", "Frost": "#B9D4E6", "Nebula": "#1E1A33", "Diamond": "#8FA6B8",
              "Toxic": "#1B2A14", "Solar": "#5A3A10", "Void": "#07060C"}


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_lin(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mesh_obj(name, bm, coll):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    return ob


def rocky_radius(v, seed):
    p = v * 1.6 + Vector((seed, seed * 0.37, seed * 0.71))
    return 1.0 + 0.16 * noise.noise(p) + 0.07 * noise.noise(p * 2.7) + 0.03 * noise.noise(p * 6.1)


def build_shell(cfg, coll, rng):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=cfg["subdiv"], radius=1.0)
    for v in bm.verts:
        d = v.co.normalized()
        v.co = d * rocky_radius(d, cfg["seed"])
    # Pęknięcia = szczeliny między płytami Voronoi: każda ściana należy do najbliższego ziarna,
    # krawędzie między komórkami rozcinamy, płyty kurczymy do ich środka → ciągła sieć szczelin.
    n_cells = cfg["cells"]
    seeds = []
    for i in range(n_cells):
        y = 1 - (i + 0.5) / n_cells * 2
        r = math.sqrt(max(0, 1 - y * y))
        th = i * math.pi * (3 - math.sqrt(5)) + rng.uniform(-0.5, 0.5)
        seeds.append(Vector((math.cos(th) * r, math.sin(th) * r, y)).normalized())
    bm.faces.ensure_lookup_table()
    cell_of = {}
    for f in bm.faces:
        c = f.calc_center_median().normalized()
        cell_of[f] = min(range(n_cells), key=lambda k: (seeds[k] - c).length_squared)
    border = [e for e in bm.edges if len(e.link_faces) == 2 and cell_of[e.link_faces[0]] != cell_of[e.link_faces[1]]]
    bmesh.ops.split_edges(bm, edges=border)
    bm.faces.ensure_lookup_table()
    cells = {}
    for f in bm.faces:
        c = f.calc_center_median().normalized()
        k = min(range(n_cells), key=lambda k: (seeds[k] - c).length_squared)
        cells.setdefault(k, set()).update(f.verts)
    for k, verts in cells.items():
        centroid = sum((v.co for v in verts), Vector()) / len(verts)
        lift = rng.uniform(0.97, 1.05)
        for v in verts:
            v.co = centroid + (v.co - centroid) * cfg["gap"]
            v.co *= lift
    ob = mesh_obj("Shell", bm, coll)
    sol = ob.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = 0.14
    sol.offset = -1
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier="Solidify")
    ob.select_set(False)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def build_core(coll):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.9)
    ob = mesh_obj("Core", bm, coll)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def crystal_bm(bm, base, direction, length, radius, rng):
    """Sześciokątny kryształ z ostrym czubkiem, osadzony w skorupie."""
    direction = direction.normalized()
    up = Vector((0, 0, 1)) if abs(direction.z) < 0.9 else Vector((1, 0, 0))
    side = direction.cross(up).normalized()
    side2 = direction.cross(side).normalized()
    sides = 6
    twist = rng.random() * math.tau
    ring0, ring1 = [], []
    for i in range(sides):
        a = twist + i * math.tau / sides
        off = side * math.cos(a) + side2 * math.sin(a)
        ring0.append(bm.verts.new(base - direction * 0.25 + off * radius * 0.9))
        ring1.append(bm.verts.new(base + direction * length * 0.72 + off * radius))
    tip = bm.verts.new(base + direction * length)
    bm.faces.new(list(reversed(ring0)))
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
        bm.faces.new((ring1[i], ring1[j], tip))


def build_crystals(cfg, coll, rng):
    bm = bmesh.new()
    # Rozkład kierunków: złota spirala + szum, żeby kryształy nie zbijały się w jednym miejscu.
    n = cfg["crystals"]
    for i in range(n):
        y = 1 - (i + 0.5) / n * 2
        r = math.sqrt(max(0, 1 - y * y))
        th = i * math.pi * (3 - math.sqrt(5)) + rng.random() * 0.4
        d = Vector((math.cos(th) * r, math.sin(th) * r, y))
        d = (d + Vector((rng.uniform(-.2, .2), rng.uniform(-.2, .2), rng.uniform(-.2, .2)))).normalized()
        base = d * rocky_radius(d, cfg["seed"]) * 0.92
        length = rng.uniform(*cfg["length"])
        crystal_bm(bm, base, d, length, rng.uniform(0.10, 0.18) * (0.8 + length * 0.3), rng)
        # Mniejsze kryształki-dzieci obok dużych.
        if rng.random() < 0.6:
            d2 = (d + Vector((rng.uniform(-.35, .35), rng.uniform(-.35, .35), rng.uniform(-.35, .35)))).normalized()
            crystal_bm(bm, d2 * rocky_radius(d2, cfg["seed"]) * 0.95, d2, length * 0.5, 0.07, rng)
    # Pływające odłamki (Nova+): pierścień wokół gwiazdy.
    for k in range(cfg["shards"]):
        a = k / max(1, cfg["shards"]) * math.tau + rng.random() * 0.3
        rad = rng.uniform(1.9, 2.4)
        c = Vector((math.cos(a) * rad, math.sin(a) * rad, rng.uniform(-0.35, 0.35)))
        d = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized()
        crystal_bm(bm, c, d, rng.uniform(0.25, 0.45), 0.08, rng)
    ob = mesh_obj("Crystals", bm, coll)
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def add_zones(cfg_zones, coll, rng):
    for i in range(cfg_zones):
        y = 1 - (i + 0.5) / cfg_zones * 2 if cfg_zones > 1 else 0.3
        y = max(-0.2, y)  # strefy nad ziemią (dół gwiazdy jest w kraterze)
        r = math.sqrt(max(0, 1 - y * y))
        th = i * 2.399963
        e = bpy.data.objects.new(f"Zone_{i + 1}", None)
        e.location = Vector((math.cos(th) * r, math.sin(th) * r, y)) * 1.05
        e.empty_display_size = 0.15
        coll.objects.link(e)


def material(name, rgb, emission=0.0, rough=0.6, metal=0.0):
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


def apply_theme(parts, theme):
    t = THEMES["themes"][theme]
    shell, core, crys = parts
    for ob, mat in ((shell, material(f"Shell_{theme}", hex_rgb(SHELL_DARK[theme]), rough=0.85)),
                    (core, material(f"Core_{theme}", hex_rgb(t["glow"]), emission=4.0)),
                    (crys, material(f"Crystals_{theme}", hex_rgb(t["color"]), emission=0.7, rough=0.2))):
        ob.data.materials.clear()
        ob.data.materials.append(mat)


def build(cls):
    cfg = SHAPE[cls]
    rng = random.Random(cfg["seed"])
    coll = bpy.data.collections.new(f"Star_{cls}")
    bpy.context.scene.collection.children.link(coll)
    parts = (build_shell(cfg, coll, rng), build_core(coll), build_crystals(cfg, coll, rng))
    add_zones(STARS["classes"][cls]["zones"], coll, rng)
    return coll, parts


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def export_fbx(coll, path):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in coll.objects:
        if ob.type == "MESH":
            ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True,
                             axis_forward="-Z", axis_up="Y", add_leaf_bones=False, mesh_smooth_type="FACE")


def setup_render(res=640):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items} else "BLENDER_EEVEE"
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.render.film_transparent = False
    try:
        sc.view_settings.view_transform = "AgX"
        sc.view_settings.look = "AgX - Punchy"
    except TypeError:
        pass
    try:
        sc.eevee.use_bloom = True
    except AttributeError:
        pass
    world = bpy.data.worlds.new("Space")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.012, 0.010, 0.03, 1)
    bg.inputs["Strength"].default_value = 1.0
    sc.world = world
    # Glare (bloom) w kompozytorze — działa w EEVEE Next.
    try:
        sc.use_nodes = True
        nt = sc.node_tree
        rl = nt.nodes.get("Render Layers") or nt.nodes.new("CompositorNodeRLayers")
        comp = nt.nodes.get("Composite") or nt.nodes.new("CompositorNodeComposite")
        gl = nt.nodes.new("CompositorNodeGlare")
        gl.glare_type = "FOG_GLOW" if hasattr(gl, "glare_type") else gl.glare_type
        gl.quality = "HIGH"
        nt.links.new(rl.outputs["Image"], gl.inputs[0])
        nt.links.new(gl.outputs[0], comp.inputs[0])
    except Exception as exc:  # kompozytor różni się między wersjami — render bez glow też jest OK
        print("glare off:", exc)
    key = bpy.data.lights.new("Key", "AREA")
    key.energy = 400
    key.size = 4
    k = bpy.data.objects.new("Key", key)
    k.location = (3, -3, 4)
    k.rotation_euler = (math.radians(50), 0, math.radians(45))
    sc.collection.objects.link(k)
    rim = bpy.data.lights.new("Rim", "AREA")
    rim.energy = 250
    rim.color = (0.6, 0.5, 1.0)
    r = bpy.data.objects.new("Rim", rim)
    r.location = (-3, 3, 2)
    r.rotation_euler = (math.radians(-60), 0, math.radians(-135))
    sc.collection.objects.link(r)


def camera(dist, target=(0, 0, 0), lens=50):
    cam = bpy.data.cameras.new("Cam")
    cam.lens = lens
    ob = bpy.data.objects.new("Cam", cam)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = Vector(target) + Vector((dist * 0.75, -dist, dist * 0.45))
    d = Vector(target) - ob.location
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = ob
    return ob


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    render = "--render" in argv
    lineup = "--lineup" in argv
    OUT.mkdir(parents=True, exist_ok=True)
    IMG.mkdir(parents=True, exist_ok=True)
    report = {}
    for cls in STARS["order"]:
        clear_scene()
        coll, parts = build(cls)
        apply_theme(parts, PREVIEW_THEME[cls])
        report[cls] = {p.name: tris(p) for p in parts}
        report[cls]["total"] = sum(report[cls].values())
        export_fbx(coll, OUT / f"star_{cls.lower()}.fbx")
        if render:
            setup_render()
            camera(4.6 if SHAPE[cls]["shards"] == 0 else 6.2)
            bpy.context.scene.render.filepath = str(IMG / f"star_{cls.lower()}.png")
            bpy.ops.render.render(write_still=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / f"star_{cls.lower()}.blend"))
    if lineup:
        clear_scene()
        themes = THEMES["order"]
        for i, th in enumerate(themes):
            coll, parts = build("Bright")
            apply_theme(parts, th)
            for ob in coll.objects:
                ob.location.x += (i - (len(themes) - 1) / 2) * 2.9
        setup_render()
        bpy.context.scene.render.resolution_x = 1920
        bpy.context.scene.render.resolution_y = 560
        cam = camera(10.5, lens=30)
        cam.location = (0, -21.0, 3.0)
        cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 34
        bpy.context.scene.render.filepath = str(IMG / "star_themes.png")
        bpy.ops.render.render(write_still=True)
    print("STAR_REPORT", json.dumps(report))


main()
