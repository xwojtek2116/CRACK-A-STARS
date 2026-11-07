---
typ: decyzja
data: 2026-11-07
tags: [decyzja]
---
# Blockout mapy

**Decyzje (T03):**
- Układ: hub w środku (r ≤ 110), pierścień 8 działek na r=300 (kąty 22.5°+45°·k), 4 strefy lądowania na r=600 (Lava 0°, Frost 90°, Crystal 180°, Nebula 270°), drogi hub → strefa między działkami. Promień planety 800, ściany na r=790, sufit y=400.
- Strefa = część `LandingZone` (cylinder Ø300) z tagiem `StarLandingZone`, atrybutem `Theme` = id strefy z `Themes.json` (pole `zone`) i `DisplayName`. Spawner gwiazd losuje punkt w obrębie tej części.
- Działki w `Workspace.Plots/Plot_N` w konwencji PlotService z CarImportEmpire (`PlotId`, `OwnerUserId`, `Points/Spawn`, `Sign`, `BuildOrigin`), żeby T08 kopiował bez zmian.
- Lighting: `LightingStyle = Realistic` (zamiast Technology=Future), `PrioritizeLightingQuality = false` (telefony same obniżają jakość). Wieczór kosmiczny: `ClockTime 20.5`, `GeographicLatitude 30`, `Brightness 2.5`, `Ambient (70,60,100)`, `OutdoorAmbient (140,125,185)`, `ExposureCompensation 0.5`, `EnvironmentDiffuseScale 0.5`, `EnvironmentSpecularScale 0.6`, `ShadowSoftness 0.3`.
- Efekty: `Atmosphere` Density 0.26, Offset 0.15, Color (140,110,210), Decay (60,40,130), Glare 0.4, Haze 1.4 · `Bloom` 0.9/28/1.4 · `ColorCorrection` Sat 0.2, Contrast 0.08, Bright 0.02, Tint (245,238,255) · `Sky` tymczasowe (5000 gwiazd, księżyc 25°). Finalny skybox z mgławicą i planetami: [[T15 Mapa finalna strefy propsy niebo]].
- Pliki: `game/assets/map/blockout.rbxm` (Map + Plots), `game/assets/map/lighting.rbxm` (dzieci Lighting).

**Dlaczego:** strefy daleko od baz (~300 studs) dają wyścig do gwiazdy, a drogi między działkami nie prowadzą przez cudze bazy. Przy 163 częściach FPS 60 w Studio.
