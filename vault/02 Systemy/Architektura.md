---
typ: system
status: w toku
taski: [T01, T02]
tags: [system]
---
# Architektura

Wzór: CarImportEmpire (bootstrap Init/Start, Remotes z walidacją i limitem, DataService na ProfileStore).

| Warstwa | Gdzie | Co |
| --- | --- | --- |
| Serwer | `game/src/server/Services/*Service.luau` | logika i stan gry, jedyne źródło prawdy |
| Klient | `game/src/client/Controllers/*Controller.luau` | wejście, kamera, efekty, minigra (prezentacja) |
| UI | `game/src/client/UI` (React-lua) | HUD, sklepy, baza, indeks |
| Wspólne | `game/src/shared` | `Remotes`, `Types`, `Net/Validate`, `Net/RateLimiter`, `Config/` |
| Liczby | `game/src/shared/Config/Data/*.json` | balans: jedno źródło, `tools/sync_vault.py` → vault |

**Serwisy (plan):** DataService · EconomyService · StarService · CrackService · LootService · BaseService · ToolService · VehicleService · JetpackService · RebirthService · MonetizationService · DailyService · CodesService · AnalyticsService · EventService.

**Kontrolery (plan):** StateController · UIController · StarFxController · CrackController · CompassController · VehicleController · JetpackController · BaseController · SoundController.

**Streaming:** `StreamingEnabled = true`. Gwiazdy są modelami `Persistent`, dopóki żyją (znacznik i kompas działają z daleka).
