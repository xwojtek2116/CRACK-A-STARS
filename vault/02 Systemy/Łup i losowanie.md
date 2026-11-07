---
typ: system
status: plan
taski: [T07]
tags: [system]
---
# Łup i losowanie

**LootService** po rozbiciu gwiazdy, dla każdego gracza z udziałem ≥ `minShare`:

1. Losowania = `lootRolls` (+1 przy udziale ≥ 25% na Giant/Supernova).
2. Motyw: ustalony przy spadku (losowanie ważone z `themes` klasy).
3. Rzadkość: od najrzadszej w dół, szansa `luck / oneIn`, gdzie `luck = klasa.luck × (1 + Lucky 0,25 + VIP 0,1 + Indeks 0,05 za motyw) × boost` (luck działa od Rare w górę). Brak przedmiotu tej rzadkości w motywie → następna niższa.
4. Pity: po `pity.Legendary` rozbić bez Legendary+ → gwarantowany Legendary (tak samo Mythic).
5. Mutacja: Golden 1/200, Shiny 1/25, inaczej None.
6. Zapis `items[uid]`, `index[itemId] = true`; wolny postument → stawiamy od razu.
7. Ogłoszenia: Epic+ na czacie, Legendary+ banner dla serwera, Mythic/Secret efekt u wszystkich.

Losowanie przez `Random.new()` na serwerze. Szanse widoczne w UI.
