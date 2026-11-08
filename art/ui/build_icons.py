"""Ikony HUD Crack a Stars (T13) — proceduralnie, kreskówkowo, z czarnym obrysem (inverted hull).

Uruchom:
  E:\\blender\\blender.exe -b --factory-startup -P art/ui/build_icons.py -- [--only coin,star]

Wynik:  art/ui/icons/<nazwa>.png (512×512, przezroczyste tło) — do uploadu jako Decal/Image,
        vault/_img/T13 ikony.png (podgląd wszystkich na ciemnym tle),
        art/ui/icons.blend.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "ui" / "icons"
IMG = ROOT / "vault" / "_img"

# Kolory jak w makiecie (Theme.luau ma te same wartości).
C = {
    "gold": "#FFC83D", "gold_dk": "#C98A12", "gold_lt": "#FFF3C4",
    "star": "#FFD84D", "cyan": "#3DF2FF", "cyan_lt": "#E6FDFF",
    "orange": "#FF8A1E", "cream": "#FFF1D6", "violet": "#8A4CFF", "lilac": "#F6EEFF",
    "blue": "#2A9BEF", "paper": "#F4F8FF", "teal": "#1FD9A8", "teal_dk": "#0A7A62",
    "dark": "#2A2340", "magenta": "#FF3DCB",
}
OUTLINE = 0.085


def hex_lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


_mats = {}


def mat(key, rough=0.35, emit=0.3):
    k = (key, rough, emit)
    if k in _mats:
        return _mats[k]
    m = bpy.data.materials.new(f"M_{key}")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*hex_lin(C[key]), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Specular IOR Level"].default_value = 0.8
    b.inputs["Coat Weight"].default_value = 0.6
    b.inputs["Coat Roughness"].default_value = 0.08
    if emit:
        b.inputs["Emission Color"].default_value = (*hex_lin(C[key]), 1)
        b.inputs["Emission Strength"].default_value = emit
    _mats[k] = m
    return m


def outline_mat():
    if "Outline" in bpy.data.materials:
        return bpy.data.materials["Outline"]
    m = bpy.data.materials.new("Outline")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0.004, 0.002, 0.008, 1)
    b.inputs["Roughness"].default_value = 1.0
    b.inputs["Specular IOR Level"].default_value = 0.0
    m.use_backface_culling = True
    return m


def obj(name, bm, coll, material, bevel=0.0, smooth=False, outline=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    me.materials.append(material)
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    if bevel:
        bv = ob.modifiers.new("Bevel", "BEVEL")
        bv.width, bv.segments, bv.limit_method = bevel, 2, "ANGLE"
    if outline:
        me.materials.append(outline_mat())
        so = ob.modifiers.new("Outline", "SOLIDIFY")
        so.thickness, so.offset, so.use_flip_normals = OUTLINE, 1.0, True
        so.material_offset = 1
        so.use_rim = False
    return ob


def star_pts(r_out, r_in, n=5, rot=math.pi / 2):
    return [((r_out if i % 2 == 0 else r_in) * math.cos(rot + i * math.pi / n),
             (r_out if i % 2 == 0 else r_in) * math.sin(rot + i * math.pi / n)) for i in range(2 * n)]


def chunky_star(r_out=1.0, r_in=0.46, puff=0.38, z0=0.0):
    """Gwiazda „poduszka”: obwód + środek wypchnięty z obu stron."""
    bm = bmesh.new()
    ring = [bm.verts.new((x, y, z0)) for x, y in star_pts(r_out, r_in)]
    top = bm.verts.new((0, 0, z0 + puff))
    bot = bm.verts.new((0, 0, z0 - puff))
    n = len(ring)
    for i in range(n):
        a, b = ring[i], ring[(i + 1) % n]
        bm.faces.new((a, b, top))
        bm.faces.new((b, a, bot))
    return bm


def prism(pts, depth, z0=0.0):
    bm = bmesh.new()
    f = bm.faces.new([bm.verts.new((x, y, z0)) for x, y in pts])
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    bmesh.ops.translate(bm, vec=(0, 0, depth), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def cyl(r1, r2, depth, seg=40, m=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth,
                          matrix=m or Matrix())
    return bm


def torus(R, r, seg=32, ring=12, half=False):
    """Torus w płaszczyźnie XY; half=True — tylko górny łuk (uchwyt torby)."""
    bm = bmesh.new()
    n = seg // 2 + 1 if half else seg
    rows = []
    for i in range(n):
        a = math.pi * i / (n - 1) if half else 2 * math.pi * i / seg
        cx, cy = R * math.cos(a), R * math.sin(a)
        row = []
        for j in range(ring):
            b = 2 * math.pi * j / ring
            d = R + r * math.cos(b)
            row.append(bm.verts.new((d * math.cos(a), d * math.sin(a), r * math.sin(b))))
        del cx, cy
        rows.append(row)
    for i in range(n - (1 if half else 0)):
        a, b2 = rows[i], rows[(i + 1) % n]
        for j in range(ring):
            k = (j + 1) % ring
            bm.faces.new((a[j], b2[j], b2[k], a[k]))
    if half:
        bm.faces.new(rows[0][::-1])
        bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def box(sx, sy, sz, loc=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(loc) @ Matrix.Diagonal((sx, sy, sz, 1)))
    return bm


def group(coll, parts, rot_deg, loc=(0, 0, 0)):
    """Rodzic (empty) z obrotem 3/4 dla całej ikony."""
    e = bpy.data.objects.new(coll.name + "_Root", None)
    coll.objects.link(e)
    for p in parts:
        p.parent = e
    e.rotation_euler = [math.radians(a) for a in rot_deg]
    e.location = loc
    return e


# ------------------------------------------------------------------ ikony (płaskie w XY, przód = +Z)

def icon_coin(c):
    body = obj("Coin_Body", cyl(1.0, 1.0, 0.32, 48), c, mat("gold", 0.25, 0.65), bevel=0.06, smooth=True)
    rim = obj("Coin_Rim", cyl(0.8, 0.8, 0.36, 48), c, mat("star", 0.3, 0.7), smooth=True, outline=False)
    st = obj("Coin_Star", chunky_star(0.55, 0.25, 0.12, 0.2), c, mat("gold_lt", 0.2, 0.6))
    group(c, [body, rim, st], (75, 0, -18))


def icon_star(c):
    s = obj("Star_Body", chunky_star(1.0, 0.46, 0.42), c, mat("star", 0.25, 0.7))
    g = obj("Star_Glint", chunky_star(0.22, 0.1, 0.05, 0.36), c, mat("cyan_lt", 0.1, 0.5), outline=False)
    g.location = (-0.22, 0.28, 0)
    group(c, [s, g], (72, 0, 12))


def icon_fuel(c):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=20, radius=0.75)
    for v in bm.verts:  # łezka: górna połowa zwęża się do czubka
        if v.co.z > 0:
            t = v.co.z / 0.75
            k = (1 - t) ** 1.6
            v.co.x *= k
            v.co.y *= k
            v.co.z = v.co.z * 1.9
    drop = obj("Fuel_Drop", bm, c, mat("cyan", 0.15, 0.25), smooth=True)
    drop.location = (0, 0, -0.35)
    hl = obj("Fuel_Hi", cyl(0.12, 0.12, 0.05, 16), c, mat("cyan_lt", 0.1, 1.0), outline=False)
    hl.location, hl.rotation_euler = (-0.3, -0.62, -0.25), (math.radians(90), 0, 0)
    group(c, [drop, hl], (0, 0, 0))


def icon_shop(c):
    bag = bmesh.new()
    bmesh.ops.create_cone(bag, cap_ends=True, cap_tris=False, segments=4, radius1=0.82, radius2=1.0, depth=1.3,
                          matrix=Matrix.Rotation(math.pi / 4, 4, "Z"))
    for v in bag.verts:
        v.co.y *= 0.55
    b = obj("Shop_Bag", bag, c, mat("orange", 0.4), bevel=0.06)
    b.location = (0, 0, -0.25)
    hd = obj("Shop_Handle", torus(0.4, 0.09, half=True), c, mat("cream", 0.4), smooth=True)
    hd.location, hd.rotation_euler = (0, 0, 0.38), (math.radians(90), 0, 0)
    tag = obj("Shop_Star", chunky_star(0.32, 0.15, 0.08), c, mat("star", 0.25))
    tag.location, tag.rotation_euler = (0, -0.6, -0.2), (math.radians(90), 0, 0)
    group(c, [b, hd, tag], (0, 0, -20), (0, 0, 0))


def icon_base(c):
    walls = obj("Base_Walls", box(1.4, 1.1, 1.0, (0, 0, -0.45)), c, mat("lilac", 0.45), bevel=0.05)
    roof = bmesh.new()
    pts = [(-0.95, -0.05), (0.95, -0.05), (0, 0.85)]
    f = roof.faces.new([roof.verts.new((x, -0.7, z)) for x, z in pts])
    ext = bmesh.ops.extrude_face_region(roof, geom=[f])
    bmesh.ops.translate(roof, vec=(0, 1.4, 0), verts=[v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(roof, faces=roof.faces)
    r = obj("Base_Roof", roof, c, mat("violet", 0.35), bevel=0.05)
    door = obj("Base_Door", box(0.38, 0.1, 0.6, (0, -0.56, -0.65)), c, mat("dark", 0.5))
    win = obj("Base_Window", box(0.3, 0.1, 0.3, (0.45, -0.56, -0.3)), c, mat("cyan", 0.1, 0.8))
    group(c, [walls, r, door, win], (8, 0, -24), (0, 0, 0.05))


def icon_index(c):
    cover = obj("Index_Cover", box(1.5, 1.85, 0.3), c, mat("blue", 0.35), bevel=0.06)
    pages = obj("Index_Pages", box(1.38, 1.75, 0.22, (0.1, 0, 0)), c, mat("paper", 0.6), outline=False)
    st = obj("Index_Star", chunky_star(0.5, 0.23, 0.12, 0.16), c, mat("star", 0.25, 0.1))
    group(c, [cover, pages, st], (72, -6, 16))


def icon_rides(c):
    body = obj("Rides_Body", box(1.9, 1.0, 0.55, (0, 0, -0.2)), c, mat("teal", 0.35), bevel=0.12)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=0.5)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01], context="VERTS")
    dome = obj("Rides_Dome", bm, c, mat("cyan", 0.05, 0.4), smooth=True)
    dome.location = (-0.15, 0, 0.05)
    parts = [body, dome]
    for i, (x, y) in enumerate(((-0.62, -0.55), (0.62, -0.55), (-0.62, 0.55), (0.62, 0.55))):
        w = obj(f"Rides_Wheel{i}", cyl(0.3, 0.3, 0.22, 24, Matrix.Rotation(math.pi / 2, 4, "X")), c,
                mat("dark", 0.6), bevel=0.04, smooth=True)
        w.location = (x, y, -0.5)
        parts.append(w)
    ant = obj("Rides_Light", chunky_star(0.18, 0.08, 0.06), c, mat("magenta", 0.2, 1.2))
    ant.location, ant.rotation_euler = (0.6, 0, 0.3), (math.radians(90), 0, 0)
    parts.append(ant)
    group(c, parts, (12, 0, -28))


def icon_premium(c):
    """Klejnot premium (sklep za Robux) — własny symbol, bez logo Robux."""
    bm = bmesh.new()
    seg = 8
    top_r, mid_r = 0.55, 1.0
    top = [bm.verts.new((top_r * math.cos(i * 2 * math.pi / seg), top_r * math.sin(i * 2 * math.pi / seg), 0.38))
           for i in range(seg)]
    mid = [bm.verts.new((mid_r * math.cos((i + 0.5) * 2 * math.pi / seg), mid_r * math.sin((i + 0.5) * 2 * math.pi / seg), 0.05))
           for i in range(seg)]
    tip = bm.verts.new((0, 0, -0.95))
    bm.faces.new(top)
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((top[i], mid[i], top[j]))
        bm.faces.new((top[j], mid[i], mid[j]))
        bm.faces.new((mid[i], tip, mid[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    g = obj("Premium_Gem", bm, c, mat("gold", 0.15, 0.7))
    sp = obj("Premium_Spark", chunky_star(0.22, 0.08, 0.04), c, mat("cyan_lt", 0.1, 1.5), outline=False)
    sp.location, sp.rotation_euler = (0.55, -0.6, 0.35), (math.radians(90), 0, 0)
    group(c, [g, sp], (22, 0, 10))


ICONS = {
    "coin": icon_coin, "star": icon_star, "fuel": icon_fuel, "shop": icon_shop,
    "base": icon_base, "index": icon_index, "rides": icon_rides, "premium": icon_premium,
}


# ------------------------------------------------------------------ scena i render

def setup_scene():
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    w = bpy.data.worlds.new("Flat")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.33, 0.45, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.3
    sc.world = w
    for name, energy, loc, col in (("Key", 2200, (5, -9, 8), (1, 0.97, 0.92)),
                                   ("Fill", 350, (-8, -7, 1), (0.75, 0.8, 1.0)),
                                   ("RimCyan", 1500, (-7, 7, 4), (0.3, 0.95, 1.0)),
                                   ("RimMagenta", 1500, (7, 7, 4), (1.0, 0.3, 0.85))):
        li = bpy.data.lights.new(name, "AREA")
        li.energy, li.size, li.color = energy, 8, col
        ob = bpy.data.objects.new(name, li)
        ob.location = loc
        ob.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(ob)
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    cob = bpy.data.objects.new("Cam", cam)
    sc.collection.objects.link(cob)
    cob.location = (0, -10, 0)
    cob.rotation_euler = (math.radians(90), 0, 0)
    sc.camera = cob
    return cob


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    if "--only" in argv:
        only = set(argv[argv.index("--only") + 1].split(","))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cam = setup_scene()
    OUT.mkdir(parents=True, exist_ok=True)
    colls = {}
    for name, fn in ICONS.items():
        if only and name not in only:
            continue
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
        fn(c)
        colls[name] = c

    sc = bpy.context.scene
    tri_report = {}
    # pojedyncze ikony
    sc.render.resolution_x = sc.render.resolution_y = 512
    cam.data.ortho_scale = 2.9
    for name, c in colls.items():
        for other in colls.values():
            other.hide_render = other is not c
        sc.render.filepath = str(OUT / f"{name}.png")
        bpy.ops.render.render(write_still=True)
        tri_report[name] = sum(len(o.data.polygons) for o in c.objects if o.type == "MESH")

    # podgląd: wszystkie w rzędzie na ciemnym tle
    names = list(colls)
    gap = 2.6
    for i, name in enumerate(names):
        colls[name].hide_render = False
        root = bpy.data.objects[name + "_Root"]
        root.location.x += (i - (len(names) - 1) / 2) * gap
    sc.render.film_transparent = False
    sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.012, 0.05, 1)
    sc.render.resolution_x, sc.render.resolution_y = 300 * len(names), 340
    cam.data.ortho_scale = gap * len(names)
    sc.render.filepath = str(IMG / "T13 ikony.png")
    bpy.ops.render.render(write_still=True)

    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art" / "ui" / "icons.blend"))
    print("ICONS_OK", tri_report)


if __name__ == "__main__":
    main()
