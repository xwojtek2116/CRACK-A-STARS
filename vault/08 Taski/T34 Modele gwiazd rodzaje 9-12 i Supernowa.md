---
id: T34
tytul: "Modele gwiazd rodzaje 9-12 i Supernowa"
status: done
dzien: 9
data: 2026-11-15
tor: B
effort: high
zalezy: [T33]
tags: [task, tor/art]
---
# T34 Modele gwiazd rodzaje 9-12 i Supernowa

**Dzień 9** (2026-11-15) · tor **B** (art) · Opus 5.5 **high** · zależy od: [[T33]]

## Cel
Modele gwiazd rodzaje 9-12 i Supernowa.

## Kontekst
- [[Styl graficzny]]
- [[Diamond Star]]
- [[Ringed Star]]
- [[Solar Star]]
- [[Void Star]]
- [[Supernova]]

## Skille
- (Blender MCP, skill projektu `blender-asset`)

## Pliki
- art/stars/{diamond,ringed,solar,void,supernova}/*

## Do zrobienia
- [ ] Moduły: Diamond (ośmiościan + klejnoty), Ringed (planeta + pierścienie), Solar (złote słońce + protuberancje), Void (czarna kula + dysk)
- [ ] Supernowa: wariant każdego rodzaju z koroną i pierścieniem odłamków
- [ ] FBX, rendery, import

## Kryteria akceptacji
- [ ] Budżet tris jak T04

## Raport
_(uzupełnia Claude po zakończeniu: co zrobiono, pliki, użyte skille, wynik testów, problemy; „Zaległe kroki” tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić)_

✔ Zrobione w [[T40]] (9.11): Diamond, Ringed, Solar, Void i Supernowa każdego rodzaju jako gwiazdy v2 (`art/stars/build_star_v2.py`, import `ServerStorage.StarImportV2`).
