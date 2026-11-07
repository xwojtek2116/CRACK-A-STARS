---
id: T04
tytul: "Generator gwiazd i rodzaje 1-4"
status: todo
dzien: 1
data: 2026-11-07
tor: B
effort: high
zalezy: [T01]
tags: [task, tor/art]
---
# T04 Generator gwiazd i rodzaje 1-4

**Dzień 1** (2026-11-07) · tor **B** (art) · Opus 5.5 **high** · zależy od: [[T01]]

## Cel
Generator gwiazd i rodzaje 1-4.

## Kontekst
- [[Styl graficzny]]
- [[Gwiazdy i spadanie]]
- [[Iron Meteorite]]
- [[Lava Star]]
- [[Frost Star]]
- [[Geode Star]]

## Skille
- (Blender MCP, skill projektu `blender-asset`)

## Pliki
- art/stars/*, .claude/skills/blender-asset/SKILL.md

## Do zrobienia
- [ ] Generator `art/stars/build_star.py` z modułem na rodzaj (sylwetka z `shape` w Themes.json) i parametrem rozmiaru (skala + gęstość detali + liczba stref)
- [ ] Rodzaje: Iron Meteorite, Lava Star, Frost Star, Geode Star × 4 rozmiary
- [ ] Akceptacja wyglądu przez użytkownika (render na telefon) przed T33/T34
- [ ] Skill `blender-asset` (pipeline: skrypt → FBX → render → import)
- [ ] Import do Studio → ServerStorage.Stars/<Rodzaj>/<Rozmiar> z Attachmentami stref

## Kryteria akceptacji
- [ ] Każdy rodzaj ma inną sylwetkę (rozpoznawalny bez koloru)
- [ ] Small ≤ 2k, Huge ≤ 8k tris
- [ ] Rendery `star_<rodzaj>.png` w vaulcie, `model: gotowy`

## Raport
**Szkic z czatu planowania (7.11):** `art/stars/build_star.py` — wspólna kula z płytami Voronoi + rdzeń + kryształy (5 starych klas). Do przerobienia na moduły rodzajów i rozmiary Small/Medium/Large/Huge (nowe `Stars.json`).

_(uzupełnia Claude po zakończeniu: co zrobiono, pliki, użyte skille, wynik testów, problemy; „Zaległe kroki” tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić)_
