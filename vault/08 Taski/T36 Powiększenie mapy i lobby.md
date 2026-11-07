---
id: T36
tytul: "Powiększenie mapy i lobby w centrum"
status: todo
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
- [ ] Planeta r=2000 (Terrain: wzgórza, kratery, skały), granica i sufit wg `Economy.json` → `map`
- [ ] Lobby r≤180 z klocków: spawn, tablica eventów, Tool Shop, Garage, Sell Station, Upgrades, Robux Shop/VIP, Index Hall + portal Rebirth, Daily/Codes; każdy budynek z tagiem `LobbyStation` i atrybutem `Station`
- [ ] Działki `Plot_1..8` przesunięte na r=320 (konwencja PlotService bez zmian)
- [ ] 4 biomy jako duże ćwiartki r 450–1900 (tag `StarLandingZone` + `Theme` zostaje jako mapa biomów), drogi z lobby, rampy
- [ ] Pomiar: czas sprintu z lobby do krawędzi i do środka biomu
- [ ] Zapis `.rbxm`, zrzut z góry na telefon

## Kryteria akceptacji
- [ ] Sprint z lobby do średniej gwiazdy ~40–50 s
- [ ] 60 FPS w Studio, StreamingEnabled działa (brak dziur przy biegu)
- [ ] Zrzut zaakceptowany z telefonu

## Raport
_(uzupełnia Claude po zakończeniu: co zrobiono, pliki, użyte skille, wynik testów, problemy; „Zaległe kroki” tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić)_
