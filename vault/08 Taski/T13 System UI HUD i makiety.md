---
id: T13
tytul: "System UI HUD i makiety"
status: todo
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
- [ ] Makiety w Claude Design w stylu referencji z [[UI]] (ramka z ozdobami, nagłówek-wstążka z ikoną, karty ofert, zielone ceny, czerwony X) w kosmicznym motywie → akceptacja z telefonu
- [ ] Kopia komponentów z CarImportEmpire + kosmiczny Theme + komponenty `Window`, `RibbonHeader`, `OfferCard`, `PriceButton`
- [ ] `Motion`: pop z overshootem, sprężynujące przyciski, liczenie kasy
- [ ] HUD: kasa, $/s, paliwo, kompas, licznik gwiazdy

## Kryteria akceptacji
- [ ] HUD skaluje się na telefonie i PC

## Raport
_(uzupełnia Claude po zakończeniu: co zrobiono, pliki, użyte skille, wynik testów, problemy; „Zaległe kroki” tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić)_
