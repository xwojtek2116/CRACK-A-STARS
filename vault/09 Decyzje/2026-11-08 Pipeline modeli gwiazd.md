---
typ: decyzja
data: 2026-11-08
tags: [decyzja]
---
# Pipeline modeli gwiazd

**Decyzja (T04):**
- Gwiazda = do 4 MeshPartów wg roli: `Shell` (bryła, kolor `shell`), `Core` (Neon, `glow`), `Accent` (detal rodzaju, `color`), `Orbit` (odłamki, tylko Large/Huge). Gra koloruje części z `Themes.json` — jedna geometria na rodzaj×rozmiar.
- Sylwetki rodzajów 1–4: Iron = spłaszczony „ziemniak” z wgnieceniami i guzami; Lava = kula płyt bazaltu na magmie z kroplami; Frost = „jeżowiec” z długich kolców lodu; Geode = jajo z otworem i grotą ametystów.
- Rozmiar zmienia gęstość: siatka (ikosfera 320 → 1280 ścian), liczba płyt/kryształów, odłamki na orbicie od Large. Budżet: Small ≤ 2k, Huge ≤ 8k tris (wyszło 0,6–1,4k i 2,6–6,3k).
- Strefy rozbijania liczone w Blenderze (raycast na Shell+Core, górna półkula) → `art/stars/zones.json`; Attachmenty `Zone_N` na Shell tworzy wygenerowany `art/stars/import_stars.luau`.
- Import bez klikania: upload FBX przez Open Cloud (`open_cloud_invoke`) → `insert_asset` → `import_stars.luau`. Wymaga zatwierdzenia folderu `E:\CrackAStars\art` w Studio (Assistant Settings → MCP Permissions).

- **Świecenie (poprawka 8.11):** `Core` = cała geometria świecąca (`glow`, Neon), w tym boczne ściany płyt odcięte od Shell (`split_rim`) — rozżarzone szwy. Frost: kolce Glass z neonowym rdzeniem. Import dodaje na Core PointLight `Glow` + ParticleEmitter `Aura` (tekstury `rbxasset://textures/particles/*`, bez uploadu); animacja/pulsowanie w T12.

**Powód:** jeden skrypt na wszystkie 12 rodzajów (T33/T34 dopisują tylko moduły), kolory i rozmiary z JSON, zero ręcznej pracy w Studio.
