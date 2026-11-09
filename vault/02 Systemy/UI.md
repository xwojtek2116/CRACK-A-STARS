---
typ: system
status: plan
taski: [T13, T14]
tags: [system]
---
# UI

React-lua, komponenty z CarImportEmpire (`Button`, `Panel`, `Modal`, `Toast`, `ProgressBar`, `Currency`, `TierBadge`, `Theme`, `Motion`).

**Styl (decyzja użytkownika 2026-11-08):** kreskówkowy „simulator shop” jak na filmie referencyjnym, ale w kosmicznym motywie naszej gry. Referencja: ![[ref_ui_tiktok.png]]

Co bierzemy z referencji (układ i „feel”, nie grafiki):
- **Okno** = gruba ramka z jasnym obrysem i cieniem, w rogach **ozdoby** (u nas: kryształy, gwiazdki, kawałki meteorytu zamiast chmurek), tło okna z delikatnym wzorem.
- **Nagłówek-wstążka** u góry: ikona 3D po lewej (np. skrzynka z gwiazdą), tytuł dużym pogrubionym fontem z obrysem, **czerwony X** w prawym rogu.
- **Belki sekcji** („Exclusives”, „Tools”, „Vehicles”) na środku okna.
- **Karty ofert**: szeroki baner z gradientem w kolorze rzadkości/rodzaju, render przedmiotu wychodzący poza kartę, nazwa **italic, gruba, z obrysem**, mały opis, żółty dopisek „LIMITED TIME ONLY” / „NEW!”, **zielony przycisk ceny** z ikoną monety lub Robux.
- Kolory nasycone, gradienty, mocne obrysy (`UIStroke` 3–4 px), font Fredoka One / Luckiest Guy.

Nasz motyw (**zmiana 8.11, T13: „kosmiczna czerń”** — patrz [[2026-11-08 Styl UI kosmiczna czerń]]): tła prawie czarne z mgławicami i neonowym obrysem (dawniej granat → fiolet), nagłówki w kolorze danego sklepu (narzędzia = pomarańcz, pojazdy = turkus, Robux = złoto), kolory rzadkości z `Rarities.json`. Wszystkie ozdoby i ikony robimy sami (render z Blendera albo Claude Design), nic z referencji nie kopiujemy.

**Animacje UI** (każde okno, patrz [[Animacje i cinematiki]]): otwarcie = pop z overshootem (0,25 s), zamknięcie = szybki zjazd, przyciski sprężynują przy hover/tap, liczniki kasy „liczą się” w górę, nowe rzeczy mają błysk.

**Ekrany na premierę**: HUD (kasa, $/s, paliwo, kompas do gwiazdy, licznik do następnej gwiazdy, przyciski Shop/Base/Index/Vehicles/Robux), minigra, karta łupu, sklep narzędzi, garaż, baza, indeks, sklep Robux, daily, kody, ustawienia, rebirth.

Makiety: Claude Design → akceptacja z telefonu → kod. Mobile: przyciski ≥ 44 px, ScreenInsets, `UIScale`.

## Stan po T13 (8.11)

Kod: `game/src/client/UI/` — `Theme` (paleta, ikony, `IDLE`), `Motion` (pop, licznik, pętle „życia”), `Store`, `Format` (skróty kasy), `Sfx`, `Hud`, `Windows` (wzór okna sklepu, reszta „Coming soon” → T14), komponenty `Label`, `Button`, `PriceButton`, `RibbonHeader`, `Window`, `OfferCard`, `Toasts`. Kontroler: `Controllers/UIController`.
Dane HUD: atrybuty gracza `IncomePerSec`, `Fuel`, `FuelMax`; `Workspace.NextStarAt`. HUD publikuje `PlayerGui.HudTopInset` / `HudLeftInset` (banery gwiazd i kompas omijają HUD).
![[T13 HUD PC.jpg]]
![[T13 HUD telefon.jpg]]
![[T13 sklep.jpg]]

## Stan po T14 (9.11)

Ekrany w `game/src/client/UI/Screens/`:
- sklep narzędzi (EQUIP/LOCKED), GARAGE (pojazdy + jetpack), STAR INDEX (indeks z sylwetkami + zakładka REBIRTH), SETTINGS (zapis w profilu),
- w HUD przycisk LOBBY (cooldown 10 s, nie w minigrze) i zębatka.

Karta łupu: tilt za palcem/kursorem, rozbłysk, shine, promienie od Legendary. Kupowanie i rebirth czekają na T09/T10/T19 (serwer odpowiada „Coming soon”). Decyzje: [[2026-11-09 Ekrany gry T14]].
![[T14 sklep narzedzi.jpg]]
![[T14 indeks PC.jpg]]
