"""sync_vault.py — generuje notatki katalogu w vaulcie z game/src/shared/Config/Data/*.json.

Uruchom z katalogu projektu:  python tools/sync_vault.py
JSON jest jedynym źródłem liczb. Notatka ma część generowaną (nadpisywaną) i sekcję
`## Notatki` pod znacznikiem NOTES_MARK, której skrypt nigdy nie rusza.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "game" / "src" / "shared" / "Config" / "Data"
VAULT = ROOT / "vault"
NOTES_MARK = "<!-- notatki: wszystko poniżej edytuj ręcznie, sync_vault.py tego nie nadpisze -->"
DEFAULT_NOTES = "## Notatki\n\n"
KEEP_FIELDS = ("model",)


def load(name: str) -> dict:
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def money(n: float) -> str:
    return f"${n:,.0f}".replace(",", " ")


def yaml_value(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, list):
        return "[" + ", ".join(yaml_value(x) for x in v) + "]"
    s = str(v)
    return '"' + s.replace('"', '\\"') + '"'


def write_note(path: Path, props: dict, body: str, written: set[Path]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    notes = DEFAULT_NOTES
    if path.exists():
        old = path.read_text(encoding="utf-8")
        if NOTES_MARK in old:
            notes = old.split(NOTES_MARK, 1)[1].lstrip("\n")
        # Pola ustawiane przez taski (np. model: gotowy) przeżywają synchronizację.
        if old.startswith("---"):
            for line in old.split("---", 2)[1].splitlines():
                key = line.split(":", 1)[0]
                if key in KEEP_FIELDS and ":" in line:
                    props[key] = line.split(":", 1)[1].strip().strip('"')
    front = "---\n" + "\n".join(f"{k}: {yaml_value(v)}" for k, v in props.items()) + "\n---\n"
    text = f"{front}{body.rstrip()}\n\n{NOTES_MARK}\n{notes}"
    if not path.exists() or path.read_text(encoding="utf-8") != text:
        path.write_text(text, encoding="utf-8", newline="\n")
        print(f"  zapisano {path.relative_to(VAULT)}")
    written.add(path)


def rarity_tag(r: str) -> str:
    return f"#rarity/{r.lower()}"


def main() -> int:
    rar = load("Rarities")
    themes = load("Themes")
    items = load("Items")
    stars = load("Stars")
    tools = load("Tools")
    vehicles = load("Vehicles")
    written: set[Path] = set()

    order = themes["order"]

    def type_weights(size_id: str) -> dict[str, float]:
        boost = stars["classes"][size_id]["rareTypeBoost"]
        raw = {tid: themes["themes"][tid]["weight"] * (1 + (boost - 1) * i / max(1, len(order) - 1)) for i, tid in enumerate(order)}
        total = sum(raw.values())
        return {k: v / total for k, v in raw.items()}

    # --- Łup ---
    shapes = items["shapes"]
    for it in items["items"]:
        r = rar["tiers"][it["rarity"]]
        t = themes["themes"][it["theme"]]
        income = r["incomePerSec"] * t["incomeMult"]
        props = {
            "typ": "przedmiot",
            "id": it["id"],
            "nazwa": it["name"],
            "motyw": it["theme"],
            "rzadkosc": it["rarity"],
            "szansa": f"1/{r['oneIn']}",
            "dochod_s": round(income, 2),
            "model": "brak",
            "tags": [f"lup/{it['theme'].lower()}", f"rarity/{it['rarity'].lower()}"],
        }
        src = "tylko z [[Supernova]] (event)" if it.get("supernovaOnly") else f"z gwiazdy [[{t['displayName']}]]"
        body = (
            f"# {it['name']}\n\n"
            f"> [!{it['rarity'].lower()}] {it['rarity']} · {src} · szansa **1/{r['oneIn']}**\n\n"
            f"| Pole | Wartość |\n| --- | --- |\n"
            f"| Dochód w bazie | **{money(income)}/s** (Shiny ×{rar['mutations']['Shiny']['incomeMult']}, Golden ×{rar['mutations']['Golden']['incomeMult']}) |\n"
            f"| Kształt | {shapes[it['rarity']]} |\n"
            f"| Styl rodzaju | {t['shape']} |\n"
            f"| Kolor / poświata | `{t['color']}` / `{t['glow']}` |\n"
            f"| Model | `art/items/{it['theme'].lower()}/{it['id']}.blend` |\n\n"
            f"![[{it['id']}.png|220]]\n"
        )
        write_note(VAULT / "04 Łup" / t["displayName"] / f"{it['name']}.md", props, body, written)

    # --- Rodzaje gwiazd ---
    for i, tid in enumerate(order):
        t = themes["themes"][tid]
        loot = "\n".join(
            f"| [[{x['name']}]] | {x['rarity']} | 1/{rar['tiers'][x['rarity']]['oneIn']} | {money(rar['tiers'][x['rarity']]['incomePerSec'] * t['incomeMult'])}/s |"
            for x in items["items"]
            if x["theme"] == tid and not x.get("supernovaOnly")
        )
        sizes = "\n".join(
            f"| [[{sid}]] | {stars['classes'][sid]['size']} | {stars['classes'][sid]['hp']:,} | {type_weights(sid)[tid]:.1%} |"
            for sid in stars["order"]
            if not stars["classes"][sid]["event"]
        )
        props = {"typ": "rodzaj", "rodzaj": tid, "nazwa": t["displayName"], "nr": i + 1, "mnoznik": t["incomeMult"],
                 "waga": t["weight"], "model": "brak", "tags": ["gwiazda", "rodzaj"]}
        body = (
            f"# {t['displayName']}\n\n![[star_{tid.lower()}.png|320]]\n\n"
            f"**Sylwetka:** {t['shape']}\n\n"
            f"Mnożnik dochodu łupu **×{t['incomeMult']}** · strefa `{t['zone']}` · kolor `{t['color']}` · poświata `{t['glow']}` · skorupa `{t['shell']}`\n\n"
            f"## Rozmiary\n| Rozmiar | Studów | HP | Szansa, że spadnie ten rodzaj |\n| --- | --- | --- | --- |\n{sizes}\n\n"
            f"## Łup\n| Przedmiot | Rzadkość | Szansa | Dochód |\n| --- | --- | --- | --- |\n{loot}\n\n"
            f"Model: `art/stars/{tid.lower()}/` (4 rozmiary: rosnąca liczba detali, kryształów i stref)\n"
        )
        write_note(VAULT / "03 Gwiazdy" / "Rodzaje" / f"{t['displayName']}.md", props, body, written)

    # --- Rozmiary ---
    for sid in stars["order"]:
        s = stars["classes"][sid]
        if s["event"]:
            dist = "Losowy rodzaj z przesunięciem do rzadkich + jedyne źródło **Secret**: " + ", ".join(
                f"[[{x['name']}]]" for x in items["items"] if x.get("supernovaOnly"))
        else:
            w = type_weights(sid)
            dist = "| Rodzaj | Szansa |\n| --- | --- |\n" + "\n".join(
                f"| [[{themes['themes'][k]['displayName']}]] | {v:.1%} |" for k, v in w.items())
        props = {"typ": "rozmiar", "rozmiar": sid, "hp": s["hp"], "studow": s["size"], "co_ile_s": f"{s['intervalMin']}-{s['intervalMax']}",
                 "luck": s["luck"], "losowania": s["lootRolls"], "strefy": s["zones"], "event": s["event"], "tags": ["gwiazda", "rozmiar"]}
        body = (
            f"# {sid}\n\n"
            f"| Pole | Wartość |\n| --- | --- |\n"
            f"| Rozmiar | {s['size']} studów |\n| HP | {s['hp']:,} |\n"
            f"| Spada co | {s['intervalMin']}–{s['intervalMax']} s (ostrzeżenie {s['warning']} s) |\n"
            f"| Znika po | {s['lifetime']} s |\n| Strefy rozbijania | {s['zones']} |\n"
            f"| Losowania łupu | {s['lootRolls']} × Luck {s['luck']} |\n| Min. udział | {s['minShare']:.0%} |\n\n"
            f"## Jaki rodzaj spadnie\n{dist}\n"
        )
        write_note(VAULT / "03 Gwiazdy" / "Rozmiary" / f"{sid}.md", props, body, written)

    # --- Narzędzia ---
    for tid in tools["order"]:
        t = tools["tools"][tid]
        props = {"typ": "narzedzie", "id": tid, "tier": t["tier"], "cena": t["price"], "obrazenia": t["damage"], "model": "brak", "tags": ["narzedzie"]}
        body = (
            f"# {t['name']}\n\nTier **{t['tier']}** · cena **{money(t['price'])}**\n\n"
            f"| Pole | Wartość |\n| --- | --- |\n| Obrażenia | {t['damage']} |\n| Cooldown | {t['cooldown']} s |\n"
            f"| Punkty w minigrze | {t['targets']} |\n| Rozmiar punktu | {t['targetSize']} |\n| Czas kurczenia | {t['shrinkTime']} s |\n"
            f"| Szansa na krytyk | {t['crit']:.0%} |\n| Wygląd | {t['look']} |\n| Model | `art/tools/{tid}.blend` |\n\n![[{tid}.png|220]]\n"
        )
        write_note(VAULT / "05 Narzędzia" / f"{t['name']}.md", props, body, written)

    # --- Pojazdy ---
    for vid in vehicles["order"]:
        v = vehicles["vehicles"][vid]
        props = {"typ": "pojazd", "id": vid, "cena": v["price"], "predkosc": v["speed"], "lata": v["flies"], "na_premiere": v["launch"], "model": "brak", "tags": ["pojazd"]}
        body = (
            f"# {v['name']}\n\nCena **{money(v['price'])}** · prędkość **{v['speed']}** · "
            f"{'lata' if v['flies'] else 'jeździ'} · miejsca {v['seats']}"
            + ("" if v["launch"] else " · *poza premierą, jeśli zabraknie czasu*")
            + f"\n\nWygląd: {v['look']}\n\nModel: `art/vehicles/{vid}.blend`\n\n![[{vid}.png|260]]\n"
        )
        write_note(VAULT / "06 Pojazdy" / f"{v['name']}.md", props, body, written)

    # --- Usuń osierocone notatki katalogu ---
    for folder in ("03 Gwiazdy", "04 Łup", "05 Narzędzia", "06 Pojazdy"):
        for p in (VAULT / folder).rglob("*.md"):
            if p not in written and NOTES_MARK in p.read_text(encoding="utf-8"):
                print(f"  usunięto osieroconą {p.relative_to(VAULT)}")
                p.unlink()

    print(f"OK: {len(written)} notatek katalogu")
    return 0


if __name__ == "__main__":
    sys.exit(main())
