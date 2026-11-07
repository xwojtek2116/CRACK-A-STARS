---
id: T04
tytul: "Pipeline blender-asset i modele gwiazd"
status: todo
dzien: 1
data: 2026-11-07
tor: B
effort: high
zalezy: [T01]
tags: [task, tor/art]
---
# T04 Pipeline blender-asset i modele gwiazd

**Dzień 1** (2026-11-07) · tor **B** (art) · Opus 5.5 **high** · zależy od: [[T01]]

## Cel
Pipeline blender-asset i modele gwiazd.

## Kontekst
- [[Styl graficzny]]
- [[Gwiazdy i spadanie]]

## Skille
- roblox-world-building

## Pliki
- art/stars/*, .claude/skills/blender-asset/SKILL.md

## Do zrobienia
- [ ] Skrypt proceduralny `art/stars/build_star.py`: bryła + kryształy + pęknięcia, parametry klasy i motywu
- [ ] Warianty 5 klas × motywy z Stars.json (materiały)
- [ ] Eksport FBX + render PNG do vault/_img
- [ ] Import do Studio → ServerStorage.Stars

## Kryteria akceptacji
- [ ] Render każdej klasy w vaulcie
- [ ] ≤ 8k tris na gwiazdę
- [ ] Gwiazda w Studio ma Attachmenty stref

## Raport
**Rozpoczęte w czacie planowania (7.11), niedokończone.** Jest `art/stars/build_star.py` (Blender w tle: `E:lenderlender.exe -b --factory-startup -P art/stars/build_star.py -- --render --lineup`): skorupa z płyt Voronoi + świecący rdzeń + kryształy, 5 klas, FBX + rendery w `vault/_img/star_*.png`, 1,3k–5,1k tris. Do zrobienia w tym tasku: ocena wyglądu z użytkownikiem, poprawki, skill `blender-asset`, import do Studio (ServerStorage.Stars), Attachmenty stref.
