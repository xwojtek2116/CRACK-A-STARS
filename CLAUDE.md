# Crack a Stars — zasady projektu dla Claude Code

Gra Roblox: na planetę w kosmosie spadają gwiazdy, gracze ścigają się do nich (bieg, jetpack, pojazdy), rozbijają je w minigrze celowania i zabierają łup (12 rodzajów gwiazd × 4 rozmiary, każdy rodzaj ma własne 6 przedmiotów), który stawiają w bazie, żeby zarabiał.
Projekt gry: `vault/01 GDD/GDD.md`. Przed pisaniem systemu przeczytaj jego notatkę w `vault/02 Systemy/`.

## Terminy

- **Premiera publiczna: sobota 21.11.2026.** Feature freeze: **środa 18.11.2026** — po tej dacie tylko poprawki.
- Plan dzień po dniu: `vault/07 Sprinty/Plan 14 dni.md`. Taski: `vault/08 Taski/` (widok `vault/00 Start/Taski.base`).
- Funkcji spoza zakresu 1.0 nie dodawaj — zapisz je w `vault/10 Pomysły/`.
- CarImportEmpire jest wstrzymany do premiery Crack a Stars — nie pracuj nad nim.

## Tryb pracy

- **Model: zawsze Opus 5.5** (`claude-opus-5-5`, ustawiony w `.claude/settings.json`). **Effort: `high`** dla modeli 3D i złożonych systemów (gwiazdy, minigra, łup, monetyzacja, mapa), **`medium`** dla reszty. Karta taska ma pole `effort`; przy starcie sesji ustaw je (`/effort high|medium` albo w aplikacji).
- O grę pytaj użytkownika śmiało (krótkie pytania z opcjami), gdy decyzja projektowa nie wynika z GDD.
- Użytkownik pisze z telefonu (Remote Control). Działaj sam; wysyłaj zrzuty i rendery przez `SendUserFile`. Odpowiedzi krótkie, po polsku.
- **Najpierw plan, potem praca.** Nowy temat = najpierw plan (tryb Plan, skill `zaplanuj`) i akceptacja użytkownika; nie zaczynaj budować bez akceptacji.
- **Jeden czat = jeden task.** Po zakończeniu taska nie bierz następnego w tym samym czacie.
- **Otwarte pliki:** jeśli w Blenderze/Studio jest otwarty inny plik — najpierw go zapisz (Ctrl+S), potem otwórz nowy plik do pracy. Nigdy nie zostawiaj niezapisanych zmian.
- **Po testach zamykaj zbędne okna Roblox Studio — zostaje dokładnie jedno** (główne okno edycji gry).
- **Miejsce gry = chmura Roblox:** gra „Crack a Star”, `placeId 128852283478472`, `universeId 10775327732` (prywatna). Uprawnienia MCP (upload, HTTP, Open Cloud) działają tylko na miejscu zapisanym na Robloxie, więc pracujemy na nim. **Team Create jest włączony (8.11)** — każda zmiana zapisuje się na Robloxie sama, Ctrl+S nie jest potrzebne (skrypty: zmiany w edytorze trzeba zatwierdzić „Commit”, ale kod i tak idzie z Rojo). `game/places/*.rbxl` to tylko kopie zapasowe — po większej zmianie zrób też Plik → Zapisz do pliku jako `game/places/CrackAStars.rbxl`. Gdy Studio zgubi połączenie (RCC-1025), odzyskaj z `%LOCALAPPDATA%\Roblox\RobloxStudio\AutoSaves\128852283478472_AutoRecovery_*.rbxl`.
- **Sterowanie ekranem zatwierdza się w każdym czacie osobno** (okienko na komputerze). Jeśli task go potrzebuje, poproś o nie na samym początku. Nie używaj `open_application` dla Studio — otwiera drugie okno.
- **Jedna sesja = jeden task** (`/task T07`). Do **3 sesji równolegle** — tory: **A kod**, **B art (Blender)**, **C świat/UI/biznes**. Dwie sesje nigdy nie zmieniają tych samych plików (karta ma pole „Pliki”).
- Nie zmieniaj zakresu taska. Brak czegoś albo błąd w karcie → zapisz w Raporcie.
- Szukaj grepem, nie czytaj całych folderów. Nie wypisuj całych plików w czacie.
- Na koniec taska: Raport w karcie, `status: done` we frontmatter karty, decyzje w `vault/09 Decyzje/`, commit + push.
- Nowe funkcje planujemy w trybie Plan skillem `zaplanuj` (pomysł → karty tasków, bez kodu).

## Foldery

| Folder | Co |
| --- | --- |
| `game/` | kod gry (Rojo). Komendy uruchamiaj w `game/`. |
| `game/src/server` | `ServerScriptService.Server` — serwisy w `Services/`, dane w `Data/` |
| `game/src/client` | `StarterPlayer.StarterPlayerScripts.Client` — `Controllers/`, `UI/` |
| `game/src/shared` | `ReplicatedStorage.Shared` — `Config/`, `Remotes`, `Types`, `Net/` |
| `game/src/shared/Config/Data/*.json` | **jedyne źródło liczb balansu** (gwiazdy, łup, narzędzia, pojazdy, ekonomia, monetyzacja). Rojo robi z nich ModuleScripty. |
| `game/Packages`, `game/ServerPackages` | paczki Wally (React, ReactRoblox, ProfileStore) — nie edytuj |
| `game/assets/` | `.rbxm` modeli i mapy zapisane ze Studio |
| `vault/` | Obsidian (GDD, systemy, katalog gwiazd/łupu/narzędzi/pojazdów, plan, taski, decyzje) |
| `art/` | Blender: `stars/`, `tools/`, `items/<motyw>/`, `vehicles/`, `map/`, `renders/` (Git LFS) |
| `tools/` | `sync_vault.py` (JSON → notatki vaultu), `balance_check.py` |

## Vault = dokumentacja, JSON = liczby

- Zmieniasz liczby balansu → edytuj JSON w `Config/Data/`, potem `python tools/sync_vault.py`. Nigdy nie wpisuj liczb ręcznie w notatkach katalogu (`03 Gwiazdy`, `04 Łup`, `05 Narzędzia`, `06 Pojazdy`) — są generowane; ręcznie edytuj tylko sekcję `## Notatki` pod znacznikiem.
- Nowe notatki: frontmatter jak w `vault/99 Szablony/`. Linki `[[…]]`, obrazy do `vault/_img/`.
- Obsidian bez wtyczek społeczności — tylko core (Properties, Bases, Canvas, Templates).

## Stack

- Luau, `--!strict` w każdym pliku. Rojo jest źródłem prawdy: kod edytuj w plikach, nie przez `multi_edit` w Studio.
- Aftman: rojo, wally, selene, stylua. Wally: React-lua (UI), ProfileStore (zapis).
- Wzorce kodu do ponownego użycia: `E:\CarImportEmpire\game\src` (UI React: `client/UI/{App,Store,Theme,Motion,Components}`, minigry `client/UI/Minigames/Common.luau`, `PlotService`, `VehicleService`). Kopiuj i dostosuj, nie pisz od zera.
- **Roblox Studio MCP**: testy — `start_stop_play`, `get_console_output`, `execute_luau`, `screen_capture`. Mapę i modele budowane w Studio zapisz jako `.rbxm` w `game/assets/`.
- **Blender MCP**: wszystkie modele (gwiazdy, narzędzia, łup, pojazdy, props mapy) — **tylko własne assety**, żadnych modeli z Creator Store. Pipeline: skill `blender-asset`.

## Zasady kodu (obowiązkowe)

1. **Serwer jest jedynym źródłem prawdy.** Obrażenia, wynik minigry, losowanie łupu, kasa, zakupy — liczy lub waliduje serwer. Klient tylko prosi.
2. Każdy Remote waliduje typy, istnienie obiektu, odległość gracza od gwiazdy, cooldown narzędzia i saldo. Każdy ma limit w `NetConfig`.
3. **Wszystkie liczby w `Config/`** (JSON albo `*Config.luau`). Nigdy na sztywno w serwisie.
4. Jeden serwis = jeden plik w `src/server/Services` z `Init()` i `Start()`, dopisany do listy w `init.server.luau`. Kontrolery klienta tak samo.
5. Remotes tylko przez `Shared/Remotes`.
6. Losowość przez `Random.new()`, nigdy `math.random` w ekonomii i łupie.
7. Dane gracza zmieniaj tylko przez `DataService.update`. Zmiana schematu = podbij `SCHEMA_VERSION` + migracja.
8. Nazwy: `PascalCaseService`, `PascalCaseController`, stałe `UPPER_SNAKE`, funkcje `camelCase`.
9. Teksty w grze po angielsku (rynek USA). Komentarze i dokumentacja po polsku.
10. Oryginalna gra: własne nazwy, modele i UI. Nie kopiujemy wyglądu ani nazw innych gier.
11. Płatne losowe rzeczy (`paidRandom` w `Monetization.json`): widoczne szanse + `PolicyService:GetPolicyInfoForPlayerAsync` (`ArePaidRandomItemsRestricted`).
12. Mobile first: każdy element UI i minigra działają dotykiem; cel ≥ 60 FPS na średnim telefonie.

## Zero ręcznych kroków

Task robi wszystko sam, także to, co wymaga klikania. Kolejność narzędzi:
1. **Studio MCP** — wszystko, co da się zrobić w Studio.
2. **Sterowanie komputerem** (skill `anthropic-skills:computer-use`) — menu i okna Studio/Blendera: Ctrl+S, File → Publish to Roblox, Game Settings, Save to File (.rbxm), Test → Clients, import 3D.
3. **Przeglądarka** — Creator Hub: gamepassy, Developer Products, opis gry, miniaturki, ankieta Maturity.
4. Terminal — instalacje, git, narzędzia.

**Sprzątanie po testach w Studio (zawsze):** stop Play (`start_stop_play`, sprawdź `get_studio_state`), Cleanup po Test → Clients, zamknij zbędne okna Studio (główne zostaw, najpierw Ctrl+S).

**Wyjątki — tylko te pytaj w czacie i czekaj na „tak”:**
- logowanie, hasła, kody 2FA;
- wydawanie Robux lub pieniędzy (reklamy, sponsorowanie), akceptacja regulaminów;
- publikacja gry jako publicznej i ogłoszenia premiery;
- nieodwracalne usuwanie.

Gdy żadne narzędzie nie działa: Raport → **Zaległe kroki** z dokładną instrukcją; następny task wykona je na starcie.

## Po każdej zmianie kodu

- W `game/`: `selene src` i `stylua --check src` (popraw przez `stylua src`), `rojo build -o build/CrackAStars.rbxl`.
- Zmiana liczb: `python tools/sync_vault.py` + skill `balance-check`.
- Test w Studio przez MCP zgodnie z kryteriami karty.

## Skille

Pakiet `roblox-*` (ten sam co github.com/EL4CTEO/roblox-skills, już zainstalowany) wczytuj, gdy praca dotyka tematu:

1. **Zawsze przy kodzie Luau:** `roblox-luau`. **Zawsze przy testach w Studio:** `roblox-studio-mcp`.
2. Skille z sekcji „Skille” karty taska.
3. Temat spoza karty → skill z tabeli (dopisz w Raporcie):

| Gdy robisz… | Skill |
| --- | --- |
| gdzie leży kod, replikacja, streaming, CollectionService | `roblox-architecture` |
| zapis danych, rankingi, MemoryStore | `roblox-data-stores` |
| RemoteEvent/Function, synchronizacja stanu gwiazd | `roblox-networking` |
| dane od klienta, minigra, ekonomia, anty-cheat | `roblox-security` |
| waluta, sklep, ekwipunek, rebirth, nagrody dzienne | `roblox-game-systems` |
| Robux, gamepassy, produkty, płatne losowania | `roblox-monetization` |
| UI, HUD, okna, telefon/pad | `roblox-ui` |
| sterowanie, jetpack, kamera, przyciski dotykowe | `roblox-input` |
| pojazdy, spadanie gwiazd, raycasty, kolizje | `roblox-physics` |
| animacje, Tweeny, narzędzia w ręku | `roblox-characters-animation` |
| mapa, światło, efekty, cząsteczki, kratery | `roblox-world-building` |
| dźwięk i muzyka | `roblox-audio` |
| lag, FPS, pamięć, telefon | `roblox-performance` |
| eventy, analityka, kody, odznaki | `roblox-analytics-liveops` |
| czat, tekst od graczy | `roblox-text-chat` |
| testy | `roblox-testing` |
| Rojo, Wally, selene, CI | `roblox-tooling` |
| Open Cloud, upload assetów z zewnątrz | `roblox-open-cloud` |

4. Przed zamknięciem taska ze zmianą kodu serwera: przegląd według `roblox-code-review`; krytyczne napraw od razu.

Nie wczytuj skilli „na zapas”. Gdy skill roblox-* i ten plik się różnią, wygrywa ten plik.

Skille projektu (`.claude/skills`):
- `task` — wykonanie jednej karty z `vault/08 Taski/`.
- `zaplanuj` — pomysł → plan → karty tasków (tryb Plan).
- `blender-asset` — model w Blenderze przez MCP → FBX → Studio (gwiazdy, narzędzia, łup, pojazdy).
- `new-item` — nowy przedmiot łupu: `Items.json` + model + sync vaultu.
- `balance-check` — symulacja ekonomii (`tools/balance_check.py`).
- `raport-dnia` — wieczorny raport na telefon.
