"""build_sky.py — niebo Crack a Stars (T15): skybox z mgławicą i zorzą + 3 planety (Blender 5.x, tryb w tle).

Uruchom:
  E:\\blender\\blender.exe -b --factory-startup -P art/map/sky/build_sky.py -- [--faces] [--planets] [--preview]

--faces    6 ścian skyboxa 1024 px (Cycles, samo tło świata) → art/map/sky/faces/sky_{bk,dn,ft,lf,rt,up}.png
--planets  3 planety (UV sphere + tekstury wypalone z proceduralnych shaderów) + pierścień → planets.fbx,
           tekstury planet_*.png, planets_meta.json (rozmiary i środki w układzie Roblox)
--preview  panorama podglądowa nieba → vault/_img/T15 niebo.png

Kolorystyka (decyzja 9.11): ciemny granat + zielone smugi zorzy, delikatna mgławica, gęste gwiazdy.
Kierunki ścian: patrz FACE_DIRS (konwencja Roblox zmierzona w Studio).
"""

import json
import math
import random
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
IMG = ROOT / "vault" / "_img"
FACES = OUT / "faces"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SEED = 1515
DEBUG = {}
FACE_RES = 1024

# Paleta nieba (sRGB hex)
NAVY_TOP = "#03050F"
NAVY_HORIZON = "#0A1838"
NEBULA_A = "#123C6B"   # chłodny błękit mgławicy
NEBULA_B = "#2A1D5C"   # fioletowy cień mgławicy
AURORA_A = "#2CFF9A"   # zieleń zorzy
AURORA_B = "#1FD6C8"   # turkus przy górnej krawędzi zorzy


def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------------------------------------------------------------- shader nieba
def node(nt, kind, loc, **props):
    n = nt.nodes.new(kind)
    n.location = loc
    for k, v in props.items():
        setattr(n, k, v)
    return n


def ramp(nt, loc, stops):
    r = node(nt, "ShaderNodeValToRGB", loc)
    els = r.color_ramp.elements
    while len(els) > 1:
        els.remove(els[-1])
    els[0].position, els[0].color = stops[0]
    for pos, col in stops[1:]:
        e = els.new(pos)
        e.color = col
    return r


def math_node(nt, op, loc, a=None, b=None):
    m = node(nt, "ShaderNodeMath", loc, operation=op)
    if a is not None:
        m.inputs[0].default_value = a
    if b is not None:
        m.inputs[1].default_value = b
    return m


def build_world():
    world = bpy.data.worlds.new("NebulaSky")
    bpy.context.scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    L = nt.links.new

    # kierunek widoku = −Incoming (Generated w świecie bywa nieciągły na granicach)
    geo = node(nt, "ShaderNodeNewGeometry", (-1900, 0))
    neg = node(nt, "ShaderNodeVectorMath", (-1750, 0), operation="SCALE")
    neg.inputs["Scale"].default_value = -1.0
    L(geo.outputs["Incoming"], neg.inputs[0])

    class _TC:  # zgodność z resztą kodu: tc.outputs["Generated"] → kierunek
        outputs = {"Generated": neg.outputs[0]}
    tc = _TC()
    # kierunek widoku: Generated w świecie = znormalizowany kierunek
    sep = node(nt, "ShaderNodeSeparateXYZ", (-1400, -300))
    L(tc.outputs["Generated"], sep.inputs[0])

    # --- gradient granatu (wysokość = z)
    grad = ramp(nt, (-1100, 400), [(0.0, lin(NAVY_HORIZON)), (0.18, lin(NAVY_HORIZON)), (0.6, lin(NAVY_TOP)), (1.0, lin(NAVY_TOP))])
    zmap = node(nt, "ShaderNodeMapRange", (-1300, 400))
    zmap.inputs["From Min"].default_value = -0.3
    zmap.inputs["From Max"].default_value = 1.0
    L(sep.outputs["Z"], zmap.inputs["Value"])
    L(zmap.outputs["Result"], grad.inputs["Fac"])

    # --- mgławica: dwa szumy 3D na kierunku
    n1 = node(nt, "ShaderNodeTexNoise", (-1100, 100))
    n1.noise_dimensions = "3D"
    n1.inputs["Scale"].default_value = 1.6
    n1.inputs["Detail"].default_value = 12.0
    n1.inputs["Roughness"].default_value = 0.62
    n1.inputs["Distortion"].default_value = 0.35
    L(tc.outputs["Generated"], n1.inputs["Vector"])
    neb = ramp(nt, (-850, 100), [(0.0, (0, 0, 0, 1)), (0.48, (0, 0, 0, 1)), (0.62, lin(NEBULA_B)), (0.8, lin(NEBULA_A)), (1.0, lin("#3A7FB8"))])
    L(n1.outputs["Fac"], neb.inputs["Fac"])
    n2 = node(nt, "ShaderNodeTexNoise", (-1100, -100))
    n2.inputs["Scale"].default_value = 0.8
    n2.inputs["Detail"].default_value = 3.0
    L(tc.outputs["Generated"], n2.inputs["Vector"])
    mask = ramp(nt, (-850, -100), [(0.0, (0, 0, 0, 1)), (0.45, (0, 0, 0, 1)), (0.7, (1, 1, 1, 1))])
    L(n2.outputs["Fac"], mask.inputs["Fac"])
    nebm = node(nt, "ShaderNodeMix", (-600, 100), data_type="RGBA", blend_type="MULTIPLY")
    nebm.inputs["Factor"].default_value = 1.0
    L(neb.outputs["Color"], nebm.inputs[6])
    L(mask.outputs["Color"], nebm.inputs[7])
    sky = node(nt, "ShaderNodeMix", (-400, 300), data_type="RGBA", blend_type="ADD")
    sky.inputs["Factor"].default_value = 1.0
    L(grad.outputs["Color"], sky.inputs[6])
    L(nebm.outputs[2], sky.inputs[7])

    # --- zorza: pionowe zasłony. az = kierunek poziomy (x, y), el = asin(z).
    nrm = node(nt, "ShaderNodeVectorMath", (-1500, -500), operation="NORMALIZE")
    L(tc.outputs["Generated"], nrm.inputs[0])
    sepn = node(nt, "ShaderNodeSeparateXYZ", (-1350, -500))
    L(nrm.outputs[0], sepn.inputs[0])
    el = math_node(nt, "ARCSINE", (-1200, -700))
    L(sepn.outputs["Z"], el.inputs[0])
    hor = node(nt, "ShaderNodeCombineXYZ", (-1200, -500))
    L(sepn.outputs["X"], hor.inputs["X"])
    L(sepn.outputs["Y"], hor.inputs["Y"])
    horn = node(nt, "ShaderNodeVectorMath", (-1050, -500), operation="NORMALIZE")
    L(hor.outputs[0], horn.inputs[0])

    def noise_on(vec_out, loc, scale, detail, w):
        # szum 3D na (kierunek poziomy + przesunięcie w) — ciągły po całym azymucie
        off = node(nt, "ShaderNodeVectorMath", (loc[0] - 150, loc[1]), operation="ADD")
        off.inputs[1].default_value = (w * 1.7, w * 2.3, w * 3.1)
        L(vec_out, off.inputs[0])
        n = node(nt, "ShaderNodeTexNoise", loc)
        n.noise_dimensions = "3D"
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        L(off.outputs[0], n.inputs["Vector"])
        return n.outputs["Fac"]

    def ribbon(y0, base, swing, w, gain, rays_scale):
        # dolna krawędź wstęgi b(az) = base + swing * (noise - 0.5)
        nb = noise_on(horn.outputs[0], (-850, y0), 1.3, 2.0, w)
        b1 = math_node(nt, "SUBTRACT", (-700, y0), b=0.5)
        L(nb, b1.inputs[0])
        b2 = math_node(nt, "MULTIPLY_ADD", (-550, y0))
        b2.inputs[1].default_value = swing
        b2.inputs[2].default_value = base
        L(b1.outputs[0], b2.inputs[0])
        h = math_node(nt, "SUBTRACT", (-400, y0))
        L(el.outputs[0], h.inputs[0])
        L(b2.outputs[0], h.inputs[1])
        # profil pionowy: ostra dolna krawędź, długi zanik w górę
        prof = node(nt, "ShaderNodeFloatCurve", (-250, y0))
        L(h.outputs[0], prof.inputs["Value"])
        c = prof.mapping.curves[0]
        prof.mapping.clip_min_x, prof.mapping.clip_max_x = -1.0, 1.0
        prof.mapping.use_clip = False
        c.points[0].location = (-0.04, 0.0)
        c.points[1].location = (0.5, 0.0)
        c.points.new(0.0, 1.0)
        c.points.new(0.08, 0.7)
        c.points.new(0.25, 0.22)
        prof.mapping.update()
        # promienie: wysoka częstotliwość wzdłuż azymutu
        nr = noise_on(horn.outputs[0], (-850, y0 - 200), rays_scale, 3.0, w + 7.0)
        rr = ramp(nt, (-550, y0 - 200), [(0.0, (0.15, 0.15, 0.15, 1)), (0.45, (0.3, 0.3, 0.3, 1)), (0.7, (1, 1, 1, 1))])
        L(nr, rr.inputs["Fac"])
        # obecność wstęgi wokół horyzontu (część azymutów bez zorzy)
        npres = noise_on(horn.outputs[0], (-850, y0 - 400), 0.9, 1.0, w + 13.0)
        pr = ramp(nt, (-550, y0 - 400), [(0.0, (0, 0, 0, 1)), (0.3, (0, 0, 0, 1)), (0.5, (0.35, 0.35, 0.35, 1)), (0.78, (1, 1, 1, 1))])
        pr.color_ramp.interpolation = "EASE"
        L(npres, pr.inputs["Fac"])
        DEBUG.setdefault("pres", pr.outputs["Color"])
        DEBUG.setdefault("prof", pc.outputs[0]) if False else None
        pc = math_node(nt, "MAXIMUM", (-175, y0), b=0.0)
        L(prof.outputs[0], pc.inputs[0])
        DEBUG.setdefault("prof", pc.outputs[0])
        DEBUG.setdefault("h", h.outputs[0])
        m1 = math_node(nt, "MULTIPLY", (-100, y0))
        L(pc.outputs[0], m1.inputs[0])
        L(rr.outputs["Color"], m1.inputs[1])
        m2 = math_node(nt, "MULTIPLY", (50, y0))
        L(m1.outputs[0], m2.inputs[0])
        L(pr.outputs["Color"], m2.inputs[1])
        m3 = math_node(nt, "MULTIPLY", (200, y0), b=gain)
        L(m2.outputs[0], m3.inputs[0])
        return m3, h

    r1, h1 = ribbon(-600, 0.16, 0.22, 2.0, 0.95, 55.0)
    r2, _ = ribbon(-1300, 0.38, 0.3, 11.0, 0.45, 38.0)
    asum = math_node(nt, "ADD", (350, -800))
    L(r1.outputs[0], asum.inputs[0])
    L(r2.outputs[0], asum.inputs[1])
    # kolor: zieleń przy dolnej krawędzi, turkus i fiolet wyżej (h1 w radianach)
    hcol = node(nt, "ShaderNodeMapRange", (200, -1000))
    hcol.inputs["From Min"].default_value = 0.0
    hcol.inputs["From Max"].default_value = 0.6
    L(h1.outputs[0], hcol.inputs["Value"])
    acol = ramp(nt, (350, -1000), [(0.0, lin(AURORA_A)), (0.3, lin(AURORA_A)), (0.65, lin(AURORA_B)), (1.0, lin("#4A3AA8"))])
    L(hcol.outputs["Result"], acol.inputs["Fac"])
    amix = node(nt, "ShaderNodeMix", (500, -800), data_type="RGBA", blend_type="MULTIPLY")
    amix.inputs["Factor"].default_value = 1.0
    L(asum.outputs[0], amix.inputs[6])
    L(acol.outputs["Color"], amix.inputs[7])
    sky2 = node(nt, "ShaderNodeMix", (650, 200), data_type="RGBA", blend_type="ADD")
    sky2.inputs["Factor"].default_value = 1.0
    L(sky.outputs[2], sky2.inputs[6])
    L(amix.outputs[2], sky2.inputs[7])

    # --- gwiazdy: dwie warstwy Voronoi (gęste małe + rzadkie jasne)
    def stars(loc, scale, size, gain):
        v = node(nt, "ShaderNodeTexVoronoi", loc, voronoi_dimensions="3D", feature="F1")
        v.inputs["Scale"].default_value = scale
        v.inputs["Randomness"].default_value = 1.0
        L(tc.outputs["Generated"], v.inputs["Vector"])
        d = ramp(nt, (loc[0] + 200, loc[1]), [(0.0, (1, 1, 1, 1)), (size, (0, 0, 0, 1))])
        L(v.outputs["Distance"], d.inputs["Fac"])
        # losowa jasność gwiazdy z koloru komórki
        sepc = node(nt, "ShaderNodeSeparateColor", (loc[0] + 200, loc[1] - 200))
        L(v.outputs["Color"], sepc.inputs[0])
        pw = math_node(nt, "POWER", (loc[0] + 400, loc[1] - 200), b=4.0)
        L(sepc.outputs[0], pw.inputs[0])
        m = math_node(nt, "MULTIPLY", (loc[0] + 550, loc[1]))
        L(d.outputs["Color"], m.inputs[0])
        L(pw.outputs[0], m.inputs[1])
        g = math_node(nt, "MULTIPLY", (loc[0] + 700, loc[1]), b=gain)
        L(m.outputs[0], g.inputs[0])
        return g

    s1 = stars((-900, 800), 220.0, 0.1, 4.0)
    s2 = stars((-900, 1200), 60.0, 0.05, 12.0)
    sadd = math_node(nt, "ADD", (100, 900))
    L(s1.outputs[0], sadd.inputs[0])
    L(s2.outputs[0], sadd.inputs[1])
    # gwiazdy słabną przy horyzoncie (mgła atmosfery)
    sfade = node(nt, "ShaderNodeMapRange", (100, 700))
    sfade.inputs["From Min"].default_value = -0.05
    sfade.inputs["From Max"].default_value = 0.35
    L(sep.outputs["Z"], sfade.inputs["Value"])
    smul = math_node(nt, "MULTIPLY", (300, 900))
    L(sadd.outputs[0], smul.inputs[0])
    L(sfade.outputs["Result"], smul.inputs[1])
    final = node(nt, "ShaderNodeMix", (400, 300), data_type="RGBA", blend_type="ADD")
    final.inputs["Factor"].default_value = 1.0
    L(sky2.outputs[2], final.inputs[6])
    L(smul.outputs[0], final.inputs[7])

    bg = node(nt, "ShaderNodeBackground", (650, 300))
    L(final.outputs[2], bg.inputs["Color"])
    dbg = next((a.split("=")[1] for a in ARGS if a.startswith("--debug=")), None)
    if dbg:
        L(DEBUG[dbg], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 1.0
    out = node(nt, "ShaderNodeOutputWorld", (850, 300))
    L(bg.outputs[0], out.inputs[0])
    return world


def setup_render(res_x, res_y, samples=8):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.render.resolution_x = res_x
    sc.render.resolution_y = res_y
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGB"
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False


# Konwencja skyboxa Roblox zmierzona w Studio (T15, ściany z siatką kierunków, Edit 9.11):
# układ Blendera = Roblox(x, y, z) → Blender(x, −z, y). Ft widać patrząc w −Z (Blender +Y),
# slot SkyboxLf jest wyświetlany po stronie +X, a SkyboxRt po stronie −X (odwrotnie niż sugerują nazwy),
# górna ściana musi być obrócona o 90° w lewo (CCW) względem renderu (patrz rotate_ccw).
FACE_DIRS = {
    "ft": Vector((0, 1, 0)),   # Roblox −Z
    "bk": Vector((0, -1, 0)),  # Roblox +Z
    "lf": Vector((1, 0, 0)),   # slot Lf → strona Roblox +X
    "rt": Vector((-1, 0, 0)),  # slot Rt → strona Roblox −X
    "up": Vector((0, 0, 1)),
    "dn": Vector((0, 0, -1)),
}
FACE_UP = {"ft": Vector((0, 0, 1)), "bk": Vector((0, 0, 1)), "rt": Vector((0, 0, 1)), "lf": Vector((0, 0, 1)),
           "up": Vector((0, -1, 0)), "dn": Vector((0, 1, 0))}
ROT_CCW = {"up"}


def rotate_ccw(path):
    """Obrót obrazu o 90° w lewo (wizualnie). Piksele Blendera idą od dołu, więc odwracamy, obracamy, odwracamy."""
    import numpy as np
    img = bpy.data.images.load(str(path))
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    px = np.ascontiguousarray(np.rot90(px, k=1)[::-1])
    img.pixels[:] = px.ravel()
    img.filepath_raw = str(path)
    img.save()
    bpy.data.images.remove(img)


def look_rot(direction, up):
    # kamera Blendera patrzy w −Z lokalnie, góra = +Y lokalnie
    z = -direction.normalized()
    x = up.cross(z).normalized()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed().to_euler()


def render_faces():
    setup_render(FACE_RES, FACE_RES, samples=4)
    FACES.mkdir(exist_ok=True)
    cam_data = bpy.data.cameras.new("SkyCam")
    cam_data.angle = math.radians(90)
    cam = bpy.data.objects.new("SkyCam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    for name, d in FACE_DIRS.items():
        cam.rotation_euler = look_rot(d, FACE_UP[name])
        bpy.context.scene.render.filepath = str(FACES / f"sky_{name}.png")
        bpy.ops.render.render(write_still=True)
        if name in ROT_CCW:
            rotate_ccw(FACES / f"sky_{name}.png")
        print("face", name)


def render_preview():
    setup_render(2048, 1024, samples=8)
    cam_data = bpy.data.cameras.new("PanoCam")
    cam_data.type = "PANO"
    cam_data.panorama_type = "EQUIRECTANGULAR"
    cam = bpy.data.objects.new("PanoCam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.rotation_euler = (math.radians(90), 0, 0)
    bpy.context.scene.camera = cam
    bpy.context.scene.render.filepath = str(IMG / "T15 niebo.png")
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- planety
PLANETS = {
    # name: (radius studs, segments, stops ramp of bands/noise, band scale, ring)
    "GasGiant": {"radius": 700, "seg": 48, "rings": 24, "ramp": ["#0E2A4A", "#1C5E7A", "#3FA3A0", "#BFE6D6", "#2A6F8F", "#123352"],
                 "bands": 9.0, "turb": 1.6, "ring": True},
    "Ember": {"radius": 260, "seg": 40, "rings": 20, "ramp": ["#2A0F24", "#6B1E3A", "#C2493F", "#F09A5A", "#4A1630"],
              "bands": 2.5, "turb": 6.0, "ring": False},
    "IceMoon": {"radius": 150, "seg": 32, "rings": 16, "ramp": ["#5C6F99", "#9FB5D9", "#E2ECFA", "#7A8DB8"],
                "bands": 1.5, "turb": 8.0, "ring": False},
}
TEX = 1024


def uv_sphere(name, radius, seg, rings):
    bm = bmesh.new()
    bm.loops.layers.uv.new("UVMap")
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=radius, calc_uvs=True)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def ring_mesh(name, r0, r1, seg=96):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    verts = []
    for i in range(seg + 1):
        a = 2 * math.pi * i / seg
        c, s = math.cos(a), math.sin(a)
        verts.append((bm.verts.new((c * r0, s * r0, 0)), bm.verts.new((c * r1, s * r1, 0)), i / seg))
    for i in range(seg):
        a0, b0, u0 = verts[i]
        a1, b1, u1 = verts[i + 1]
        if i == seg - 1:
            a1, b1 = verts[0][0], verts[0][1]
        for face_verts, flip in (((a0, b0, b1, a1), False), ((a1, b1, b0, a0), True)):  # dwustronny
            try:
                f = bm.faces.new(face_verts)
            except ValueError:
                continue
            for loop in f.loops:
                v = loop.vert
                vv = u0 if v in (a0, b0) else u1
                loop[uv].uv = (0.0 if v in (a0, a1) else 1.0, vv)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def bake_material(ob, build_fn, img_name, w, h, alpha=False):
    mat = bpy.data.materials.new(img_name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    emit_col, emit_alpha = build_fn(nt)
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(emit_col, em.inputs["Color"])
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(em.outputs[0], out.inputs[0])
    img = bpy.data.images.new(img_name, w, h, alpha=alpha)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.nodes.active = tex
    ob.data.materials.append(mat)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.scene.objects:
        o.select_set(o == ob)
    bpy.ops.object.bake(type="EMIT", margin=4)
    if alpha and emit_alpha is not None:
        # osobny bake alfy do kanału A
        nt.links.new(emit_alpha, em.inputs["Color"])
        img_a = bpy.data.images.new(img_name + "_a", w, h)
        tex.image = img_a
        bpy.ops.object.bake(type="EMIT", margin=4)
        px = list(img.pixels)
        pa = list(img_a.pixels)
        for i in range(0, len(px), 4):
            px[i + 3] = pa[i]
        img.pixels = px
    if not alpha:
        fill_poles(img)
    img.filepath_raw = str(OUT / f"{img_name}.png")
    img.file_format = "PNG"
    img.save()
    return img


def fill_poles(img, rows=24):
    """Bieguny UV sphere zostawiają puste trójkąty — wypełniamy wiersze przy krawędziach średnim kolorem
    pierwszego pełnego wiersza (biegun = jeden punkt, więc jeden kolor jest poprawny)."""
    import numpy as np
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    for edge_rows, ref_row in ((range(0, rows), rows), (range(h - rows, h), h - rows - 1)):
        mean = px[ref_row, :, :3].mean(axis=0)
        for r in edge_rows:
            t = abs(r - ref_row) / rows  # im bliżej bieguna, tym bardziej średni kolor
            row = px[r, :, :3]
            dark = row.sum(axis=1) < 0.02
            row[dark] = mean
            px[r, :, :3] = row * (1 - t) + mean * t
        px[edge_rows.start:edge_rows.stop, :, 3] = 1.0
    img.pixels[:] = px.ravel()


def planet_shader(cfg, seed):
    def build(nt):
        L = nt.links.new
        tc = nt.nodes.new("ShaderNodeTexCoord")
        # pasy: współrzędna z obiektu (wysokość) + turbulencja szumu
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.noise_dimensions = "4D"
        noise.inputs["Scale"].default_value = 2.5
        noise.inputs["Detail"].default_value = 10.0
        noise.inputs["Roughness"].default_value = 0.6
        noise.inputs["W"].default_value = seed
        noise.noise_dimensions = "4D"
        nrm = nt.nodes.new("ShaderNodeVectorMath")
        nrm.operation = "NORMALIZE"
        L(tc.outputs["Object"], nrm.inputs[0])
        L(nrm.outputs[0], noise.inputs["Vector"])
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        L(nrm.outputs[0], sep.inputs[0])
        t = nt.nodes.new("ShaderNodeMath")
        t.operation = "MULTIPLY_ADD"
        t.inputs[1].default_value = cfg["turb"] * 0.1
        L(noise.outputs["Fac"], t.inputs[0])
        L(sep.outputs["Z"], t.inputs[2])
        wave = nt.nodes.new("ShaderNodeMath")
        wave.operation = "SINE"
        sc = nt.nodes.new("ShaderNodeMath")
        sc.operation = "MULTIPLY"
        sc.inputs[1].default_value = cfg["bands"]
        L(t.outputs[0], sc.inputs[0])
        L(sc.outputs[0], wave.inputs[0])
        fac = nt.nodes.new("ShaderNodeMapRange")
        fac.inputs["From Min"].default_value = -1.0
        fac.inputs["From Max"].default_value = 1.0
        L(wave.outputs[0], fac.inputs["Value"])
        # mieszanka pasów z szumem (dla planet skalistych szum dominuje)
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "FLOAT"
        mix.inputs["Factor"].default_value = 0.35 if cfg["bands"] > 5 else 0.75
        L(fac.outputs["Result"], mix.inputs[2])
        L(noise.outputs["Fac"], mix.inputs[3])
        r = nt.nodes.new("ShaderNodeValToRGB")
        els = r.color_ramp.elements
        cols = cfg["ramp"]
        els[0].position, els[0].color = 0.0, lin(cols[0])
        els[1].position, els[1].color = 1.0, lin(cols[-1])
        for i, c in enumerate(cols[1:-1], 1):
            e = els.new(i / (len(cols) - 1))
            e.color = lin(c)
        L(mix.outputs[0], r.inputs["Fac"])
        return r.outputs["Color"], None
    return build


def ring_shader(nt):
    L = nt.links.new
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    L(tc.outputs["UV"], sep.inputs[0])
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.noise_dimensions = "1D"
    n.inputs["Scale"].default_value = 30.0
    n.inputs["Detail"].default_value = 8.0
    L(sep.outputs["X"], n.inputs["W"])
    r = nt.nodes.new("ShaderNodeValToRGB")
    els = r.color_ramp.elements
    els[0].position, els[0].color = 0.2, lin("#2A5C6E")
    els[1].position, els[1].color = 0.8, lin("#CFEFE6")
    L(n.outputs["Fac"], r.inputs["Fac"])
    # alfa: pasy + zanikanie przy krawędziach
    a = nt.nodes.new("ShaderNodeValToRGB")
    ea = a.color_ramp.elements
    ea[0].position, ea[0].color = 0.35, (0.05, 0.05, 0.05, 1)
    ea[1].position, ea[1].color = 0.65, (0.9, 0.9, 0.9, 1)
    L(n.outputs["Fac"], a.inputs["Fac"])
    edge = nt.nodes.new("ShaderNodeFloatCurve")
    L(sep.outputs["X"], edge.inputs["Value"])
    c = edge.mapping.curves[0]
    c.points[0].location = (0.0, 0.0)
    c.points[1].location = (1.0, 0.0)
    c.points.new(0.12, 1.0)
    c.points.new(0.85, 1.0)
    edge.mapping.update()
    m = nt.nodes.new("ShaderNodeMath")
    m.operation = "MULTIPLY"
    L(a.outputs["Color"], m.inputs[0])
    L(edge.outputs[0], m.inputs[1])
    return r.outputs["Color"], m.outputs[0]


def build_planets():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 1
    sc.view_settings.view_transform = "Standard"
    meta = {}
    objs = []
    for i, (name, cfg) in enumerate(PLANETS.items()):
        ob = uv_sphere(f"{name}_Body", cfg["radius"], cfg["seg"], cfg["rings"])
        bake_material(ob, planet_shader(cfg, i * 3.7 + 1.3), f"planet_{name}", TEX, TEX // 2)
        objs.append(ob)
        meta[name] = {"radius": cfg["radius"], "tris": sum(len(p.vertices) - 2 for p in ob.data.polygons)}
        if cfg["ring"]:
            r = ring_mesh(f"{name}_Ring", cfg["radius"] * 1.35, cfg["radius"] * 2.3)
            bake_material(r, ring_shader, f"planet_{name}_ring", 512, 16, alpha=True)
            objs.append(r)
            meta[name]["ringOuter"] = cfg["radius"] * 2.3
    # eksport: każdy obiekt osobno w jednym FBX (środki w 0, rozmieszczenie robi Studio)
    for o in bpy.context.scene.objects:
        o.select_set(o in objs)
    bpy.ops.export_scene.fbx(filepath=str(OUT / "planets.fbx"), use_selection=True, object_types={"MESH"},
                             axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_ALL",
                             mesh_smooth_type="FACE", path_mode="STRIP", bake_space_transform=True)
    (OUT / "planets_meta.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "planets.blend"))
    print("planets", meta)


def build_debug_world():
    """Kolor = kierunek (x, y, z)·0.5 + 0.5, białe linie co 15° elewacji, czarne co 30° azymutu."""
    world = bpy.data.worlds.new("Debug")
    bpy.context.scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    L = nt.links.new
    geo = node(nt, "ShaderNodeNewGeometry", (0, 0))
    neg = node(nt, "ShaderNodeVectorMath", (150, 0), operation="SCALE")
    neg.inputs["Scale"].default_value = -1.0
    L(geo.outputs["Incoming"], neg.inputs[0])
    col = node(nt, "ShaderNodeVectorMath", (300, 0), operation="MULTIPLY_ADD")
    col.inputs[1].default_value = (0.5, 0.5, 0.5)
    col.inputs[2].default_value = (0.5, 0.5, 0.5)
    L(neg.outputs[0], col.inputs[0])
    sep = node(nt, "ShaderNodeSeparateXYZ", (300, -200))
    L(neg.outputs[0], sep.inputs[0])
    el = math_node(nt, "ARCSINE", (450, -200))
    L(sep.outputs["Z"], el.inputs[0])
    az = math_node(nt, "ARCTAN2", (450, -350))
    L(sep.outputs["Y"], az.inputs[0])
    L(sep.outputs["X"], az.inputs[1])

    def lines(src, step, width, loc):
        m = math_node(nt, "PINGPONG", loc, b=step / 2)
        L(src.outputs[0], m.inputs[0])
        lt = math_node(nt, "LESS_THAN", (loc[0] + 150, loc[1]), b=width)
        L(m.outputs[0], lt.inputs[0])
        return lt

    le = lines(el, math.radians(15), 0.006, (600, -200))
    la = lines(az, math.radians(30), 0.006, (600, -350))
    mix1 = node(nt, "ShaderNodeMix", (900, 0), data_type="RGBA")
    L(le.outputs[0], mix1.inputs["Factor"])
    L(col.outputs[0], mix1.inputs[6])
    mix1.inputs[7].default_value = (1, 1, 1, 1)
    mix2 = node(nt, "ShaderNodeMix", (1050, 0), data_type="RGBA")
    L(la.outputs[0], mix2.inputs["Factor"])
    L(mix1.outputs[2], mix2.inputs[6])
    mix2.inputs[7].default_value = (0, 0, 0, 1)
    bg = node(nt, "ShaderNodeBackground", (1200, 0))
    L(mix2.outputs[2], bg.inputs["Color"])
    out = node(nt, "ShaderNodeOutputWorld", (1400, 0))
    L(bg.outputs[0], out.inputs[0])


def main():
    reset()
    global FACES
    if "--debug-faces" in ARGS:
        build_debug_world()
        FACES = OUT / "faces_debug"
        render_faces()
        return
    build_world()
    if "--faces" in ARGS:
        render_faces()
    if "--preview" in ARGS:
        render_preview()
    if "--planets" in ARGS:
        build_planets()


main()
