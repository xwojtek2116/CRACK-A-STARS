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

Nasz motyw: tła ramek granat → fiolet z gwiazdkami, nagłówki w kolorze danego sklepu (narzędzia = pomarańcz, pojazdy = turkus, Robux = złoto), kolory rzadkości z `Rarities.json`. Wszystkie ozdoby i ikony robimy sami (render z Blendera albo Claude Design), nic z referencji nie kopiujemy.

**Animacje UI** (każde okno, patrz [[Animacje i cinematiki]]): otwarcie = pop z overshootem (0,25 s), zamknięcie = szybki zjazd, przyciski sprężynują przy hover/tap, liczniki kasy „liczą się” w górę, nowe rzeczy mają błysk.

**Ekrany na premierę**: HUD (kasa, $/s, paliwo, kompas do gwiazdy, licznik do następnej gwiazdy, przyciski Shop/Base/Index/Vehicles/Robux), minigra, karta łupu, sklep narzędzi, garaż, baza, indeks, sklep Robux, daily, kody, ustawienia, rebirth.

Makiety: Claude Design → akceptacja z telefonu → kod. Mobile: przyciski ≥ 44 px, ScreenInsets, `UIScale`.
