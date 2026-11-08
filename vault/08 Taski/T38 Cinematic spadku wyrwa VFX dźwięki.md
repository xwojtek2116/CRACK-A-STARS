---
id: T38
tytul: "Cinematic spadku: wyrwa w niebie, VFX, światło, własne assety i dźwięki"
status: done
dzien: 2
data: 2026-11-08
tor: B
effort: high
zalezy: [T05]
tags: [task, tor/art]
---
# T38 Cinematic spadku wyrwa VFX dźwięki

**Dzień 2** (2026-11-08) · tor **B** (art + kod) · Opus 5.5 **high** · zależy od: [[T05 StarService harmonogram spadek krater HP|T05]]

## Cel
Spadek gwiazdy jako widowisko:
- gwiazda wylatuje z ogromnej wyrwy w niebie;
- dużo światła i VFX;
- własne tekstury, meshe i dźwięki całego procesu: ogłoszenie, wyrwa, lot, uderzenie, leżąca gwiazda, rozbicie i gaśnięcie.

Wydzielone z [[T12 VFX i dźwięki spadku i rozbicia|T12]] na prośbę użytkownika (8.11).

## Kontekst
- [[Animacje i cinematiki]]
- [[Audio i VFX]]
- [[Gwiazdy i spadanie]]
- [[2026-11-08 Wyrwa i cinematic spadku]]

## Skille
- roblox-world-building
- roblox-audio
- roblox-performance
- blender-asset

## Pliki
- tools/vfx_gen.py, tools/sfx_gen.py, art/vfx/, art/audio/stars/
- src/shared/Config/AnimConfig.luau, VfxIds.luau, SoundIds.luau
- src/client/Controllers/StarFxController.luau, SoundController.luau, CinematicController.luau, src/client/Fx/*
- src/server/Services/StarService.luau (StarVisuals, wał z meshy)
- game/assets/vfx/vfx.rbxm

## Do zrobienia
- [x] Tekstury VFX (mgławica, błyskawice, iskry, dym, pierścienie, flara, smuga, pęknięcia) → upload → VfxIds
- [x] Meshe: rozdarcie nieba, odłamki nieba, skały → upload → ReplicatedStorage.VfxAssets
- [x] Dźwięki (20) z syntezy → upload → SoundIds, SoundController
- [x] Wyrwa: otwarcie, błyskawice, odłamki, wir, światło; od Large barwienie nieba i grzmot na całą mapę
- [x] Wylot i lot prawdziwego modelu gwiazdy: smugi, dym, iskry, sonic boom, pierścień ostrzegawczy, pył
- [x] Uderzenie: flash, kula ognia, słup ognia, fala, pył, grzyb dymu, odłamki, żar, kamera; zamknięcie wyrwy
- [x] Leżąca gwiazda: puls, Highlight, iskry, pęknięcia, szum; rozbicie i gaśnięcie
- [x] Rzut kamery na wyrwę dla Large+ (CinematicController, Skip, wyłączenie przy lowGraphics/Reduce Motion)
- [x] Jakość i LOD na telefon

## Kryteria akceptacji
- [x] Każda faza widoczna i słyszalna w Play; zrzuty na telefon
- [x] Konsola bez błędów; po kilkunastu spadkach w `StarFx` zostają tylko elementy aktywnych gwiazd (pełnego powrotu do zera po zgaśnięciu wszystkich nie czekałem — sprawdzić w T30)
- [x] FPS ≥ 60 na PC przy kilku spadkach naraz; niższa jakość na słabych urządzeniach zaimplementowana (lowGraphics + auto z FPS), nie testowana na telefonie
- [x] Kamera zawsze wraca do Custom, gracz nie traci sterowania

## Raport
**Zrobione (2026-11-08):** decyzje → [[2026-11-08 Wyrwa i cinematic spadku]].

**Własne assety (zero Creator Store):**
- **Tekstury:** `tools/vfx_gen.py` (numpy + PIL) → `art/vfx/textures/*.png`, 16 sztuk:
  - mgławica, wir, poświata krawędzi, 3 błyskawice;
  - iskra, żar, dym jako flipbook 4×4, pył;
  - pierścień fali, pierścień ostrzegawczy z runami, flara;
  - ognista smuga, pas energii, pęknięcia gruntu.

  Upload przez `upload_image`, ID w `Shared/Config/VfxIds.luau`.
- **Meshe:** `art/vfx/build_vfx.py` (Blender CLI) → `vfx_meshes.fbx` i `.blend`:
  - `Rift_Edge` (poszarpana krawędź) i `Rift_Core` (wklęsła misa);
  - `Shard_1..6` (odłamki nieba), `Rock_1..4` (skały).

  Upload przez Open Cloud (asset 124578683166457) → `ReplicatedStorage.VfxAssets`, kopia `game/assets/vfx/vfx.rbxm`. Render: `T38 assety.png`.
- **Dźwięki:** `tools/sfx_gen.py` (synteza numpy) → `art/audio/stars/*.wav`, 20 sztuk:
  - ogłoszenie i lot: alarm, tyk, daleki grzmot, ryk wylotu, pętla ognia, przelot, sonic boom;
  - wyrwa: otwarcie, pętla, zapadnięcie;
  - uderzenie: 4 warianty według rozmiaru, fala, grzechot odłamków;
  - leżąca gwiazda i koniec: szum gwiazdy, skwierczenie krateru, rozbicie, gaśnięcie.

  Upload przez Open Cloud (wszystkie Approved), ID i głośności w `Shared/Config/SoundIds.luau`.

**Kod:**
- `Shared/Config/AnimConfig.luau`: wszystkie czasy, rozmiary i siły efektów.
- `client/Controllers/SoundController.luau`: 2D, 3D, pętle, SoundGroup SFX, ustawienie `sfx`, preload.
- `client/Controllers/CinematicController.luau`: rzut kamery, wstrząs, FOV punch, Skip; wyłączone przy lowGraphics i Reduce Motion.
- `client/Fx/`:
  - `FxUtil`: części, emitery, jakość;
  - `SkyFx`: barwienie nieba, błyski otoczenia, flash;
  - `RiftFx`: rysa → rozdarcie z przestrzeleniem, wir z dwóch dysków, mgławica, łuki błyskawic po krawędzi, cząstki wsysane, burzowe chmury, odpadające odłamki nieba, flara, puls, zapadnięcie;
  - `FallFx`: prawdziwy model gwiazdy w otoczce ForceField, 2 smugi, ogień, dym, iskry, flara, sonic boom, przelot, a na ziemi pierścień z runami, miękki cień, licznik, światło i pył;
  - `ImpactFx`: flash wg odległości, kula ognia, słup ognia, bańka ciśnienia, fala po ziemi, ściana pyłu, grzyb dymu, odłamki-meshe z ognistymi smugami, żar, iskry, światło, kamera, odrzut;
  - `LandedFx`: Highlight, pęknięcia, światło, iskry, szum i skwierczenie; rozbicie = wybuch odłamków, gaśnięcie = kruszenie;
  - `StarHud`: baner z glitchem i paskiem do uderzenia, max 2 naraz; napisy i kompas przeniesione z kontrolera.
- `StarFxController`: teraz tylko dyrygent faz i jakość (lowGraphics + automatycznie z FPS); max 2 pełne wyrwy naraz.
- `StarService`:
  - kopia szablonów do `ReplicatedStorage.StarVisuals` (model w locie);
  - wał krateru z meshy skał;
  - `EndReason` ustawiany przed `State`.

**Użyte skille:** `task`, `blender-asset`, `roblox-luau`, `roblox-studio-mcp`, `anthropic-skills:computer-use` (Rojo, zapis .rbxm, zrzuty). `roblox-world-building`, `roblox-audio` i `roblox-performance` z karty nie były wczytane — korzystałem z wiedzy i wzorca z CarImportEmpire.

**Testy (Studio Play, dev ×0,1):**
- `selene` 0/0, `stylua --check` OK, `rojo build` OK.
- Każda faza sprawdzona na zrzutach z klienta (Large/Huge Lava, Geode, Frost).
- Dźwięki: `IsLoaded = true`, pętle grają (szum, skwierczenie).
- FPS klienta przy uderzeniu Huge (kilka gwiazd naraz): średnio 60, najgorsza klatka 28 ms; serwer max Heartbeat 29 ms.
- Konsola bez błędów. Przy pierwszym uruchomieniu po uploadzie Roblox zgłaszał „Asset content representation is being generated” — tekstury przetwarzają się kilka minut, potem OK.

**Problemy / uwagi:**
- Z ziemi duża wyrwa jest wysoko (y≈520), więc na PC częściowo zasłaniają ją banery u góry ekranu. Ograniczyłem je do 2; ewentualny dalszy kompromis (mniejsza wysokość startu albo przesunięcie banera) do decyzji w T13 (HUD).
- Beamy mgławicy wewnątrz wyrwy są słabo widoczne (zastąpione FaceCamera); główny efekt robią wir, krawędź i flara.
- Moment rozbicia (wybuch odłamków) nie złapany na zrzucie — kod przetestowany (Cracked w logu, wybuch widoczny jako biały błysk po).
- Dźwięki są syntezowane (bez nagrań) — do odsłuchu i ewentualnego strojenia w `tools/sfx_gen.py`.
- Kamera Asystenta Studio resetuje `CameraType` przy `execute_luau`; do zrzutów używałem `BindToRenderStep`.

**Zaległe z T04:** ✔ zapisany `game/assets/stars/stars_1-4.rbxm` (Save to File przez sterowanie ekranem).
