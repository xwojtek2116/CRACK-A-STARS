---
typ: system
status: plan
taski: [T16]
tags: [system]
---
# Monetyzacja

Lista i ceny: `Monetization.json`.

**Gamepassy**: 2× Cash 199 · VIP 299 · Lucky 249 · Auto Crack 399 · Fast Vehicles 149 · +5 Slots 179.
**Dev Products**: Pile/Bag/Vault of Cash 49/149/449 (skaluje się z dochodem) · Luck Boost 15m 79 · **Summon a Star** 99 (Nova dla całego serwera) · Starter Pack 99 (raz).

- `ProcessReceipt` idempotentny (id paragonu w `purchases`), `PurchaseGranted` dopiero po zapisie.
- Gamepassy: `UserOwnsGamePassAsync` przy wejściu + `PromptGamePassPurchaseFinished`.
- **Summon a Star** = płatna losowość → szanse widoczne + `PolicyService` (`ArePaidRandomItemsRestricted`).
- Produkty zakłada sesja przez przeglądarkę w Creator Hub; id wpisujemy do `Monetization.json` (pole `assetId`).
- Okienka kontekstowe: po Miss → Auto Crack, pełna baza → +5 Slots, cudza Legendary → Lucky.
