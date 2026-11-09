---
id: T11
tytul: "Modele narzędzi tier 1-8"
status: done
dzien: 3
data: 2026-11-09
tor: B
effort: high
zalezy: [T04]
tags: [task, tor/art]
---
# T11 Modele narzędzi tier 1-8

**Dzień 3** (2026-11-09) · tor **B** (art) · Opus 5.5 **high** · zależy od: [[T04]]

## Cel
Modele narzędzi tier 1-8.

## Kontekst
- [[Narzędzia]]
- [[Styl graficzny]]

## Skille
- (Blender MCP, skill projektu `blender-asset`)

## Pliki
- art/tools/*

## Do zrobienia
- [x] 8 modeli wg `look` z Tools.json
- [x] 2 ekskluzywy za Robux: Comet Blade, Galaxy Hammer (`Monetization.json` → `exclusives`)
- [x] Uchwyt (Handle) i orientacja pod Tool
- [x] Render + FBX + import do ServerStorage.Tools

## Kryteria akceptacji
- [x] ≤ 3k tris
- [x] Rendery w vaulcie, `model: gotowy` w notatkach

## Przebieg (9.11, dwie sesje)

**Decyzje użytkownika (pytania przed startem):**
- Nowe projekty od zera (nie ulepszone ikony T13); ikony sklepu podmieniamy w T11 na rendery nowych modeli (też Comet Blade i Galaxy Hammer, które teraz pożyczają ikony laser_sword / gravity_hammer w `Windows.luau`).
- Skala rośnie z tierem (Stone Pickaxe ~3,3 studs → Starbreaker ~6,8 studs).
- Neon od tieru 3; od tieru 5 smuga (Trail) przy ruchu; Gravity Hammer: pierścienie krążą; Plasma Saw: tarcza się kręci.
- Nova Cannon = broń hybrydowa: młot, lufa jako obuch z przodu, komora z gwiezdnym rdzeniem z tyłu (zamach bez zmian w kodzie minigry).
- Kolory poświaty wg motywu narzędzia (tier 1–2 bez poświaty).
- Ekskluzywy z własnym efektem: Comet Blade (lodowa zakrzywiona klinga, ogon komety, długa smuga), Galaxy Hammer (szklana kula z wirującą galaktyką).
- Akceptacja etapami: szkice → rendery → Studio.

**Zrobione:**
- [x] Generator `art/tools/build_tools.py` (10 modeli: 8 tierów + 2 ekskluzywy). Układ: trzonek +Z, chwyt w (0,0,0), uderzenie −Y → w Roblox Handle +Y, uderzenie −Z, `Tool.Grip` = przesunięcie chwytu bez obrotu. Części wg materiału (`<id>_Handle/Grip/Body/Accent/Glow/Core/Glass/Blade/Beam…`, `Spin*` = części kręcone przez klienta).
- [x] `art/tools/tools.fbx` + `tools.blend`, `art/tools/tools_meta.json` (materiał/kolor/przezroczystość Roblox, środki części w układzie Roblox, Trail A/B, cząsteczki, Spin oś+prędkość).
- [x] Tris: 466–2284 na narzędzie (≤ 3k OK).
- [x] Szkice wysłane: `vault/_img/T11 narzedzia sylwetki.png`, `T11 narzedzia.png`, `T11 skala.png`.

**Druga sesja (9.11):**
- [x] Kształty zaakceptowane przez użytkownika („Tak, dalej”).
- [x] Upload FBX (asset 92818850521397) → `ServerStorage.ToolImport` → import `art/tools/import_tools.luau` (generuje `gen_import.py` z `import_tools.template.luau` + meta) → **10 Tooli w `ServerStorage.Tools/<toolId>`** (Name = toolId, ToolTip/atrybut DisplayName, ToolId, Tier, Exclusive; Weld `ToolWeld`; Trail, cząsteczki, PointLight). Błąd osi vs meta 0,000.
- [x] Grip = środek części Grip + **obrót 180° wokół trzonka** (bez niego obuch patrzył na gracza). Sprawdzone w Play: obuch do przodu, `Feel.swing` zamach za bark → cios przed siebie → powrót.
- [x] `ToolFxController` (klient, tag `ToolSpin`, czeka na `ToolWeld`) — tarcza piły i pierścienie kręcą się w Play.
- [x] Zrzut z gry: `vault/_img/T11 narzedzia w grze.jpg` (wysłany).
- [x] Ikony sklepu, vault, sprzątanie (opis w Raporcie).


## Raport

**Wynik:** 10 narzędzi (8 tierów + Comet Blade, Galaxy Hammer) jako Tool w `ServerStorage.Tools/<toolId>` z poprawnym chwytem i efektami, nowe ikony w sklepie (Tools i Exclusives) i w `Tool.TextureId`. Etapy zaakceptowane przez użytkownika: decyzje → szkice → zrzut z gry.

**Co zrobiono:**
- Blender: `art/tools/build_tools.py` (proceduralnie, bmesh) → `tools.fbx`, `tools.blend`, `tools_meta.json`; tris 466–2284 (≤ 3k). Nowy tryb `--icons` → `art/ui/tools/<id>.png` (512 px, przezroczyste, obrys jak ikony T13).
- Studio: FBX przez Open Cloud (asset 92818850521397) → `insert_asset` → skrypt `art/tools/import_tools.luau` (generuje `art/tools/gen_import.py` z `import_tools.template.luau` + meta). Tool: `Handle`, części na `Weld` „ToolWeld”, Massless, bez kolizji i zapytań; atrybuty `ToolId`, `DisplayName`, `Tier`, `Exclusive`; `ToolTip` = nazwa; Trail `SwingTrail` (tier 5+ i ekskluzywy), cząsteczki z `VfxIds` (spark/glint), PointLight na `Glow`; części `Spin*` z tagiem `ToolSpin` + `SpinAxis`/`SpinSpeed`. `ServerStorage.ToolImport` usunięty.
- `Tool.Grip` = środek owijki + obrót 180° wokół trzonka (bez obrotu obuch patrzył na gracza).
- Kod: `game/src/client/Controllers/ToolFxController.luau` (kręci `Spin*` przez `Weld.C0`, tylko w Workspace; czeka na Weld, bo tag przychodzi przed nim), dopisany w `init.client.luau`. `Theme.TOOL_RENDERS` → 10 nowych ID obrazków (upload Decal przez Open Cloud → ID obrazka przez `InsertService`), `Windows.luau`: ekskluzywy mają własne rendery.
- Vault: `model: gotowy` w 8 notatkach `05 Narzędzia` + opis i rendery, ikony `vault/_img/<id>.png` (256 px), decyzja [[2026-11-09 Modele narzedzi T11]]. `tools/sync_vault.py`: poprawiona ścieżka modelu narzędzia (`art/tools/tools.blend`, `ServerStorage.Tools.<id>`).

**Testy (Studio MCP, Play):** 10 postaci z narzędziami w szeregu — obuchy i ostrza do przodu, skala rośnie z tierem; `Feel.swing` na Starbreaker: zamach za bark → cios → powrót do chwytu, bez błędów; tarcza Plasma Saw obraca się; sklep Tools i Exclusives z nowymi renderami. `selene`/`stylua` 0/0, `rojo build` OK. Zrzuty: `T11 narzedzia w grze.jpg`, `T11 sklep narzedzia.jpg`, `T11 sklep exclusives.jpg`, `T11 ikony.png`.

**Użyte skille:** `task`, `blender-asset`, `roblox-luau`, `roblox-studio-mcp` (narzędzia Studio MCP), `roblox-characters-animation` (Tool, Grip).

**Uwagi dla innych tasków:**
- T09: klonuj `ServerStorage.Tools/<toolId>`, ustaw `Name = DisplayName` (Tool ma nazwę = id), usuń `PlaceholderTool`. Do tego czasu gracze dostają placeholder — modele T11 widać w grze dopiero po T09.
- Brak notatek vaultu dla ekskluzywów (Comet Blade, Galaxy Hammer) — katalog `05 Narzędzia` generuje się tylko z `Tools.json`.
- `.rbxm` Tooli nie zapisany do `game/assets/` (Team Create trzyma miejsce w chmurze; model można odtworzyć skryptem importu z assetu FBX).
