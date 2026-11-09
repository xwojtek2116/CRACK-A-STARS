---
typ: decyzja
data: 2026-11-09
tags: [decyzja]
---
# Baza postumenty dochód sprzedaż

**Kontekst:** T08 — baza na działce, dochód, offline, kupno slotów, Sell Station. GDD ([[Baza i dochód]]) nie rozstrzygał wyglądu, sposobu zbierania kasy, miejsca kupna slotów, zachowania pełnej bazy ani limitu ekwipunku — pytania do użytkownika 9.11.

**Decyzja (użytkownik, 9.11):**
- **Postument** — własny model z Blendera (`art/map/pedestal/build_pedestal.py`, 600 tris): oktagonalny cokół, kolumna z neonowymi żyłkami, misa z 4 szponami. Neon (`Ring`) = kolor rzadkości, pusty = przygaszony fiolet. Na postumencie **kryształ-placeholder w kolorze poświaty motywu** (`glow`, bo `color` Void jest prawie czarny), automatycznie zastępowany modelem z `ServerStorage.Items/<itemId>`, gdy powstanie (T21–T23). Shiny = iskry, Golden = złoty kolor.
- **Kasa wpada sama co 1 s** + popupy „+$X” nad własnymi postumentami co 3 s + licznik HUD.
- **Sloty:** hologram następnego postumentu na działce (prompt „Buy $X”) + przycisk w oknie MY BASE (stacja **Upgrades** w lobby otwiera to okno). Cena `1000 × 1,6^(kupione − 6)` — pierwszy dodatkowy slot $1000. Nowy postument od razu dostaje najlepszy przedmiot z ekwipunku.
- **Sell Station:** pojedynczo z listy, „SELL ALL BELOW <rzadkość>” (tylko ekwipunek, bez mutacji, progi Uncommon–Legendary), sprzedaż także z menu postumentu (przy własnym postumencie). Od Legendary okno potwierdzenia, wymuszone też na serwerze (`confirm`).
- **Pełna baza:** nowy łup zastępuje najsłabszy postument, jeśli jest lepszy (zdjęty → ekwipunek, toast). Przycisk **AUTO-PLACE BEST** ustawia czołówkę $/s, nie ruszając przedmiotów, które już w niej stoją.
- **Ekwipunek max 100** (`Economy.base.inventoryLimit`): nadmiar sprzedaje się sam — najpierw najsłabszy Common/Uncommon bez mutacji, potem najsłabszy poniżej Legendary. Legendary+ i świeży łup nigdy.
- **Cudze bazy** można oglądać; prompty postumentów tylko u właściciela (akcje i tak zmieniają wyłącznie dane gracza).
- **Welcome back** — pełne okno w stylu T13: czas nieobecności, licznik kwoty, COLLECT. Kasa offline dopisuje się **od razu przy wejściu** (nic nie przepada, gdy gracz zamknie okno), okno pobiera podsumowanie przez `WelcomeInfo`.

**Decyzje techniczne (Claude):**
- `BaseMath` (shared, czysty) = wszystkie wzory; serwis zmienia dane tylko w `DataService.update`.
- `lastOnline` aktualizowany co tik (ukryty przed klientem) — padnięcie serwera nie zawyża offline.
- Offline od 60 s nieobecności (`offlineMinSeconds`), cap 8 h, 50%.
- Akcje bazy (place/remove/auto/buy) działają z dowolnego miejsca (okno MY BASE); sprzedaż wymaga Sell Station albo stania przy własnym postumencie.
- Gracz spawnuje się na swojej działce (też po śmierci) — wzór PlotService z CarImportEmpire.
- Mnożnik 2× Cash czytany z `Monetization.json` (`cashMult: 2` przy `double_cash`).
- Rozmiar serwera = 8 (liczba działek), ustawiony przez Open Cloud.

**Dlaczego:** pętla „łup → postument → $/s” ma działać bez klikania (mobile), ale z decyzjami gracza (sprzedaż, sloty). Limit ekwipunku chroni zapis i UI.

**Skutki:** T14 może dopracować okna bazy (są funkcjonalne, w stylu T13). T16: po zakupie gamepassa wołać `BaseService.render` + `EconomyService.refresh`. T19 (Rebirth): reset `items/slots` przez `DataService.update` — baza przebuduje się sama. T21–T23: modele łupu do `ServerStorage.Items/<itemId>`.
