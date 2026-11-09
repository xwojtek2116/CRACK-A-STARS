---
id: T40
tytul: "Przebudowa gwiazd: efektowne, żywe, VFX"
status: doing
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
- [ ] Plansze konceptów w Claude Design dla 13 gwiazd → akceptacja
- [x] Toxic v2: prototyp techniczny (Toxic Star Lab) + specyfikacja produkcyjna → akceptacja
- [x] Użytkownik zaakceptował Toxic v2 (prototyp + specyfikację) — 9.11
- [x] Toxic v2 w Blenderze: `art/stars/toxic/build_toxic_v2.py` → `star_toxic_v2.fbx/.blend` (Large ~10,5k tris + gruz, Small ~2,2k), `toxic_v2_anchors.json` (ANCHOR_*, 12 stref), rendery `vault/_img/T40 toxic v2 studio.png`, `T40 toxic v2 noc.png` — czeka na akceptację modelu
- [ ] Toxic v2: bake tekstur PBR (Color/Normal/Roughness 1024²) dla MAT_Rock i MAT_Ground
- [ ] Toxic v2: import do Studio (upload FBX, rozszerzenie `import_stars.luau`, `Themes.json` Toxic `shell` → #3B3842), `.rbxm`
- [ ] Generator v2 dla pozostałych gwiazd (po akceptacji Toxica w grze)
- [ ] `StarFX` (klient): idle obrót/unoszenie, puls jądra, miganie, kapanie, dym, aura; więcej efektów z rozmiarem; „Ogranicz ruch”
- [ ] Prototyp Toxic (4 rozmiary) w Studio → zrzuty + nagranie → akceptacja
- [ ] Pozostałe 12 gwiazd × 4 rozmiary, import do `ServerStorage.Stars`, kolizja (`PreciseConvexDecomposition` dla Shell)
- [ ] Aktualizacja [[Styl graficzny]], kart T33/T34, commit

## Kryteria akceptacji
- [ ] Użytkownik akceptuje plansze i prototyp Toxic
- [ ] Każda gwiazda ma animację idle i co najmniej 2 efekty żywe
- [ ] Budżet tris, płynnie na telefonie

## Raport
