"""maplib.py — wspólne helpery geometrii dla generatorów mapy (T15): lobby, propsy, niebo.

Skopiowane z art/tools/build_tools.py (T11) + dodatki: zaokrąglone bryły, skały z szumem, UV box-projection,
zapis części wg roli materiału i meta JSON w układzie Roblox (−x, z, y).
"""
import math
import random

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def to_roblox(v):
    return [round(-v[0], 4), round(v[2], 4), round(v[1], 4)]


# ---------------------------------------------------------------- geometria

def bev(bm, off, angle=35):
    """Faza tylko na ostrych krawędziach (cylindry nie dostają faz na bokach)."""
    bm.normal_update()
    edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0) > math.radians(angle)]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=off, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)
    return bm


def cyl(r1, r2, depth, seg, M=Matrix()):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth, matrix=M)
    return bm


def zcyl(z0, z1, r, seg=8, r_top=None):
    """Walec wzdłuż Z od z0 do z1."""
    return cyl(r, r if r_top is None else r_top, z1 - z0, seg, Matrix.Translation((0, 0, (z0 + z1) / 2)))


def ycyl(y0, y1, r, z, seg=8, r_end=None, x=0.0):
    """Walec wzdłuż Y (głowice młotów), środek w (x, ·, z)."""
    M = Matrix.Translation((x, (y0 + y1) / 2, z)) @ Matrix.Rotation(-math.pi / 2, 4, "X")
    return cyl(r, r if r_end is None else r_end, y1 - y0, seg, M)


def xcyl(x0, x1, r, y, z, seg=8):
    M = Matrix.Translation(((x0 + x1) / 2, y, z)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
    return cyl(r, r, x1 - x0, seg, M)


def box(sx, sy, sz, c=(0, 0, 0), rot=None):
    bm = bmesh.new()
    M = Matrix.Translation(c) @ (rot or Matrix()) @ Matrix.Diagonal((sx, sy, sz, 1))
    bmesh.ops.create_cube(bm, size=1.0, matrix=M)
    return bm


def sphere(r, c, u=12, v=8):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r, matrix=Matrix.Translation(c))
    return bm


def ico(r, c, sub=1):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r, matrix=Matrix.Translation(c))
    return bm


def hull(points):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in points]
    res = bmesh.ops.convex_hull(bm, input=vs)
    junk = list({v for v in res["geom_interior"] + res["geom_unused"] if isinstance(v, bmesh.types.BMVert)})
    if junk:
        bmesh.ops.delete(bm, geom=junk, context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def loft(path, radii, sides=8, ref=X, cap=True, closed=False, phase=0.0):
    """Rura po ścieżce. radius = r albo (r_ref, r_drugi); r = 0 → szpic."""
    bm = bmesh.new()
    rings = []
    n = len(path)
    pts = [Vector(p) for p in path]
    for i, p in enumerate(pts):
        if closed:
            t = (pts[(i + 1) % n] - pts[i - 1]).normalized()
        else:
            t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        a = ref - t * ref.dot(t)
        if a.length < 1e-5:
            a = Z - t * t.z
        a.normalize()
        b = t.cross(a)
        r = radii[i]
        rx, ry = (r, r) if not isinstance(r, (tuple, list)) else r
        if max(rx, ry) < 1e-4:
            rings.append([bm.verts.new(p)])
            continue
        ring = []
        for k in range(sides):
            ang = 2 * math.pi * k / sides + phase
            ring.append(bm.verts.new(p + a * math.cos(ang) * rx + b * math.sin(ang) * ry))
        rings.append(ring)
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for r0, r1 in pairs:
        if len(r0) == 1 and len(r1) == 1:
            continue
        if len(r0) == 1:
            for k in range(sides):
                bm.faces.new((r0[0], r1[k], r1[(k + 1) % sides]))
        elif len(r1) == 1:
            for k in range(sides):
                bm.faces.new((r0[(k + 1) % sides], r0[k], r1[0]))
        else:
            for k in range(sides):
                k1 = (k + 1) % sides
                bm.faces.new((r0[k], r0[k1], r1[k1], r1[k]))
    if cap and not closed:
        if len(rings[0]) > 1:
            bm.faces.new(rings[0][::-1])
        if len(rings[-1]) > 1:
            bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def arc_pts(R, a0, a1, n):
    return [(R * math.cos(a0 + (a1 - a0) * i / (n - 1)), R * math.sin(a0 + (a1 - a0) * i / (n - 1)), 0) for i in range(n)]


def torus(R, r, M=Matrix(), seg=32, sides=6, a0=0.0, a1=2 * math.pi):
    """Pierścień wokół osi Z (M obraca/przesuwa). a0..a1 < 2π → łuk z zaślepkami."""
    full = abs(a1 - a0 - 2 * math.pi) < 1e-6
    pts = arc_pts(R, a0, a1 - (a1 - a0) / seg if full else a1, seg if full else max(4, seg))
    bm = loft(pts, [r] * len(pts), sides=sides, ref=Z, closed=full)
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)
    return bm


def plate(pts, th, x=0.0):
    """Płyta z obrysu w płaszczyźnie Y-Z, grubość (połowa) per wierzchołek wzdłuż X — ostrza i klingi."""
    bm = bmesh.new()
    L = [bm.verts.new((x - t, y, z)) for (y, z), t in zip(pts, th)]
    R = [bm.verts.new((x + t, y, z)) for (y, z), t in zip(pts, th)]
    n = len(pts)
    bm.faces.new(L[::-1])
    bm.faces.new(R)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((L[i], L[j], R[j], R[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def star_pts(r_out, r_in, n=5, cy=0.0, cz=0.0, rot=math.pi / 2):
    out = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rot + math.pi * i / n
        out.append((cy + r * math.cos(a), cz + r * math.sin(a)))
    return out


def spiky(r, c, spike=1.9):
    """Kolczasta kula (gwiezdny rdzeń): icosphere, 12 wierzchołków o 5 krawędziach wypchnięte."""
    bm = ico(r, (0, 0, 0), sub=2)
    for v in bm.verts:
        if len(v.link_edges) == 5:
            v.co *= spike
    bmesh.ops.translate(bm, vec=c, verts=bm.verts)
    return bm


def jitter(bm, rng, amt):
    for v in bm.verts:
        v.co += Vector((rng.uniform(-amt, amt), rng.uniform(-amt, amt), rng.uniform(-amt, amt)))
    return bm


def mirror_x(bm):
    out = bm.copy()
    bmesh.ops.scale(out, vec=(-1, 1, 1), verts=out.verts)
    bmesh.ops.reverse_faces(out, faces=out.faces[:])
    return out


def bm_append(dst, src):
    me = bpy.data.meshes.new("_tmp")
    src.to_mesh(me)
    dst.from_mesh(me)
    bpy.data.meshes.remove(me)


# ---------------------------------------------------------------- dodatki mapy (T15)

def rbox(sx, sy, sz, c=(0, 0, 0), r=0.5, rot=None):
    """Prostopadłościan z fazą r na wszystkich krawędziach (realistyczne krawędzie budynków)."""
    bm = box(sx, sy, sz, c, rot)
    if r > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=r, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)
    return bm


def merge(*bms):
    out = bmesh.new()
    for b in bms:
        bm_append(out, b)
        b.free()
    return out


def frame(sx, sz, w, d, c=(0, 0, 0)):
    """Rama (4 belki) w płaszczyźnie XZ (ściana frontowa), wymiary zewn. sx × sz, belka w, głębokość d."""
    cx, cy, cz = c
    return merge(box(sx, d, w, (cx, cy, cz + sz / 2 - w / 2)), box(sx, d, w, (cx, cy, cz - sz / 2 + w / 2)),
                 box(w, d, sz - 2 * w, (cx - sx / 2 + w / 2, cy, cz)), box(w, d, sz - 2 * w, (cx + sx / 2 - w / 2, cy, cz)))


def ring_band(sx, sy, h, z, t=0.4):
    """Opaska wokół prostopadłościanu sx × sy (4 płyty grubości t) na wysokości z..z+h."""
    return merge(box(sx + 2 * t, t, h, (0, -sy / 2 - t / 2, z + h / 2)), box(sx + 2 * t, t, h, (0, sy / 2 + t / 2, z + h / 2)),
                 box(t, sy, h, (-sx / 2 - t / 2, 0, z + h / 2)), box(t, sy, h, (sx / 2 + t / 2, 0, z + h / 2)))


def dome(r, c=(0, 0, 0), u=16, v=6, squash=1.0):
    """Półkula (kopuła) od z = c.z w górę, z zamkniętym dnem."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v * 2, radius=r)
    bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if vv.co.z < -1e-4], context="VERTS")
    for vv in bm.verts:
        vv.co.z *= squash
    edges = [e for e in bm.edges if e.is_boundary]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bmesh.ops.translate(bm, vec=c, verts=bm.verts)
    return bm


def rock(rng, size, detail=2, rough=0.35, flat=1.0, cuts=0, sink=0.25):
    """Realistyczna skała: icosphere przesunięta szumem fraktalnym, opcjonalnie cięta płaszczyznami (kanciasty bazalt).
    size = promienie (sx, sy, sz). Dno lekko pod z = 0 (osadzenie w terenie)."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=detail, radius=1.0)
    off = Vector((rng.uniform(-100, 100), rng.uniform(-100, 100), rng.uniform(-100, 100)))
    if detail >= 2 and max(size) >= 4.5:
        detail_extra = 1  # duże skały: o poziom gęściej (szum fraktalny widoczny na sylwetce)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    for v in bm.verts:
        d = v.co.normalized()
        n = noise.fractal(d * 1.3 + off, 0.55, 2.1, 4)
        n2 = noise.noise(d * 3.7 + off * 0.5)
        k = 1.0 + rough * n + rough * 0.35 * n2
        v.co = Vector((d.x * size[0], d.y * size[1], d.z * size[2] * flat)) * k
    for _ in range(cuts):
        nrm = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.3, 1))).normalized()
        ext = max(abs(v.co.dot(nrm)) for v in bm.verts)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], dist=1e-4,
                               plane_co=nrm * ext * rng.uniform(0.6, 0.85), plane_no=nrm, clear_outer=True)
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    zmin = min(v.co.z for v in bm.verts)
    zmax = max(v.co.z for v in bm.verts)
    bmesh.ops.translate(bm, vec=(0, 0, -zmin - (zmax - zmin) * sink), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def box_uv(bm, tile=8.0):
    """UV box-projection w studs/tile — materiały Roblox na MeshPart kafelkują się wg UV."""
    uv = bm.loops.layers.uv.active or bm.loops.layers.uv.new("UVMap")
    bm.normal_update()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            co = loop.vert.co
            if ax == 0:
                loop[uv].uv = (co.y / tile, co.z / tile)
            elif ax == 1:
                loop[uv].uv = (co.x / tile, co.z / tile)
            else:
                loop[uv].uv = (co.x / tile, co.y / tile)


def bbox(ob):
    ws = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector([min(w[i] for w in ws) for i in range(3)])
    hi = Vector([max(w[i] for w in ws) for i in range(3)])
    return lo, hi


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


_MATS = {}


def preview_material(key, hx, rbx, tr):
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    c = lin(hex_rgb(hx))
    if rbx == "Neon":
        b.inputs["Base Color"].default_value = (0, 0, 0, 1)
        b.inputs["Emission Color"].default_value = (*c, 1)
        b.inputs["Emission Strength"].default_value = 5.0
    else:
        b.inputs["Base Color"].default_value = (*c, 1)
        b.inputs["Roughness"].default_value = {"Metal": 0.35, "Glass": 0.08, "Ice": 0.15, "Glacier": 0.3}.get(rbx, 0.8)
        b.inputs["Metallic"].default_value = 0.8 if rbx in ("Metal", "DiamondPlate") else 0.0
    if tr > 0:
        b.inputs["Alpha"].default_value = 1 - tr
        m.surface_render_method = "BLENDED"
    _MATS[key] = m
    return m


class Asset:
    """Model złożony z części; każda część = jeden mesh o jednym materiale Roblox (MeshPart)."""

    def __init__(self, name, palette):
        self.name = name
        self.pal = palette  # klucz → (hex, materiał Roblox, przezroczystość)
        self.parts = {}  # część → [klucz, [bmesh]]
        self.collide = set()  # części z CanCollide
        self.extra = {}  # dodatkowe dane do meta (kotwice itp.)

    def add(self, part, key, bm, bevel=0.0, collide=False):
        if bevel:
            bev(bm, bevel)
        slot = self.parts.setdefault(part, [key, []])
        assert slot[0] == key, f"{self.name}_{part}: dwa materiały ({slot[0]}, {key})"
        slot[1].append(bm)
        if collide:
            self.collide.add(part)
        return bm

    def build(self, coll, tile=8.0):
        obs = {}
        for part, (key, bms) in self.parts.items():
            dst = bmesh.new()
            for b in bms:
                bm_append(dst, b)
                b.free()
            bmesh.ops.remove_doubles(dst, verts=dst.verts[:], dist=1e-4)
            bmesh.ops.triangulate(dst, faces=dst.faces[:])
            box_uv(dst, tile)
            me = bpy.data.meshes.new(f"{self.name}_{part}")
            dst.to_mesh(me)
            dst.free()
            ob = bpy.data.objects.new(f"{self.name}_{part}", me)
            coll.objects.link(ob)
            hx, rbx, tr = self.pal[key]
            me.materials.append(preview_material(f"{self.name}_{key}", hx, rbx, tr))
            for p in me.polygons:
                p.use_smooth = False
            obs[part] = ob
        return obs

    def meta(self, obs):
        parts = {}
        for part, ob in obs.items():
            lo, hi = bbox(ob)
            hx, rbx, tr = self.pal[self.parts[part][0]]
            size = hi - lo
            parts[part] = {"material": rbx, "color": hx, "transparency": tr, "center": to_roblox((lo + hi) / 2),
                           "size": [round(size.x, 4), round(size.z, 4), round(size.y, 4)], "tris": tris(ob),
                           "collide": part in self.collide}
        out = {"parts": parts, "tris": sum(p["tris"] for p in parts.values())}
        out.update(self.extra)
        return out


def export_fbx(path, obs):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in obs:
        ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=str(path), use_selection=True, object_types={"MESH"},
                             apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True,
                             axis_forward="-Z", axis_up="Y", add_leaf_bones=False, mesh_smooth_type="FACE")


def setup_render(w, h, bg=(0.012, 0.01, 0.03)):
    sc = bpy.context.scene
    engines = {e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items}
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (*bg, 1)
    sc.world = world
    for name, energy, loc in (("Key", 4.0, (1, -1.4, 1.6)), ("Fill", 1.2, (-1.5, -0.6, 0.6)), ("Rim", 3.0, (-0.5, 1.6, 1.0))):
        li = bpy.data.lights.new(name, "SUN")
        li.energy = energy
        ob = bpy.data.objects.new(name, li)
        ob.rotation_euler = (-Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        sc.collection.objects.link(ob)
    ng = bpy.data.node_groups.new("Comp", "CompositorNodeTree")
    ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    rl = ng.nodes.new("CompositorNodeRLayers")
    gl = ng.nodes.new("CompositorNodeGlare")
    out = ng.nodes.new("NodeGroupOutput")
    for key, val in (("Type", "Bloom"), ("Threshold", 1.0), ("Strength", 0.8), ("Size", 6), ("Quality", "High")):
        try:
            gl.inputs[key].default_value = val
        except (TypeError, KeyError, AttributeError):
            pass
    ng.links.new(rl.outputs["Image"], gl.inputs["Image"])
    ng.links.new(gl.outputs[0], out.inputs[0])
    sc.compositing_node_group = ng


def frame_camera(objs, direction=(1.0, -1.6, 0.9), lens=50, margin=1.1):
    sc = bpy.context.scene
    bpy.context.view_layer.update()
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for ob in objs:
        a, b = bbox(ob)
        lo = Vector([min(x, y) for x, y in zip(lo, a)])
        hi = Vector([max(x, y) for x, y in zip(hi, b)])
    c = (lo + hi) / 2
    r = (hi - lo).length / 2 * margin
    cam_d = bpy.data.cameras.new("Cam")
    cam_d.lens = lens
    cam_d.clip_end = 100000
    cam = bpy.data.objects.new("Cam", cam_d)
    sc.collection.objects.link(cam)
    d = Vector(direction).normalized()
    fov = 2 * math.atan(18 / lens)
    cam.location = c + d * (r / math.sin(fov / 2))
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    return cam

