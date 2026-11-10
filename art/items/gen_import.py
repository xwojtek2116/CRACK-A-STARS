"""T21: generuje art/items/import_items.luau z szablonu i items_meta.json (zwięzły JSON, tylko pola potrzebne w Studio).

Uruchom: python art/items/gen_import.py [--themes Iron,Lava]  (po build_item.py)
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).parent
KEEP_PART = ("material", "color", "center", "anim")
KEEP_ITEM = ("name", "rarity", "particles")


def main():
    argv = sys.argv[1:]
    themes = argv[argv.index("--themes") + 1].split(",") if "--themes" in argv else None
    meta = json.loads((HERE / "items_meta.json").read_text(encoding="utf-8"))
    out = {}
    for iid, m in meta.items():
        if themes and m["theme"] not in themes:
            continue
        t = {k: m[k] for k in KEEP_ITEM if m.get(k)}
        t["parts"] = {p: {k: v[k] for k in KEEP_PART if k in v} for p, v in m["parts"].items()}
        out[iid] = t
    src = (HERE / "import_items.template.luau").read_text(encoding="utf-8")
    src = src.replace("-- Szablon importu modeli łupu (T21). Plik import_items.luau generuje",
                      "-- WYGENEROWANE (T21) z import_items.template.luau przez")
    src = src.replace("__META__", json.dumps(out, separators=(",", ":"), ensure_ascii=False))
    (HERE / "import_items.luau").write_text(src, encoding="utf-8")
    print("import_items.luau:", len(src), "znaków,", len(out), "przedmiotów")


if __name__ == "__main__":
    main()
