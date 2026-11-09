---
id: T08
tytul: "Baza działki postumenty dochód offline"
status: done
dzien: 5
data: 2026-11-11
tor: C
effort: high
zalezy: [T02, T36]
tags: [task, tor/swiat-ui-biznes]
---
# T08 Baza działki postumenty dochód offline

**Dzień 5** (2026-11-11) · tor **C** (swiat-ui-biznes) · Opus 5.5 **high** · zależy od: [[T02]], [[T03]]

## Cel
Baza działki postumenty dochód offline.

## Kontekst
- [[Baza i dochód]]

## Skille
- roblox-luau
- roblox-game-systems

## Pliki
- src/server/Services/PlotService.luau, src/server/Services/BaseService.luau, src/server/Services/EconomyService.luau

## Do zrobienia
- [x] PlotService z CarImportEmpire (8 działek)
- [x] Postumenty z modelem przedmiotu, obrót, poświata, tabliczka $/s
- [x] Tick dochodu 1 s, offline 50%/8 h
- [x] Kupno slotów, auto-place best
- [x] `SellService` + Sell Station w lobby (cena $/s × 300 s, potwierdzenie od Legendary, walidacja serwera)

## Kryteria akceptacji
- [x] Dochód rośnie zgodnie z wzorem
- [x] Welcome back po ponownym wejściu (ścieżka wejścia przez hook Studio — patrz Raport)

## Raport
**2026-11-09 — zrobione.** Przed pracą 8 pytań projektowych do użytkownika (wygląd postumentu, zbieranie kasy, sloty, Sell Station, pełna baza, limit ekwipunku, cudze bazy, Welcome back) — odpowiedzi i reszta decyzji: [[2026-11-09 Baza postumenty dochód sprzedaż]].

**Co działa:**
- Działka przydzielana przy wejściu (nazwa gracza na słupku, spawn na działce), siatka 6×6 postumentów od `BuildOrigin`; widać tylko kupione + hologram następnego z ceną.
- Postument z Blendera (600 tris) z neonem w kolorze rzadkości; na nim kryształ-placeholder w kolorze motywu (Shiny = iskry, Golden = złoto); klient obraca/unosi przedmiot i pulsuje światłem, tabliczka nazwa + $/s, popupy „+$X” co 3 s.
- Kasa co 1 s = Σ $/s × (1 + 0,5 × rebirth) × 2× Cash; offline przy wejściu (min 60 s, cap 8 h, 50%) od razu do kasy + okno WELCOME BACK.
- Okna: MY BASE (postumenty/ekwipunek, AUTO-PLACE BEST, kupno slotu), PEDESTAL (prompt na postumencie: REMOVE / SELL / PLACE HERE), SELL STATION (pojedynczo, SELL ALL BELOW, z bazy), potwierdzenie od Legendary. Prompty stacji Sell Station i Upgrades w lobby.
- Łup przy pełnej bazie zastępuje najsłabszy postument; ekwipunek max 100 z auto-sprzedażą (toasty).

**Pliki:** serwer `Services/{PlotService,BaseService,EconomyService,SellService}.luau` (nowe), `LootService.luau` (placeNew + limit ekwipunku), `DataService.luau` (`lastOnline` ukryty), `init.server.luau`; shared `BaseMath.luau`, `Config/BaseConfig.luau` (nowe), `Remotes.luau` (7 remotów), `NetConfig.luau`, `LootConfig.luau` (`cashMult`), `Data/Economy.json`, `Data/Monetization.json`; klient `Controllers/BaseController.luau`, `UI/Base/{Actions,Parts,BaseWindow,PedestalWindow,SellWindow,WelcomeWindow}.luau` (nowe), `UI/Store.luau`, `UI/Windows.luau`, `init.client.luau`; art `art/map/pedestal/{build_pedestal.py,pedestal.fbx,pedestal.blend,import_pedestal.luau}`; render `vault/_img/T08 postument.png`.
**Poza listą „Pliki” karty:** `SellService.luau` (w treści karty, nie w liście), cały klient i UI, `LootService` (hook pełnej bazy), `DataService` (1 linia), model postumentu.

**Skille:** roblox-luau, roblox-studio-mcp, blender-asset, roblox-code-review (bez krytycznych uwag). roblox-game-systems z karty — wzorce ekonomii zastosowane bez osobnego wczytania.

**Testy (Studio MCP, Play):**
- `BaseMath` 13/13 OK (cena slotu 1000/1600/max, offline <60 s / 2 h / cap, mnożnik rebirth+2×, auto-place, zamiana przy pełnej bazie, limit ekwipunku, potwierdzenie).
- Dochód: 3165,6 $/s → +32 131 w ~10,15 s (zgodnie ze wzorem).
- Remoty: BuySlot ($1000 → slot 7, następny $1600), Remove/AutoPlace OK, zły uid → InvalidArgs, cudzy/nieistniejący → NoItem, sprzedaż z daleka → TooFar, Legendary bez potwierdzenia → ConfirmRequired, z potwierdzeniem $810 000 (2700 × 300), SELL BELOW Uncommon 3 szt. $1080.
- Offline (hook „rejoin” = ta sama funkcja co wejście): 2 h → $453 600, 10 h → cap 8 h $1 814 400, 30 s → 0; okno WELCOME BACK z licznikiem.
- Łup: 40× Huge Solar → baza sama wymieniła słabsze (1394 → 44 880 $/s), ekwipunek zatrzymany na 100, nadmiar sprzedany. Brak błędów w konsoli.
- Zrzuty: baza z postumentami, MY BASE, PEDESTAL, SELL STATION, WELCOME BACK.

**Problemy / uwagi:**
- W Studio brak dostępu do DataStore (tryb testowy, dane w pamięci) — prawdziwego wyjścia i powrotu nie da się przetestować; logika offline sprawdzona hookiem przez tę samą funkcję co przy wejściu. Pełny test: T25 (alfa) na serwerze Roblox.
- Test 2 klientów (cudza baza bez promptów) nie wykonany — wymaga Test → Clients (sterowanie ekranem); logika prosta (`OwnerUserId == LocalPlayer`), do sprawdzenia w T25.
- `tools/balance_check.py` nie istnieje (skill `balance-check` się do niego odwołuje) — symulacji ekonomii nie uruchomiono.
- `.rbxm` `BaseAssets` nie zapisany do `game/assets/` (zapis przez base64 z wyniku MCP za duży, by go wiernie przepisać); zamiast tego odtwarzalny skrypt `art/map/pedestal/import_pedestal.luau` + asset 74109633398415. Modele są w miejscu na Robloxie (Team Create).
- `MaxPlayers` w Studio jest tylko do odczytu — rozmiar serwera 8 ustawiony przez Open Cloud (`serverSize: 8`).
- Hooki testowe tylko w Studio: `ServerStorage.DebugHooks.BaseService` (`give`, `away`, `state`), `EconomyService` (`rejoin`), atrybut klienta `DevWelcome`.
