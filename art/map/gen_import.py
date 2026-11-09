"""T15: generuje skrypty importu Studio z meta JSON (lobby, propsy, planety).

Uruchom: python art/map/gen_import.py  (po build_lobby.py / build_props.py / build_sky.py)
Wynik: art/map/lobby/import_lobby.luau, art/map/props/import_props.luau — wklejane przez execute_luau (Edit).
"""
import json
from pathlib import Path

HERE = Path(__file__).parent
KEEP = ("material", "color", "transparency", "center", "size", "collide")


def compact(meta, extra_keys):
    out = {}
    for name, m in meta.items():
        e = {k: m[k] for k in extra_keys if k in m}
        e["parts"] = {p: {k: v[k] for k in KEEP} for p, v in m["parts"].items()}
        out[name] = e
    return json.dumps(out, separators=(",", ":"), ensure_ascii=False)


def render(template, meta_json, out):
    src = (HERE / template).read_text(encoding="utf-8").replace("__META__", meta_json)
    (HERE / out).write_text(src, encoding="utf-8")
    print(out, len(src), "znaków")


def main():
    lobby = json.loads((HERE / "lobby" / "lobby_meta.json").read_text(encoding="utf-8"))
    render("lobby/import_lobby.template.luau", compact(lobby, ("sign", "core", "footprint")), "lobby/import_lobby.luau")
    props_path = HERE / "props" / "props_meta.json"
    if props_path.exists() and (HERE / "props" / "import_props.template.luau").exists():
        props = json.loads(props_path.read_text(encoding="utf-8"))
        render("props/import_props.template.luau", compact(props, ("category", "biome", "fx", "light")),
               "props/import_props.luau")


if __name__ == "__main__":
    main()
