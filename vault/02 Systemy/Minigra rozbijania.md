---
typ: system
status: w toku
taski: [T06]
tags: [system]
---
# Minigra rozbijania

Cel: krótka (1–2 s), satysfakcjonująca, działająca dotykiem. Lepsze narzędzie = łatwiej.

1. Klik/tap strefy gwiazdy → `CrackStart(starId, zone)` → serwer zwraca `seed` i parametry narzędzia (`targets`, `targetSize`, `shrinkTime`).
2. Klient pokazuje tarczę: punkty pojawiają się kolejno (pozycje z `seed`) i kurczą przez `shrinkTime`.
3. Trafienie = moment w cyklu kurczenia (0–1). `window` z `Tools.json`: ≤ 0,33 Perfect (2,0×), ≤ 0,75 Good (1,0×), reszta / brak = Miss (0,2×).
4. `CrackFinish(starId, times[])` → serwer odtwarza punkty z `seed`, sprawdza, czy czasy są możliwe, liczy mnożnik = średnia, krytyk losuje serwer → obrażenia = `damage × mnożnik × boosty`.
5. Liczby obrażeń nad gwiazdą, wstrząs kamery przy Perfect i krytyku.

**Auto Crack (gamepass):** klient pomija tarczę, serwer liczy ocenę Good. **Cooldown** liczony na serwerze.

## Implementacja (T06)
- Kod: `CrackService` (serwer), `CrackController` + `UI/Minigame/{Round,DamageNumbers}` (klient), wspólna logika `Shared/CrackRound`.
- Remotes: `CrackStart(starId)` → `{ roundId, seed, toolId, autoCrack }`, `CrackFinish(roundId, times[])` (−1 = brak), `CrackResult` do wszystkich.
- Szczegóły decyzji: [[2026-11-08 Minigra rozbijania T06]]. Zrzut: ![[T06 minigra telefon.jpg]]
