---
typ: decyzja
data: 2026-11-09
tags: [decyzja]
---
# Mapa finalna: niebo, lobby, propsy (T15)

**Kontekst:** T15 zamienia blockout T03/T36 na finalną mapę. Przed startem 16 pytań do użytkownika (9.11).

**Decyzje użytkownika:**
- Lobby: wszystkie 8 stacji z Blendera, styl **stacji kosmicznej** (metal, szklane kopuły, Neon w kolorze stacji).
- Propsy: kształty **bardziej realistyczne**, 6–8 na biom, średnia gęstość w skupiskach, duże kolizyjne, małe nie.
- Teren między biomami: płynne przejścia, drogi i rampy, punkty orientacyjne.
- Niebo: skybox z Blendera, **ciemny granat + zielona zorza**, 2–3 planety 3D, **stała noc**.
- Dodatki: kopuła/granica, cząsteczki per biom, oświetlenie per biom, wystrój tylko obrzeża działek.

**Decyzje techniczne (Claude):**
- **Materiały propsów = wbudowane materiały Roblox na MeshPart** (Basalt, Rock, Ice, Glacier, Snow, Sandstone, Salt, Limestone, Glass, Neon) zamiast własnych atlasów 1024 px — to też PBR, a nie dokłada pamięci tekstur. Realizm daje bryła: skały z fraktalnego szumu cięte płaszczyznami, kolumny bazaltu, warstwowe mesy.
- **„Noc” przy ClockTime 14,5:** Roblox mocno przyciemnia skybox w nocy (zorza była niewidoczna). Zostaje dzień w silniku, ale z nocnym światłem: Brightness 1,6, GeographicLatitude 55, chłodny ColorShift_Top i ambient, słońce i księżyc ukryte. Preset: `game/assets/map/lighting.rbxm`.
- **Konwencja skyboxa Roblox** (zmierzona na siatce kierunków): Ft = −Z, Bk = +Z, slot **Lf pokazuje stronę +X, Rt stronę −X**, ściana Up obrócona o 90° w lewo względem renderu. Zapisane w `art/map/sky/build_sky.py`.
- **Planety:** MeshPart + SurfaceAppearance (tekstury wypalone w Blenderze), pierścień z 168 półprzezroczystych segmentów (płaski mesh z FBX się nie renderował). Klient przesuwa je za kamerą co 25 studs (`MapAmbienceController`) — bez paralaksy na mapie r = 2000.
- **Kopuła** = istniejące ściany ForceField (T36) + 16 pylonów pola siłowego na r = 1995.
- **Kotwica `Body`** w każdej stacji (niewidzialna): `ToolService` (witryna narzędzi) liczy front z `Body`; nowy budynek nie ma tej części.
- Propsy: `ModelStreamingMode = Atomic`, duże i punkty orientacyjne `LevelOfDetail = StreamingMesh`. Duże mają `CanQuery`, więc `StarService` nie wyląduje gwiazdą na skale (punkt musi trafić w Terrain).
- `.rbxm` całej mapy nie jest zapisany (za duży na base64 z MCP) — mapa jest w miejscu na Robloxie (Team Create) i odtwarzalna skryptami (patrz [[T15 Mapa finalna strefy propsy niebo|T15]]).

**Skutki:** T37 ma gotowe ujęcia (zrzuty T15). Liczby klimatu biomów w `Shared/Config/MapAmbienceConfig.luau`.
