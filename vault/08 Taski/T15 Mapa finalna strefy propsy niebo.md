---
id: T15
tytul: "Mapa finalna strefy propsy niebo"
status: done
dzien: 8
data: 2026-11-14
tor: C
effort: high
zalezy: [T36, T03]
tags: [task, tor/swiat-ui-biznes]
---
# T15 Mapa finalna strefy propsy niebo

**Dzień 8** (2026-11-14) · tor **C** (swiat-ui-biznes) · Opus 5.5 **high** · zależy od: [[T03]]

## Cel
Mapa finalna strefy propsy niebo.

## Kontekst
- [[Mapa]]
- [[Styl graficzny]]

## Skille
- roblox-world-building
- roblox-performance

## Pliki
- art/map/*, game/assets/map/*

## Do zrobienia
- [x] Propsy z Blendera dla 4 stref i hubu
- [x] Skybox z mgławicą, planety
- [x] Budynki hubu (sklep, garaż, portal)
- [x] Teren między biomami grywalny i ładny (gwiazdy spadają losowo po całej planecie — [[2026-11-08 UI spadanie i animacje]])

- [x] Po skończeniu: ujęcia beauty shots do [[T37 Nagrania cinematic na social media|T37]]

## Ustalenia z użytkownikiem (2026-11-09)
- **Lobby:** wszystkie 8 stacji z Blendera (ToolShop, Garage, SellStation, Upgrades, RobuxShop+VipZone, IndexHall+RebirthPortal, DailyCodes, Spawn+EventBoard), styl **stacji kosmicznej** (moduły metalu, szklane kopuły, neonowe pasy w kolorze stacji). Wspólny zestaw modułów → szybciej. Zachować `PromptAnchor/Prompt`, tagi `LobbyStation`, atrybut `Station`.
- **Propsy biomów:** bardziej realistyczne kształty (sculpt → decimate), **lekkie PBR: 1 atlas 1024 px na biom**, akcenty Neon. 6–8 propsów na biom (ok. 30 + wspólne).
- **Kolizje:** duże propsy kolizyjne (omijanie / jetpack), drobne `CanCollide=false`.
- **Gęstość:** średnia, skupiska z otwartymi polami pod lądowanie gwiazd, ~400–700 instancji.
- **Teren między biomami:** płynne przejścia materiałów + mieszane propsy, drogi i rampy, landmarki do orientacji.
- **Niebo:** skybox renderowany w Blenderze (6 ścian), **ciemny granat + zielone smugi (zorza)**; 2–3 planety jako modele 3D daleko (jedna z pierścieniami), powolny ruch. **Stała noc**; zachód tylko jako preset do nagrań T37.
- **Dodatki:** kopuła pola siłowego r=2000, cząsteczki ambient per biom, **lighting per biom** (mały kontroler klienta — plik dopisany do karty), wystrój działek **tylko na obrzeżu** (bez zmian `Base`, `BuildOrigin`, `Sign`, `Spawn`).
- **Kolejność / cięcie przy braku czasu:** 1) niebo + planety, 2) 8 budynków lobby, 3) propsy biomów + przejścia, 4) landmarki/drogi, 5) kopuła, cząsteczki, lighting per biom, działki → reszta do „Zaległe kroki”.

## Plan
1. Blender: skybox (mgławica + zorza) → 6 PNG, 3 planety → FBX; upload, `Sky` + modele w `Workspace.Map.Sky`.
2. Blender: kit modułów stacji → 8 budynków (≤ 10k tris każdy) → import, podmiana blockoutu z zachowaniem promptów/tagów.
3. Blender: propsy 4 biomów + wspólne (atlasy 1024) → import do `ReplicatedStorage`/`ServerStorage` jako wzorce, rozmieszczanie skryptem `tools/studio/T15_props.luau` (deterministyczny seed, unikanie dróg, działek, lobby).
4. Przejścia materiałów Terrain na granicach biomów, landmarki, poprawki dróg/ramp.
5. Kopuła, `ParticleEmitter` per biom, `BiomeLightingController` (klient), obrzeże działek.
6. Wydajność: `LevelOfDetail`/StreamingEnabled, pomiar pamięci klienta (< 1 GB), FPS.
7. Zrzuty każdej strefy na telefon, beauty shots dla T37, `.rbxm` do `game/assets/map/`, raport, decyzja, commit + push.

**Pliki (dopisane):** `art/map/*`, `game/assets/map/*`, `tools/studio/T15_props.luau`, `game/src/client/Controllers/MapAmbienceController.luau` + `game/src/shared/Config/MapAmbienceConfig.luau` (+ wpis w `init.client.luau`).

## Kryteria akceptacji
- [x] Zrzuty każdej strefy na telefon
- [ ] Pamięć klienta < 1 GB na telefonie — w Studio mapa po stronie klienta to ok. 330 MB (tekstury 86, teren 91, instancje 108, fizyka 38 MB); na telefonie niezmierzone (patrz Zaległe kroki)

## Raport
**Zrobione (9.11):**
- **Niebo:** `art/map/sky/build_sky.py` — shader świata (granat, mgławica, 2 wstęgi zorzy z pionowymi promieniami, 2 warstwy gwiazd) → 6 ścian 1024 px → `Lighting.NebulaSky` (StarCount 0, bez słońca/księżyca). Konwencja ścian Roblox zmierzona siatką kierunków (Lf = +X, Rt = −X, Up obrócone o 90°) — bez szwów. Podgląd: ![[T15 niebo.png]]
- **Planety:** 3 MeshParty z teksturami wypalonymi w Blenderze (`SurfaceAppearance`), gazowy olbrzym z pierścieniem z 168 segmentów. `Workspace.Map.Sky` (Persistent), klient przesuwa je za kamerą i obraca.
- **Oświetlenie:** nocny wygląd przy ClockTime 14,5 (w nocy Roblox gasi skybox), preset `game/assets/map/lighting.rbxm`.
- **Lobby:** `art/map/lobby/build_lobby.py` — wspólny moduł stacji + element na dachu (kilof i młot, radar i lądowisko, kontenery i moneta, wieża ze strzałkami, obserwatorium, klejnot, holo-prezent, pierścień portalu); 1,4–3,1 tys. tris na budynek. Podmiana w Studio: `Stations.<Stacja>.Building`, szyld przeniesiony na fasadę, prompt/tagi/VIP bez zmian, tafla portalu okrągła. Render: ![[T15 lobby.png]] Zrzut: ![[T15 Tool Shop.jpg]]
- **Propsy:** `art/map/props/build_props.py` — 33 modele (7 na biom + wspólne: skały, latarnia, wrak, pylon), realistyczne bryły na materiałach Roblox. `ServerStorage.MapProps` (szablony) → `tools/studio/T15_props.luau` (SEED 1515) → 765 instancji: skupiska, mieszanie przy granicach biomów, omijanie dróg/ramp/lobby, punkty orientacyjne, 8 kominów lawy z dymem, iskry wraku. Render: ![[T15 propsy.png]]
- **Granica:** 16 pylonów pola siłowego (r = 1995) przy ścianach ForceField z T36. **Rampy:** neonowe krawędzie. **Działki:** `Plot_N.Decor` — 4 pylony i niska ścianka z tyłu/boków (Base/BuildOrigin/Sign/Spawn bez zmian). Zrzuty: ![[T15 dzialka.jpg]] ![[T15 rampa.jpg]]
- **Klimat biomów (kod klienta):** `MapAmbienceController` + `MapAmbienceConfig` — Atmosphere i tint „BiomeTint” per biom (tween 2,5 s), cząsteczki wokół kamery (iskry, śnieg, pył kryształów, zarodniki), planety za kamerą.
- **Strefy:** ![[T15 Lava Fields.jpg]] ![[T15 Frost Crater.jpg]] ![[T15 Crystal Canyon.jpg]] ![[T15 Nebula Plateau.jpg]] ![[T15 lobby niebo.jpg]] — to też ujęcia dla [[T37 Nagrania cinematic na social media|T37]].

**Testy (Play w Studio):** 11/11 serwisów i 11/11 kontrolerów bez błędów; witryna Tool Shop: 8 postumentów (po dodaniu kotwicy `Body`); gwiazdy spadają do wszystkich biomów; wejście do Lava → Atmosphere a06078, tint ffe8de, iskry; Frost → 96aadc, e4f0ff, śnieg. FPS w Studio 15 niezależnie od propsów i nieba (limit okna w tle — z propsami i bez wynik ten sam). Na klienta streamuje się ok. 975 instancji propsów. `selene` 0/0, `stylua --check` OK, `rojo build` OK.

**Pliki:** `art/map/maplib.py`, `art/map/gen_import.py`, `art/map/sky/*` (build_sky.py, faces/*.png, planet_*.png, planets.fbx/.blend/_meta.json), `art/map/lobby/*` (build_lobby.py, lobby.fbx/.blend/_meta.json, import_lobby.template.luau, import_lobby.luau), `art/map/props/*` (build_props.py, props.fbx/.blend/_meta.json, import_props.template.luau, import_props.luau), `tools/studio/T15_props.luau`, `game/assets/map/lighting.rbxm`, `game/src/client/Controllers/MapAmbienceController.luau`, `game/src/shared/Config/MapAmbienceConfig.luau`, `game/src/client/init.client.luau`, `vault/09 Decyzje/2026-11-09 Mapa finalna T15.md`, `vault/02 Systemy/Mapa.md`, `vault/_img/T15 *`.
**Assety Roblox:** niebo 72370868720317 (ft), 129826250072136 (bk), 79382991385219 (slot Lf), 98379622442156 (slot Rt), 138838040978970 (up), 129885769999597 (dn); planety: model 124132619213319, tekstury 100331948901724 / 138227139286450 / 96342294194848; lobby: model 129737341287677; propsy: model 81577794889258.

**Skille:** blender-asset, roblox-luau, roblox-world-building (zakres karty), roblox-performance (streaming/LOD), roblox-studio-mcp.

**Odstępstwa od karty / problemy:**
- Zamiast atlasów 1024 px — materiały Roblox (PBR bez dodatkowej pamięci); decyzja w [[2026-11-09 Mapa finalna T15]].
- Plik kontrolera: `MapAmbienceController` (zamiast `BiomeLightingController` z planu) — jeden kontroler na klimat mapy: światło, cząsteczki, planety.
- Płaski pierścień z FBX nie renderował się w Roblox → pierścień z części.
- Zmieniony budynek usunął `Body`, którego używa `ToolService` → dodana niewidzialna kotwica `Body` (kod toru A bez zmian).
- Studio zamknęło się w trakcie (limit sesji); zmiany przetrwały dzięki Team Create, miejsce otwarte ponownie.
- `EventBoard` (plac, środek lobby) został z blockoutu — poza listą 8 stacji.
- `.rbxm` całej mapy nie zapisany (za duży na base64 z MCP); mapa jest w miejscu (Team Create) i odtwarzalna: import_lobby.luau, import_props.luau, T15_props.luau, build_*.py.

**Zaległe kroki:**
- [ ] Pomiar pamięci klienta na prawdziwym telefonie (Developer Console → Memory, cel < 1 GB) i FPS w opublikowanej grze — wymaga telefonu użytkownika; w Studio nie da się zmierzyć samego klienta.
- [ ] Ściana Dn skyboxa nie ma zmierzonej orientacji (jest pod terenem, niewidoczna) — przy zmianie nieba sprawdzić siatką jak Up.
