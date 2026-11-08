---
id: T36
tytul: "Powiększenie mapy i lobby w centrum"
status: done
dzien: 2
data: 2026-11-08
tor: C
effort: high
zalezy: [T03]
tags: [task, tor/swiat-ui-biznes]
---
# T36 Powiększenie mapy i lobby w centrum

**Dzień 2** (2026-11-08) · tor **C** (swiat-ui-biznes) · Opus 5.5 **high** · zależy od: [[T03]]

## Cel
Przebudować blockout z T03 na dużą mapę (promień 2000) z lobby w centrum, żeby wyścig do gwiazdy dawał presję.

## Kontekst
- [[Mapa]]
- [[2026-11-08 Duża mapa i lobby]]
- [[2026-11-07 Blockout mapy]]

## Skille
- roblox-world-building
- roblox-studio-mcp
- roblox-performance

## Pliki
- game/assets/map/blockout.rbxm, game/assets/map/lighting.rbxm (Studio przez MCP)

## Do zrobienia
- [x] Planeta r=2000 (Terrain: wzgórza, kratery, skały), granica i sufit wg `Economy.json` → `map`
- [x] Lobby r≤180 z klocków: spawn, tablica eventów, Tool Shop, Garage, Sell Station, Upgrades, Robux Shop/VIP, Index Hall + portal Rebirth, Daily/Codes; każdy budynek z tagiem `LobbyStation` i atrybutem `Station`
- [x] Działki `Plot_1..8` przesunięte na r=320 (konwencja PlotService bez zmian)
- [x] 4 biomy jako duże ćwiartki r 450–1900 (tag `StarLandingZone` + `Theme` zostaje jako mapa biomów), drogi z lobby, rampy
- [x] Pomiar: czas sprintu z lobby do krawędzi i do środka biomu
- [x] Zapis `.rbxm`, zrzut z góry na telefon

## Kryteria akceptacji
- [x] Sprint z lobby do średniej gwiazdy ~40–50 s — 41.9–42.8 s do środka biomu drogą, 51.0 s do r=1324 przez Crystal Canyon (najtrudniejszy teren)
- [x] 60 FPS w Studio, StreamingEnabled działa (brak dziur przy biegu) — średnio 60.2 FPS, 0 dziur w terenie przed postacią
- [ ] Zrzut zaakceptowany z telefonu — wysłane 8.11, czeka na odpowiedź

## Raport
**Zrobione (2026-11-08, Studio „Rozbij gwiazdę” przez MCP, Team Create):**
- Pytania do użytkownika na starcie: teren średni, lobby na płaskowyżu +20, układ krzyż + ćwiartki, płynne przejście biomów.
- **Teren** (Terrain, 21 mln voxeli, ~15 s generowania): generator `tools/studio/T36_map_gen.luau` (deterministyczny, SEED 3636). Lobby y=20 → zbocze → płasko y=0 (działki) → biomy r 420–1880 → wał górski do r 2060. Lava: wzgórza + 4 wulkany z kalderą; Frost: 24 kratery + Wielki Lodowy Krater; Crystal: grzbiety/kaniony + 34 kępy neonowych kryształów; Nebula: tarasy. 491 głazów (FillBall). Drogi z Asphalt do r=1800.
- **Lobby** `Workspace.Map.Lobby`: podłoga Ø364 na y=20.4, plac, `Spawn`, `EventBoard` nad spawnem, 4 drogi + bramy z nazwami biomów, barierka. 9 stacji (tag `LobbyStation`, atrybut `Station`): EventBoard, ToolShop, Garage, SellStation, Upgrades, IndexHall, RebirthPortal, RobuxShop (z `VipZone`), DailyCodes; każda ma `PromptAnchor/Prompt` pod ProximityPrompt.
- **Działki** `Plot_1..8` przesunięte radialnie na r=320 (z `BuildOrigin`).
- **Biomy** `Workspace.Map.Biomes.<Theme>`: znacznik `LandingZone` (tag `StarLandingZone`, `Theme`, `DisplayName`, `AngleMin/Max`, `RadiusMin/Max`) + tablice przy wejściu (r=470) + propsy. **Rampy**: 12 (3 na drogę). **Granica**: 64 ściany ForceField r=2000, sufit y=600.
- Usunięte stare części T03: `Hub`, `Paths`, `Zones`, `Ground`, `Bounds` (kopia w historii gita `blockout.rbxm`).
- **Atmosphere** pod dużą mapę: Density 0.20, Haze 0.8, Offset 0.10 (było 0.26/1.4/0.15 — dalszy teren znikał w mgle).
- Decyzje i konwencje: [[2026-11-08 Teren i lobby T36]], [[Mapa]].

**Pliki:** `game/assets/map/blockout.rbxm` (Map + Plots, 521 części, 39 KB), `game/assets/map/lighting.rbxm`, `tools/studio/T36_map_gen.luau` (nowy — generator terenu; teren nie mieści się w `.rbxm`), `vault/_img/T36 mapa z gory.jpg`, `T36 lobby.jpg`, `T36 Lava Fields.jpg`, `T36 Crystal Canyon.jpg`, `vault/09 Decyzje/2026-11-08 Teren i lobby T36.md`, `vault/02 Systemy/Mapa.md`. Kopia miejsca: `game/places/CrackAStars.rbxl` (Plik → Pobierz kopię, poza gitem).

**Użyte skille:** roblox-world-building, roblox-studio-mcp, roblox-performance, anthropic-skills:computer-use (zapis `.rbxl`).

**Testy (Play w Studio, WalkSpeed 28 = `Vehicles.json` sprintSpeed):**
- Lobby → środek Lava Fields drogą: 41.9 s; → środek Nebula: 42.8 s; → krawędź r=1880: 68.7 s.
- Lobby → średni dystans gwiazdy (r=1324, 150°, Crystal Canyon, przez bramę i teren bez drogi): 51.0 s, bez zablokowania.
- FPS średnio 60.2 we wszystkich biegach, minimum ~38–43 (chwilowe, przy doczytywaniu terenu). Raycast terenu 150 studs przed postacią w trakcie biegu: 0 dziur; siatka 7803 punktów w Edit: 0 dziur.
- Nachylenie >40°: Lava 5.7%, Frost 9.4%, Crystal 18.4%, Nebula 18.8% (grzbiety i progi tarasów — do przeskoczenia lub obejścia).
- Konsola: bez nowych błędów (tylko znane `rbxassetid://203785492 … Asset type does not match`).

**Problemy / uwagi:**
- Gładki teren rysuje powierzchnię ~2 studs wyżej niż granica voxela — w pierwszym przebiegu działki były zakopane; poprawione offsetem w generatorze.
- Prosta linia ze spawnu przez ćwiartkę blokuje się o budynek — gracz wychodzi bramami (drogi). Do rozważenia w T15: przejścia między budynkami.
- Zrzut „z góry” ma ucięty dół mapy — Studio nie renderuje terenu tak daleko od kamery (raycasty potwierdzają, że teren jest kompletny).
- Wyrzutnie skoku (jump pady) wymagają kodu — poza zakresem; są tylko rampy.
