---
typ: system
status: w toku
taski: [T02]
tags: [system]
---
# Dane gracza

ProfileStore, magazyn `CrackAStars_Player_v1`, schemat w `game/src/server/Data/PlayerSchema.luau`, typ `PlayerData` w `shared/Types.luau`.

| Klucz | Co |
| --- | --- |
| `cash`, `rebirths` | waluta i liczba odrodzeń (leaderstats) |
| `tools`, `equippedTool` | posiadane narzędzia |
| `vehicles`, `jetpackLevel` | pojazdy i poziom jetpacka |
| `items` | `{ [uid] = { itemId, mutation, obtainedAt, slot? } }` |
| `slots` | liczba postumentów |
| `index` | odkryte `itemId` (Indeks) |
| `pity` | liczniki pity (ukryte przed klientem) |
| `boosts` | aktywne boosty (koniec w `os.time`) |
| `daily`, `codesUsed`, `tutorialStep`, `settings` | retencja |
| `purchases` | id paragonów (idempotentny ProcessReceipt, ukryte) |
| `lastOnline` | do zarobku offline |

Zmiana schematu = podbij `SCHEMA_VERSION` w `DataConfig` + migracja w `MIGRATIONS`.
