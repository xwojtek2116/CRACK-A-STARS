---
id: T07
tytul: "LootService losowanie pity mutacje ogłoszenia"
status: todo
dzien: 5
data: 2026-11-11
tor: A
effort: high
zalezy: [T06]
tags: [task, tor/kod]
---
# T07 LootService losowanie pity mutacje ogłoszenia

**Dzień 5** (2026-11-11) · tor **A** (kod) · Opus 5.5 **high** · zależy od: [[T06]]

## Cel
LootService losowanie pity mutacje ogłoszenia.

## Kontekst
- [[Łup i losowanie]]

## Skille
- roblox-luau
- roblox-game-systems
- roblox-security

## Pliki
- src/server/Services/LootService.luau, src/shared/LootMath.luau, src/server/Tests/LootMath.spec.luau

## Do zrobienia
- [ ] Losowanie wg Rarities/Themes/Stars.json, luck od Rare
- [ ] Pity, mutacje
- [ ] Zapis items + index
- [ ] Ogłoszenia Epic+/Legendary+
- [ ] Test statystyczny 1M losowań

## Kryteria akceptacji
- [ ] Rozkład losowań zgodny z oneIn ±5%
- [ ] Łup trafia do danych gracza i na postument

## Raport
_(uzupełnia Claude po zakończeniu: co zrobiono, pliki, użyte skille, wynik testów, problemy; „Zaległe kroki” tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić)_
