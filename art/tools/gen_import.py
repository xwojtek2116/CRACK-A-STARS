"""T11: generuje art/tools/import_tools.luau z szablonu i tools_meta.json (zwięzły JSON, tylko pola potrzebne w Studio).

Uruchom: python art/tools/gen_import.py  (po build_tools.py)
"""
import json
from pathlib import Path

HERE = Path(__file__).parent
KEEP_PART = ("material", "color", "transparency", "center", "spin")
KEEP_TOOL = ("name", "tier", "exclusive", "grip", "trail", "particles")


def main():
    meta = json.loads((HERE / "tools_meta.json").read_text(encoding="utf-8"))
    out = {}
    for tid, m in meta.items():
        t = {k: m[k] for k in KEEP_TOOL if m.get(k) is not None}
        t["parts"] = {p: {k: v[k] for k in KEEP_PART if k in v} for p, v in m["parts"].items()}
        out[tid] = t
    src = (HERE / "import_tools.template.luau").read_text(encoding="utf-8")
    src = src.replace("-- Szablon importu narzędzi (T11). Plik import_tools.luau generuje",
                      "-- WYGENEROWANE (T11) z import_tools.template.luau przez")
    src = src.replace("__META__", json.dumps(out, separators=(",", ":"), ensure_ascii=False))
    (HERE / "import_tools.luau").write_text(src, encoding="utf-8")
    print("import_tools.luau:", len(src), "znaków")


if __name__ == "__main__":
    main()
