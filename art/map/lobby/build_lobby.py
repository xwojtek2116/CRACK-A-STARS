"""build_lobby.py — budynki lobby Crack a Stars (T15), styl stacji kosmicznej (Blender 5.x, tryb w tle).

Uruchom:
  E:\\blender\\blender.exe -b --factory-startup -P art/map/lobby/build_lobby.py -- [--only ToolShop,Garage] [--render]

Każda stacja = wspólny moduł (cokół, kadłub z fazami, żebra, narożne słupy, gzyms, wejście z daszkiem, iluminatory)
+ własny element rozpoznawczy na dachu/fasadzie. Części wg materiału Roblox (MeshPart):
  Base (Concrete, kolizja) · Shell (Metal jasny, kolizja) · Frame (Metal ciemny) · Trim (DiamondPlate)
  Glass (Glass) · Glow (Neon w kolorze stacji) · Accent (Metal w kolorze stacji)
Układ lokalny: przód (wejście) = −Y Blendera = −Z Roblox (LookVector modelu), z = 0 = poziom podłogi lobby.
Wyjście: art/map/lobby/lobby.fbx + lobby.blend + lobby_meta.json (części, środki/rozmiary w studs, kotwica szyldu),
z --render: vault/_img/T15 lobby.png
"""

import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from maplib import (Asset, box, dome, export_fbx, frame, frame_camera, hull, merge, rbox, ring_band, setup_render,  # noqa: E402
                    torus, xcyl, ycyl, zcyl)

ROOT = HERE.parents[2]
IMG = ROOT / "vault" / "_img"
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
BUDGET = 10000

# kolory stacji = kolory pasów z blockoutu T36 (DisplayName/Stripe)
STATIONS = {
    "ToolShop": "#FFAA3C", "Garage": "#3CC8FF", "SellStation": "#50E678", "Upgrades": "#FFDC50",
    "IndexHall": "#AA78FF", "RobuxShop": "#FF5AC8", "DailyCodes": "#3CF0D2", "RebirthPortal": "#FF5AC8",
}


def palette(glow):
    g = glow.lstrip("#")
    r, gg, b = (int(g[i:i + 2], 16) for i in (0, 2, 4))
    acc = "#%02X%02X%02X" % (int(r * 0.55), int(gg * 0.55), int(b * 0.55))
    return {
        "hull": ("#C9CDE0", "Metal", 0), "hull_dk": ("#3B3F5E", "Metal", 0), "trim": ("#262A42", "DiamondPlate", 0),
        "base": ("#45435E", "Concrete", 0), "glass": ("#86D8FF", "Glass", 0.45), "glow": (glow, "Neon", 0),
        "accent": (acc, "Metal", 0),
    }


# ---------------------------------------------------------------- wspólny moduł

def module(a, W, D, H, door_w=12, door_h=11, hangar=False, windows=True):
    """Kadłub stacji. Zwraca z wierzchu gzymsu (dach)."""
    z0 = 1.2
    a.add("Base", "base", rbox(W + 8, D + 8, z0, (0, 0, z0 / 2), r=0.35), collide=True)
    a.add("Glow", "glow", ring_band(W + 8, D + 8, 0.22, z0 - 0.3, t=0.12))
    a.add("Shell", "hull", rbox(W, D, H, (0, 0, z0 + H / 2), r=1.0), collide=True)
    # żebra i narożne słupy
    for f in (0.36, 0.7):
        a.add("Frame", "hull_dk", ring_band(W - 0.4, D - 0.4, 0.7, z0 + H * f, t=0.35))
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.add("Frame", "hull_dk", rbox(2.0, 2.0, H + 0.6, (sx * (W / 2 - 0.3), sy * (D / 2 - 0.3), z0 + H / 2), r=0.3))
    # gzyms + pas Neon pod nim
    top = z0 + H
    a.add("Frame", "hull_dk", rbox(W + 2.4, D + 2.4, 1.4, (0, 0, top + 0.5), r=0.45))
    a.add("Glow", "glow", ring_band(W + 0.2, D + 0.2, 0.35, top - 0.6, t=0.18))
    a.add("Trim", "trim", rbox(W - 3, D - 3, 0.6, (0, 0, top + 1.4), r=0.2))
    # wejście
    yf = -D / 2
    if hangar:
        a.add("Frame", "hull_dk", frame(door_w + 3, door_h + 2, 1.5, 1.6, (0, yf - 0.5, z0 + (door_h + 2) / 2)))
        for i in range(int(door_h / 1.25)):
            a.add("Trim", "trim", box(door_w, 0.5, 1.0, (0, yf - 0.2, z0 + 0.6 + i * 1.25)))
        a.add("Glow", "glow", box(door_w + 1.2, 0.3, 0.3, (0, yf - 1.35, z0 + door_h + 1.5)))
        for sx in (-1, 1):
            a.add("Glow", "glow", box(0.3, 0.3, door_h + 1.4, (sx * (door_w / 2 + 0.6), yf - 1.35, z0 + (door_h + 1.4) / 2)))
        canopy_z = z0 + door_h + 2.4
    else:
        a.add("Frame", "hull_dk", frame(door_w + 3, door_h + 2, 1.3, 1.4, (0, yf - 0.4, z0 + (door_h + 2) / 2)))
        a.add("Glass", "glass", box(door_w, 0.4, door_h, (0, yf - 0.05, z0 + door_h / 2)))
        a.add("Frame", "hull_dk", box(0.5, 0.6, door_h, (0, yf - 0.2, z0 + door_h / 2)))  # podział drzwi
        a.add("Glow", "glow", frame(door_w + 3.6, door_h + 2.6, 0.32, 0.4, (0, yf - 1.2, z0 + (door_h + 2) / 2 + 0.3)))
        canopy_z = z0 + door_h + 2.6
    a.add("Frame", "hull_dk", rbox(door_w + 8, 6.5, 0.8, (0, yf - 3.0, canopy_z), r=0.25))
    a.add("Glow", "glow", box(door_w + 8, 0.3, 0.3, (0, yf - 6.2, canopy_z - 0.45)))
    for sx in (-1, 1):  # wsporniki daszka
        a.add("Frame", "hull_dk", box(0.6, 6.0, 0.6, (sx * (door_w / 2 + 3.4), yf - 3.0, canopy_z - 0.9),
                                      rot=Matrix.Rotation(math.radians(-18), 4, "X")))
    if windows:
        # przeszklenia frontu po bokach wejścia
        ww = (W - door_w - 12) / 2
        if ww > 3:
            for sx in (-1, 1):
                cx = sx * (door_w / 2 + 3 + ww / 2 + 1)
                a.add("Glass", "glass", box(ww, 0.3, 3.2, (cx, yf - 0.05, z0 + H * 0.5)))
                a.add("Frame", "hull_dk", frame(ww + 1.2, 4.4, 0.6, 0.7, (cx, yf - 0.25, z0 + H * 0.5)))
        # iluminatory na bokach
        for sx in (-1, 1):
            for fy in (-0.22, 0.22):
                cy, cz = fy * D, z0 + H * 0.53
                a.add("Glass", "glass", xcyl(sx * W / 2 - 0.3, sx * W / 2 + 0.3, 2.0, cy, cz, seg=12))
                M = Matrix.Translation((sx * (W / 2 + 0.25), cy, cz)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
                a.add("Frame", "hull_dk", torus(2.3, 0.45, M, seg=14, sides=5))
    # kotwica szyldu (SurfaceGui z blockoutu): środek na fasadzie nad daszkiem
    sign_z = canopy_z + 0.4 + 3.2
    a.extra["sign"] = {"center": [0, round(sign_z, 3), round(yf - 0.55, 3)], "size": [round(min(W * 0.78, 36), 2), 5.5, 0.8]}
    a.extra["footprint"] = [W + 8, D + 8]
    # wierzch dachu
    return top + 1.7


def dish(a, c, r=4.0, tilt=35, yaw=0):
    """Antena talerzowa na maszcie."""
    x, y, z = c
    a.add("Frame", "hull_dk", zcyl(z, z + 3.2, 0.45, 8))
    _shift_last(a, "Frame", (x, y, 0))
    M = (Matrix.Translation((x, y, z + 3.4)) @ Matrix.Rotation(math.radians(yaw), 4, "Z")
         @ Matrix.Rotation(math.radians(180 - tilt), 4, "X"))
    d = dome(r, (0, 0, 0), u=16, v=4, squash=0.35)
    d.transform(M)
    a.add("Shell", "hull", d)
    a.add("Accent", "accent", zcyl(z + 3.2, z + 5.6, 0.18, 6))
    _shift_last(a, "Accent", (x, y, 0))
    a.add("Glow", "glow", ico_glow((x, y, z + 5.8), 0.45))


def ico_glow(c, r):
    from maplib import ico
    return ico(r, c, sub=1)


def beacon(a, c, h=6):
    x, y, z = c
    a.add("Frame", "hull_dk", zcyl(z, z + h, 0.3, 6))
    _shift_last(a, "Frame", (x, y, 0))
    a.add("Glow", "glow", ico_glow((x, y, z + h + 0.3), 0.55))


# ---------------------------------------------------------------- stacje

def tool_shop(a):
    W, D, H = 38, 28, 22
    top = module(a, W, D, H)
    # godło: skrzyżowany kilof i młot na postumencie
    a.add("Frame", "hull_dk", rbox(10, 5, 2.2, (0, 0, top + 1.1), r=0.4))
    zc = top + 9.5
    for ang, kind in ((35, "pick"), (-35, "hammer")):
        R = Matrix.Translation((0, 0, zc)) @ Matrix.Rotation(math.radians(ang), 4, "Y")
        h = box(1.3, 1.3, 15, (0, 0, 0))
        h.transform(R)
        a.add("Accent", "accent", h)
        if kind == "pick":
            head = torus(7.0, 0.9, Matrix.Rotation(math.pi / 2, 4, "X"), seg=10, sides=6,
                         a0=math.radians(35), a1=math.radians(145))
            head.transform(Matrix.Translation((0, 0, -0.5)))
            head.transform(R @ Matrix.Translation((0, 0, 0.5)))
            a.add("Shell", "hull", head)
            edge = torus(7.6, 0.25, Matrix.Rotation(math.pi / 2, 4, "X"), seg=10, sides=4,
                         a0=math.radians(38), a1=math.radians(142))
            edge.transform(R)
            a.add("Glow", "glow", edge)
        else:
            hd = rbox(6.5, 3.4, 3.4, (0, 0, 7.0), r=0.5)
            hd.transform(R)
            a.add("Shell", "hull", hd)
            band = box(0.6, 3.8, 3.8, (2.2, 0, 7.0))
            band.transform(R)
            a.add("Glow", "glow", band)
    # wywietrzniki na dachu
    for sx in (-1, 1):
        a.add("Trim", "trim", rbox(5, 4, 1.6, (sx * 13, 7, top + 0.8), r=0.3))
        for i in range(4):
            a.add("Frame", "hull_dk", box(4.6, 0.25, 0.25, (sx * 13, 5.6 + i * 0.9, top + 1.7)))


def garage(a):
    W, D, H = 46, 32, 20
    top = module(a, W, D, H, door_w=26, door_h=13, hangar=True, windows=False)
    # iluminatory boczne zostają z modułu? (windows=False) — dodajemy pas okien na bokach
    for sx in (-1, 1):
        a.add("Glass", "glass", box(0.3, D * 0.6, 2.4, (sx * (W / 2 + 0.05), 0, 1.2 + H * 0.62)))
    dish(a, (-14, 6, top), r=4.5, tilt=40, yaw=-30)
    beacon(a, (15, -8, top), h=5)
    beacon(a, (15, 8, top), h=3.5)
    # lądowisko na dachu: krąg z pasami
    a.add("Trim", "trim", zcyl(top, top + 0.3, 7.5, 20))
    a.add("Glow", "glow", torus(6.6, 0.18, Matrix.Translation((4, 2, top + 0.35)), seg=24, sides=4))
    _shift_last(a, "Trim", (4, 2, 0))


def _shift_last(a, part, v):
    bm = a.parts[part][1][-1]
    for vv in bm.verts:
        vv.co += Vector(v)


def sell_station(a):
    W, D, H = 36, 28, 21
    top = module(a, W, D, H)
    # kontenery cargo po bokach
    for sx in (-1, 1):
        cx = sx * (W / 2 + 6.5)
        a.add("Accent", "accent", rbox(8, 14, 7, (cx, 4, 1.2 + 3.5), r=0.3), collide=True)
        for i in range(5):
            a.add("Frame", "hull_dk", box(8.3, 0.4, 7.2, (cx, -2.4 + i * 2.6, 1.2 + 3.6)))
        a.add("Glow", "glow", box(8.4, 0.25, 0.25, (cx, -3.05, 1.2 + 6.4)))
    # moneta na dachu (pionowy dysk przodem do placu) w pierścieniu Neon
    zc = top + 7.5
    a.add("Frame", "hull_dk", rbox(6, 4, 2.0, (0, 0, top + 1.0), r=0.4))
    a.add("Frame", "hull_dk", box(1.2, 1.2, 3.5, (0, 0, top + 2.5)))
    a.add("Accent", "accent", ycyl(-0.7, 0.7, 5.2, zc, seg=24))
    a.add("Shell", "hull", ycyl(-0.9, 0.9, 3.6, zc, seg=24))
    a.add("Glow", "glow", torus(5.6, 0.32, Matrix.Translation((0, 0, zc)) @ Matrix.Rotation(math.pi / 2, 4, "X"),
                                seg=28, sides=5))
    a.add("Glow", "glow", box(0.8, 2.2, 3.6, (0, 0, zc)))  # znak w środku monety


def upgrades(a):
    W, D, H = 34, 26, 20
    top = module(a, W, D, H)
    # wieża ze strzałkami w górę
    a.add("Shell", "hull", zcyl(top, top + 13, 4.2, 16, r_top=3.4), collide=False)
    a.add("Frame", "hull_dk", zcyl(top + 13, top + 14.2, 4.0, 16))
    for i in range(3):
        z = top + 3 + i * 3.4
        for sx in (-1, 1):
            arm = box(4.0, 0.6, 0.9, (0, 0, 0))
            arm.transform(Matrix.Translation((sx * 1.5, -4.05 + i * 0.12, z)) @ Matrix.Rotation(math.radians(-sx * 35), 4, "Y"))
            a.add("Glow", "glow", arm)
    a.add("Glow", "glow", zcyl(top + 14.2, top + 14.8, 2.4, 16))
    beacon(a, (0, 0, top + 14.8), h=4)
    for sx in (-1, 1):
        a.add("Trim", "trim", rbox(5, 5, 1.4, (sx * 11, 6, top + 0.7), r=0.3))


def index_hall(a):
    W, D, H = 40, 30, 22
    top = module(a, W, D, H)
    # obserwatorium: szklana kopuła z żebrami i teleskopem
    R = 11
    a.add("Frame", "hull_dk", zcyl(top - 0.2, top + 1.2, R + 0.8, 24))
    a.add("Glass", "glass", dome(R, (0, 2, top + 1.2), u=20, v=5, squash=0.75))
    for k in range(6):
        M = Matrix.Translation((0, 2, top + 1.2)) @ Matrix.Rotation(k * math.pi / 6, 4, "Z") @ Matrix.Diagonal((1, 1, 0.75, 1))
        a.add("Frame", "hull_dk", torus(R + 0.15, 0.3, M @ Matrix.Rotation(math.pi / 2, 4, "X"), seg=16, sides=4,
                                        a0=0, a1=math.pi))
    tel = ycyl(-9, 3, 1.6, 0, seg=12, r_end=2.2)
    tel.transform(Matrix.Translation((0, 2, top + 8.6)) @ Matrix.Rotation(math.radians(-35), 4, "X"))
    a.add("Accent", "accent", tel)
    a.add("Glow", "glow", torus(2.4, 0.2, Matrix.Translation((0, 2, top + 1.3)), seg=16, sides=4))
    # kolumnada przed wejściem
    for sx in (-1, 1):
        for k in (0, 1):
            x = sx * (9 + k * 5)
            a.add("Frame", "hull_dk", zcyl(1.2, 1.2 + 12.5, 0.9, 10))
            _shift_last(a, "Frame", (x, -D / 2 - 5.5, 0))
            a.add("Glow", "glow", zcyl(1.2 + 12.5, 1.2 + 12.9, 1.1, 10))
            _shift_last(a, "Glow", (x, -D / 2 - 5.5, 0))


def robux_shop(a):
    W, D, H = 40, 30, 23
    top = module(a, W, D, H)
    # wielki klejnot na postumencie + 4 małe
    a.add("Frame", "hull_dk", zcyl(top, top + 2.4, 5.0, 8, r_top=3.6))
    zc = top + 9.5

    def gem(c, r, h):
        pts = [(c[0] + r * math.cos(k * math.pi / 4), c[1] + r * math.sin(k * math.pi / 4), c[2]) for k in range(8)]
        pts += [(c[0] + r * 0.65 * math.cos(k * math.pi / 4 + math.pi / 8), c[1] + r * 0.65 * math.sin(k * math.pi / 4 + math.pi / 8), c[2] + h * 0.28) for k in range(8)]
        pts += [(c[0], c[1], c[2] - h), (c[0], c[1], c[2] + h * 0.35)]
        return hull(pts)

    a.add("Glow", "glow", gem((0, 0, zc), 5.2, 6.5))
    a.add("Glass", "glass", gem((0, 0, zc), 5.8, 7.2))
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.add("Glow", "glow", gem((sx * 14, sy * 9, top + 2.6), 1.4, 2.0))
            a.add("Frame", "hull_dk", zcyl(top, top + 0.8, 1.6, 8))
            _shift_last(a, "Frame", (sx * 14, sy * 9, 0))
    # szklana fasada-pryzmat nad wejściem
    a.add("Glass", "glass", box(W * 0.62, 0.4, H * 0.3, (0, -D / 2 - 0.05, 1.2 + H * 0.8)))


def daily_codes(a):
    W, D, H = 32, 26, 20
    top = module(a, W, D, H)
    dish(a, (9, 4, top), r=4.0, tilt=45, yaw=20)
    # holograficzny prezent: krawędzie sześcianu (Neon) + kokarda
    c = Vector((-7, 0, top + 6.5))
    s = 5.0
    a.add("Frame", "hull_dk", rbox(7, 7, 1.6, (c.x, c.y, top + 0.8), r=0.3))
    for ax in range(3):
        for u in (-1, 1):
            for v in (-1, 1):
                size = [0.35, 0.35, 0.35]
                size[ax] = s
                pos = [0, 0, 0]
                o = [i for i in range(3) if i != ax]
                pos[o[0]], pos[o[1]] = u * s / 2, v * s / 2
                a.add("Glow", "glow", box(*size, tuple(c + Vector(pos))))
    a.add("Accent", "accent", box(s * 0.98, 0.6, s * 0.98, tuple(c)))  # wstążka
    a.add("Accent", "accent", box(0.6, s * 0.98, s * 0.98, tuple(c)))
    for sx in (-1, 1):
        bow = torus(1.0, 0.3, Matrix.Translation(c + Vector((sx * 0.9, 0, s / 2 + 0.6))) @ Matrix.Rotation(math.pi / 2, 4, "X"),
                    seg=10, sides=4)
        a.add("Glow", "glow", bow)


def rebirth_portal(a):
    """Pionowy pierścień portalu (płaszczyzna XZ, przód −Y) na schodkowym cokole + pylony."""
    R, zc = 12.0, 15.5
    a.add("Base", "base", rbox(28, 14, 1.2, (0, 0, 0.6), r=0.35), collide=True)
    a.add("Base", "base", rbox(22, 10, 1.2, (0, 0, 1.8), r=0.35))
    a.add("Glow", "glow", ring_band(28, 14, 0.2, 0.95, t=0.12))
    ringM = Matrix.Translation((0, 0, zc)) @ Matrix.Rotation(math.pi / 2, 4, "X")
    a.add("Shell", "hull", torus(R, 1.7, ringM, seg=40, sides=8), collide=True)
    a.add("Glow", "glow", torus(R - 1.9, 0.35, ringM, seg=40, sides=5))
    a.add("Glow", "glow", torus(R + 1.85, 0.22, ringM, seg=40, sides=4))
    for k in range(12):
        ang = k * math.pi / 6
        M = ringM @ Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation((R, 0, 0))
        clamp = rbox(2.4, 4.6, 4.4, (0, 0, 0), r=0.35)
        clamp.transform(M)
        a.add("Frame", "hull_dk", clamp)
    for sx in (-1, 1):
        a.add("Frame", "hull_dk", rbox(3.2, 4.0, 12, (sx * (R + 3.5), 0, 2.4 + 6), r=0.4))
        a.add("Glow", "glow", box(0.3, 4.2, 9, (sx * (R + 3.5) - sx * 1.65, 0, 2.4 + 6)))
        a.add("Accent", "accent", rbox(4.0, 4.8, 1.2, (sx * (R + 3.5), 0, 2.4 + 12.6), r=0.3))
    a.extra["sign"] = {"center": [0, round(zc + R + 4.5, 3), 0], "size": [16, 4, 0.8]}
    a.extra["core"] = [0, zc, 0]
    a.extra["footprint"] = [28, 14]


BUILDERS = {"ToolShop": tool_shop, "Garage": garage, "SellStation": sell_station, "Upgrades": upgrades,
            "IndexHall": index_hall, "RobuxShop": robux_shop, "DailyCodes": daily_codes, "RebirthPortal": rebirth_portal}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    only = None
    for arg in ARGS:
        if arg.startswith("--only"):
            only = arg.split("=", 1)[1].split(",") if "=" in arg else None
    names = [n for n in BUILDERS if only is None or n in only]
    meta, all_obs = {}, []
    for i, name in enumerate(names):
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
        a = Asset(name, palette(STATIONS[name]))
        BUILDERS[name](a)
        obs = a.build(coll, tile=8.0)
        meta[name] = a.meta(obs)
        meta[name]["ok"] = meta[name]["tris"] <= BUDGET
        all_obs += list(obs.values())
        # podgląd: stacje obok siebie
        for ob in obs.values():
            ob.location.x += (i % 4) * 70
            ob.location.y += (i // 4) * 70
        print(f"{name}: {meta[name]['tris']} tris ok={meta[name]['ok']}")
    # eksport w położeniu lokalnym (przesunięcie podglądu cofnięte)
    for i, name in enumerate(names):
        for ob in bpy.data.collections[name].objects:
            ob.location = (0, 0, 0)
    export_fbx(HERE / "lobby.fbx", all_obs)
    (HERE / "lobby_meta.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "lobby.blend"))
    if "--render" in ARGS:
        for i, name in enumerate(names):
            for ob in bpy.data.collections[name].objects:
                ob.location = ((i % 4) * 70, (i // 4) * 70, 0)
        setup_render(1920, 1080)
        frame_camera(all_obs, direction=(0.25, -1.0, 0.7), lens=35, margin=0.75)
        bpy.context.scene.render.filepath = str(IMG / "T15 lobby.png")
        bpy.ops.render.render(write_still=True)
    print("LOBBY_DONE")


main()
