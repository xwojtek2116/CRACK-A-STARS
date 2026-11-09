---
id: T33
tytul: "Modele gwiazd rodzaje 5-8"
status: done
dzien: 4
data: 2026-11-10
tor: B
effort: high
zalezy: [T04]
tags: [task, tor/art]
---
# T33 Modele gwiazd rodzaje 5-8

**Dzień 4** (2026-11-10) · tor **B** (art) · Opus 5.5 **high** · zależy od: [[T04]]

## Cel
Modele gwiazd rodzaje 5-8.

## Kontekst
- [[Styl graficzny]]
- [[Comet]]
- [[Toxic Star]]
- [[Storm Star]]
- [[Nebula Star]]

## Skille
- (Blender MCP, skill projektu `blender-asset`)

## Pliki
- art/stars/{comet,toxic,electric,nebula}/*

## Do zrobienia
- [x] Moduły generatora: Comet (jądro + ogon), Toxic (maź + zarodniki), Storm (klatka prętów + łuki), Nebula (gaz w szklanej skorupie)
- [x] 4 rozmiary każdy, FBX, rendery, import

## Ustalenia z użytkownikiem (9.11)
- **Comet:** ogon jako siatka (świecące wstęgi Neon) + w Studio ParticleEmitter/Trail z iskierkami.
- **Storm / Nebula:** import dodaje efekty: Storm — Beamy błyskawic między Attachmentami na prętach; Nebula — ParticleEmitter mgiełki w szklanej skorupie. Animacja (miganie, obrót) → T12.
- **Toxic:** „skażona gwiazda” — twarda, popękana skorupa, z pęknięć wylewa się świecąca zielona maź, rosną grzyby/zarodniki (nie galaretowaty glut).
- **Akceptacja:** najpierw render 4× Huge + porównanie z rodzajami 1-4 na telefon; po OK reszta rozmiarów, FBX, upload, import.

## Kryteria akceptacji
- [x] Inna sylwetka niż rodzaje 1-4
- [x] Budżet tris jak T04

## Raport
**Zrobione (9.11):**
- `art/stars/build_star.py`: nowe moduły `build_comet/toxic/electric/nebula` i pomocnicze (`sweep` = rurka/wstęga po krzywej, `bolt` = piorun, `dome` = kapelusz grzyba, `spiral`, `plated_ball`, `append_bm`). Części jak w T04: `Shell/Core/Accent/Orbit`, rozmiar = gęstość detali.
  - **Comet:** lodowe jądro z płyt z białymi szwami. Ogon z 4–8 wstęg (Neon `color`) rozchodzi się stożkiem w +X, w środku jasna wstęga i iskry (Core). Zamiast orbity okruchy lodu za ogonem.
  - **Toxic („skażona gwiazda”):** popękana skorupa z szerokimi świecącymi szczelinami, kałuże i zacieki mazi z kroplą. Kępy grzybów: trzonki w Shell (ciemne), kapelusze w Accent (Neon), zarodniki w Core.
  - **Storm (Electric):** metalowa kula z płyt z cyjanowymi szwami w walcowej klatce prętów (6–12), na prętach świecące cewki i końcówki. Od Medium pierścienie nad i pod klatką, Huge ma pierścień równikowy z węzłami. Żółte pioruny w siatce (Accent).
  - **Nebula:** „galaktyka w butelce”. Fasetowana szklana kula, w środku jądro i wstęgi gazu w różnych płaszczyznach, od Medium spiralne ramiona dysku na zewnątrz. Orbita = gwiazdki.
- Render: układ rzędów wg prawdziwej szerokości (ogon Comet), `render_grid`. Nowe obrazy: `star_lineup_5-8.png`, `star_lineup_all.png` (8 rodzajów), `star_silhouettes.png` (8 sylwetek), `star_{comet,toxic,electric,nebula}.png`, `T33 gwiazdy 5-8 w Studio.jpg`.
- Efekty dla Studio: `art/stars/fx.json` (z Blendera: Comet `tail` = początek + kierunek, Electric `beams` = pary punktów), wstrzykiwane do szablonu jako `__FX__`. Szablon `import_stars.template.luau`: LOOK/FX dla 4 rodzajów (Comet Ice, Toxic Slate, Storm Metal, Nebula Glass 0.55) i `addExtra`:
  - Comet: Attachment `Tail` + ParticleEmitter `TailSparks` wzdłuż ogona;
  - Storm: Beamy `ArcN` (żółto-cyjanowe, zakrzywione) między kulą a prętami;
  - Nebula: ParticleEmitter `Mist` (mgiełka w objętości Core).
  Animacja → T12.
- Upload FBX przez Open Cloud: Comet `95069178470467`, Toxic `79517295834281`, Electric `87067213032862`, Nebula `85564590743220`. Import: 16 modeli w `ServerStorage.Stars/<Rodzaj>/<Rozmiar>`, `StarImport` usunięty, miejsce zapisane na Roblox (Ctrl+S, „Zapisano nowe zmiany”).
- Notatki rodzajów: `model: gotowy`, `sync_vault.py` OK.

**Kryteria:**
- Sylwetki: test bez koloru (8 rodzajów) — każda inna (ogon, grzyby, klatka-walec, dysk spiralny) i inna niż 1-4. Użytkownik zaakceptował wygląd (9.11).
- Tris (Small/Medium/Large/Huge), budżet 2k/3,5k/5,5k/8k:
  - Comet: 1568 / 1856 / 3604 / 4124
  - Toxic: 1552 / 2116 / 5328 / 6364
  - Storm: 1476 / 2296 / 3000 / 4010
  - Nebula: 720 / 1688 / 2308 / 3108
  - Wszystko `ok`.
- Strefy: w Blenderze każda strefa leży 0,02–0,04 j. nad powierzchnią Shell/Core (BVH, Huge). W Studio raycast daje 0,1–1,0 studa dla Comet/Nebula/Storm. Wyjątki („inf”/7 studów) przy Toxic i Comet wynikają z przybliżonej kolizji MeshPart (`CollisionFidelity` Default — wypukła otoczka wokół grzybów i spodu), a nie z błędnych stref.

**Użyte skille:** `task`, `blender-asset`, Studio MCP (`open_cloud_invoke`, `insert_asset`, `execute_luau`, `screen_capture`), `anthropic-skills:computer-use` (Ctrl+S).

**Problemy / uwagi:**
- `CollisionFidelity` Default na Shell/Core: kliknięcia/raycasty trafiają w otoczkę, nie w siatkę (najbardziej Toxic z grzybami, Storm z klatką). Do rozważenia w T06: `PreciseConvexDecomposition` dla Shell albo trafienia liczone po strefach. Zapisane tutaj, poza zakresem T33.
- Import zrobiłem skryptem tylko z rodzajami 5-8 (żeby nie odtwarzać 1-4). Pełny `import_stars.luau` zawiera wszystkie 8.
- Assety Open Cloud mają `isPublished: true` (jak w T04).
