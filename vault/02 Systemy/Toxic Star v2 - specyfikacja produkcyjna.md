---
typ: system
status: plan
taski: [T40]
tags: [system, gwiazdy, art]
---
# Toxic Star v2 · specyfikacja produkcyjna

Źródło prawdy wyglądu: arkusz referencyjny użytkownika `vault/_ref/toxic_user_3.png` (9.11). Nie przeprojektowujemy go. Prototyp techniczny (stany, animacje, hierarchia, debug): [Toxic Star Lab](https://claude.ai/artifact/Ws7C2sw5cG8dXctChArpmM), źródło `art/stars/toxic/viewer/ToxicStarLab.html`.

Gdy wizualna złożoność koliduje z użytecznością w Roblox, wygrywa użyteczność, a główne cechy wyglądu zostają.

## 1. Analiza referencji

| Cecha | Co widać | Decyzja techniczna |
| --- | --- | --- |
| Sylwetka | Skalna „korona” z ostrych płyt bazaltu, z boku trójkąt z najwyższym szpicem z tyłu-środka, z góry nieregularna gwiazda 6–8 ramion | Skorupa z ~30 płyt w 6 segmentach |
| Główne masy | Skorupa (~60% objętości), krater (szeroka podstawa ~2,2× szerokości gwiazdy), rdzeń | Krater osobno, nie ląduje z gwiazdą |
| Proporcje | Szer. skorupy ≈ wys.; krater ≈ 2,2× szer.; rdzeń ≈ 0,45× szer., na ~⅓ wysokości, wysunięty do przodu | Origin = środek dna krateru |
| Symetria | Asymetryczna, przód otwarty (rdzeń widoczny), tył wyższy i zamknięty | Jedna strona „front” = +Z w Blenderze, −Z w Roblox (LookVector) |
| Kryształy | Kępy zielonych heksagonalnych słupów: lewy-przód u podstawy, prawy-przód, pióropusz u góry/tyłu, pojedyncze w kraterze | 4 grupy główne + 4 małe gruntowe |
| Rdzeń | Świecąca kula z komórkowym wzorem, z której kapie maź | Neon + PointLight + flara |
| Pęknięcia | Świecące żółto-zielone żyły na płytach skorupy i krateru, promieniste pęknięcia w dnie | Neon-geometria (nie tekstura!) |
| Latające elementy | 8–12 skalnych brył + 3–5 małych kryształów wokół | Tylko klient, MeshParty bez fizyki |
| Krater | Pierścień płyt + dno z pęknięciami | Jeden MeshPart + płaska siatka pęknięć |
| Materiały | Ciemny bazalt (szary z fioletem), zielone kryształy (półprzezroczyste), świecąca maź i rdzeń | 5 materiałów (sekcja 7) |
| Ruchome | Segmenty skorupy, rdzeń, grupy kryształów, latający gruz | osobne MeshParty z pivotami |
| Tylko VFX | Poświata rdzenia, zarodniki, iskry z pęknięć, dym (stan po wybuchu), krople, fala uderzeniowa | ParticleEmitter / Beam / Neon-pierścień |

## 2. Hierarchia komponentów

```
ToxicStar (Model, PrimaryPart = MainBody.Shell01)
├── MainBody (Model)
│   ├── Shell01 … Shell06        MeshPart · MAT_Rock · ruchome (Burst, Damage, Collapse, Rebuild)
│   └── CrackVeins01 … 06        MeshPart Neon · zespawane ze swoim Shell (świecące żyły)
├── Core                          MeshPart Neon · MAT_Core · puls
├── Crystals (Model)
│   ├── CrystalA  CrystalB        kępy przód-lewo / przód-prawo · wyrastają
│   ├── CrystalC                  pióropusz u góry · nie znika w Damaged
│   └── CrystalG01 … G04          małe kępy w kraterze · wyrastają
├── Slime                         MeshPart Neon · zacieki + kałuża (statyczne)
├── Crater                        MeshPart · MAT_Ground (+ żyły Neon w CraterVeins)
├── GroundCracks                  płaski MeshPart Neon · MAT_GroundGlow
├── Hitbox                        Part, niewidoczny, CanQuery (raycasty minigry)
└── Attachments (w Shell01 / Crater)
    ANCHOR_Core, ANCHOR_Shockwave, ANCHOR_Particles, ANCHOR_Cracks_01…03, ANCHOR_Drip_01…03, Zone_1…N

Klient dokłada (nie ma tego na serwerze):
├── FloatingDebris (Folder)      Rock01…10, Shard01…05
└── Effects (Folder)             CoreGlow, CoreParticles, CrackSparks, ToxicSmoke, Drops, Shockwave
```

Zmiany względem propozycji z briefu:
- **MainBody = 6 segmentów, nie 1 siatka**: wybuch, obrażenia i odbudowa ruszają skorupą osobno w częściach. 6 to kompromis między efektem a liczbą draw calli.
- **Kryształy scalone w grupy**: 1 grupa = 1 MeshPart z pivotem u podstawy. Pojedyncze kryształy jako osobne części dałyby ~40 MeshPartów.
- **Świecące pęknięcia jako osobna geometria Neon**: SurfaceAppearance w Roblox nie świeci, a Neon tak. Żyły modelujemy jako wąskie paski wpuszczone w szczeliny płyt.
- **Latający gruz i VFX tylko na kliencie**: zero replikacji ruchu, serwer ma statyczny model.
- **Hitbox**: jedna prosta bryła do raycastów minigry zamiast precyzyjnej kolizji skorupy (problem z T33).

## 3. Stany i animacje

Stany są zaimplementowane w prototypie. Każdy stan to zestaw parametrów: energia, puls, ruch gruzu, rozlot skorupy, dym, cząsteczki, odbarwienie, ukryte kryształy. Przejście między stanami to płynny lerp (~0,4 s).

| Stan | Wygląd | Kiedy w grze (StarService) |
| --- | --- | --- |
| `Dormant` | ledwo żarzy się, gruz płynie powoli | daleko od graczy (> 250 studs) albo „Ogranicz ruch” |
| `Active` | idle: gruz krąży, nieregularny puls rdzenia, kapanie | `State = Landed` |
| `Charging` | gruz ściąga do środka, puls 2,6 Hz, iskry | ktoś gra rundę minigry na tej gwieździe |
| `Burst` | rozlot skorupy, fala, dym, potem → `Depleted` | `State = Dying`, `EndReason = Cracked` |
| `Damaged` | migotanie, brak części kryształów, luźne segmenty | `Hp / MaxHp < 0,4` |
| `Depleted` | gruz leży, kryształy szare, dym | po `Burst` albo po `Collapse` (`EndReason = Expired`) |

| Animacja | Czas | Pętla | Zachowanie | Roblox |
| --- | --- | --- | --- | --- |
| `Idle_Loop` | 4,0 s | tak | gruz unosi się, nieregularny puls | RenderStepped, sinusy z fazą per część |
| `Core_Pulse` | 1,2 s | nie | rdzeń +28% skali i jasności, powrót | Tween Size + PointLight.Brightness |
| `Floating_Debris_Loop` | 8,0 s | tak | orbity z różną prędkością i falą pionową | `PivotTo` co klatkę |
| `Crystal_Pulse` | 1,6 s | nie | fala światła od rdzenia przez grupy | opóźnienie wg odległości od `ANCHOR_Core` |
| `Crystal_Growth` | 1,4 s | nie | grupy A, B, G wyrastają (outBack) | Size + CFrame od pivotu u podstawy |
| `Energy_Charge` | 2,5 s | nie | gruz do środka, jasność rośnie, drżenie | lerp parametrów + Beamy skała → rdzeń |
| `Toxic_Burst` | 1,8 s | nie | ściśnięcie 0–0,2 s, rozlot do 0,6 s, fala do 1,35 s, powrót | Tween CFrame segmentów, Neon pierścień, `Emit` |
| `Impact_Landing` | 1,6 s | nie | spadek, odbicie, tłumione zgniecenie, rozlot gruzu | po `FallFx` (T38), krater terenu robi serwer |
| `Damage_Reaction` | 0,6 s | nie | wstrząs, impuls segmentów, migotanie | na zmianę atrybutu `Hp` |
| `Collapse` | 2,2 s | nie | energia gaśnie, gruz spada → `Depleted` | `EndReason = Expired` |
| `Depleted_Idle` | 3,0 s | tak | słaby, przerywany puls | pętla klienta |
| `Respawn_Rebuild` | 3,0 s | nie | części zlatują się, kryształy wyrastają, fala → `Active` | tylko dev i eventy (gra nie odradza gwiazd) |

Ruchy są przesadzone (rozlot ~1,8 szerokości, zgniecenie 22%), żeby były czytelne z kamery Roblox na telefonie.

## 4. Plan budowy w Blenderze

Skrypt: `art/stars/toxic/build_toxic_v2.py` (nowy, obok `build_star.py`). Jednostki: 1 BU = 1 stud dla rozmiaru Large (24 studs). Inne rozmiary skalujemy przy imporcie, LOD osobno (sekcja 6).

Nazwy obiektów: `STAR_Shell_01…06`, `STAR_CrackVeins_01…06`, `STAR_Core`, `STAR_Crystal_A`, `STAR_Crystal_B`, `STAR_Crystal_C`, `STAR_Crystal_G01…G04`, `STAR_FloatingRock_01…03` (3 warianty, klient klonuje do 10), `STAR_FloatingCrystal_01…02`, `STAR_Slime`, `STAR_Crater`, `STAR_CraterVeins`, `STAR_GroundCracks`, puste: `ANCHOR_Core`, `ANCHOR_Shockwave`, `ANCHOR_Particles`, `ANCHOR_Cracks_01…03`, `ANCHOR_Drip_01…03`, `Zone_1…N`.

1. **Blockout** (prymitywy): krater 2,2× szer., kula rdzenia 0,45× na wys. 0,33, 9 płyt pierścienia + 2 tylne szpice + 3 górne + 8 promienistych u podstawy (jak w prototypie). Porównać z widokiem z przodu, z boku i z góry arkusza.
2. **Sylwetka**: front otwarty (płyty z przodu niższe o połowę), najwyższy szpic z tyłu-środka, z góry nieregularna gwiazda.
3. **Skorupa**: płyty jako wypukłe bryły (convex hull z losowych punktów, stały seed), fazki 1 segment, Weighted Normals. Przypisanie do 6 segmentów wg kąta, join per segment, origin = środek ciężkości segmentu.
4. **Rdzeń**: ico sphere subdiv 3, wzór komórek w teksturze emisji (tylko podgląd, w Roblox kolor Neon) + `STAR_CoreShell` opcjonalnie.
5. **Kryształy**: heksagonalny słup z czubkiem (lathe 6), kępy 2–5 słupów, join per grupa, origin na dole kępy, oś Z w górę kępy.
6. **Żyły**: krzywe po szczelinach płyt → Bevel 0,02–0,04 → mesh, lekko wpuszczone (0,01) w powierzchnię. Tak samo na kraterze i w dnie (`STAR_GroundCracks`, promieniste z bocznymi gałęziami).
7. **Krater**: pierścień 26 płyt + drobny gruz + dno, join → `STAR_Crater`.
8. **Maź**: kapsuły i metaball-zacieki pod rdzeniem i na 2 przednich płytach + kałuża, join → `STAR_Slime`. Końce kropel = `ANCHOR_Drip_*`.
9. **Latający gruz**: 3 warianty skały + 2 kryształy, klient klonuje i losuje skalę.
10. **UV**: Smart UV Project 66°, margin 0,02, jedna atlasowa tekstura 1024² na `MAT_Rock` dla skorupy i krateru (2 UDIM-y niepotrzebne).
11. **Materiały i tekstury**: bake (Cycles) do Color / Normal / Roughness / Metalness 1024² (Small 512²).
12. **Optymalizacja**: Decimate (Planar 5°) do budżetu, sprawdzenie tris skryptem.
13. **Przygotowanie animacji**: originy (segmenty, kryształy u podstawy), puste ANCHOR_* jako dzieci `STAR_Shell_01` / `STAR_Crater`.
14. **Eksport**: FBX, Apply Transform, scale 1, Selected Objects; render podglądu do `vault/_img/T40 Toxic v2.png`.

## 5. Materiały

| Materiał | Blender | Roblox | Uwagi |
| --- | --- | --- | --- |
| `MAT_Rock` | Principled, bazalt #4b4853, roughness 0,85, normal z płyt i rys | SurfaceAppearance (Color, Normal, Roughness, Metalness 1024²) | jedna tekstura na 6 segmentów |
| `MAT_Core` | Emission #9dff2a, siła 5 | `Material = Neon`, `Color = #9dff2a`, PointLight `Glow` | jasność steruje `Color` i Brightness |
| `MAT_ToxicCrystal` | Principled, #8dff3f, transmission 0,6, emisja 0,6 | `Material = Glass`, `Transparency 0,15`, zielony + Neon-rdzeń w środku kępy | Glass załamuje i łapie Bloom |
| `MAT_Ground` | jak Rock, jaśniejszy #55525c | SurfaceAppearance (wspólna tekstura z Rock) | — |
| `MAT_GroundGlow` | Emission #b6ff3b | `Material = Neon`, `Color = #b6ff3b` | żyły i pęknięcia dna |
| `MAT_Slime` | Emission #8dff2a, roughness 0,1 | `Material = Neon` | zacieki i kałuża |

`MAT_SecondaryMetal` nie jest potrzebny, bo w nowej referencji nie ma metalu (łańcuchy i emblemat odpadają).

## 6. Optymalizacja w Roblox

**Budżet tris (Huge ≤ 20k, Small ≤ 5k):**

| Część | Large/Huge | Small |
| --- | --- | --- |
| Shell 6× | 6 000 | 1 500 |
| CrackVeins | 1 200 | 400 |
| Core | 600 | 200 |
| Crystals (8 grup) | 4 000 | 1 000 |
| Slime | 800 | 300 |
| Crater + Veins | 4 500 | 1 000 |
| GroundCracks | 600 | 200 |
| Gruz (klient) | 1 400 | 300 |
| **Razem** | **19 100** | **4 900** |

- **Rozmiary**: Small = osobny FBX (Decimate ~25%), bez latających kryształów, 4 skały. Medium/Large/Huge = ten sam mesh skalowany (`Model:ScaleTo`); Medium ma 6 skał, Large 8, Huge 10 + 2× cząstek.
- **LOD**: `RenderFidelity = Automatic` na skorupie i kraterze; `Performance` na gruzie i kryształach gruntowych. Klient wyłącza cząsteczki i gruz > 250 studs (stan `Dormant`).
- **Kolizja**: `Shell*` CanCollide on, `CollisionFidelity = Hull` (Huge: `PreciseConvexDecomposition` tylko dla Shell01–03). Reszta: CanCollide/CanTouch/CanQuery off. `Hitbox`: Part, Transparency 1, CanQuery on, CanCollide off (raycasty minigry). `Crater`: CanCollide on, `Box`.
- **Anchored**: wszystko Anchored. Klient przesuwa części przez `CFrame` / `PivotTo` (lokalnie, nie replikuje się).
- **Tekstury**: 1024² (Large/Huge), 512² (Small/Medium). Jedna tekstura na skorupę i krater, żeby zmieścić się w pamięci telefonu.
- **Światło**: 1 PointLight (`Glow`, Range 16–40 wg rozmiaru, Shadows off).
- **Cząsteczki** (limity Rate dla Huge, Small = ⅓): Spores 12/s, Sparks 8/s, Smoke 3/s (tylko Burst, Damaged, Depleted), Drops 2/s, flary rdzenia 1.
- **Serwer i klient**: serwer klonuje statyczny model z `ServerStorage.Stars/Toxic/<Rozmiar>` i ustawia tylko atrybuty (`State`, `Hp`, `MaxHp`, `EndReason`). Wszystko, co się rusza i świeci, robi klient (`StarVisual`). Pozycje części na serwerze się nie zmieniają.

## 7. Import do Roblox

1. FBX → Open Cloud upload (jak w T04/T33) → `insert_asset` → `ServerStorage.StarImport.Toxic`.
2. Skrypt importu (`art/stars/import_stars.luau`, rozszerzony o Toxic v2) buduje hierarchię z sekcji 2, ustawia materiały, kolizje, Attachmenty z pustych `ANCHOR_*` i `Zone_*`, PointLight `Glow` w `ANCHOR_Core`.
3. Latający gruz i VFX trafiają do `ReplicatedStorage.StarVisuals.Toxic` (szablony dla klienta).
4. Kopia: `game/assets/stars/toxic_v2.rbxm`.

## 8. Kontroler stanów (API)

Moduł klienta `StarVisual` (`game/src/client/Fx/StarVisual.luau`) zastępuje część `LandedFx`. Jeden obiekt na model gwiazdy, wspólny dla wszystkich rodzajów (Toxic pierwszy). Parametry stanów i animacji trzymamy w `Config/StarVisualConfig.luau`, zgodnie z zasadą „liczby w Config”.

```lua
export type VisualState = "Dormant" | "Active" | "Charging" | "Burst" | "Damaged" | "Depleted"
export type AnimName = "IdleLoop" | "CorePulse" | "FloatingDebrisLoop" | "CrystalPulse" | "CrystalGrowth"
	| "EnergyCharge" | "ToxicBurst" | "ImpactLanding" | "DamageReaction" | "Collapse" | "DepletedIdle" | "RespawnRebuild"

export type StarVisual = {
	SetState: (self: StarVisual, state: VisualState) -> (),
	PlayAnimation: (self: StarVisual, name: AnimName, opts: { loop: boolean?, speed: number?, thenState: VisualState? }?) -> (),
	StopAnimation: (self: StarVisual) -> (),
	SetEnergyLevel: (self: StarVisual, value: number) -> (), -- 0..1.5, mnożnik jasności
	SetEffectsEnabled: (self: StarVisual, enabled: boolean) -> (),
	Destroy: (self: StarVisual) -> (),
}
StarVisual.attach(model: Model): StarVisual?
```

**Mapowanie z gry (klient, bez nowych Remote'ów):**
- `State` = `Landed` → `PlayAnimation("ImpactLanding", { thenState = "Active" })`.
- Zmiana `Hp` → `DamageReaction`; `Hp / MaxHp < 0,4` → `SetState("Damaged")`.
- Runda minigry trwa (lokalnie z `CrackController`; dla innych graczy nowy atrybut `Cracking` liczony przez serwer) → `Charging`.
- `State = Dying` + `EndReason = Cracked` → `PlayAnimation("ToxicBurst", { thenState = "Depleted" })`; `Expired` → `Collapse`.
- Odległość > 250 studs albo ustawienie „Ogranicz ruch” → `Dormant`, bez cząsteczek.

Implementacja wzorem prototypu: każdy stan to tablica parametrów, poza = lerp do stanu + nadpisania aktywnej animacji. Jedna pętla `RenderStepped` na wszystkie gwiazdy w zasięgu.

## 9. Panel deweloperski

Prototyp ma panel: Spawn, Despawn, zmiana stanu, odtwarzanie animacji, Trigger Burst, Damage −20, Reset, efekty, hitbox, statystyki. W grze to samo daje istniejący `ServerStorage.DevStar` (tryb Studio). Dopisujemy akcje `state`, `anim`, `damage`, `hitbox`, a statystyki pokazuje `Stats` / MicroProfiler.

## 10. Kolejność pracy (handoff)

1. **Blender** (tor B, effort high): `build_toxic_v2.py` → FBX Large i Small → render → akceptacja użytkownika.
2. **Import** (tor B): upload, import, `.rbxm`, zrzut w Studio.
3. **`StarVisual` + Config** (tor A): kod według sekcji 8, testy stanów w Studio (`execute_luau` przez DevStar).
4. **Nagranie** stanów z gry → akceptacja prototypu Toxic → ten sam pipeline dla pozostałych 12 gwiazd (każda swoja referencja).
