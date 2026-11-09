---
id: T11
tytul: "Modele narzędzi tier 1-8"
status: doing
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
- [ ] 8 modeli wg `look` z Tools.json
- [ ] 2 ekskluzywy za Robux: Comet Blade, Galaxy Hammer (`Monetization.json` → `exclusives`)
- [ ] Uchwyt (Handle) i orientacja pod Tool
- [ ] Render + FBX + import do ServerStorage.Tools

## Kryteria akceptacji
- [ ] ≤ 3k tris
- [ ] Rendery w vaulcie, `model: gotowy` w notatkach

## Stan pracy (9.11, przerwane — kontynuacja w nowej sesji)

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

**Druga sesja (9.11, przerwana limitem):**
- [x] Kształty zaakceptowane przez użytkownika („Tak, dalej”).
- [x] Upload FBX (asset 92818850521397) → `ServerStorage.ToolImport` → import `art/tools/import_tools.luau` (generuje `gen_import.py` z `import_tools.template.luau` + meta) → **10 Tooli w `ServerStorage.Tools/<toolId>`** (Name = toolId, ToolTip/atrybut DisplayName, ToolId, Tier, Exclusive; Weld `ToolWeld`; Trail, cząsteczki, PointLight). Błąd osi vs meta 0,000.
- [x] Grip = środek części Grip + **obrót 180° wokół trzonka** (bez niego obuch patrzył na gracza). Sprawdzone w Play: obuch do przodu, `Feel.swing` zamach za bark → cios przed siebie → powrót.
- [x] `ToolFxController` (klient, tag `ToolSpin`, czeka na `ToolWeld`) — tarcza piły i pierścienie kręcą się w Play.
- [x] Zrzut z gry: `vault/_img/T11 narzedzia w grze.jpg` (wysłany).
- `ToolImport` zostaje w ServerStorage (do usunięcia na koniec taska).

**Następne kroki (zostały):** 5 (ikony sklepu) i 6 (vault, Raport, `status: done`) poniżej, potem usunąć `ServerStorage.ToolImport`, commit + push.

**Następne kroki (stara lista):**
1. ~~Akceptacja kształtów~~ (zrobione).
2. ~~Studio~~ (zrobione): upload `tools.fbx` (Open Cloud, folder `E:\CrackAStars\art` zatwierdzony w MCP Permissions), `insert_asset`, skrypt importu z `tools_meta.json` → `ServerStorage.Tools/<id>` (Tool: Handle, Weld do Handle — Weld, nie WeldConstraint, żeby klient mógł kręcić `Spin*` przez C0; Massless, CanCollide/CanQuery/CanTouch false; atrybuty ToolId, Tier; Grip; Trail + Attachmenty; ParticleEmitter z `Theme.FX`/VfxIds). Skalę wyznacz z rozmiaru Handle vs `parts.Handle.size` z meta.
3. Mały klient `ToolFxController` (CollectionService/atrybut Spin) — kręci części `Spin*`.
4. Test Play: założyć Tool na postać (execute_luau), sprawdzić orientację Grip w zamachu (`Feel.swing`), zrzut.
5. Ikony sklepu: rendery 10 narzędzi → upload → `Theme.TOOL_RENDERS` (+ comet_blade, galaxy_hammer w `Windows.luau`).
6. Vault: `model: gotowy` w `vault/05 Narzędzia/*`, rendery w notatkach, decyzja w `09 Decyzje`, Raport, commit + push.

## Raport
_(uzupełnia Claude po zakończeniu: co zrobiono, pliki, użyte skille, wynik testów, problemy; „Zaległe kroki” tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić)_
