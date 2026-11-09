---
typ: decyzja
data: 2026-11-09
tags: [decyzja]
---
# Losowanie łupu pity i mutacje

**Kontekst:** T07 — LootService. [[Łup i losowanie]] mówi „od najrzadszej w dół, szansa luck/oneIn”, a kryterium karty to rozkład zgodny z 1/oneIn ±5%. Dosłowne losowanie po kolei (osobny rzut na każdą rzadkość) daje Uncommon ~1/3,5 zamiast 1/3 (−14%).

**Decyzja:**
- **Jeden rzut** `u ∈ [0,1)` i progi od najrzadszej w dół: `p = luck/oneIn` (luck od Rare w górę, niżej `1/oneIn`), suma ucięta do 1, reszta = Common. Przy luck 1 rozkład to dokładnie 1/oneIn (test 1M: odchyłki ≤ 1,9%).
- Duży luck (Supernova ×9) zjada najpierw Common/Uncommon — najrzadsze mają pierwszeństwo.
- Brak rzadkości w puli motywu → jej szansa przechodzi na następną niższą. **Wyjątek: Secret** (`loot.exclusiveTiers`) — istnieje tylko w puli Supernowej, poza nią nie jest losowany (inaczej Mythic dostawałby +1/5000).
- **Pity na rozbicie, wspólne dla wszystkich rodzajów** (decyzja użytkownika): 250. rozbicie z rzędu bez Legendary+ podnosi najlepszy łup do Legendary, 1200. bez Mythic+ — do Mythic. Liczniki zerują się też, gdy taki łup wypadnie sam.
- **Luck działa też na mutacje** (decyzja użytkownika): Golden `luck/200`, Shiny `luck/25`.
- Luck = `rozmiar.luck × (1 + Lucky 0,25 + VIP 0,1 + 0,05 × komplety indeksu) × boost 2`. Liczby gamepassów dopisane jako pola `luckBonus` / `slotBonus` / `luckMult` w `Monetization.json` (wcześniej były tylko w tekście `effect`).
- Postument: T07 zapisuje `slot` (najniższy wolny z `slots + VIP 1 + Extra Slots 5`), bez wolnego → ekwipunek (`slot = nil`). Model na postumencie robi T08.

**Dlaczego:** dokładna zgodność z szansami pokazywanymi graczom (zasada 11 — szanse widoczne), prosty i tani rachunek (1M losowań w 0,5 s).

**Skutki:** przy luck Supernowej (9) Shiny wypada w 36%, Golden w 4,5% — do oceny w balansie (można dodać `mutationLuckScale`). `LootMath.odds()` daje szanse do UI.
