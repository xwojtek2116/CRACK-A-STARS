---
typ: system
status: plan
taski: [T08]
tags: [system]
---
# Baza i dochód

**Sprzedaż (decyzja 2026-11-08):** w lobby jest **Sell Station** — przedmiot z ekwipunku lub postumentu można sprzedać za `$/s × Economy.sell.incomeSeconds` (300 s, z mutacją). Od Legendary wzwyż okno potwierdzenia. Sprzedaż liczy i waliduje serwer (`SellService`, limit w `NetConfig`).

- Działki w pierścieniu wokół hubu (wzór: `PlotService` z CarImportEmpire). Nazwa gracza nad bramą.
- **Postumenty**: start 6, max 30, cena slotu `slotPriceBase × slotPriceGrowth^(n−6)`. Model przedmiotu obraca się i świeci w kolorze rzadkości; tabliczka z $/s.
- **Dochód**: suma `incomePerSec × mnożnik motywu × mutacja` × (1 + 0,5 × rebirths) × 2× Cash. Tick 1 s na serwerze.
- **Offline**: `min(teraz − lastOnline, 8 h) × dochód × 0,5` + okienko „Welcome back”.
- Klik postumentu → zamień/zdejmij; „Auto-place best”.
