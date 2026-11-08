---
name: task
description: Wykonaj jedną kartę taska z vault/08 Taski (np. "/task T05"). Używaj, gdy użytkownik wpisze /task z numerem albo poprosi o zrobienie konkretnego taska Txx.
---

# Wykonanie jednego taska

Argument: numer taska, np. `T05`. Task kończy się **bez ręcznych kroków dla użytkownika** (zasady: `AGENTS.md` → „Zero ręcznych kroków”).

1. Znajdź kartę: `vault/08 Taski/<numer> *.md`. Brak karty → powiedz to i zakończ.
2. Sprawdź `zalezy` we frontmatter karty. Jeśli któryś task ma `status` inny niż `done`, napisz to użytkownikowi i zapytaj, czy kontynuować. Sprawdź `effort` karty: `high` → upewnij się, że sesja ma effort high (`/effort high`), inaczej medium.
3. **Zaległe kroki z poprzednich tasków:** przejrzyj grepem Raporty kart ze statusem `done` w `vault/08 Taski/` (wzorzec: `ręcznie|Nie sprawdz|Zaległe|Problemy`) i wykonaj punkty, które nie są odhaczone i da się je zrobić teraz (te, które czekają na późniejszy task, zostaw), zanim zaczniesz swój task. Po wykonaniu dopisz w tamtej karcie „✔ zrobione w <Txx>”.
4. Ustaw `status: doing` we frontmatter karty.
5. Wczytaj **tylko**: kartę, pliki z sekcji „Pliki”, notatkę systemu z sekcji „Kontekst” i skille: z sekcji „Skille” + `roblox-luau` (gdy piszesz kod) + `roblox-studio-mcp` (gdy testujesz w Studio) + `anthropic-skills:computer-use` (gdy trzeba klikać w okna Studio, Blendera lub systemu). Gdy w trakcie praca dotknie tematu spoza karty, wczytaj pasujący skill z tabeli w `AGENTS.md` (sekcja Skille). Inne pliki szukaj grepem.
6. Pokaż plan w 3–7 punktach i od razu pracuj (karta jest już zatwierdzona).
7. Pracuj według `AGENTS.md`. Zakres = sekcja „Do zrobienia”. Rzeczy spoza zakresu zapisz w `vault/10 Pomysły/` albo w Raporcie.
   - Każdy punkt wymagający klikania (zapis miejsca, Publish, Game Settings, Save to File, Test → Clients, Creator Hub, import 3D) wykonaj sam: Studio MCP → sterowanie komputerem → przeglądarka.
   - Po zmianach w Workspace (mapa, modele) **zapisz miejsce** (Ctrl+S przez sterowanie komputerem) i zrób kopię `.rbxm`/`.rbxl` do `game/assets/`, jeśli karta tego wymaga.
   - Pytaj w czacie tylko o wyjątki z `AGENTS.md` (logowanie, wydawanie Robux/pieniędzy, regulaminy, publiczna publikacja, nieodwracalne usuwanie) albo o zgodę na sterowanie ekranem.
8. Sprawdź każde kryterium z sekcji „Kryteria akceptacji”:
   - kod: w `game/` uruchom `selene src` i `stylua --check src`;
   - gra: przez Studio MCP (`start_stop_play`, `get_console_output`, `execute_luau`, `screen_capture`); test wielu graczy przez Test → Clients (sterowanie komputerem);
   - kod serwera: krótki przegląd zmian według listy `roblox-code-review`; krytyczne problemy napraw od razu.
   - po każdym teście (także nieudanym) posprzątaj Studio według `AGENTS.md` („Sprzątanie po testach w Studio”): stop Play, Cleanup po Test → Clients, zamknij zbędne okna Studio — zostaje tylko główne okno edycji (najpierw Ctrl+S).
9. Uzupełnij w karcie sekcję **Raport**: co zrobiono, zmienione pliki, **użyte skille**, wynik testów, problemy. Sekcja **Zaległe kroki** tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić (z powodem i dokładną instrukcją dla następnego taska).
10. `status: done` we frontmatter karty (albo `blocked` z powodem). Zmieniłeś liczby w `Config/Data/*.json` albo zrobiłeś model → `python tools/sync_vault.py` i ustaw `model: gotowy` w notatce katalogu, render do `vault/_img/`. Zrzut ekranu / render wyślij użytkownikowi przez `SendUserFile`. Ważne decyzje zapisz w `vault/09 Decyzje/RRRR-MM-DD <temat>.md`.
11. Commit **tylko plików tego taska** (inne sesje mogą pracować równolegle): `git add -- <lista zmienionych plików>` (sprawdź `git status`, pomiń cudze), potem `git commit -m "<Txx>: <tytuł>"` i `git push`.
12. Na koniec jedna linijka: następny task z kolejki i przypomnienie o `/clear`.
