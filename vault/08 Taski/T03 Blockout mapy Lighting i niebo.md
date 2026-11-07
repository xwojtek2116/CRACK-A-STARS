---
id: T03
tytul: "Blockout mapy Lighting i niebo"
status: done
dzien: 2
data: 2026-11-08
tor: C
effort: high
zalezy: [T02]
tags: [task, tor/swiat-ui-biznes]
---
# T03 Blockout mapy Lighting i niebo

**Dzień 2** (2026-11-08) · tor **C** (swiat-ui-biznes) · Opus 5.5 **high** · zależy od: [[T02]]

## Cel
Blockout mapy Lighting i niebo.

## Kontekst
- [[Mapa]]
- [[Styl graficzny]]

## Skille
- roblox-world-building
- roblox-studio-mcp

## Pliki
- Workspace (Studio), game/assets/map/blockout.rbxm

## Do zrobienia
- [x] Planeta-hub z klocków: hub, 8 działek, 4 strefy z tagiem StarLandingZone i atrybutem Theme
- [x] Lighting: Future, Atmosphere, Bloom, ColorCorrection, skybox tymczasowy
- [x] Granice mapy
- [ ] Zapis place + .rbxm — `.rbxm` ✔, Ctrl+S miejsca ✘ (patrz Zaległe kroki)

## Kryteria akceptacji
- [x] Zrzut z góry i z perspektywy gracza wysłany na telefon
- [x] FPS ≥ 60 w Studio

## Raport
**Zrobione (2026-11-07, Studio `game/places/CrackAStars.rbxl` przez MCP):**
- `Workspace.Map`: `Ground` (dysk Ø1600, grunt Slate, 16 łagodnych wzgórz), `Paths` (4 drogi hub → strefy), `Hub` (platforma Ø220, `Spawn` SpawnLocation, bloki `ToolShop`, `Garage`, `EventBoard` „Star Shower”, `RebirthPortal`), `Zones`, `Bounds`.
- `Workspace.Plots`: `Plot_1..8` (Model, atrybuty `PlotId`, `OwnerUserId=0`, `Base` 96×96, `Points/Spawn`, `Sign`, `BuildOrigin` CFrameValue) — konwencja PlotService z CarImportEmpire, gotowe pod T08. Działki na r=300, kąty 22.5°+45°·k, przodem do hubu.
- 4 strefy na r=600 (0°/90°/180°/270°): część `LandingZone` (cylinder Ø300) z tagiem `StarLandingZone`, atrybutami `Theme` (= id strefy z `Themes.json`: `LavaFields`, `FrostCrater`, `CrystalCanyon`, `NebulaPlateau`) i `DisplayName`. Frost Crater ma wał z bloków lodu, Nebula Plateau jest podniesiony o 14 studs z rampą, Crystal Canyon ma neonowe kryształy.
- Granice: 48 niewidzialnych ścian (r=790, wys. 400), niewidzialny sufit na y=400, kopuła `Dome` (ForceField, bez kolizji).
- Lighting: `LightingStyle = Realistic` (następca Technology=Future — `Technology` nie jest już dostępne z MCP), `ClockTime 20.5`, Brightness 2.5, Ambient (70,60,100), OutdoorAmbient (140,125,185), Exposure 0.5; `Atmosphere` fioletowa (Density 0.26), `BloomEffect`, `ColorCorrectionEffect`, `Sky` tymczasowe (`TempSky`, 5000 gwiazd, duży księżyc).
- Szczegóły i liczby: [[2026-11-07 Blockout mapy]].

**Pliki:** `game/assets/map/blockout.rbxm` (Map + Plots, 163 części), `game/assets/map/lighting.rbxm` (folder `LightingPreset` z dziećmi Lighting), `vault/_img/T03 blockout z gory.jpg`, `vault/_img/T03 blockout gracz.jpg`, `vault/09 Decyzje/2026-11-07 Blockout mapy.md`, `vault/02 Systemy/Mapa.md`.

**Użyte skille:** roblox-world-building, roblox-studio-mcp, anthropic-skills:computer-use (dostęp odrzucony).

**Testy:** Play w Studio: avg FPS 60.0 (min 53.6 w pomiarze 5 s), postać pojawia się na `Spawn` w hubie. Zrzut z góry i z perspektywy gracza wysłane na telefon. Konsola: tylko `rbxassetid://203785492 … Asset type does not match` (×3) — nie pochodzi z naszych instancji (sprawdzone), prawdopodobnie wewnętrzny asset Studio.

**Problemy:**
- Sterowanie ekranem Roblox Studio odrzucone 2× → brak Ctrl+S. `.rbxm` wyciągnięte bez klikania: `SerializationService` → base64 → wynik MCP → plik (sumy kontrolne zgodne). HTTP ze Studio na localhost blokuje allowlista Assistant.
- Karta mówi „Lighting: Future” — w tej wersji Studio to `LightingStyle.Realistic`.

## Zaległe kroki
- [ ] **Zapisać miejsce w Studio (Ctrl+S)** — `game/places/CrackAStars.rbxl` ma mapę i Lighting tylko w pamięci Studio. Jeśli Studio zostało zamknięte bez zapisu: wstaw `game/assets/map/blockout.rbxm` do Workspace (Map i Plots), dzieci `LightingPreset` z `lighting.rbxm` przenieś do Lighting, a właściwości Lighting ustaw wg [[2026-11-07 Blockout mapy]]. Powód: sterowanie komputerem odrzucone. (T04: ponowna próba — odrzucone, krok przeniesiony do Zaległych T04.)
