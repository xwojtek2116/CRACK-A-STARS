---
typ: pomysly
tags: [pomysly]
---
# Pomysły po 1.0

- Handel przedmiotami między graczami (wymaga trade-safety, `roblox-security`).
- Nowe motywy: Electric, Shadow, Candy, Ocean.
- Pety-drony, które same rozbijają małe gwiazdy.
- Klany i ranking klanów (OrderedDataStore).
- Druga planeta (teleport) z większymi gwiazdami.
- Fuzja przedmiotów (5 × Common → 1 × Uncommon).

- **Limit ekwipunku łupu + delty `items`** (z T07, 2026-11-09): `items` rośnie bez końca, gdy baza pełna, a `DataService.update` wysyła klientowi cały klucz `items` przy każdej zmianie. Propozycja: limit ekwipunku (np. 100, nadmiar → auto-sprzedaż za $/s × 300) i delty per uid zamiast całej tabeli. **Limit 100 zrobiony w T08**; delty per uid nadal do zrobienia (przy 130 przedmiotach pełna tabela ~10 KB na zmianę).
- **`mutationLuckScale`** (z T07): luck Supernowej ×9 daje Shiny 36% — rozważyć osobny, słabszy mnożnik luck dla mutacji.
- **2× offline za reklamę / Robux** (z T08, 2026-11-09): w oknie „Welcome back” przycisk „2× (watch ad)” albo produkt za Robux — rewarded video (`roblox-monetization`). Miejsce w oknie już jest.
- **Dźwięk kasy z bazy** (z T08): cichy „ding” przy popupach „+$X”, gdy gracz stoi w bazie (T12/audio).
