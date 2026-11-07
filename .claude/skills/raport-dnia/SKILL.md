---
name: raport-dnia
description: Wieczorny raport dnia Crack a Stars dla użytkownika na telefonie — co zrobiono, zrzuty, ryzyka, plan na jutro. Używaj, gdy użytkownik poprosi o raport/podsumowanie dnia albo na koniec dnia pracy.
---

# Raport dnia

1. Zbierz: karty z `status: done` i `data:` = dziś (grep w `vault/08 Taski/`), `git log --since=midnight --oneline`, otwarte bugi w `vault/11 Bugi/`.
2. Zrób 1–3 zrzuty (Studio `screen_capture` w Play albo rendery z `vault/_img/`) i wyślij przez `SendUserFile` (status `proactive`).
3. Zapisz `vault/07 Sprinty/Raporty/RRRR-MM-DD.md` wg `vault/99 Szablony/Szablon raportu dnia.md`.
4. Porównaj z `vault/07 Sprinty/Plan 14 dni.md`: czy dzień jest na czas. Opóźnienie → zaproponuj cięcie wg GDD §12.
5. W czacie maks. 8 linijek: zrobione, kamień milowy, ryzyko, jutro, pytania (z opcjami).
