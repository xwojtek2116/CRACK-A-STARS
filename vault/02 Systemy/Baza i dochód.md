---
typ: system
status: w toku
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

## Stan po T08 (2026-11-09)
Decyzje: [[2026-11-09 Baza postumenty dochód sprzedaż]]. Render: ![[T08 postument.png]]

- Kod: `PlotService` (działki), `BaseService` (postumenty, akcje, sloty), `EconomyService` (kasa, tik 1 s, offline), `SellService` (Sell Station), wzory w `shared/BaseMath`, układ i wygląd w `Config/BaseConfig`. Klient: `BaseController` + okna `UI/Base/` (MY BASE, PEDESTAL, SELL STATION, WELCOME BACK).
- Liczby: `Economy.json` → `base` (sloty, offline, `inventoryLimit` 100, `autoSellMaxRarity`), `sell` (300 s, potwierdzenie od Legendary, zasięgi).
- Działka: `Plot_N/Pedestals/Pedestal_<slot>` + `Hologram`, siatka 6×6 od `BuildOrigin` (rząd 1 od strony lobby). Atrybuty postumentu: `Slot, ItemUid, ItemId, ItemName, Rarity, Mutation, Income`. Atrybuty gracza: `IncomePerSec, BaseCapacity, NextSlotPrice, IncomeMult`.
- Modele: `ServerStorage.BaseAssets/{Pedestal, Hologram, Placeholder}` (asset 74109633398415, skrypt `art/map/pedestal/import_pedestal.luau`); modele łupu: `ServerStorage.Items/<itemId>`.
