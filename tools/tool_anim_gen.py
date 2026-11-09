"""Animacje zamachu narzędzi (T09) jako KeyframeSequence R15 (.rbxmx).

Uruchom z katalogu repo:  python tools/tool_anim_gen.py
Wynik: art/anim/tool_<styl>.rbxmx — upload przez Open Cloud (assetType Animation),
ID w Shared/Config/ToolConfig.luau → ANIMS.

Style (przypisanie narzędzi w ToolConfig.STYLE):
- smash — zamach znad głowy i uderzenie w dół (kilof, młoty),
- slash — skręt tułowia i cięcie po skosie (topór, miecz, legendarny topór),
- thrust — przyciągnięcie i pchnięcie przed siebie (piła plazmowa),
- blast — celowanie i odrzut (działo).
Każda animacja ma znacznik „Hit” (chwila uderzenia — dźwięk, iskry, hit-stop).

Konwencja kątów (Transform jointów R15, CFrame.Angles = Rx·Ry·Rz):
ramię +X = do przodu/w górę, ramię +Z (prawe) = na zewnątrz, tułów +X = odchylenie do tyłu,
tułów +Y = skręt w lewo.
"""

from __future__ import annotations

import math
from pathlib import Path
from xml.sax.saxutils import escape

OUT_DIR = Path(__file__).resolve().parent.parent / "art" / "anim"

# Hierarchia póz R15 (rodzic → dzieci). Pozy bez wpisu w klatce = identyczność.
TREE: dict[str, list[str]] = {
    "HumanoidRootPart": ["LowerTorso"],
    "LowerTorso": ["UpperTorso", "RightUpperLeg", "LeftUpperLeg"],
    "UpperTorso": ["Head", "RightUpperArm", "LeftUpperArm"],
    "RightUpperArm": ["RightLowerArm"],
    "RightLowerArm": ["RightHand"],
    "LeftUpperArm": ["LeftLowerArm"],
    "LeftLowerArm": ["LeftHand"],
    "RightUpperLeg": ["RightLowerLeg"],
    "LeftUpperLeg": ["LeftLowerLeg"],
    "Head": [],
    "RightHand": [],
    "LeftHand": [],
    "RightLowerLeg": [],
    "LeftLowerLeg": [],
}

# Easing pozy (PoseEasingStyle / PoseEasingDirection): przejście z tej klatki do następnej.
LINEAR, CONSTANT, ELASTIC, CUBIC, BOUNCE = 0, 1, 2, 3, 4
IN, OUT, INOUT = 0, 1, 2

Pose = dict[str, tuple[float, ...]]  # joint → (rx, ry, rz[, px, py, pz]) w radianach / studs


def rot(rx: float, ry: float, rz: float) -> list[list[float]]:
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    mx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    my = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    mz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]

    return mul(mul(mx, my), mz)


def cframe_xml(v: tuple[float, ...]) -> str:
    rx, ry, rz = v[0], v[1], v[2]
    px, py, pz = (v[3], v[4], v[5]) if len(v) >= 6 else (0.0, 0.0, 0.0)
    m = rot(rx, ry, rz)
    parts = [f"<X>{px:.5f}</X>", f"<Y>{py:.5f}</Y>", f"<Z>{pz:.5f}</Z>"]
    for i in range(3):
        for j in range(3):
            parts.append(f"<R{i}{j}>{m[i][j]:.6f}</R{i}{j}>")
    return '<CoordinateFrame name="CFrame">' + "".join(parts) + "</CoordinateFrame>"


_ref = 0


def ref() -> str:
    global _ref
    _ref += 1
    return f"RBX{_ref:06d}"


def pose_xml(joint: str, pose: Pose, style: int, direction: int) -> str:
    v = pose.get(joint, (0.0, 0.0, 0.0))
    children = "".join(pose_xml(c, pose, style, direction) for c in TREE[joint])
    return (
        f'<Item class="Pose" referent="{ref()}"><Properties>'
        f'<string name="Name">{joint}</string>{cframe_xml(v)}'
        f'<float name="Weight">1</float>'
        f'<token name="EasingStyle">{style}</token><token name="EasingDirection">{direction}</token>'
        f"</Properties>{children}</Item>"
    )


def keyframe_xml(time: float, pose: Pose, style: int, direction: int, marker: str | None) -> str:
    mk = ""
    if marker:
        mk = (
            f'<Item class="KeyframeMarker" referent="{ref()}"><Properties>'
            f'<string name="Name">{escape(marker)}</string><string name="Value"></string>'
            f"</Properties></Item>"
        )
    return (
        f'<Item class="Keyframe" referent="{ref()}"><Properties>'
        f'<string name="Name">Keyframe</string><float name="Time">{time:.4f}</float>'
        f"</Properties>{pose_xml('HumanoidRootPart', pose, style, direction)}{mk}</Item>"
    )


# Klatka = (czas, pozy, easing do następnej, kierunek, znacznik)
Frame = tuple[float, Pose, int, int, str | None]

REST: Pose = {}

ANIMS: dict[str, list[Frame]] = {
    # Kierunek narzędzia w dłoni (zmierzone w Studio): ψ = ramię + łokieć + nadgarstek + odchylenie tułowia
    # (oś X, rad); ψ = 0 → do przodu, π/2 → w górę, π → do tyłu, −π/2 → w dół.
    # Zamach znad głowy: obuch za głową, uderzenie w dół przed sobą z przysiadem, powrót.
    "smash": [
        (0.00, REST, CUBIC, OUT, None),
        (
            0.17,
            {
                "UpperTorso": (0.28, -0.18, 0.0),
                "Head": (0.12, 0.1, 0.0),
                "RightUpperArm": (2.6, 0.0, 0.2),
                "RightLowerArm": (0.5, 0.0, 0.0),
                "RightHand": (0.0, 0.0, 0.0),
                "LeftUpperArm": (1.1, 0.0, -0.3),
                "LeftLowerArm": (0.6, 0.0, 0.0),
                "LowerTorso": (0.0, 0.0, 0.0, 0.0, 0.08, 0.0),
            },
            CUBIC,
            IN,
            None,
        ),
        (
            0.29,
            {
                "UpperTorso": (-0.42, 0.08, 0.0),
                "Head": (-0.1, 0.0, 0.0),
                "RightUpperArm": (0.75, 0.0, 0.05),
                "RightLowerArm": (0.15, 0.0, 0.0),
                "RightHand": (-1.1, 0.0, 0.0),
                "LeftUpperArm": (0.7, 0.0, -0.2),
                "LeftLowerArm": (0.3, 0.0, 0.0),
                "LowerTorso": (0.0, 0.0, 0.0, 0.0, -0.32, 0.0),
                "RightUpperLeg": (0.35, 0.0, 0.0),
                "RightLowerLeg": (-0.55, 0.0, 0.0),
                "LeftUpperLeg": (0.15, 0.0, 0.0),
                "LeftLowerLeg": (-0.35, 0.0, 0.0),
            },
            CONSTANT,
            IN,
            "Hit",
        ),
        (
            0.36,
            {
                "UpperTorso": (-0.38, 0.06, 0.0),
                "RightUpperArm": (0.8, 0.0, 0.05),
                "RightLowerArm": (0.18, 0.0, 0.0),
                "RightHand": (-1.0, 0.0, 0.0),
                "LeftUpperArm": (0.7, 0.0, -0.2),
                "LeftLowerArm": (0.3, 0.0, 0.0),
                "LowerTorso": (0.0, 0.0, 0.0, 0.0, -0.28, 0.0),
                "RightUpperLeg": (0.32, 0.0, 0.0),
                "RightLowerLeg": (-0.5, 0.0, 0.0),
                "LeftUpperLeg": (0.12, 0.0, 0.0),
                "LeftLowerLeg": (-0.3, 0.0, 0.0),
            },
            CUBIC,
            INOUT,
            None,
        ),
        (0.58, REST, LINEAR, IN, None),
    ],
    # Cięcie po skosie: skręt w prawo z ramieniem wysoko na zewnątrz, cięcie przez ciało w lewo w dół.
    "slash": [
        (0.00, REST, CUBIC, OUT, None),
        (
            0.15,
            {
                "LowerTorso": (0.0, -0.25, 0.0),
                "UpperTorso": (0.1, -0.75, 0.0),
                "Head": (0.0, 0.55, 0.0),
                "RightUpperArm": (2.1, 0.0, 1.0),
                "RightLowerArm": (0.7, 0.0, 0.0),
                "RightHand": (0.0, 0.0, 0.3),
                "LeftUpperArm": (0.6, 0.0, -0.5),
                "LeftLowerArm": (0.5, 0.0, 0.0),
            },
            CUBIC,
            IN,
            None,
        ),
        (
            0.26,
            {
                "LowerTorso": (0.0, 0.3, 0.0, 0.0, -0.12, 0.0),
                "UpperTorso": (-0.25, 0.8, 0.0),
                "Head": (0.0, -0.45, 0.0),
                "RightUpperArm": (1.15, 0.0, -0.75),
                "RightLowerArm": (0.1, 0.0, 0.0),
                "RightHand": (-1.15, 0.0, -0.2),
                "LeftUpperArm": (0.2, 0.0, -0.9),
                "LeftLowerArm": (0.3, 0.0, 0.0),
                "RightUpperLeg": (0.2, 0.0, 0.0),
                "LeftUpperLeg": (-0.15, 0.0, 0.0),
            },
            CONSTANT,
            IN,
            "Hit",
        ),
        (
            0.33,
            {
                "LowerTorso": (0.0, 0.28, 0.0, 0.0, -0.1, 0.0),
                "UpperTorso": (-0.22, 0.75, 0.0),
                "Head": (0.0, -0.42, 0.0),
                "RightUpperArm": (1.1, 0.0, -0.7),
                "RightLowerArm": (0.12, 0.0, 0.0),
                "RightHand": (-1.05, 0.0, -0.2),
                "LeftUpperArm": (0.2, 0.0, -0.85),
                "LeftLowerArm": (0.3, 0.0, 0.0),
                "RightUpperLeg": (0.18, 0.0, 0.0),
                "LeftUpperLeg": (-0.12, 0.0, 0.0),
            },
            CUBIC,
            INOUT,
            None,
        ),
        (0.55, REST, LINEAR, IN, None),
    ],
    # Pchnięcie: przyciągnięcie narzędzia do biodra, pchnięcie przed siebie z wypadem.
    "thrust": [
        (0.00, REST, CUBIC, OUT, None),
        (
            0.15,
            {
                "UpperTorso": (0.12, -0.45, 0.0),
                "Head": (0.0, 0.35, 0.0),
                "RightUpperArm": (0.4, 0.0, 0.3),
                "RightLowerArm": (1.3, 0.0, 0.0),
                "RightHand": (-1.2, 0.0, 0.0),
                "LeftUpperArm": (1.2, 0.0, -0.4),
                "LeftLowerArm": (1.1, 0.0, 0.0),
                "LowerTorso": (0.0, -0.15, 0.0, 0.0, 0.0, 0.25),
            },
            CUBIC,
            IN,
            None,
        ),
        (
            0.25,
            {
                "UpperTorso": (-0.3, 0.3, 0.0),
                "Head": (0.15, -0.2, 0.0),
                "RightUpperArm": (1.6, 0.0, 0.0),
                "RightLowerArm": (0.05, 0.0, 0.0),
                "RightHand": (-1.2, 0.0, 0.0),
                "LeftUpperArm": (1.5, 0.0, -0.6),
                "LeftLowerArm": (0.35, 0.0, 0.0),
                "LowerTorso": (0.0, 0.15, 0.0, 0.0, -0.2, -0.45),
                "RightUpperLeg": (0.55, 0.0, 0.0),
                "RightLowerLeg": (-0.6, 0.0, 0.0),
                "LeftUpperLeg": (-0.35, 0.0, 0.0),
            },
            CONSTANT,
            IN,
            "Hit",
        ),
        (
            0.33,
            {
                "UpperTorso": (-0.26, 0.26, 0.0),
                "RightUpperArm": (1.55, 0.0, 0.0),
                "RightLowerArm": (0.1, 0.0, 0.0),
                "RightHand": (-1.15, 0.0, 0.0),
                "LeftUpperArm": (1.45, 0.0, -0.6),
                "LeftLowerArm": (0.4, 0.0, 0.0),
                "LowerTorso": (0.0, 0.12, 0.0, 0.0, -0.18, -0.4),
                "RightUpperLeg": (0.5, 0.0, 0.0),
                "RightLowerLeg": (-0.55, 0.0, 0.0),
                "LeftUpperLeg": (-0.3, 0.0, 0.0),
            },
            CUBIC,
            INOUT,
            None,
        ),
        (0.55, REST, LINEAR, IN, None),
    ],
    # Działo: szybkie wycelowanie dwiema rękami, strzał, odrzut do tyłu, powrót.
    "blast": [
        (0.00, REST, CUBIC, OUT, None),
        (
            0.12,
            {
                "UpperTorso": (-0.1, 0.25, 0.0),
                "Head": (-0.05, -0.2, 0.0),
                "RightUpperArm": (0.35, 0.0, 0.1),
                "RightLowerArm": (0.6, 0.0, 0.0),
                "RightHand": (-0.85, 0.0, 0.0),
                "LeftUpperArm": (0.9, 0.0, -0.55),
                "LeftLowerArm": (0.9, 0.0, 0.0),
                "LowerTorso": (0.0, 0.0, 0.0, 0.0, -0.12, 0.0),
            },
            LINEAR,
            IN,
            None,
        ),
        (
            0.16,
            {
                "UpperTorso": (-0.12, 0.25, 0.0),
                "Head": (-0.05, -0.2, 0.0),
                "RightUpperArm": (0.35, 0.0, 0.1),
                "RightLowerArm": (0.6, 0.0, 0.0),
                "RightHand": (-0.85, 0.0, 0.0),
                "LeftUpperArm": (0.9, 0.0, -0.55),
                "LeftLowerArm": (0.9, 0.0, 0.0),
                "LowerTorso": (0.0, 0.0, 0.0, 0.0, -0.14, 0.0),
            },
            CUBIC,
            OUT,
            "Hit",
        ),
        (
            0.26,
            {
                "UpperTorso": (0.3, 0.15, 0.0),
                "Head": (0.2, -0.1, 0.0),
                "RightUpperArm": (0.55, 0.0, 0.15),
                "RightLowerArm": (0.65, 0.0, 0.0),
                "RightHand": (-0.55, 0.0, 0.0),
                "LeftUpperArm": (1.1, 0.0, -0.5),
                "LeftLowerArm": (1.0, 0.0, 0.0),
                "LowerTorso": (0.0, 0.0, 0.0, 0.0, -0.05, 0.35),
                "RightUpperLeg": (-0.2, 0.0, 0.0),
                "LeftUpperLeg": (0.25, 0.0, 0.0),
            },
            CUBIC,
            INOUT,
            None,
        ),
        (0.6, REST, LINEAR, IN, None),
    ],
}


def build(name: str, frames: list[Frame]) -> str:
    kfs = "".join(keyframe_xml(t, p, s, d, m) for t, p, s, d, m in frames)
    return (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">'
        f'<Item class="KeyframeSequence" referent="{ref()}"><Properties>'
        f'<string name="Name">Tool_{name}</string><bool name="Loop">false</bool>'
        f'<token name="Priority">2</token>'
        f"</Properties>{kfs}</Item></roblox>"
    )


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, frames in ANIMS.items():
        path = OUT_DIR / f"tool_{name}.rbxmx"
        path.write_text(build(name, frames), encoding="utf-8")
        print(f"{path.relative_to(OUT_DIR.parent.parent)}  ({len(frames)} klatek)")


if __name__ == "__main__":
    main()
