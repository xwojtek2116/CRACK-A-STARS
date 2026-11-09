"""Generuje art/stars/toxic/import_toxic_v2.luau z szablonu (punkty zaczepienia z Blendera, rozmiary i kolory z JSON)."""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = HERE.parents[2] / "game" / "src" / "shared" / "Config" / "Data"
stars = json.loads((DATA / "Stars.json").read_text(encoding="utf-8"))
theme = json.loads((DATA / "Themes.json").read_text(encoding="utf-8"))["themes"]["Toxic"]
anchors = json.loads((HERE / "toxic_v2_anchors.json").read_text(encoding="utf-8"))
anchors.pop("note", None)
sizes = {s: stars["classes"][s]["size"] for s in ("Small", "Medium", "Large", "Huge")}
src = (HERE / "import_toxic_v2.template.luau").read_text(encoding="utf-8")
out = (src.replace("__ANCHORS__", json.dumps(anchors)).replace("__SIZES__", json.dumps(sizes))
       .replace("__COLORS__", json.dumps({"color": theme["color"], "glow": theme["glow"]})))
(HERE / "import_toxic_v2.luau").write_text(out.replace("Szablon: art/stars/toxic/import_toxic_v2.template.luau,\n-- gotowy", "WYGENEROWANE — nie edytuj; gotowy"), encoding="utf-8")
print("ok", len(out))
