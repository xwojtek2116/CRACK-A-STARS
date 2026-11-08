---
typ: decyzja
data: 2026-11-08
tags: [decyzja]
---
# Teren i lobby (T36)

**Decyzje użytkownika (8.11):** teren „średni” (wzgórza 30–80 studs, kratery, skały), lobby na **płaskowyżu +20 studs** z łagodnym zboczem dookoła, układ lobby **krzyż + ćwiartki**, **płynne przejście** między biomami.

**Ustalenia techniczne:**
- Teren = Terrain (voxele 4 studs), generowany deterministycznie skryptem `tools/studio/T36_map_gen.luau` (SEED 3636). Teren nie jest w `.rbxm` — odtwarza się go tym skryptem (instrukcja w nagłówku pliku). Gładki teren rysuje powierzchnię ~2 studs nad granicą pełnego voxela — generator to kompensuje (`TERRAIN_SURFACE_OFFSET`).
- Strefy: r<184 lobby (y=20), zbocze do r=250, płasko y=0 do r=420 (działki), przejście do biomów r 420–640, biomy do r=1880, wał górski r 1880–2060. Kąt biomu = atan2(z, x): Lava 0°, Frost 90°, Crystal 180°, Nebula 270°.
- Biomy: Lava — wzgórza + 4 wulkany z kalderą (CrackedLava); Frost — 24 kratery + Wielki Lodowy Krater (r=220) obok drogi; Crystal — grzbiety i kaniony + 34 kępy neonowych kryształów; Nebula — tarasy co 16 studs. Przejście: wysokość mieszana w pasie 120 studs, materiał z szumem ±~90 studs.
- **Mapa biomów dla StarService (T05):** `Workspace.Map.Biomes.<Theme>.LandingZone` — niewidzialny znacznik z tagiem `StarLandingZone`, atrybuty `Theme`, `DisplayName`, `AngleMin`/`AngleMax` (stopnie, Lava −45…45), `RadiusMin` 450, `RadiusMax` 1900. Gwiazda losuje punkt w pierścieniu (`Stars.json` → `landing`), biom = ćwiartka z kąta punktu.
- **Lobby:** `Workspace.Map.Lobby` — podłoga y=20.4, `Spawn` w środku, nad nim `EventBoard`; 4 drogi i bramy z nazwami biomów; budynki w ćwiartkach (45°: ToolShop, Garage · 135°: SellStation, Upgrades · 225°: IndexHall, RebirthPortal · 315°: RobuxShop z `VipZone`, DailyCodes). Każda stacja = Model z tagiem `LobbyStation`, atrybutami `Station` (= nazwa modelu) i `DisplayName`, część `PromptAnchor` z Attachmentem `Prompt` pod ProximityPrompt (T14).
- Drogi = materiał Asphalt w terenie (oś wygładzona), 3 rampy na każdej drodze (r 650/1050/1450, jeden pas, niska strona od lobby).
- Granica: 64 ściany ForceField na r=2000 (y −100…600), niewidzialny sufit y=600 (4 części 2048×2048).
- Działki `Plot_1..8` przesunięte radialnie na r=320 razem z `BuildOrigin`.
- **Atmosphere** pod dużą mapę: Density 0.26 → **0.20**, Haze 1.4 → **0.8**, Offset 0.15 → **0.10** (przy starych wartościach teren dalej niż ~500 studs znikał w mgle, a neonowe kryształy „wisiały” w powietrzu).

**Pomiary (Play, WalkSpeed 28 = `sprintSpeed`):** lobby → środek biomu drogą 41.9 s (Lava) i 42.8 s (Nebula); lobby → średnia gwiazda (r=1324, Crystal Canyon, przez bramę i teren) 51.0 s; lobby → krawędź r=1880 68.7 s. FPS w Studio średnio 60.2, chwilowe spadki do ~38 przy doczytywaniu terenu.
