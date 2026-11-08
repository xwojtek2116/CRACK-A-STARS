---
id: T18
tytul: "Retencja daily kody grupa odznaki Deszcz Gwiazd analityka"
status: todo
dzien: 10
data: 2026-11-16
tor: A
effort: medium
zalezy: [T05, T07]
tags: [task, tor/kod]
---
# T18 Retencja daily kody grupa odznaki Deszcz Gwiazd analityka

**Dzień 10** (2026-11-16) · tor **A** (kod) · Opus 5.5 **medium** · zależy od: [[T05]], [[T07]]

## Cel
Retencja daily kody grupa odznaki Deszcz Gwiazd analityka.

## Kontekst
- [[Live ops i retencja]]
- [[Analityka]]

## Skille
- roblox-analytics-liveops
- roblox-game-systems

## Pliki
- src/server/Services/{DailyService,CodesService,EventService,AnalyticsService}.luau

## Do zrobienia
- [ ] Nagroda dzienna
- [ ] Kody promocyjne: `CodesService` (walidacja, raz na gracza, limit prób, nagrody z `Codes.json`), live kody przez ConfigService, okno Codes w HUD + tablica w lobby, komunikaty „Code redeemed!”/„Invalid”/„Already used”
- [ ] Bonus grupy
- [ ] Odznaki
- [ ] Deszcz Gwiazd co godzinę
- [ ] Lejki analityki

## Kryteria akceptacji
- [ ] Event odpala się i kończy Supernową

## Raport
_(uzupełnia Claude po zakończeniu: co zrobiono, pliki, użyte skille, wynik testów, problemy; „Zaległe kroki” tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić)_
