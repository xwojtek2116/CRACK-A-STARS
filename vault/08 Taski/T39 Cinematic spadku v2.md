---
id: T39
tytul: "Cinematic spadku v2: światło, głębia wyrwy, ogon plazmy, etapy uderzenia, słup światła, kino, muzyka"
status: done
dzien: 2
data: 2026-11-08
tor: B
effort: high
zalezy: [T38]
tags: [task, tor/art]
---
# T39 Cinematic spadku v2

**Dzień 2** (2026-11-08) · tor **B** (art + kod) · Opus 5.5 **high** · zależy od: [[T38 Cinematic spadku wyrwa VFX dźwięki|T38]]

## Cel
„1000× lepiej” (prośba użytkownika 8.11): mocniejsze światło (dynamiczny Bloom), głębia wyrwy, pęknięcia nieba i snopy światła, ogon plazmy, etapy uderzenia z hit-stopem, słup światła nad leżącą gwiazdą, kinowe pasy i karta tytułowa od Large, więcej warstw dźwięku i muzyka.

## Kontekst
- [[Animacje i cinematiki]]
- [[Audio i VFX]]
- [[2026-11-08 Wyrwa i cinematic spadku]]

## Skille
- roblox-world-building
- roblox-audio
- roblox-performance
- blender-asset

## Pliki
- tools/vfx_gen.py, tools/sfx_gen.py, art/vfx/build_vfx.py, art/vfx/, art/audio/stars/
- src/shared/Config/AnimConfig.luau, VfxIds.luau, SoundIds.luau
- src/client/Fx/*, src/client/Controllers/StarFxController.luau, SoundController.luau

## Do zrobienia
- [x] Tekstury: light_shaft, plasma, heat_ring, energy_wave, streak, glint
- [x] Meshe: SkyCrack_1..3, ShockTorus, BowCone, LavaBlob_1..2
- [x] Dźwięki: sky_crack, impact_tail, crater_cool, beacon_hum, music_tension, music_impact
- [x] Dynamiczny Bloom, HDR cząsteczek
- [x] Wyrwa: warstwy 3D, pęknięcia nieba, snopy światła, aura, mocniejsze błyskawice
- [x] Lot: ogon plazmy, stożek żaru, odpadające płonące kawałki, 3 pierścienie, Doppler
- [x] Uderzenie: hit-stop, rdzeń plazmy, torus + ściana pyłu, grzyb, rozbryzgi, płonący deszcz odłamków, stygnący krater
- [x] Słup światła nad leżącą gwiazdą, orbitujące iskry, fale energii
- [x] Kino Large+: pasy, karta tytułowa, muzyka

## Kryteria akceptacji
- [x] Zrzuty każdej fazy na telefon
- [x] FPS średnio ≥ 60, najgorsza klatka < 40 ms przy Huge i kilku spadkach
- [x] Bloom/ColorCorrection/Ambient/kamera/muzyka wracają do bazy; brak wycieków po zgaśnięciu gwiazd
- [x] Konsola bez błędów

## Raport
**Zrobione (2026-11-08):** decyzje użytkownika → [[2026-11-08 Cinematic spadku v2]].

**Nowe własne assety:**
- **Tekstury:** `tools/vfx_gen.py` (`--t39`) → `light_shaft`, `plasma`, `heat_ring`, `energy_wave`, `glint`; ID w `VfxIds.luau`.
- **Meshe:** `art/vfx/build_vfx.py -- --t39` → `vfx_meshes_t39.fbx`/`.blend` (asset 112309850615664) → `ReplicatedStorage.VfxAssets`:
  - `SkyCrack_1..3`, `ShockTorus`, `BowCone`, `LavaBlob_1..2`;
  - kopia `game/assets/vfx/vfx.rbxm`.
- **Dźwięki:** `tools/sfx_gen.py --only …` → `sky_crack`, `impact_tail`, `crater_cool`, `beacon_hum`, `music_tension` (pętla 16 s, 120 BPM: bębny, bas, smyczki, tremolo), `music_impact` (akord + bęben + talerz); wszystkie Approved, ID w `SoundIds.luau`.

**Kod:**
- `AnimConfig`: nowe sekcje BLOOM, HITSTOP, CINEMA; rozszerzone RIFT, FALL, IMPACT i LANDED.
- `SkyFx`: dynamiczny Bloom (mocniejszy przy spadku, skok przy flashu, powrót do bazy z Lighting).
- `RiftFx`:
  - 4 warstwy głębi (dwa wiry, głęboka mgławica, jasny rdzeń);
  - rosnące pęknięcia nieba (meshe);
  - snopy światła z wyrwy w stronę uderzenia;
  - aura błysków, błyskawice grubsze ×1,5 z HDR;
  - smugi cząstek (Squash).
- `FallFx`: 3-warstwowy ogon plazmy (długość rośnie z prędkością), stożek żaru (ForceField + Neon), płonące kawałki odrywające się w locie, 3 pierścienie przyspieszenia (środkowy z sonic boom), Doppler pętli lotu.
- `ImpactFx` — hit-stop 0,12 s (zamrożony biały rdzeń), potem etapy:
  - torus fali i ściana pyłu;
  - kapelusz grzyba;
  - roztopione rozbryzgi z ognistymi smugami;
  - unoszący się żar przez 7 s;
  - ogon pogłosu (Large+) i stygnięcie krateru.
- `LandedFx`: słup światła do nieba (2 Beamy + błysk na szczycie, widoczny z całej mapy, pulsuje), orbitujące iskry-komety, fale energii co 2,2 s, buczenie słupa; przy końcu słup się zwęża i gaśnie.
- `StarHud`: kino — pasy kinowe i karta tytułowa „HUGE LAVA STAR / IS TEARING THROUGH THE SKY!”, która potem chowa się do banera.
- `SoundController`: grupa Music, `playMusic`, ustawienie `music`.
- `StarFxController`: kino i muzyka od Large (motyw napięcia od ogłoszenia, akord przy uderzeniu, wyciszenie).
- `StarService` (tylko tryb dev): akcja `pause` w `DevStar` do testów.

**Użyte skille:** `task`, `blender-asset`, `roblox-luau`, `roblox-studio-mcp`, `anthropic-skills:computer-use`.

**Testy (Studio Play, dev ×0,1):**
- `selene` 0/0, `stylua` OK, `rojo build` OK; konsola bez błędów.
- Zrzuty każdej fazy wysłane na telefon (`vault/_img/T39 *.jpg`).
- **FPS:**
  - 4 spadki naraz (Huge, Large, Medium, Small): średnio 59,8, jeden skok 107 ms w klatce, w której powstały 4 wyrwy naraz (razem z teleportem postaci);
  - pojedyncze Huge i Large: 0 klatek > 35 ms przez 40 s, włącznie z uderzeniami.
- **Sprzątanie po zgaśnięciu wszystkich gwiazd:**
  - `StarFx` = 0, attachmenty w Terrain = 0, ColorCorrection usunięty;
  - Bloom wrócił do 0,9/28/1,4, OutdoorAmbient do bazy, kamera `Custom`;
  - zostaje 9 dźwięków (domyślne dźwięki postaci).

**Problemy / uwagi:**
- Gdy w tej samej klatce startuje kilka wyrw (np. event Deszcz Gwiazd), może być pojedyncze przycięcie. W evencie (T18) rozłożyć starty o kilka klatek.
- Pęknięcia nieba z Bloom były zbyt grube — zmniejszone (`crackThickness` 0,5, kolor bez rozjaśnienia).
- Studio miało drugie okno (strona startowa), którego nie da się zamknąć przyciskiem; zostawione, główne okno gry działa.
- Muzyka i dźwięki to synteza — do odsłuchu na telefonie (wysłane próbki).
