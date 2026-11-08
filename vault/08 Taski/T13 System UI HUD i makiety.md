---
id: T13
tytul: "System UI HUD i makiety"
status: done
dzien: 3
data: 2026-11-09
tor: C
effort: medium
zalezy: [T02]
tags: [task, tor/swiat-ui-biznes]
---
# T13 System UI HUD i makiety

**Dzień 3** (2026-11-09) · tor **C** (swiat-ui-biznes) · Opus 5.5 **medium** · zależy od: [[T02]]

## Cel
System UI HUD i makiety.

## Kontekst
- [[UI]]

## Skille
- roblox-ui

## Pliki
- src/client/UI/{App,Store,Theme,Motion,Components}/*, src/client/Controllers/UIController.luau

## Do zrobienia
- [x] Makiety w Claude Design w stylu referencji z [[UI]] (ramka z ozdobami, nagłówek-wstążka z ikoną, karty ofert, zielone ceny, czerwony X) w kosmicznym motywie → akceptacja z telefonu
- [x] Kopia komponentów z CarImportEmpire + kosmiczny Theme + komponenty `Window`, `RibbonHeader`, `OfferCard`, `PriceButton`
- [x] `Motion`: pop z overshootem, sprężynujące przyciski, liczenie kasy
- [x] HUD: kasa, $/s, paliwo, kompas, licznik gwiazdy

## Kryteria akceptacji
- [x] HUD skaluje się na telefonie i PC

## Raport
**Co zrobiono (8.11):**
- **Pytania → plan → makiety.** Decyzje użytkownika: układ „klasyczny simulator”, paleta „kosmiczna czerń”, Luckiest Guy + ikony 3D z Blendera, latające monety, błysk, „NEW!”, mruganie przy niskim paliwie, dźwięki UI, kasa w skrócie. Makiety w Claude Design (HUD PC, HUD telefon, okno sklepu) zaakceptowane z telefonu: https://claude.ai/artifact/845YbLK7N2XEba2WzJG78r. Po akceptacji dodatkowa prośba: lekkie animacje w tle.
- **Ikony 3D** (`art/ui/build_icons.py`, Blender CLI, kreskówkowy obrys inverted hull): moneta, gwiazda, paliwo, sklep, baza, indeks, pojazd, klejnot premium. Upload jako Decal przez Open Cloud, ID obrazków w `Theme.ICONS`. Podgląd: `vault/_img/T13 ikony.png`.
- **Dźwięki UI** (`tools/ui_sfx_gen.py` → `art/audio/ui/`): klik, pop, zamknięcie, moneta. Upload jako Audio, wpisy `uiClick/uiPop/uiClose/uiCoin` w `SoundIds`.
- **Kod UI** (wzór z CarImportEmpire, przerobiony):
  - `Theme`: paleta, ikony, `IDLE`.
  - `Motion`: pop z overshootem, licznik kasy, pulsy, pętle „życia” (`useLoop`, `useBob`, `useShine`).
  - `Store`, `Format` (skróty $1.25M), `Sfx`, `Hud`.
  - `Windows`: wzór okna sklepu z kartami narzędzi z `Tools.json`; reszta okien „Coming soon”.
  - Komponenty `Label`, `Button`, `PriceButton`, `RibbonHeader`, `Window`, `OfferCard`, `Toasts`.
  - `UIController` (ScreenGui MainUI, DisplayOrder 10).
- **HUD:**
  - Kasa liczy się w górę z pulsem; $/s z atrybutu `IncomePerSec`.
  - Licznik do gwiazdy z `Workspace.NextStarAt` z paskiem postępu („INCOMING!” po czasie).
  - Menu 5 przycisków: unoszą się falą, Shop i R$ mają błysk; na telefonie 2 kolumny.
  - Paliwo z `Fuel`/`FuelMax`: 5 segmentów, < 20% mruga na czerwono i się trzęsie, bez atrybutu ukryte.
  - Latające monety + „+$X” przy przyroście > 2× dochód/s.
- **Lekkie animacje w tle:** oddychające neonowe obrysy pigułek i okien, kołysząca się gwiazda w liczniku, kołysząca się ikona wstążki, unoszące się ozdoby w rogach okien, migoczące gwiazdki w tle okna, unoszące się rendery i pulsujące dopiski na kartach.
- **Poza kartą, potrzebne do HUD:**
  - `StarService.publishNextDrop` ustawia `Workspace.NextStarAt`, replikowane tylko przy zmianie harmonogramu.
  - `Fx/StarHud`: banery gwiazd schodzą pod licznik (`PlayerGui.HudTopInset`), strzałka kompasu omija menu (`HudLeftInset`).

**Zmienione pliki:**
- Nowe: `game/src/client/UI/{App,Hud,Windows,Theme,Motion,Store,Format,Sfx}.luau`, `game/src/client/UI/Components/{Label,Button,PriceButton,RibbonHeader,Window,OfferCard,Toasts}.luau`, `game/src/client/Controllers/UIController.luau`, `art/ui/build_icons.py`, `art/ui/icons/*.png`, `art/ui/icons.blend`, `tools/ui_sfx_gen.py`, `art/audio/ui/*.wav`.
- Zmienione: `game/src/client/init.client.luau` (+UIController), `game/src/shared/Config/SoundIds.luau`, `game/src/server/Services/StarService.luau`, `game/src/client/Fx/StarHud.luau`.
- Vault: `vault/02 Systemy/UI.md`, `vault/09 Decyzje/2026-11-08 Styl UI kosmiczna czerń.md`, `vault/_img/T13 *.jpg|png`.

**Użyte skille:** `task`, `blender-asset`, `roblox-ui`, `anthropic-skills:computer-use` (Rojo, klikanie w Studio, emulator urządzeń). `roblox-luau` i `roblox-studio-mcp` nie były wczytane (wiedza + wzorce projektu); `roblox-code-review` przejrzany w głowie dla zmiany serwera (StarService: tylko atrybut, bez danych od klienta).

**Testy:**
- `stylua --check` i `selene` (pliki T13) bez uwag, `rojo build` OK.
- Studio Play (place 128852283478472, kod przez `rojo serve`): konsola bez błędów UI.
- Wartości testowe przez atrybuty (`IncomePerSec` 350, `Fuel` 3.2/4.5, `DevCash`): kasa $1.29M, $/s, paliwo, licznik gwiazdy nad banerami, kompas po prawej. Okno sklepu otwiera się z pop i zamyka X-em.
- **Kryterium „HUD skaluje się na telefonie i PC”: spełnione.**
  - PC 2215×879 i VGA 640×480: menu w 1 kolumnie.
  - Emulator iPhone 17 Pro poziomo (749×381): UIScale 0,6, menu w 2 kolumnach, przyciski 48×46 px (≥ 44), paliwo obok przycisku skoku, nic nie wchodzi w wcięcie.
- Zrzuty: `vault/_img/T13 HUD PC.jpg`, `T13 HUD telefon.jpg`, `T13 sklep.jpg`.

**Problemy / uwagi:**
- `execute_luau` ma osobny cache `require` i nie dosięga `DataService`. Dlatego `UIController` ma hak tylko dla Studio: atrybut `DevCash` podmienia wyświetlaną kasę, bez zmiany danych.
- Dźwięki UI były w moderacji Roblox w chwili testu, więc ich odtworzenia nie sprawdziłem.
- Renderów narzędzi jeszcze nie ma (T11), więc karty sklepu mają ikonę gwiazdy. Kupowanie robi T09/T14; przycisk ceny pokazuje toast.
- Emulator w oknie edycji Studio został na widoku iPhone 17 Pro. To ustawienie widoku Studio, nie gry; wraca się listą urządzeń nad widokiem.
- Równolegle sesja T06 zmieniała `init.client.luau` i `UI/Minigame/`. Commit obejmuje tylko pliki T13.
- `Theme.TIMER_ALERT` (pulsowanie licznika w ostatnich 10 s) pominięty, bo użytkownik go nie wybrał.
