---
name: zaplanuj
description: Zamień swobodny opis pomysłu lub funkcji Crack a Stars w plan i karty tasków w vault/08 Taski (bez pisania kodu). Używaj w trybie Plan, gdy użytkownik opisuje nową funkcję, zmianę albo pomysł do gry.
---

# Planowanie funkcji → karty tasków

1. Przeczytaj `vault/01 GDD/GDD.md` (sekcje tematu), widok `vault/00 Start/Taski.base` (grep `status:` w `vault/08 Taski/`) i terminy z `CLAUDE.md` (freeze 18.11, premiera 21.11).
2. Oceń, czy pomysł mieści się w 1.0. Po feature freeze albo gdy jest duży — zapis w `vault/10 Pomysły/Pomysły.md`.
3. Jeśli decyzja projektowa nie wynika z GDD — zadaj użytkownikowi krótkie pytania z opcjami (AskUserQuestion).
4. Pokaż plan: cel dla gracza, jak działa (3–8 punktów), systemy i pliki, ryzyka, podział na taski (każdy na 1 sesję, ok. 2–3 h), tor A/B/C i `effort` (high: modele 3D i złożone systemy; medium: reszta).
5. Po akceptacji zapisz karty wg `vault/99 Szablony/Szablon taska.md` (następny wolny `Txx`, frontmatter `status: todo`), dopisz notatkę systemu w `vault/02 Systemy/` i decyzję w `vault/09 Decyzje/`. Liczby → `Config/Data/*.json` + `python tools/sync_vault.py`.
6. Nie pisz kodu. Na końcu lista `/task Txx` w kolejności i co może iść równolegle.
