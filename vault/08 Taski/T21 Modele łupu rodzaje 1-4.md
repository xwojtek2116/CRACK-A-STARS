---
id: T21
tytul: "Modele łupu rodzaje 1-4"
status: todo
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
- [ ] 24 modele (6 rzadkości × 4 rodzaje), kształt wg rzadkości + styl rodzaju
- [ ] Rendery + FBX + import do ServerStorage.Items
- [ ] Ikony na karcie łupu: render każdego przedmiotu (jak `art/ui/build_tool_icons.py`) → upload → ID w `Theme.ITEM_RENDERS[itemId]`; `Reveal.gem` (`client/UI/Loot/Reveal.luau`) pokazuje render zamiast klejnotu, klejnot zostaje tylko gdy brak ID (z T07)

## Kryteria akceptacji
- [ ] ≤ 2k tris
- [ ] Rendery w notatkach przedmiotów, `model: gotowy`

## Raport
_(uzupełnia Claude po zakończeniu: co zrobiono, pliki, użyte skille, wynik testów, problemy; „Zaległe kroki” tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić)_
