---
id: T40
tytul: "Przebudowa gwiazd: efektowne, żywe, VFX"
status: done
dzien: 4
data: 2026-11-09
tor: B
effort: high
zalezy: [T33]
tags: [task, tor/art]
---
# T40 Przebudowa gwiazd: efektowne, żywe, VFX

**Tor B (art) · Opus 5.5 high · zależy od: [[T33]]** · obejmuje też [[T34]]

## Cel
Wszystkie gwiazdy (rodzaje 1-12 i Supernowa) od nowa, naprawdę „wow”: złożone modele, tekstury, płyny, VFX i animacje, tak żeby gwiazdy **żyły**.

## Ustalenia z użytkownikiem (9.11)
- **Zakres:** wszystkie 12 rodzajów + Supernowa (T34 robimy tym samym sposobem).
- **Kształt:** mieszany. Część gwiazd jako 5 ramion (np. Toxic, Lava, Frost, Storm, Geode), reszta jako bryły tematyczne (Comet z ogonem, Nebula galaktyka, Ringed, Void). Ostateczny podział na planszach konceptów.
- ~~**Wzór Toxic:** 5-ramienna gwiazda z łańcuchami, fiolkami i emblematem (`toxic_user_1/2`)~~ → **zmiana 9.11:** Toxic według arkusza `vault/_ref/toxic_user_3.png`: korona z płyt bazaltu wokół zielonego rdzenia, kryształy, latający gruz, maź, krater z pęknięciami. Decyzja: [[2026-11-09 Toxic v2 skalno-krysztalowy]], specyfikacja: [[Toxic Star v2 - specyfikacja produkcyjna]].
- **Gwiazdy mają żyć:** migają, pulsują, lekkie animacje (obrót, unoszenie, pulsowanie jądra, migotanie poświaty, kapanie mazi, dym, iskry). Na każdej gwieździe zawsze coś się rusza.
- **Płyny:** z niektórych gwiazd wypływa ciecz (Toxic: maź, Lava: magma, Frost: topniejąca woda/mgła itd.).
- **Budżet:** Small ≤ 5k, Huge ≤ 20k tris. Detal głównie z tekstur PBR (SurfaceAppearance).
- **Proces:** zdjęcia referencyjne → plansze konceptów w Claude Design (akceptacja) → prototyp Toxic w pełnej jakości w Studio (akceptacja) → pozostałe gwiazdy.

## Propozycja konceptów (do potwierdzenia na planszach)
**Podział kształtów:**
- **5 ramion:** Lava, Frost, Toxic, Storm, Diamond.
- **Bryły:** Iron, Geode, Comet, Nebula, Ringed, Solar, Void.
- **Supernowa** (z T34): wariant każdego rodzaju z koroną i pierścieniem odłamków.

| Rodzaj | Kształt i detale | Płyn | Życie (animacje, VFX) |
| --- | --- | --- | --- |
| Iron | ospała skała metalowa, gorące pomarańczowe szwy | — | szwy żarzą się jak węgle, dym, iskry |
| Lava | 5 ramion z płyt bazaltu na magmowej gwieździe | magma kapie z końców ramion | puls magmy, płyty lekko dryfują, żar unosi się w górę |
| Frost | 5 ramion z lodowych kryształów, zamrożony klejnot w środku | topniejące krople | błyski, mgła spływa w dół, płatki śniegu na orbicie |
| Geode | pęknięte jajo skalne, w środku jaskinia ametystów | — | kryształy migoczą, fioletowa poświata pulsuje, pyłki |
| Comet | lodowe jądro, ogon ze wstęg | — | ogon faluje, smuga iskier, strumienie szronu |
| Toxic | jak na zdjęciu: łańcuchy, fiolki, emblemat biohazard | zielona maź kapie, kałuża | puls rdzenia, zielony dym, zarodniki, bąble w fiolkach |
| Storm | 5 metalowych ramion jak cewki Tesli, kula energii w środku | — | pioruny skaczą między końcami ramion, trzaski, iskry |
| Nebula | szklana kula z galaktyką w środku | — | gaz wiruje, gwiazdki migają, szkło lśni |
| Diamond | fasetowana kryształowa gwiazda, klejnoty na orbicie | — | błyski przebiegają po fasetach, tęczowe refleksy |
| Ringed | mini planeta z pochylonymi pierścieniami odłamków | — | pierścienie kręcą się w przeciwne strony, poświata atmosfery |
| Solar | złote płynne słońce, protuberancje, kolce korony | złote krople | flary pętlą się, powierzchnia „gotuje się”, puls korony |
| Void | czarna kula z fioletowym dyskiem akrecyjnym | — | dysk się kręci, cząstki są wciągane, krawędź faluje |

## Stan na koniec czatu (9.11)
- Zdjęcia od użytkownika: `vault/_ref/toxic_user_1.webp`, `toxic_user_2.webp`. Linki z sieci: `vault/_ref/Referencje gwiazd.md`. Wyszukiwarka zwraca tylko tekst, więc plansze rysujemy sami (SVG plus animacje CSS), a zdjęcia z sieci zostają wyłącznie linkami.
- Utworzone **puste** płótno Claude Design: https://claude.ai/artifact/FX9urch7Hf194qCsFvkRp6 („Gwiazdy Crack a Stars koncepty”). Kontynuujemy na nim, nie zakładamy nowego.
  - Plan płótna: `Main.dc.html` = przegląd 13 kart (sylwetka SVG, paleta, płyn, animacje życia pokazane jako CSS) oraz plansza `Toxic.dc.html` jak druga grafika użytkownika.
  - ✔ 9.11 (2. czat): narysowane plansze v1 na płótnie — `Main.dc.html` (13 animowanych kart + zasady) i `Toxic.dc.html` (duży widok, 4 rozmiary z budżetem, materiały PBR, efekty → technika Roblox, oś rozbicia). Czeka na akceptację użytkownika.
  - 9.11 (2. czat, cd.): użytkownik zmienił Toxic (arkusz `toxic_user_3.png`) i poprosił o prototyp techniczny + handoff. Zrobione: **Toxic Star Lab** https://claude.ai/artifact/Ws7C2sw5cG8dXctChArpmM (źródło `art/stars/toxic/viewer/ToxicStarLab.html`: three.js, 6 stanów, 12 animacji z osią czasu, hierarchia, debug, log wywołań Luau) oraz specyfikacja produkcyjna w vaulcie. Karta Toxic na płótnie konceptów jest nieaktualna. **Następny krok po akceptacji:** `build_toxic_v2.py` w Blenderze według sekcji 4 specyfikacji.

## Do zrobienia
- [x] Zdjęcia referencyjne: zdjęcia od użytkownika i linki w `vault/_ref/`
- [x] Plansze konceptów v1 na płótnie (potem Toxic według arkusza użytkownika, reszta zaprojektowana w stylu Toxica — decyzja użytkownika „projektuj sam”)
- [x] Toxic v2: prototyp techniczny (Toxic Star Lab) + specyfikacja produkcyjna → akceptacja
- [x] Użytkownik zaakceptował Toxic v2 (prototyp + specyfikację) — 9.11
- [x] Toxic v2 w Blenderze: `art/stars/toxic/build_toxic_v2.py` → `star_toxic_v2.fbx/.blend` (Large ~10,5k tris + gruz, Small ~2,2k), `toxic_v2_anchors.json` (ANCHOR_*, 12 stref), rendery `vault/_img/T40 toxic v2 studio.png`, `T40 toxic v2 noc.png` — zaakceptowany
- [x] Tekstury: wbudowane materiały Roblox z fakturą (Basalt, CorrodedMetal, Ice, Glacier, Slate, Sandstone, Foil…) zamiast własnego bake PBR — decyzja w Raporcie
- [x] Import do Studio: `art/stars/import_stars_v2.luau` (ModuleScript `ServerStorage.StarImportV2`), assety w `art/stars/stars_v2_assets.json`
- [x] Generator v2 dla wszystkich rodzajów: `art/stars/build_star_v2.py` (style: płyty, głazy, lodowe słupy, klejnoty, pręty, jajo, pierścień, korona)
- [x] `StarVisual` (klient) + `Config/StarVisualConfig`: 6 stanów, 8 animacji, gruz na orbicie, emitery (zarodniki, iskry, dym, krople), fala; Dormant daleko od kamery. „Ogranicz ruch” — brak takiego ustawienia w grze (Zaległe)
- [x] Toxic w grze (Small/Medium/Large/Huge + Supernova): zrzuty lotu, lądowania i rozbicia wysłane
- [x] 12 rodzajów × 5 rozmiarów (z Supernową) w `ServerStorage.Stars`; kolizja: Shell `Hull`, reszta bez kolizji, `Hitbox` do raycastów
- [x] Aktualizacja [[Styl graficzny]], karty T34, commit

## Kryteria akceptacji
- [x] Użytkownik akceptuje plansze i prototyp Toxic (9.11: „Toksyczna mi się podoba”, model z Blendera „jest okej”)
- [x] Każda gwiazda ma animację idle i co najmniej 2 efekty żywe (StarVisual wspólny dla v2)
- [x] Budżet tris (Large/Huge 8–11k ≤ 20k, Small 1,5–2,2k ≤ 5k) — FPS na fizycznym telefonie niesprawdzony (Zaległe)

## Raport

**Co zrobiono (9.11):**
- Plansze konceptów v1 na płótnie Claude Design; potem zmiana Toxica na arkusz użytkownika (`vault/_ref/toxic_user_3.png`).
- **Toxic Star Lab** (https://claude.ai/artifact/Ws7C2sw5cG8dXctChArpmM, `art/stars/toxic/viewer/ToxicStarLab.html`): prototyp three.js — 6 stanów, 12 animacji z osią czasu, hierarchia, debug, log API Luau. Specyfikacja: [[Toxic Star v2 - specyfikacja produkcyjna]], decyzja: [[2026-11-09 Toxic v2 skalno-krysztalowy]].
- Blender: `art/stars/toxic/build_toxic_v2.py` (Toxic) i `art/stars/build_star_v2.py` (11 pozostałych rodzajów, ten sam szkielet części, różne style skorupy). FBX `art/stars/<rodzaj>/star_<rodzaj>_v2.fbx` + `.blend`. Rendery: `T40 gwiazdy v2.png`, `T40 gwiazdy v2 sylwetki.png`, w Studio: `T40 gwiazdy v2 w studio.jpg`.
- Import do Studio: upload Open Cloud (12 assetów, `art/stars/stars_v2_assets.json`), `ServerStorage.StarImportV2` (`art/stars/import_stars_v2.luau`): hierarchia MainBody/Core/Crystals/Slime/Crater/FloatingDebris/Hitbox, kotwice i strefy `Zone_N` liczone raycastami w Studio, skala do `size`, pivot nad dnem krateru. Stare modele v1 → `ServerStorage.StarsBackup.<Rodzaj>_v1`. Nowe rodzaje (Diamond, Ringed, Solar, Void) i Supernowa mają teraz modele, więc też spadają (zamyka T34).
- Kod: `client/Fx/StarVisual.luau`, `shared/Config/StarVisualConfig.luau`; `StarFxController` (podpięcie, `fresh` = animacja lądowania), `LandedFx` (Highlight tylko na skorupie, części v2 wygasza StarVisual), `FallFx` (w locie bez krateru, pivot w rdzeniu, gruz ciasno — `AnimConfig.FALL.v2DebrisTighten`), `StarService` (gwiazdy z atrybutem `Upright` stoją prosto).

**Pliki:** `art/stars/build_star_v2.py`, `art/stars/<rodzaj>/star_<rodzaj>_v2.*`, `art/stars/stars_v2_anchors.json`, `art/stars/stars_v2_assets.json`, `art/stars/import_stars_v2.luau`, `art/stars/toxic/*` (v2, viewer, import), `game/src/client/Fx/{StarVisual,LandedFx,FallFx}.luau`, `game/src/client/Controllers/StarFxController.luau`, `game/src/server/Services/StarService.luau`, `game/src/shared/Config/{StarVisualConfig,AnimConfig}.luau`, vault (spec, decyzje, rendery, zrzuty).

**Użyte skille:** `task`, `blender-asset`, `roblox-luau`, artifact quickstart (strona prototypu), Studio MCP (`open_cloud_invoke`, `insert_asset`, `execute_luau`, `start_stop_play`, `screen_capture`, `get_console_output`).

**Testy:** `selene src` 0/0, `stylua --check` OK, `rojo build` OK. Studio (Play): Toxic Large i Huge — wyrwa, lot bez krateru, lądowanie z rozrostem krateru i falą, stan Damaged (znikające kryształy, migotanie), rozbicie (wybuch, fala, wygaszenie); Solar, Void, Ringed i Diamond spadają i lądują; konsola bez błędów z nowych modułów. Prototyp w przeglądarce bez błędów konsoli.

**Problemy / uwagi:**
- Tekstury: zamiast własnego bake PBR (plan w specyfikacji) wbudowane materiały Roblox z fakturą — bez dodatkowych uploadów i pamięci na telefonie. Własne MaterialVariant można dodać później.
- `Themes.json` → `shell` nie jest używany przez modele v2 (kolory skały w `stars_v2_assets.json`); zostawiony, bo może go czytać UI.
- Płótno konceptów (Toxic z 5 ramionami) jest nieaktualne względem v2.
- `.rbxm` szablonów nie zapisany do `game/assets/` (Team Create trzyma miejsce w chmurze; zapis przez SerializationService to kilka MB base64).
- Strefy minigry leżą blisko rdzenia (promienie trafiają w wewnętrzne płyty) — do sprawdzenia przy rozbijaniu w grze.

## Zaległe kroki
- [ ] **FPS na telefonie** z kilkoma gwiazdami v2 naraz (T26 Wydajność): Studio → Test → emulator urządzenia, MicroProfiler; ewentualnie zmniejszyć `StarVisualConfig.EMITTERS` / `DEBRIS_COUNT`.
- [ ] **„Ogranicz ruch”**: w grze nie ma takiego ustawienia; gdy powstanie (UI ustawień), w `StarVisual` wymusić stan `Dormant` bez ruchu części.
- [ ] Kopia `.rbxm` szablonów gwiazd do `game/assets/stars/` przy następnym Save to File (sterowanie komputerem).
