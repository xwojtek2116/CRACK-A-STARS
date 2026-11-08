---
id: T04
tytul: "Generator gwiazd i rodzaje 1-4"
status: done
dzien: 1
data: 2026-11-07
tor: B
effort: high
zalezy: [T01]
tags: [task, tor/art]
---
# T04 Generator gwiazd i rodzaje 1-4

**Dzień 1** (2026-11-07) · tor **B** (art) · Opus 5.5 **high** · zależy od: [[T01]]

## Cel
Generator gwiazd i rodzaje 1-4.

## Kontekst
- [[Styl graficzny]]
- [[Gwiazdy i spadanie]]
- [[Iron Meteorite]]
- [[Lava Star]]
- [[Frost Star]]
- [[Geode Star]]

## Skille
- (Blender MCP, skill projektu `blender-asset`)

## Pliki
- art/stars/*, .claude/skills/blender-asset/SKILL.md

## Do zrobienia
- [x] Generator `art/stars/build_star.py` z modułem na rodzaj (sylwetka z `shape` w Themes.json) i parametrem rozmiaru (skala + gęstość detali + liczba stref)
- [x] Rodzaje: Iron Meteorite, Lava Star, Frost Star, Geode Star × 4 rozmiary
- [ ] Akceptacja wyglądu przez użytkownika (render na telefon) przed T33/T34 — rendery wysłane 8.11, czeka na odpowiedź
- [x] Skill `blender-asset` (pipeline: skrypt → FBX → render → import)
- [ ] Import do Studio → ServerStorage.Stars/<Rodzaj>/<Rozmiar> z Attachmentami stref — skrypt gotowy, upload zablokowany (Zaległe kroki)

## Kryteria akceptacji
- [x] Każdy rodzaj ma inną sylwetkę (rozpoznawalny bez koloru)
- [x] Small ≤ 2k, Huge ≤ 8k tris
- [x] Rendery `star_<rodzaj>.png` w vaulcie, `model: gotowy`

## Raport
**Szkic z czatu planowania (7.11):** `art/stars/build_star.py` — wspólna kula z płytami Voronoi + rdzeń + kryształy (5 starych klas). Do przerobienia na moduły rodzajów i rozmiary Small/Medium/Large/Huge (nowe `Stars.json`).

**Zrobione (8.11):**
- `art/stars/build_star.py` przepisany: moduł na rodzaj (`build_iron/lava/frost/geode`), rozmiar Small/Medium/Large/Huge = gęstość siatki, liczba płyt/kryształów/kropli, odłamki na orbicie od Large. Liczba stref z `Stars.json` (1/2/4/8), kolory z `Themes.json`. Części: `Shell`, `Core`, `Accent`, `Orbit`.
- Sylwetki: Iron = spłaszczony „ziemniak” z wgnieceniami, szwami i guzami; Lava = płyty bazaltu na magmie + krople; Frost = „jeżowiec” z kolców lodu; Geode = jajo z otworem i grotą ametystów. Test bez koloru: `star_silhouettes.png` — wszystkie 4 rozpoznawalne.
- Tris (Small/Medium/Large/Huge): Iron 1408/1508/4528/5332 · Lava 1386/1514/4550/6340 · Frost 648/812/2124/2560 · Geode 1102/1212/3640/4214 — wszystko w budżecie.
- Wyjście: `art/stars/<rodzaj>/star_<rodzaj>.{fbx,blend}` (obiekty `<Rozmiar>_<Część>`), `art/stars/zones.json`, wygenerowany `art/stars/import_stars.luau` (układa `ServerStorage.Stars/<Rodzaj>/<Rozmiar>`, materiały/kolory motywu, `ScaleTo` do size, Attachmenty `Zone_N`; dane wbudowane, bo Config w Studio jest nieświeży). Logika skryptu sprawdzona w Studio na atrapach (skala 6/12/24/45, strefy) i posprzątana.
- Rendery `vault/_img/star_{iron,lava,frost,geode}.png` + `star_silhouettes.png` wysłane na telefon. Notatki rodzajów: `model: gotowy`. Stare klasy (dust/bright/nova/giant/supernova) usunięte.
- Skill `.claude/skills/blender-asset/SKILL.md` (pipeline skrypt → FBX → render → upload → import). Decyzja: [[2026-11-08 Pipeline modeli gwiazd]].

**Użyte skille:** `task`, `anthropic-skills:computer-use` (dostęp odrzucony), Studio MCP (`execute_luau`, `open_cloud_invoke`), Blender CLI.

**Problemy:**
- Sterowanie ekranem Roblox Studio odrzucone (3. raz) → zaległe Ctrl+S z T03 nadal niezrobione.
- `open_cloud_invoke` odmawia uploadu FBX: folder nie jest zatwierdzony w Studio (Assistant Settings → MCP Permissions). Użytkownik wybrał „pomiń na razie”.
- `ReplicatedStorage.Shared.Config.Data.Stars` w otwartym Studio ma stare klasy (Dust…Supernova) — miejsce nie było synchronizowane z Rojo po zmianie JSON-ów (do zrobienia przy T05).
- Render: Small–Huge pokazane w skali 0.55/0.75/1/1.3, nie w prawdziwej (6:12:24:45).

## Zaległe kroki
- [ ] **Import gwiazd do Studio.** Warunek: w Studio Assistant Settings → MCP Permissions dodać `E:\CrackAStarsrt` do approved upload directories (albo zgoda na sterowanie ekranem). Potem: dla każdego rodzaju `open_cloud_invoke` POST `/assets/v1/assets` (assetType `Model`, displayName `CAS_Star_<Rodzaj>`, creator userId `11654521782`, plik `art/stars/<rodzaj>/star_<rodzaj>.fbx`), poll `/assets/v1/operations/{id}`, `insert_asset` (Model) do `ServerStorage.StarImport` z nazwą `<Rodzaj>`, potem `execute_luau` z treścią `art/stars/import_stars.luau`, usunąć `StarImport`, zapisać `ServerStorage.Stars` jako `game/assets/stars/stars_1-4.rbxm` (SerializationService) i Ctrl+S. Sprawdzić nazwy MeshPartów po imporcie (`<Rozmiar>_<Część>`).
- [ ] Ctrl+S miejsca (z T03) — nadal wymaga sterowania ekranem.
