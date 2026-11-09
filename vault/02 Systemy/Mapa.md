---
typ: system
status: gotowe
taski: [T03, T36, T15]
tags: [system]
---
# Mapa

> [!important] Decyzja 2026-11-08
> Mapa jest **duża** (promień 2000 studs, ok. 2,5× więcej niż blockout T03), żeby gracze czuli presję, czy zdążą do gwiazdy przed innymi. **Lobby** jest w centrum mapy. Liczby: `Economy.json` → `map`, `Stars.json` → `landing`.

```
            granica r=2000 (ściana pola siłowego)
      biomy + otwarty teren: gwiazdy spadają losowo (r 450–1900)
           pierścień 8 działek graczy (r=320)
                LOBBY w centrum (r<=180)
```

**Lobby (centrum, r ≤ 180)** — plac z budynkami w stylu stacji kosmicznej:
- **Spawn** i tablica eventów (odliczanie do Deszczu Gwiazd, ostatnie rzadkie dropy serwera).
- **Tool Shop** — narzędzia ([[Narzędzia]]).
- **Garage** — kupno pojazdów, jetpack ([[Pojazdy i ruch]]).
- **Sell Station** — sprzedaż przedmiotów łupu za kasę (cena = $/s × 300 s, potwierdzenie od Legendary).
- **Upgrades** — sloty bazy.
- **Robux Shop / VIP** — gamepassy i produkty ([[Monetyzacja]]), strefa VIP.
- **Index Hall** — kolekcja (Indeks) i **portal Rebirth**.
- **Daily / Codes** — nagroda dzienna, kody, nagroda za grupę.
- Każdy budynek = ProximityPrompt + ten sam ekran co przycisk w HUD (gracz nie musi biec do lobby, żeby kupić; ale w lobby jest to naturalne i widowiskowe).

**Działki (r = 320):** 8 baz w pierścieniu tuż przy lobby — blisko sklepów, daleko od gwiazd.

**Teren gry (r 450–1900):** 4 biomy (Pola Lawy, Lodowy Krater, Kryształowy Kanion, Mgławicowy Płaskowyż) jako duże ćwiartki planety z przejściami między nimi; wzgórza, kratery, skały do przeskakiwania jetpackiem. **Gwiazdy spadają losowo w dowolnym miejscu tego pierścienia**; biom pod punktem uderzenia zwiększa szansę pasujących rodzajów ×2.

**Presja, ale bez frustracji:**
- Średnio ~1200 studs do gwiazdy: sprint ~45 s, Hoverboard ~30 s, Rocket Bike ~16 s → pojazdy realnie się opłacają.
- Ostrzeżenie przed spadkiem 8–45 s (wg rozmiaru), gwiazda żyje 2–7 min, kompas i znacznik na ekranie.
- Przycisk **Return to Lobby** (cooldown 10 s) i przywołanie kupionego pojazdu w dowolnym miejscu.
- Drogi z lobby do biomów, rampy i wyrzutnie skoku.

**Niebo**: skybox z mgławicą, 2–3 wielkie planety, `Atmosphere` fioletowo-niebieska. Granice: kopuła pola siłowego, sufit y=600.

**Wydajność:** `StreamingEnabled` (już włączone), teren z Terrain + niewiele dużych meshy, propsy z instancjonowanych modeli, `Model.LevelOfDetail` dla dalekich skał. Cel 60 FPS na telefonie.

Blockout w Studio (T03, mały) → **powiększenie i lobby (T36)** → finalne propsy z Blendera (T15). Zapis `.rbxm` w `game/assets/map/`.

**Mapa finalna (T15, 2026-11-09):** niebo `Lighting.NebulaSky` (granat + zorza, z Blendera) i planety `Workspace.Map.Sky` (gazowy olbrzym z pierścieniem, czerwona, lodowy księżyc; klient przesuwa je za kamerą); 8 budynków stacji w stylu stacji kosmicznej (`Stations.<Stacja>.Building` + niewidzialna kotwica `Body` dla witryny `ToolService`); 765 propsów z Blendera w `Workspace.Map.Props.<Biom>` (skupiska, mieszanie w pasie ±12° granicy biomów, punkty orientacyjne: łuk lawy, łuk lodu, iglica kryształu, monolit mgławicy, 8 wież-latarni, 2 wraki), 16 pylonów pola siłowego na r = 1995, neonowe krawędzie ramp, wystrój obrzeża działek (`Plot_N.Decor`). Klimat biomów (Atmosphere, tint, cząsteczki) robi `MapAmbienceController` z `MapAmbienceConfig`. Szczegóły: [[2026-11-09 Mapa finalna T15]]. Zrzuty: ![[T15 lobby niebo.jpg]] ![[T15 Lava Fields.jpg]]

**Duża mapa (T36, 2026-11-08):** teren z Terrain generowany skryptem `tools/studio/T36_map_gen.luau`; `Workspace.Map` = `Lobby` (płaskowyż +20, stacje z tagiem `LobbyStation` + atrybut `Station`), `Biomes/<Theme>/LandingZone` (tag `StarLandingZone`, atrybuty `Theme`, `AngleMin/Max`, `RadiusMin/Max`), `Ramps`, `Bounds`; działki `Workspace.Plots/Plot_1..8` na r=320. Sprint do średniej gwiazdy ~42–51 s. Szczegóły: [[2026-11-08 Teren i lobby T36]]. Zrzut: ![[T36 mapa z gory.jpg]]

**Blockout (T03, 2026-11-07, przed powiększeniem):** hub r ≤ 110, działki `Workspace.Plots/Plot_1..8` na r=300, strefy `Workspace.Map.Zones.<Theme>.LandingZone` (tag `StarLandingZone`, atrybut `Theme`) na r=600, granice r=790 / y=400. Szczegóły: [[2026-11-07 Blockout mapy]]. Zrzut: ![[T03 blockout z gory.jpg]]
