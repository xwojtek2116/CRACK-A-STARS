---
id: T08
tytul: "Baza działki postumenty dochód offline"
status: todo
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
- [ ] PlotService z CarImportEmpire (8 działek)
- [ ] Postumenty z modelem przedmiotu, obrót, poświata, tabliczka $/s
- [ ] Tick dochodu 1 s, offline 50%/8 h
- [ ] Kupno slotów, auto-place best
- [ ] `SellService` + Sell Station w lobby (cena $/s × 300 s, potwierdzenie od Legendary, walidacja serwera)

## Kryteria akceptacji
- [ ] Dochód rośnie zgodnie z wzorem
- [ ] Welcome back po ponownym wejściu

## Raport
_(uzupełnia Claude po zakończeniu: co zrobiono, pliki, użyte skille, wynik testów, problemy; „Zaległe kroki” tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić)_
