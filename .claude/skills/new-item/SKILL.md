---
name: new-item
description: Dodaj nowy przedmiot łupu (albo motyw) do Crack a Stars — wpis w Items.json/Themes.json, model w Blenderze, notatka w vaulcie. Używaj przy prośbie o nowy przedmiot, motyw albo event z nowym łupem.
---

# Nowy przedmiot łupu

1. Wpis w `game/src/shared/Config/Data/Items.json`: `id` = `<motyw>_<kształt>` (małe litery), `name` (EN, oryginalna nazwa), `theme`, `rarity`. Nowy motyw → najpierw `Themes.json` (kolor, poświata, mnożnik, `eventOnly`).
2. `python tools/sync_vault.py` → notatka w `vault/04 Łup/<Motyw>/`.
3. Model: skill `blender-asset` (kształt wg rzadkości z `Items.json → shapes`, materiał motywu), plik `art/items/<motyw>/<id>.blend`, render `vault/_img/<id>.png`, FBX, import do `ServerStorage.Items/<id>`.
4. W notatce przedmiotu ustaw `model: gotowy` (sync_vault zachowuje to pole).
5. `selene`/`rojo build`, test: `execute_luau` sprawdza, że `ServerStorage.Items[id]` istnieje i LootService może go wylosować.
6. Commit: JSON + art + vault.
