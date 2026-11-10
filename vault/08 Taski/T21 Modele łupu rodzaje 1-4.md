---
id: T21
tytul: "Modele łupu rodzaje 1-4"
status: done
dzien: 5
data: 2026-11-11
tor: B
effort: high
zalezy: [T04]
tags: [task, tor/art]
---
# T21 Modele łupu rodzaje 1-4

**Dzień 5** (2026-11-11) · tor **B** (art) · Opus 5.5 **high** · zależy od: [[T04]]

## Cel
Modele łupu rodzaje 1-4.

## Kontekst
- [[Styl graficzny]]
- [[Iron Meteorite]]
- [[Lava Star]]
- [[Frost Star]]
- [[Geode Star]]

## Skille
- (Blender MCP, skill projektu `blender-asset`)

## Pliki
- art/items/{iron,lava,frost,geode}/*, art/ui/items/*
- game/src/client/UI/Theme.luau (`ITEM_RENDERS`), game/src/client/UI/Loot/Reveal.luau (`gem`)

## Do zrobienia
- [x] 24 modele (6 rzadkości × 4 rodzaje), kształt wg rzadkości + styl rodzaju
- [x] Rendery + FBX + import do ServerStorage.Items
- [x] Ikony na karcie łupu: render każdego przedmiotu (jak `art/ui/build_tool_icons.py`) → upload → ID w `Theme.ITEM_RENDERS[itemId]`; `Reveal.gem` (`client/UI/Loot/Reveal.luau`) pokazuje render zamiast klejnotu, klejnot zostaje tylko gdy brak ID (z T07)

## Kryteria akceptacji
- [x] ≤ 2k tris (184–1944)
- [x] Rendery w notatkach przedmiotów, `model: gotowy`

## Decyzje (2026-11-10, z użytkownikiem)
- **Kształt: hybryda.** Drabina rzadkości jest szkieletem (Common kamyk → Uncommon odłamek → Rare klaster → Epic rdzeń w klatce → Legendary kula z pierścieniami → Mythic serce z odłamkami), a każdy przedmiot dostaje unikalny akcent z nazwy (Meteor Ingot = sztabka, Crystal Egg = jajo, Aurora Prism = pryzmat, **Phoenix Ember = żarzące pióro feniksa w pierścieniu lawy**).
- **Styl:** chunky, przesadzone bryły z fazami, flat shading, dużo emisji (Neon); spójnie z narzędziami i gwiazdami v2.
- **Frost:** lód nieprzezroczysty i stylizowany, Neon w szczelinach i we wnętrzu (bez Glass/Transparency).
- **Kolory zapieczone:** każdy model ma własną paletę motywu; atrybut `Tint` tylko na elementach świecących. Golden: złota skorupa, emisja zostaje (zmiana w `BaseService.itemModel`).
- **Rozmiar rośnie z rzadkością** (mniej więcej Common 60% → Mythic 130% `ITEM_MAX_SIZE`): skala na rzadkość w `BaseConfig` i `BaseService`.
- **Animacja na postumencie, pełny pakiet:** wszystkie się obracają i unoszą; od Epic wiruje klatka/pierścienie, od Legendary krążą odłamki; Mythic pulsuje serce, 3–5 orbitujących odłamków, aura z cząsteczek w kolorze motywu, mocniejsze światło. Ruchome elementy to osobne, nazwane części animowane przez klienta.
- **Ikony:** przezroczyste tło, ujęcie hero 3/4 z lekkiego góry, światło konturowe w kolorze rzadkości, widoczna emisja.
- **Pipeline:** jeden parametryczny `art/items/build_item.py` (szkielet rzadkości + moduł na rodzaj), na nim powstaną też T22/T23.
- **Punkt kontrolny:** najpierw Iron (6 modeli + rendery) → zrzuty na telefon → czekamy na OK → Lava, Frost, Geode.

## Postęp (2026-11-10)
- [x] Generator `art/items/build_item.py`: szkielet + moduł Iron, meta animacji (Spin/Orbit/Pulse, cząsteczki) w `art/items/items_meta.json`
- [x] Iron: 6 modeli (254–1944 tris, wszystkie ≤ 2k), `art/items/iron/items_iron.fbx` + `.blend`, render `vault/_img/T21 lup Iron.png`, sylwetki, ikony `art/ui/items/iron_*.png`
- [x] Akceptacja Iron przez użytkownika („Tak podoba mi się”) → Lava, Frost, Geode
- [x] Import do `ServerStorage.Items`, animacja na postumencie (klient), skala wg rzadkości, Golden, ikony → `Theme.ITEM_RENDERS`, `Reveal.gem`

## Raport

**Wynik:** 24 przedmioty łupu (Iron, Lava, Frost, Geode × 6 rzadkości) leżą jako modele w `ServerStorage.Items/<itemId>`. Na postumentach żyją: obracają się klatki i pierścienie, krążą odłamki, serca Mythic pulsują. Rozmiar i poświata rosną z rzadkością. Karta łupu pokazuje render przedmiotu. Decyzja: [[2026-11-10 Modele lupu T21]].

**Co zrobiono:**
- **Blender:** `art/items/build_item.py` generuje modele proceduralnie (bmesh): szkielet rzadkości plus moduł na rodzaj. Wspólne bryły to kryształ, pęknięta skorupa (`cracked`), serce, płomień, kropla i śnieżynka.
  - Wyjście: `art/items/<theme>/items_<theme>.fbx` + `.blend` i `art/items/items_meta.json` (materiały, kolory, role animacji, cząsteczki).
  - Rendery: `vault/_img/T21 lup <Rodzaj>.png` i sylwetki.
  - Ikony 512 px: `art/ui/items/<id>.png` i 256 px w `vault/_img/<id>.png`. Emisję na przezroczystym tle naprawia `glow_alpha`, bo EEVEE dawał jej alfę 0.
- **Studio:**
  - 4 pliki FBX przez Open Cloud: Iron 94217978252831, Lava 77944211435111, Frost 108051081353926, Geode 124370774447911.
  - Import przez `insert_asset`, potem `art/items/import_items.luau` (generowany przez `gen_import.py` z `import_items.template.luau`). Błąd położenia części względem meta: 0,000 we wszystkich 24.
  - 24 ikony jako Decal (Open Cloud), ID obrazków odczytane przez `InsertService`, wpisane do `Theme.ITEM_RENDERS`.
- **Kod:**
  - `BaseConfig`: `ITEM_RARITY_SCALE`, `GLOW_RARITY_BOOST`, `GOLDEN_BLEND`.
  - `BaseService.itemModel`: skala wg rzadkości, Golden bez zmiany Neon, mocniejsze światło, atrybut `PartCount`.
  - Nowy `client/Fx/ItemFx.luau` (Spin, Orbit, Pulse).
  - `BaseController`: animuje części dopiero po dotarciu wszystkich części, a światło szuka po klasie, bo w modelach jest też część o nazwie „Glow”.
  - `Reveal`: render zamiast klejnotu (Golden ma złoty odcień, Shiny mieni się), rendery wczytywane po starcie klienta.
- **Vault:** `tools/sync_vault.py` ma nową ścieżkę modelu (`items_<theme>.blend`, `ServerStorage.Items.<id>`). 24 notatki mają `model: gotowy` i render.

**Testy (Studio Play, dane tylko w pamięci, bo DataStore w Studio jest wyłączony):**
- Postumenty: 6 przedmiotów od Common do Mythic. Rozmiary 2,5 / 3,0 / 3,6 / 4,2 / 4,8 / 5,5 studa, Golden Phoenix Ember jest złoty.
- Na kliencie względem bryły: Orbit +43°, SpinHalo +26°, PulseCore rośnie do +8%.
- Karta łupu: rendery wczytane przy pierwszym rozbiciu (Huge Iron, Frost, Lava).
- Konsola bez błędów. `selene` i `stylua` 0/0.
- Zrzuty: `T21 lup w grze.jpg`, `T21 lup w grze zblizenie.jpg`, `T21 karta lupu.jpg`.

**Użyte skille:** `task`, `blender-asset`, `roblox-studio-mcp` (narzędzia Studio MCP), `roblox-luau`.

**Problemy i uwagi:**
- Rojo nie było uruchomione, a sterowanie ekranem Studio zostało odrzucone, więc nie było kliknięcia Connect. Zmiany kodu wgrałem do Studio łatkami przez `execute_luau`. Źródła 6 skryptów są identyczne z plikami (porównane sumą kontrolną), więc następne Connect w Rojo nic nie zmieni. `rojo serve` zostało uruchomione w tle.
- Światło Mythic (różowe, ×1,8) mocno barwi metalowe Ironheart Relic. Jeśli będzie przeszkadzać, wystarczy zmniejszyć `GLOW_RARITY_BOOST.Mythic`.
- Kopia `.rbxm` folderu `Items` nie jest zapisana. Model da się odtworzyć skryptem importu z assetów FBX (tak samo jak w T11).
- Dla T22/T23: dopisz moduły rodzajów w `build_item.py` (paleta w `EXTRA_PAL`, 6 funkcji `<theme>_<tier>`, wpis w `BUILDERS`). Dalej: `--themes X --render --sketch --icons`, upload FBX, `gen_import.py --themes X`, import, Decale do `Theme.ITEM_RENDERS`.
