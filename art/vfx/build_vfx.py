"""build_vfx.py — meshe VFX spadku gwiazdy (T38), Blender 5.x w tle.

Uruchom:
  E:\\blender\\blender.exe -b --factory-startup -P art/vfx/build_vfx.py -- [--render]

Obiekty (jeden FBX, wszystko w środku układu; kolor/materiał nadaje gra):
  Rift_Edge   — poszarpana krawędź rozdarcia nieba (Neon w kolorze glow), wąski kształt „oka” z kolcami
  Rift_Core   — wnętrze rozdarcia: wklęsła misa (głębia w niebo), UV planarne pod mgławicę
  Shard_1..6  — odłamki nieba odpadające przy otwarciu (cienkie, nieregularne)
  Rock_1..4   — skały-odłamki (wał krateru i lecące odłamki)

Układ: rozdarcie leży w płaszczyźnie XZ Blendera i patrzy w −Y. Po imporcie FBX (Blender (x, y, z) → Roblox (−x, z, y))
front = LookVector części, szerokość = X, wysokość = Y. Promień rozdarcia ≈ 1 (skalę ustawia gra).

Wyjście: art/vfx/vfx_meshes.fbx, art/vfx/vfx_meshes.blend, vault/_img/T38 assety.png (z --render)
"""

import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "vfx"
IMG = ROOT / "vault" / "_img"
SEED = 38

RIFT_POINTS = 96  # wierzchołki obrysu rozdarcia
RIFT_HALF_HEIGHT = 0.32  # połowa wysokości „oka” względem połowy szerokości (1.0)
RIFT_DEPTH = 0.55  # głębia misy wnętrza (w −Y, czyli w głąb nieba)
TRIS_BUDGET = {"Rift_Edge": 3000, "Rift_Core": 2500, "Shard": 120, "Rock": 400}


# ---------------------------------------------------------------- narzędzia

def mesh_obj(name, bm, coll, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    coll.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = smooth
    return ob


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def rift_outline(rng):
    """Obrys „oka” z ostrymi końcami i poszarpaniem. Zwraca listę (x, z, normalna_xz)."""
    pts = []
    for i in range(RIFT_POINTS):
        t = i / RIFT_POINTS * 2 * math.pi
        x = math.cos(t)
        z = RIFT_HALF_HEIGHT * math.sin(t) * (1 - abs(x) ** 3) ** 0.6
        # poszarpanie: mocniejsze przy środku, słabsze przy czubkach
        jag = (1 - abs(x) ** 2) * RIFT_HALF_HEIGHT * rng.uniform(-0.22, 0.22)
        if i % 3 == 0:
            jag += (1 - abs(x) ** 2) * RIFT_HALF_HEIGHT * rng.uniform(0.0, 0.35)
        pts.append([x, z + math.copysign(jag, z) if abs(z) > 1e-4 else z])
    out = []
    n = len(pts)
    for i in range(n):
        a, b = pts[i - 1], pts[(i + 1) % n]
        tx, tz = b[0] - a[0], b[1] - a[1]
        length = math.hypot(tx, tz) or 1
        nx, nz = tz / length, -tx / length  # na zewnątrz (obrys jest przeciwnie do zegara)
        out.append((pts[i][0], pts[i][1], nx, nz))
    return out


def build_rift(coll, rng):
    outline = rift_outline(rng)
    n = len(outline)

    # Krawędź: wstęga od obrysu na zewnątrz, z kolcami (poszarpane niebo), z grubością w głąb (−Y).
    bm = bmesh.new()
    inner_f, outer_f, inner_b, outer_b = [], [], [], []
    for i, (x, z, nx, nz) in enumerate(outline):
        mid = 1 - abs(x) ** 2
        width = 0.03 + 0.05 * mid + (rng.uniform(0.06, 0.2) * mid if i % 4 == 0 else rng.uniform(0.0, 0.04))
        ox, oz = x + nx * width, z + nz * width
        inner_f.append(bm.verts.new((x, 0.0, z)))
        outer_f.append(bm.verts.new((ox, 0.02, oz)))
        inner_b.append(bm.verts.new((x, 0.12, z)))
        outer_b.append(bm.verts.new((ox, 0.1, oz)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((inner_f[i], inner_f[j], outer_f[j], outer_f[i]))  # front
        bm.faces.new((outer_b[i], outer_b[j], inner_b[j], inner_b[i]))  # tył
        bm.faces.new((outer_f[i], outer_f[j], outer_b[j], outer_b[i]))  # brzeg zewnętrzny
        bm.faces.new((inner_b[i], inner_b[j], inner_f[j], inner_f[i]))  # brzeg wewnętrzny
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    edge = mesh_obj("Rift_Edge", bm, coll)

    # Wnętrze: wachlarz od środka z pierścieniami, wklęsły w głąb nieba; UV planarne (x, z) → (u, v).
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rings = 8
    center = bm.verts.new((0.0, RIFT_DEPTH, 0.0))
    grid = []
    for r in range(1, rings + 1):
        k = r / rings
        row = []
        for x, z, _, _ in outline:
            depth = RIFT_DEPTH * (1 - k * k)
            row.append(bm.verts.new((x * k, depth, z * k)))
        grid.append(row)
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((center, grid[0][j], grid[0][i])))
        for r in range(rings - 1):
            faces.append(bm.faces.new((grid[r][i], grid[r][j], grid[r + 1][j], grid[r + 1][i])))
    for f in faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[uv].uv = (co.x * 0.5 + 0.5, co.z * 0.5 / RIFT_HALF_HEIGHT * 0.35 + 0.5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # normalne do widza (−Y): wnętrze ma być widoczne od frontu
    for f in bm.faces:
        if f.normal.y > 0:
            f.normal_flip()
    core = mesh_obj("Rift_Core", bm, coll, smooth=True)
    return edge, core


def build_shard(coll, rng, index):
    """Odłamek nieba: nieregularny wielokąt 4–6 wierzchołków, lekko wygięty, cienki."""
    bm = bmesh.new()
    count = rng.randint(4, 6)
    angles = sorted(rng.uniform(0, 2 * math.pi) for _ in range(count))
    front, back = [], []
    for a in angles:
        r = rng.uniform(0.5, 1.0)
        x, z = math.cos(a) * r, math.sin(a) * r * rng.uniform(0.4, 0.9)
        bend = (x * x) * 0.12
        front.append(bm.verts.new((x, bend, z)))
        back.append(bm.verts.new((x, bend + 0.05, z)))
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(count):
        j = (i + 1) % count
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(f"Shard_{index}", bm, coll)


def build_rock(coll, rng, index):
    """Skała-odłamek: ikosfera z losowym przemieszczeniem, spłaszczona, ostre ściany."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    squash = (rng.uniform(0.8, 1.2), rng.uniform(0.55, 0.85), rng.uniform(0.8, 1.3))
    for v in bm.verts:
        d = v.co.normalized()
        bump = 1 + rng.uniform(-0.22, 0.22)
        v.co = Vector((d.x * squash[0], d.y * squash[1], d.z * squash[2])) * bump
    # kilka „ściętych” płaszczyzn — skała wygląda na odłupaną
    for _ in range(3):
        n = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))).normalized()
        cut = rng.uniform(0.55, 0.8)
        for v in bm.verts:
            dist = v.co.dot(n)
            if dist > cut:
                v.co -= n * (dist - cut)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(f"Rock_{index}", bm, coll)


def export_fbx(path):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True,
                             axis_forward="-Z", axis_up="Y", add_leaf_bones=False, mesh_smooth_type="FACE")


# ---------------------------------------------------------------- render podglądu

def material(name, rgb, emission=0.0, neon=False, rough=0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (0, 0, 0, 1) if neon else (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    if emission > 0:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emission
    return m


def render(objects):
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.01, 0.008, 0.03, 1)
    sc.world = world
    ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
    ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    rl = ng.nodes.new("CompositorNodeRLayers")
    gl = ng.nodes.new("CompositorNodeGlare")
    out = ng.nodes.new("NodeGroupOutput")
    for key, val in (("Type", "Bloom"), ("Threshold", 0.5), ("Strength", 1.4), ("Size", 8)):
        try:
            gl.inputs[key].default_value = val
        except (TypeError, KeyError, AttributeError):
            pass
    ng.links.new(rl.outputs["Image"], gl.inputs["Image"])
    ng.links.new(gl.outputs[0], out.inputs[0])
    sc.compositing_node_group = ng

    glow = material("Glow", (1.0, 0.45, 0.12), emission=12, neon=True)
    void = material("Void", (0.12, 0.03, 0.25), emission=1.5)
    sky = material("Sky", (0.35, 0.3, 0.9), emission=2.5, neon=True)
    rock = material("Rock", (0.08, 0.07, 0.07), rough=0.9)
    layout = {"Rift_Edge": ((0, 0, 1.6), 2.2, glow), "Rift_Core": ((0, 0, 1.6), 2.2, void)}
    for i in range(1, 7):
        layout[f"Shard_{i}"] = ((-3.3 + (i - 1) * 1.3, 0, -0.4), 0.45, sky)
    for i in range(1, 5):
        layout[f"Rock_{i}"] = ((-2.4 + (i - 1) * 1.6, 0, -1.9), 0.5, rock)
    for ob in objects:
        loc, scale, mat = layout[ob.name]
        ob.location = loc
        ob.scale = (scale, scale, scale)
        ob.data.materials.append(mat)
    key = bpy.data.lights.new("Key", "AREA")
    key.energy, key.size = 1500, 8
    kob = bpy.data.objects.new("Key", key)
    kob.location = (4, -8, 6)
    kob.rotation_euler = (-Vector(kob.location)).to_track_quat("-Z", "Y").to_euler()
    sc.collection.objects.link(kob)
    cam = bpy.data.cameras.new("Cam")
    cam.lens = 35
    cob = bpy.data.objects.new("Cam", cam)
    sc.collection.objects.link(cob)
    cob.location = (0, -9.5, 0.4)
    cob.rotation_euler = (Vector((0, 0, 0.1)) - cob.location).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cob
    IMG.mkdir(parents=True, exist_ok=True)
    sc.render.filepath = str(IMG / "T38 assety.png")
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    rng = random.Random(SEED)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    coll = bpy.context.scene.collection
    objects = list(build_rift(coll, rng))
    objects += [build_shard(coll, rng, i) for i in range(1, 7)]
    objects += [build_rock(coll, rng, i) for i in range(1, 5)]
    report = {}
    for ob in objects:
        kind = ob.name.split("_")[0] if not ob.name.startswith("Rift") else ob.name
        report[ob.name] = {"tris": tris(ob), "ok": tris(ob) <= TRIS_BUDGET[kind]}
    OUT.mkdir(parents=True, exist_ok=True)
    export_fbx(OUT / "vfx_meshes.fbx")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "vfx_meshes.blend"))
    if "--render" in argv:
        render(objects)
    print("VFX_REPORT", report)


# ---------------------------------------------------------------- T39

def build_sky_crack(coll, rng, index):
    """Pęknięcie nieba: poszarpana wstęga wzdłuż X (0..1) z 2–3 odgałęzieniami, zwężająca się; front = −Y."""
    bm = bmesh.new()

    def ribbon(points, w0, w1):
        n = len(points)
        left, right = [], []
        for i, (x, z) in enumerate(points):
            a = points[max(i - 1, 0)]
            b = points[min(i + 1, n - 1)]
            tx, tz = b[0] - a[0], b[1] - a[1]
            length = math.hypot(tx, tz) or 1
            nx, nz = -tz / length, tx / length
            w = (w0 + (w1 - w0) * i / (n - 1)) / 2
            left.append(bm.verts.new((x + nx * w, 0.0, z + nz * w)))
            right.append(bm.verts.new((x - nx * w, 0.0, z - nz * w)))
        for i in range(n - 1):
            bm.faces.new((left[i], left[i + 1], right[i + 1], right[i]))

    def jagged(start, angle, length, steps, rough):
        pts = [start]
        x, z = start
        for i in range(1, steps + 1):
            a = angle + rng.uniform(-rough, rough)
            x += math.cos(a) * length / steps
            z += math.sin(a) * length / steps
            pts.append((x, z))
        return pts

    main = jagged((0.0, 0.0), 0.0, 1.0, 14, 0.55)
    ribbon(main, 0.07, 0.008)
    for _ in range(rng.randint(2, 3)):
        k = rng.randint(3, 9)
        branch = jagged(main[k], rng.choice([-1, 1]) * rng.uniform(0.5, 1.0), rng.uniform(0.25, 0.45), 6, 0.6)
        ribbon(branch, 0.035, 0.005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.y > 0:
            f.normal_flip()
    return mesh_obj(f"SkyCrack_{index}", bm, coll)


def build_shock_torus(coll):
    """Pierścień fali uderzeniowej: torus (R=1, r=0.12), spłaszczony w pionie; leży poziomo."""
    bm = bmesh.new()
    seg, ring = 48, 10
    verts = []
    for i in range(seg):
        a = i / seg * 2 * math.pi
        row = []
        for j in range(ring):
            b = j / ring * 2 * math.pi
            r = 1 + 0.12 * math.cos(b)
            row.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, 0.05 * math.sin(b))))
        verts.append(row)
    for i in range(seg):
        for j in range(ring):
            bm.faces.new((verts[i][j], verts[(i + 1) % seg][j], verts[(i + 1) % seg][(j + 1) % ring], verts[i][(j + 1) % ring]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj("ShockTorus", bm, coll, smooth=True)


def build_bow_cone(coll):
    """Stożek żaru przed gwiazdą: wierzchołek z przodu (−Y), otwarty z tyłu, paraboliczny profil."""
    bm = bmesh.new()
    seg, rings, length = 24, 8, 1.6
    tip = bm.verts.new((0.0, -length * 0.5, 0.0))
    rows = []
    for k in range(1, rings + 1):
        t = k / rings
        radius = math.sqrt(t)
        y = -length * 0.5 + length * t
        rows.append([bm.verts.new((math.cos(i / seg * 2 * math.pi) * radius, y, math.sin(i / seg * 2 * math.pi) * radius)) for i in range(seg)])
    for i in range(seg):
        bm.faces.new((tip, rows[0][(i + 1) % seg], rows[0][i]))
        for k in range(rings - 1):
            bm.faces.new((rows[k][i], rows[k][(i + 1) % seg], rows[k + 1][(i + 1) % seg], rows[k + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj("BowCone", bm, coll, smooth=True)


def build_lava_blob(coll, rng, index):
    """Kropla roztopionej materii: wydłużona łza z guzami (do rozbryzgów przy uderzeniu)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    for v in bm.verts:
        d = v.co.normalized()
        tail = max(0.0, -d.y) ** 2 * rng.uniform(0.8, 1.4)
        v.co = Vector((d.x * (1 - tail * 0.6), d.y * (1 + tail), d.z * (1 - tail * 0.6))) * (1 + rng.uniform(-0.12, 0.12))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(f"LavaBlob_{index}", bm, coll, smooth=True)


def main_t39():
    rng = random.Random(SEED + 1)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    coll = bpy.context.scene.collection
    objects = [build_sky_crack(coll, rng, i) for i in range(1, 4)]
    objects += [build_shock_torus(coll), build_bow_cone(coll)]
    objects += [build_lava_blob(coll, rng, i) for i in range(1, 3)]
    OUT.mkdir(parents=True, exist_ok=True)
    export_fbx(OUT / "vfx_meshes_t39.fbx")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "vfx_meshes_t39.blend"))
    print("VFX_T39_REPORT", {ob.name: tris(ob) for ob in objects})


if "--t39" in sys.argv:
    main_t39()
else:
    main()
