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

**Poprawki wyglądu (8.11, prośba użytkownika „100x cooler, świecące”):**
- Każda gwiazda świeci. `Core` to teraz wszystko, co świeci kolorem `glow` (Neon). Należą do niego ściany boczne płyt, odcięte od Shell (`split_rim`), więc każda krawędź płyty jest rozżarzonym szwem.
- Zmiany per rodzaj:
  - **Iron:** cienkie świecące szwy i stopiony metal w wgnieceniach. Zamiast guzów są kępy chromowanych kostek (Metal), na orbicie też kostki.
  - **Lava:** zamiast „nóg” są bąble magmy i łuki rozbłysków (od Medium).
  - **Frost:** popękana lodowa skorupa. Kolce są szklane (Glass 0.35), w każdym świecący rdzeń.
  - **Geode:** kępy ametystów, korona z kryształów przy otworze, świecące pęknięcia. Od Large kryształy przebijają skorupę.
- Import do Studio dodaje na `Core` PointLight `Glow` (kolor `glow`, zasięg zależny od rozmiaru) i ParticleEmitter `Aura` z wbudowanymi teksturami Roblox: Iron dym, Lava iskry, Frost i Geode iskierki. Pulsowanie zostaje w T12. Szablon importu przeniesiony do `art/stars/import_stars.template.luau`.
- Poprawiony błąd stref: promień przez szczelinę trafiał w drugą stronę skorupy. Teraz liczy się najbliższe trafienie Shell/Core.
- Render: tło z gwiazdami, bloom w kompozytorze Blendera 5, emisja jak Neon. Nowy podgląd `star_lineup.png` (Huge 4 rodzajów).
- Tris (Small/Medium/Large/Huge):
  - Iron: 1032 / 1180 / ~2.8k / ~3.1k
  - Lava: 1180 / 1552 / 3872 / 4984
  - Frost: 1344 / 1604 / 3464 / 4184
  - Geode: 1500 / 1696 / 4102 / 4786
  - Wszystkie w budżecie.
- Logika importu (części, materiały, skala, światło, cząsteczki) sprawdzona w Studio na atrapach i posprzątana. Upload FBX nadal blokowany przez MCP Permissions.

**Frost od nowa (8.11, prośba użytkownika — kolce wyglądały dziwnie):**
- Nowy pomysł to „zamrożona gwiazda”:
  - świecąca kolczasta gwiazda (`spiky_star`) w środku fasetowanego, półprzezroczystego klejnotu lodu (`gem`, Glass 0.45);
  - grube kryształy lodu w układzie płatka śniegu: 6 ramion w płaszczyźnie pionowej plus krótsze przód i tył, każdy z neonowym rdzeniem.
- Rozmiary:
  - Medium i większe mają odgałęzienia na ramionach: 1 para, a od Large 2 pary.
  - Od Large dochodzi 8 ukośnych promieni i aureola odłamków ułożonych wzdłuż orbity.
  - Huge ma dodatkowo 6 krótszych ramion między głównymi.
- Z przodu widać płatek śniegu, z boku czteroramienny błysk gwiazdy (`star_frost_angles.png`).
- Tris: 352 / 800 / 1670 / ~2.2k.

**Akceptacja:** użytkownik zaakceptował wygląd Iron/Lava/Frost/Geode (8.11).

**Użyte skille:** `task`, `anthropic-skills:computer-use` (dostęp odrzucony), Studio MCP (`execute_luau`, `open_cloud_invoke`), Blender CLI.

**Problemy:**
- Sterowanie ekranem Roblox Studio odrzucone (3. raz) → zaległe Ctrl+S z T03 nadal niezrobione.
- `open_cloud_invoke` odmawia uploadu FBX: folder nie jest zatwierdzony w Studio (Assistant Settings → MCP Permissions). Użytkownik wybrał „pomiń na razie”.
- `ReplicatedStorage.Shared.Config.Data.Stars` w otwartym Studio ma stare klasy (Dust…Supernova) — miejsce nie było synchronizowane z Rojo po zmianie JSON-ów (do zrobienia przy T05).
- Render: Small–Huge pokazane w skali 0.55/0.75/1/1.3, nie w prawdziwej (6:12:24:45).

## Zaległe kroki
- [x] **Import gwiazd do Studio.** ✔ zrobione 8.11:
  - Upload FBX przez Open Cloud jako assety Model: Iron `98913719514275`, Lava `111779316629905`, Frost `90949978724284`, Geode `132377142638097`.
  - `insert_asset`, potem `import_stars.luau`: 16 modeli w `ServerStorage.Stars/<Rodzaj>/<Rozmiar>` (Neon, PointLight `Glow`, ParticleEmitter `Aura`, strefy `Zone_N`). Podgląd na mapie: `T04 gwiazdy w Studio.jpg`.
  - Miejsce: chmurowe `placeId 128852283478472`, universe `10775327732`, z mapą z T03.
  - Poprawki przy imporcie:
    - Frost skalowana po całym płatku (`FIT_BODY`), bo sam klejnot jest mały.
    - Strefy były obrócone o 180°: FBX po imporcie daje Blender (x, y, z) → Roblox (−x, z, y), co zmierzyłem na otworze Geode. Poprawione w `to_roblox`, `zones.json` i Attachmentach w Studio. Błąd strefy względem powierzchni wynosi teraz 0,5–0,9 studa.
- [x] ✔ zrobione w T38 (8.11, Explorer → Zapisz do pliku) — Kopia `game/assets/stars/stars_1-4.rbxm` nie jest zrobiona. `SerializationService` działa (ok. 400 KB), ale wysłanie pliku na dysk przez `HttpService` na `127.0.0.1:8765` blokuje Assistant HTTP allowlist. Następna próba po dodaniu `127.0.0.1` do allowlisty, albo ponowny import z assetów powyżej.
- [x] (8.11 12:00, czat planowania) Studio straciło połączenie z miejscem chmurowym (RCC-1025) przed zapisem; gwiazdy odzyskane z autozapisu 11:51 i zapisane w `game/places/CrackAStars.rbxl` (stara wersja: `CrackAStars_kopia_2026-11-08_1025.rbxl`). Pierwotnie: Ctrl+S miejsca (place 128852283478472), żeby zachować `ServerStorage.Stars` i mapę. Sterowanie ekranem odrzucone (8.11, 4. raz), więc zapis musi zrobić użytkownik albo następny task. ✔ 12:02: sprawdziłem przez MCP 16 gwiazd z poprawionymi strefami (Geode Huge `Zone_1` = (−7.7, 18.7, −2.1)) i ponownie zapisałem sterowaniem ekranem (Plik → Zapisz do pliku).
