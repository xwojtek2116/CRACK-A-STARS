---
id: T05
tytul: "StarService harmonogram spadek krater HP"
status: todo
dzien: 3
data: 2026-11-09
tor: A
effort: high
zalezy: [T36, T02, T03, T04]
tags: [task, tor/kod]
---
# T05 StarService harmonogram spadek krater HP

**Dzień 3** (2026-11-09) · tor **A** (kod) · Opus 5.5 **high** · zależy od: [[T02]], [[T03]], [[T04]]

## Cel
StarService harmonogram spadek krater HP.

## Kontekst
- [[Gwiazdy i spadanie]]

## Skille
- roblox-luau
- roblox-networking
- roblox-physics

## Pliki
- src/server/Services/StarService.luau, src/client/Controllers/StarFxController.luau, src/shared/Config/StarConfig.luau

## Do zrobienia
- [ ] Harmonogram wg Stars.json
- [ ] Losowy punkt lądowania na całej planecie (`Stars.json` → `landing`: raycast, odrzucenie hubu/działek/stoków, odstępy, biom pod punktem → boost rodzaju)
- [ ] Ogłoszenie + smuga + cień + uderzenie (klient) — wersja podstawowa, pełny cinematic w T12
- [ ] Model, krater, HP, strefy, gaśnięcie po lifetime
- [ ] Kompas do najbliższej gwiazdy

## Kryteria akceptacji
- [ ] W Play gwiazdy spadają wg harmonogramu
- [ ] Konsola bez błędów
- [ ] Zrzut uderzenia na telefon

## Raport
_(uzupełnia Claude po zakończeniu: co zrobiono, pliki, użyte skille, wynik testów, problemy; „Zaległe kroki” tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić)_
