"""Rendery narzędzi do kart sklepu (T13 poprawki) — 8 narzędzi z Tools.json, kreskówkowo, z obrysem.

Uruchom:
  E:\\blender\\blender.exe -b --factory-startup -P art/ui/build_tool_icons.py -- [--only stone_pickaxe,laser_sword]

Wynik: art/ui/tools/<id>.png (512×512, przezroczyste), vault/_img/T13 narzedzia.png (podgląd).
Pełne modele 3D do ręki robi T11 (art/tools/) — tu tylko obrazki do UI. Pomocnicze funkcje z build_icons.py.
"""

import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_icons as bi  # noqa: E402

ROOT = bi.ROOT
OUT = ROOT / "art" / "ui" / "tools"
TOOLS = json.loads((ROOT / "game" / "src" / "shared" / "Config" / "Data" / "Tools.json").read_text(encoding="utf-8"))

bi.C.update({
    "wood": "#9A5B2E", "wood_dk": "#6A3A1A", "stone": "#8E8A9E", "stone_dk": "#5E5A70",
    "iron": "#A9B4C6", "iron_dk": "#5A6478", "leather": "#4A2A1A", "crystal": "#4FC8FF",
    "violet_dk": "#3A1E6A", "metal_dk": "#2E3348", "plasma": "#3DF2FF", "beam": "#B8FFFF",
    "ring": "#C78BFF", "core": "#FFB23D", "goldx": "#FFC83D", "purple": "#8A3DFF",
})


def handle(c, length, radius, material, z0=-1.3, grip=None):
    parts = [bi.obj(f"{c.name}_Handle", bi.cyl(radius, radius, length, 16, Matrix.Translation((0, 0, z0 + length / 2))), c,
                    material, bevel=0.02, smooth=True)]
    if grip:
        parts.append(bi.obj(f"{c.name}_Grip", bi.cyl(radius * 1.25, radius * 1.25, length * 0.3, 16,
                                                     Matrix.Translation((0, 0, z0 + length * 0.18))), c, grip, smooth=True))
    return parts


def pickaxe(c):
    parts = handle(c, 2.4, 0.09, bi.mat("wood"))
    bm = bmesh.new()
    for sign in (-1, 1):  # dwa zakrzywione szpikulce z kamienia
        bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.2, radius2=0.03, depth=0.95,
                              matrix=Matrix.Translation((sign * 0.5, 0, 1.0)) @ Matrix.Rotation(sign * math.radians(-100), 4, "Y"))
    parts.append(bi.obj(f"{c.name}_Head", bm, c, bi.mat("stone", 0.7), bevel=0.03))
    parts.append(bi.obj(f"{c.name}_Core", bi.box(0.42, 0.36, 0.42, (0, 0, 1.0)), c, bi.mat("stone_dk", 0.8), bevel=0.06))
    return parts


def hammer(c):
    parts = handle(c, 2.3, 0.09, bi.mat("wood_dk"), grip=bi.mat("leather", 0.8))
    parts.append(bi.obj(f"{c.name}_Head", bi.box(1.15, 0.55, 0.6, (0, 0, 1.05)), c, bi.mat("iron", 0.3), bevel=0.08))
    for x in (-0.35, 0, 0.35):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.06)
        bmesh.ops.translate(bm, vec=(x, -0.29, 1.05), verts=bm.verts)
        parts.append(bi.obj(f"{c.name}_Rivet{x}", bm, c, bi.mat("iron_dk", 0.3), smooth=True, outline=False))
    return parts


def axe_blade(name, c, material, rim_material, scale=1.0, double=False):
    out = []
    sides = (-1, 1) if double else (1,)
    for sign in sides:
        pts = [(0.05, 0.7), (0.95, 1.15), (1.15, 0.65), (0.95, 0.1), (0.05, 0.45)]
        pts = [(sign * x * scale, (z - 0.6) * scale + 1.0) for x, z in pts]
        bm = bmesh.new()
        f = bm.faces.new([bm.verts.new((x, -0.08, z)) for x, z in pts])
        ext = bmesh.ops.extrude_face_region(bm, geom=[f])
        bmesh.ops.translate(bm, vec=(0, 0.16, 0), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        out.append(bi.obj(f"{name}_Blade{sign}", bm, c, material, bevel=0.03))
        edge = bmesh.new()
        e_pts = [(sign * 0.95 * scale, (1.15 - 0.6) * scale + 1.0), (sign * 1.15 * scale, (0.65 - 0.6) * scale + 1.0),
                 (sign * 0.95 * scale, (0.1 - 0.6) * scale + 1.0)]
        for (x1, z1), (x2, z2) in zip(e_pts, e_pts[1:]):
            length = math.hypot(x2 - x1, z2 - z1)
            ang = math.atan2(x2 - x1, z2 - z1)
            bmesh.ops.create_cone(edge, cap_ends=True, segments=8, radius1=0.05, radius2=0.05, depth=length,
                                  matrix=Matrix.Translation(((x1 + x2) / 2, 0, (z1 + z2) / 2)) @ Matrix.Rotation(ang, 4, "Y"))
        out.append(bi.obj(f"{name}_Edge{sign}", edge, c, rim_material, smooth=True, outline=False))
    return out


def crystal_axe(c):
    parts = handle(c, 2.4, 0.085, bi.mat("violet_dk", 0.4), grip=bi.mat("metal_dk"))
    parts += axe_blade(c.name, c, bi.mat("crystal", 0.05, 0.6), bi.mat("beam", 0.1, 3.0))
    return parts


def plasma_saw(c):
    parts = handle(c, 1.2, 0.1, bi.mat("metal_dk"), z0=-1.4, grip=bi.mat("leather"))
    parts.append(bi.obj(f"{c.name}_Body", bi.box(0.5, 0.5, 0.9, (0, 0, -0.35)), c, bi.mat("iron_dk", 0.35), bevel=0.08))
    rot = Matrix.Translation((0, 0, 0.55)) @ Matrix.Rotation(math.pi / 2, 4, "X")
    parts.append(bi.obj(f"{c.name}_Disc", bi.cyl(0.85, 0.85, 0.08, 40, rot), c, bi.mat("iron", 0.2), smooth=True))
    parts.append(bi.obj(f"{c.name}_Hub", bi.cyl(0.25, 0.25, 0.16, 20, rot), c, bi.mat("metal_dk"), smooth=True))
    ring = bi.torus(0.92, 0.06, 40, 8)
    bmesh.ops.transform(ring, matrix=rot @ Matrix.Rotation(-math.pi / 2, 4, "X") @ Matrix.Rotation(math.pi / 2, 4, "X"),
                        verts=ring.verts)
    parts.append(bi.obj(f"{c.name}_Plasma", ring, c, bi.mat("plasma", 0.1, 4.0), smooth=True, outline=False))
    return parts


def laser_sword(c):
    parts = handle(c, 0.9, 0.11, bi.mat("iron", 0.25), z0=-1.5, grip=bi.mat("metal_dk"))
    parts.append(bi.obj(f"{c.name}_Guard", bi.box(0.7, 0.24, 0.16, (0, 0, -0.55)), c, bi.mat("metal_dk", 0.3), bevel=0.05))
    parts.append(bi.obj(f"{c.name}_Beam", bi.cyl(0.13, 0.09, 2.2, 20, Matrix.Translation((0, 0, 0.6))), c,
                        bi.mat("beam", 0.05, 5.0), smooth=True))
    parts.append(bi.obj(f"{c.name}_Glow", bi.cyl(0.2, 0.14, 2.25, 20, Matrix.Translation((0, 0, 0.6))), c,
                        bi.mat("plasma", 0.1, 1.5), smooth=True, outline=False))
    bpy.data.objects[f"{c.name}_Glow"].data.materials[0] = glass_glow()
    return parts


def glass_glow():
    if "GlowShell" in bpy.data.materials:
        return bpy.data.materials["GlowShell"]
    m = bpy.data.materials.new("GlowShell")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0, 0, 0, 1)
    b.inputs["Emission Color"].default_value = (*bi.hex_lin(bi.C["plasma"]), 1)
    b.inputs["Emission Strength"].default_value = 2.0
    b.inputs["Alpha"].default_value = 0.35
    m.surface_render_method = "BLENDED"
    return m


def gravity_hammer(c):
    parts = handle(c, 2.3, 0.1, bi.mat("metal_dk", 0.35), grip=bi.mat("violet_dk"))
    parts.append(bi.obj(f"{c.name}_Head", bi.box(1.3, 0.75, 0.8, (0, 0, 1.0)), c, bi.mat("purple", 0.3), bevel=0.12))
    parts.append(bi.obj(f"{c.name}_Core", bi.box(0.4, 0.8, 0.4, (0, 0, 1.0)), c, bi.mat("ring", 0.1, 2.5), bevel=0.05,
                        outline=False))
    for i, (tilt, r) in enumerate(((25, 1.05), (-35, 1.2))):
        ring = bi.torus(r, 0.045, 40, 8)
        bmesh.ops.transform(ring, matrix=Matrix.Translation((0, 0, 1.0)) @ Matrix.Rotation(math.radians(tilt), 4, "X")
                            @ Matrix.Rotation(math.radians(70), 4, "Y"), verts=ring.verts)
        parts.append(bi.obj(f"{c.name}_Ring{i}", ring, c, bi.mat("ring", 0.1, 3.0), smooth=True, outline=False))
    return parts


def nova_cannon(c):
    parts = []
    rot = Matrix.Rotation(math.radians(90), 4, "Y")
    parts.append(bi.obj(f"{c.name}_Barrel", bi.cyl(0.42, 0.34, 2.3, 28, Matrix.Translation((0.2, 0, 0.2)) @ rot), c,
                        bi.mat("metal_dk", 0.3), bevel=0.04, smooth=True))
    parts.append(bi.obj(f"{c.name}_Muzzle", bi.cyl(0.5, 0.5, 0.25, 28, Matrix.Translation((1.35, 0, 0.2)) @ rot), c,
                        bi.mat("goldx", 0.2), smooth=True))
    parts.append(bi.obj(f"{c.name}_Glowtip", bi.cyl(0.3, 0.3, 0.27, 28, Matrix.Translation((1.36, 0, 0.2)) @ rot), c,
                        bi.mat("core", 0.1, 4.0), smooth=True, outline=False))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=0.48)
    bmesh.ops.translate(bm, vec=(-0.55, 0, 0.25), verts=bm.verts)
    parts.append(bi.obj(f"{c.name}_Chamber", bm, c, bi.mat("core", 0.1, 3.0), smooth=True))
    parts.append(bi.obj(f"{c.name}_Grip", bi.box(0.25, 0.3, 0.7, (-0.1, 0, -0.45)), c, bi.mat("leather"), bevel=0.05))
    st = bi.obj(f"{c.name}_Star", bi.chunky_star(0.22, 0.1, 0.06), c, bi.mat("goldx", 0.2, 0.5))
    st.location, st.rotation_euler = (-0.55, -0.5, 0.25), (math.radians(90), 0, 0)
    parts.append(st)
    return parts


def starbreaker(c):
    parts = handle(c, 2.6, 0.1, bi.mat("goldx", 0.2), z0=-1.45, grip=bi.mat("violet_dk"))
    parts += axe_blade(c.name, c, bi.mat("purple", 0.2, 0.3), bi.mat("goldx", 0.1, 1.5), scale=1.1, double=True)
    st = bi.obj(f"{c.name}_Star", bi.chunky_star(0.32, 0.14, 0.12), c, bi.mat("core", 0.1, 3.0))
    st.location, st.rotation_euler = (0, -0.12, 1.0), (math.radians(90), 0, 0)
    parts.append(st)
    tip = bmesh.new()
    bmesh.ops.create_cone(tip, cap_ends=True, segments=6, radius1=0.12, radius2=0.0, depth=0.5,
                          matrix=Matrix.Translation((0, 0, 1.45)))
    parts.append(bi.obj(f"{c.name}_Tip", tip, c, bi.mat("goldx", 0.2)))
    return parts


BUILDERS = {
    "stone_pickaxe": (pickaxe, (0, -40, -10)),
    "iron_hammer": (hammer, (0, -40, -10)),
    "crystal_axe": (crystal_axe, (0, -35, -12)),
    "plasma_saw": (plasma_saw, (0, -30, -8)),
    "laser_sword": (laser_sword, (0, -42, -6)),
    "gravity_hammer": (gravity_hammer, (0, -38, -12)),
    "nova_cannon": (nova_cannon, (0, 20, -20)),
    "starbreaker": (starbreaker, (0, -38, -12)),
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cam = bi.setup_scene()
    OUT.mkdir(parents=True, exist_ok=True)
    colls = {}
    for tid in TOOLS["order"]:
        if only and tid not in only:
            continue
        fn, rot = BUILDERS[tid]
        c = bpy.data.collections.new(tid)
        bpy.context.scene.collection.children.link(c)
        parts = fn(c)
        bi.group(c, parts, rot)
        colls[tid] = c

    sc = bpy.context.scene
    sc.render.resolution_x = sc.render.resolution_y = 512
    cam.data.ortho_scale = 3.6
    for tid, c in colls.items():
        for other in colls.values():
            other.hide_render = other is not c
        sc.render.filepath = str(OUT / f"{tid}.png")
        bpy.ops.render.render(write_still=True)

    names = list(colls)
    gap = 3.2
    for i, tid in enumerate(names):
        colls[tid].hide_render = False
        bpy.data.objects[tid + "_Root"].location.x += (i - (len(names) - 1) / 2) * gap
    sc.render.film_transparent = False
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.012, 0.05, 1)
    sc.render.resolution_x, sc.render.resolution_y = 280 * len(names), 380
    cam.data.ortho_scale = gap * len(names)
    sc.render.filepath = str(bi.IMG / "T13 narzedzia.png")
    bpy.ops.render.render(write_still=True)
    print("TOOLS_OK", names)


main()
