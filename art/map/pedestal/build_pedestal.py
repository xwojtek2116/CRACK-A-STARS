"""build_pedestal.py — postument bazy Crack a Stars i kryształ-placeholder przedmiotu (Blender 5.x, tryb w tle).

Uruchom:
  E:\\blender\\blender.exe -b --factory-startup -P art/map/pedestal/build_pedestal.py -- [--render]

Postument (sci-fi, oktagonalny cokół → zwężana kolumna → misa z rantem i 4 szponami trzymającymi przedmiot).
Części = osobne meshe (gra nadaje materiał/kolor, BaseService):
  Pedestal_Shell  — bryła (ciemny kamień/metal)
  Pedestal_Ring   — świecące elementy: pas na kolumnie, rant cokołu, płyta pod przedmiotem (Neon, kolor rzadkości)
  Pedestal_Accent — szpony i obręcze (metal)
  Placeholder_Crystal — kryształ zastępujący model łupu do czasu T21–T23 (kolor motywu)

Jednostki = studs (średnica cokołu 6,4, wierzch płyty 4,1); import w Studio skaluje do tych wymiarów.
Wyjście: art/map/pedestal/pedestal.fbx, pedestal.blend, z --render: vault/_img/T08 postument.png
"""

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[3]
DATA = ROOT / "game" / "src" / "shared" / "Config" / "Data"
OUT = Path(__file__).resolve().parent
IMG = ROOT / "vault" / "_img"

RARITIES = json.loads((DATA / "Rarities.json").read_text(encoding="utf-8"))
THEMES = json.loads((DATA / "Themes.json").read_text(encoding="utf-8"))

TOP = 4.1  # wierzch płyty (ItemPoint)
BUDGET = {"Pedestal": 1500, "Placeholder": 400}


def hex_rgb(h):
    h = h.lstrip("#")
    c = tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def cone(bm, segments, r_bottom, r_top, z0, z1, rot=0.0, matrix=None):
    """Graniastosłup/stożek ścięty od z0 do z1 (oś Z), obrócony o rot wokół Z."""
    m = Matrix.Translation((0, 0, (z0 + z1) / 2)) @ Matrix.Rotation(rot, 4, "Z")
    if matrix is not None:
        m = matrix @ m
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=r_bottom,
                          radius2=r_top, depth=z1 - z0, matrix=m)


def mesh_obj(name, bm, smooth=False):
    me = bpy.data.meshes.new(name)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = smooth
    return ob


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def build_pedestal():
    eighth = math.pi / 8
    # Bryła: dwa stopnie oktagonalnego cokołu, zwężana kolumna, misa i rant.
    bm = bmesh.new()
    cone(bm, 8, 3.2, 3.05, 0.0, 0.55, eighth)
    cone(bm, 8, 2.75, 2.55, 0.55, 1.05, eighth)
    cone(bm, 8, 1.75, 1.35, 1.05, 3.05, eighth)
    cone(bm, 8, 1.55, 1.55, 3.3, 3.45, eighth)
    cone(bm, 16, 1.6, 2.65, 3.45, 3.85)
    cone(bm, 16, 2.75, 2.7, 3.85, 4.0)
    shell = mesh_obj("Pedestal_Shell", bm)

    # Świecące: pas na kolumnie, rant cokołu, płyta pod przedmiotem, 8 pionowych żyłek kolumny.
    bm = bmesh.new()
    cone(bm, 8, 1.42, 1.38, 3.05, 3.3, eighth)
    cone(bm, 8, 3.12, 3.1, 0.42, 0.5, eighth)
    cone(bm, 16, 2.2, 2.2, 4.0, 4.1)
    for i in range(8):
        a = i * math.pi / 4
        # Żyłka na ścianie kolumny: cienki prostopadłościan pochylony jak ściana (r 1.75 → 1.35).
        mid_r = 1.55 * math.cos(eighth) + 0.02
        tilt = math.atan2(1.75 - 1.35, 2.0)
        m = (Matrix.Rotation(a, 4, "Z") @ Matrix.Translation((mid_r, 0, 2.05)) @ Matrix.Rotation(tilt, 4, "Y")
             @ Matrix.Diagonal((0.06, 0.16, 1.7, 1.0)))
        bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    ring = mesh_obj("Pedestal_Ring", bm)

    # Detale: 4 szpony na rancie (pochylone na zewnątrz, czubki do środka) i obręcz pod misą.
    bm = bmesh.new()
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        base = Matrix.Rotation(a, 4, "Z") @ Matrix.Translation((2.45, 0, 3.95))
        lean = Matrix.Rotation(math.radians(-18), 4, "Y")
        cone(bm, 4, 0.32, 0.12, 0.0, 0.95, math.pi / 4, matrix=base @ lean)
        tip = base @ lean @ Matrix.Translation((0, 0, 0.95)) @ Matrix.Rotation(math.radians(-55), 4, "Y")
        cone(bm, 4, 0.12, 0.03, 0.0, 0.45, math.pi / 4, matrix=tip)
    cone(bm, 16, 1.7, 1.7, 3.2, 3.32)
    accent = mesh_obj("Pedestal_Accent", bm)
    return [shell, ring, accent]


def build_placeholder():
    """Kępa kryształów: duży heksagonalny bipiramidowy + dwa mniejsze pochylone. Środek w (0,0,0), wys. ~3."""
    bm = bmesh.new()

    def crystal(radius, height, tip, matrix):
        cone(bm, 6, radius, radius, -height / 2, height / 2, matrix=matrix)
        cone(bm, 6, radius, 0.0, height / 2, height / 2 + tip, matrix=matrix)
        cone(bm, 6, 0.0, radius, -height / 2 - tip * 0.6, -height / 2, matrix=matrix)

    crystal(0.55, 1.4, 0.75, Matrix.Translation((0, 0, 0.1)))
    crystal(0.3, 0.7, 0.4, Matrix.Translation((0.55, 0.15, -0.55)) @ Matrix.Rotation(math.radians(32), 4, "Y"))
    crystal(0.26, 0.6, 0.35, Matrix.Translation((-0.45, -0.3, -0.6)) @ Matrix.Rotation(math.radians(-28), 4, "X"))
    return mesh_obj("Placeholder_Crystal", bm)


def export_fbx(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True,
                             axis_forward="-Z", axis_up="Y", add_leaf_bones=False, mesh_smooth_type="FACE")


# ---------------------------------------------------------------- render

def mat(name, color, emission=0.0, metallic=0.0, rough=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metallic
    b.inputs["Roughness"].default_value = rough
    if emission > 0:
        b.inputs["Base Color"].default_value = (0, 0, 0, 1)
        b.inputs["Emission Color"].default_value = (*color, 1)
        b.inputs["Emission Strength"].default_value = emission
    return m


def setup_render(w, h):
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Space")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.01, 0.008, 0.03, 1)
    sc.world = world
    ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
    ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    rl = ng.nodes.new("CompositorNodeRLayers")
    gl = ng.nodes.new("CompositorNodeGlare")
    out = ng.nodes.new("NodeGroupOutput")
    for key, val in (("Type", "Bloom"), ("Threshold", 0.6), ("Strength", 1.4), ("Size", 7), ("Quality", "High")):
        try:
            gl.inputs[key].default_value = val
        except (TypeError, KeyError, AttributeError):
            pass
    ng.links.new(rl.outputs["Image"], gl.inputs["Image"])
    ng.links.new(gl.outputs[0], out.inputs[0])
    sc.compositing_node_group = ng
    for name, energy, loc, col in (("Key", 9000, (14, -26, 22), (1, 0.97, 0.92)),
                                   ("Fill", 2500, (-24, -18, 8), (0.7, 0.75, 1.0)),
                                   ("Rim", 9000, (-6, 26, 16), (0.6, 0.45, 1.0))):
        li = bpy.data.lights.new(name, "AREA")
        li.energy, li.size, li.color = energy, 18, col
        ob = bpy.data.objects.new(name, li)
        ob.location = loc
        ob.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(ob)
    floor = bpy.data.meshes.new("Floor")
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=80)
    bm.to_mesh(floor)
    fo = bpy.data.objects.new("Floor", floor)
    fo.data.materials.append(mat("FloorMat", hex_rgb("#1A1530"), rough=0.8))
    sc.collection.objects.link(fo)


def render(parts, crystal):
    show = [("Common", "Iron"), ("Rare", "Frost"), ("Epic", "Nebula"), ("Legendary", "Lava"), (None, None)]
    shell_m = mat("Shell", hex_rgb("#2A2440"), metallic=0.3, rough=0.55)
    accent_m = mat("Accent", hex_rgb("#6A6390"), metallic=0.9, rough=0.3)
    holo_m = mat("Holo", hex_rgb("#3DF2FF"), emission=2.0)
    spacing = 8.0
    x0 = -spacing * (len(show) - 1) / 2
    for i, (rarity, theme) in enumerate(show):
        x = x0 + i * spacing
        for p in parts:
            ob = p.copy()
            ob.data = p.data.copy()
            ob.location = (x, 0, 0)
            bpy.context.scene.collection.objects.link(ob)
            if rarity is None:
                ob.data.materials.append(holo_m)
            elif p.name.endswith("Ring"):
                ob.data.materials.append(mat(f"Ring{i}", hex_rgb(RARITIES["tiers"][rarity]["color"]), emission=6.0))
            elif p.name.endswith("Accent"):
                ob.data.materials.append(accent_m)
            else:
                ob.data.materials.append(shell_m)
        if rarity is not None:
            c = crystal.copy()
            c.data = crystal.data.copy()
            c.location = (x, 0, TOP + 2.0)
            c.rotation_euler = (0, 0, math.radians(20 * i))
            col = THEMES["themes"].get(theme, {}).get("color", "#FFFFFF")
            c.data.materials.append(mat(f"Cr{i}", hex_rgb(col), emission=3.0))
            bpy.context.scene.collection.objects.link(c)
    for ob in parts + [crystal]:
        ob.hide_render = True
    setup_render(1920, 720)
    cam = bpy.data.cameras.new("Cam")
    cam.lens = 50
    co = bpy.data.objects.new("Cam", cam)
    bpy.context.scene.collection.objects.link(co)
    co.location = (0, -60, 17)
    co.rotation_euler = (Vector((0, 0, 3.6)) - Vector(co.location)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co
    bpy.context.scene.render.filepath = str(IMG / "T08 postument.png")
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    parts = build_pedestal()
    crystal = build_placeholder()
    report = {
        "Pedestal": sum(tris(p) for p in parts),
        "Placeholder": tris(crystal),
    }
    for k, v in report.items():
        print(f"TRIS {k}: {v} / {BUDGET[k]} {'ok' if v <= BUDGET[k] else 'ZA DUZO'}")
    export_fbx(OUT / "pedestal.fbx", parts + [crystal])
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "pedestal.blend"))
    if "--render" in argv:
        render(parts, crystal)
    print("DONE", json.dumps(report))


main()
