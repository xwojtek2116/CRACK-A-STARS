---
id: T14
tytul: "UI ekrany gry"
status: done
dzien: 6
data: 2026-11-12
tor: C
effort: medium
zalezy: [T13, T07, T08]
tags: [task, tor/swiat-ui-biznes]
---
# T14 UI ekrany gry

**Dzień 6** (2026-11-12) · tor **C** (swiat-ui-biznes) · Opus 5.5 **medium** · zależy od: [[T13]], [[T07]], [[T08]]

## Cel
UI ekrany gry.

## Kontekst
- [[UI]]

## Skille
- roblox-ui

## Pliki
- src/client/UI/Screens/*

## Do zrobienia
- [x] Karta łupu z animacją rzadkości (rozbłysk, tilt, shine; Legendary+ z promieniami — [[Animacje i cinematiki]])
- [x] Sklep narzędzi, garaż, baza, **sprzedaż (Sell)**, indeks, rebirth, ustawienia
- [x] Przycisk Return to Lobby w HUD

## Kryteria akceptacji
- [x] Każdy ekran działa dotykiem i padem

## Raport
**2026-11-09.** Decyzje: [[2026-11-09 Ekrany gry T14]].

**Zrobione**
- `Screens/ToolsScreen`: sklep narzędzi ma stany EQUIPPED / EQUIP / cena następnego tieru / LOCKED (przyciemnione).
- `Screens/GarageScreen`: okno GARAGE (przycisk RIDES) z zakładkami VEHICLES i JETPACK.
- `Screens/IndexScreen`: 12 rodzajów, sylwetki „???”, paski kompletów, +5% Luck.
- `Screens/RebirthScreen`: zakładka REBIRTH w STAR INDEX z kolumnami LOSE/KEEP i „Are you sure?”.
- `Screens/SettingsScreen`: 6 przełączników z zapisem w profilu.
- `Screens/HudSide`: LOBBY (fade, odliczanie cooldownu) i zębatka SETTINGS.
- Klocki wspólne: `Screens/Common` i `Screens/Request` (toasty z powodem odmowy).
- Baza i Sell były już z T08 — bez zmian.
- Karta łupu (`Loot/Reveal`): tilt, odbłysk, rozbłysk, shine od Rare, promienie sunburst od Legendary. Liczby w `LootConfig.REVEAL`.
- Pad: okno po otwarciu zaznacza pierwszy przycisk (`Window`), okno potwierdzenia przejmuje zaznaczenie, B zamyka.
- Ustawienia działają w grze: `skipCinematics` (CinematicController) i `hideAnnouncements` (Loot/Announce).

**Poza `Screens/*` (potrzebne do działania ekranów)**
- `Shared/Remotes`: nowe Remote'y BuyTool, EquipTool, BuyVehicle, BuyJetpack, Rebirth, ReturnToLobby.
- `Config/NetConfig`: limity dla nowych Remote'ów.
- `Config/DataConfig`: nowe klucze ustawień i `SETTING_DEFAULTS`.
- `Config/Data/Economy.json`: `map.lobbyTeleportSpread`.
- `Shared/RebirthMath`: wzory rebirthu (nowy plik).
- Serwer: handler `SetSetting` w DataService, nowy `LobbyService`, tymczasowy `ShopStubService`, `CrackService.isInRound`.
- Klient: Store i UIController dostały pola profilu; `Windows` podpina nowe ekrany.
- Komponenty: `OfferCard` i `PriceButton` dostały własny napis przycisku i przyciemnienie; `Theme.ICONS.settings`.

**Testy (Studio MCP + sterowanie ekranem)**
- Boot 10/10 serwisów i 8/8 kontrolerów, bez błędów.
- Zrzuty wszystkich ekranów w emulacji iPhone 17 Pro i w trybie PC.
- ReturnToLobby: teleport z (258, 4, 107) na spawn lobby, drugie wywołanie → Cooldown.
- BuyTool → ComingSoon, zły toolId → odrzucony przez schemat.
- SetSetting zapisuje się w profilu.
- Dotyk (prawdziwy klik w emulatorze telefonu): CANCEL w potwierdzeniu, X okna, zębatka, przełącznik ustawień z zapisem na serwerze.
- Pad/klawiatura: zaznaczenie przez GuiService i Enter działa na przełączniku i na REBIRTH (otwiera potwierdzenie).
- Tilt myszą: karta przechylona o 6°, odbłysk podąża za kursorem.
- `selene` 0/0, `stylua --check` OK, `rojo build` OK.
- Przegląd wg roblox-code-review: bez krytycznych problemów.
- Zrzuty: ![[T14 HUD telefon.jpg]] ![[T14 sklep narzedzi.jpg]] ![[T14 garaz.jpg]] ![[T14 indeks PC.jpg]] ![[T14 rebirth potwierdzenie.jpg]] ![[T14 ustawienia.jpg]] ![[T14 karta lupu Legendary.jpg]] ![[T14 karta lupu Mythic tilt PC.jpg]]

**Skille:** roblox-luau, roblox-ui (z karty, styl T13), roblox-studio-mcp, roblox-code-review.

**Uwagi dla kolejnych tasków**
- T09/T10/T19: obsłużyć gotowe Remote'y i usunąć swoje nazwy z `ShopStubService.STUBBED`.
- T19 używa `Shared/RebirthMath`.
- Brak w karcie (do T15 albo osobnego taska): prompty stacji Tool Shop / Garage / Index Hall w lobby nie otwierają jeszcze okien (działa HUD i Sell/Upgrades z T08).
- Ikony zębatki i pojazdów są tymczasowe (wbudowana ikona Roblox i ikona RIDES). Własne rendery: T24 / Blender.
- Przycisku ButtonA nie dało się zasymulować z klawiatury MCP. Nawigację padem sprawdziłem przez zaznaczenie GuiService i Enter (to ta sama ścieżka Activated).
