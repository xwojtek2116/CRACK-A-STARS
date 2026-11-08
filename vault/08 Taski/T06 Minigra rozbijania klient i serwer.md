---
id: T06
tytul: "Minigra rozbijania klient i serwer"
status: done
dzien: 4
data: 2026-11-10
tor: A
effort: high
zalezy: [T05]
tags: [task, tor/kod]
---
# T06 Minigra rozbijania klient i serwer

**Dzień 4** (2026-11-10) · tor **A** (kod) · Opus 5.5 **high** · zależy od: [[T05]]

## Cel
Minigra rozbijania klient i serwer.

## Kontekst
- [[Minigra rozbijania]]

## Skille
- roblox-luau
- roblox-security
- roblox-ui
- roblox-input

## Pliki
- src/server/Services/CrackService.luau, src/client/Controllers/CrackController.luau, src/client/UI/Minigame/*

## Do zrobienia
- [x] CrackStart/CrackFinish z seed
- [x] Tarcza z punktami (mysz, dotyk, pad)
- [x] Walidacja czasów, cooldown, odległość
- [x] Liczby obrażeń, wstrząs kamery
- [x] Auto Crack (flaga gamepassa)

## Kryteria akceptacji
- [x] Perfect/Good/Miss dają mnożniki z Tools.json
- [x] Spam remote'u odrzucony limitem
- [x] Test na telefonie (emulacja w Studio)

## Raport
**Co zrobiono (8.11):** minigra kurczących się punktów — serwer liczy wszystko, klient tylko pokazuje i mierzy czasy. Decyzje projektowe (start narzędziem, tarcza na gwieździe, auto-pętla, słaby punkt ★ ×1,25, Auto Crack z animacją, liczby moje/cudze): [[2026-11-08 Minigra rozbijania T06]].

**Pliki:**
- `src/server/Services/CrackService/init.luau` — CrackStart/CrackFinish: typy (schemat w Remotes), gwiazda Landed, odległość ≤ promień + `range`, Tool w ręku = `equippedTool`, jedna runda naraz, cooldown narzędzia od końca rundy, czasy z seed (trafienie nie może być później niż dotarcie Finish, min. odstęp tapów), krytyk `Random.new()`, `StarService.damage`, `CrackResult`. Auto Crack: `UserOwnsGamePassAsync` (gdy jest `assetId`) albo atrybut `DevAutoCrack` w Studio. Hook `setBoostProvider` dla boostów.
- `src/server/Services/CrackService/PlaceholderTool.luau` — **tymczasowy** Tool z części do T09.
- `src/shared/CrackRound.luau` — runda z seed, ocena, mnożnik (wspólne serwer/klient).
- `src/client/Controllers/CrackController.luau`, `src/client/UI/Minigame/{Round,DamageNumbers}.luau`.
- `Remotes.luau` (+3 remoty), `Net/Validate.luau` (`numberList`), `NetConfig` (limity), `DataConfig` (ustawienie `cameraShake`), `Tools.json → minigame` (weakSpotMult, spawnGap, range, latencyGrace, minTapGap, cooldownGrace, fx), bootstrapy.

**Testy (Studio MCP + sterowanie ekranem):**
- Mnożniki (Stone Pickaxe, dmg 10, runda ze słabym punktem): Perfect 25 (10×2×1,25), Good 13 (10×1×1,25), Miss 2 (10×0,2) ✔. Mieszana runda Perfect/Miss/Miss = 8 ✔.
- Spam 50× CrackStart: 1 OK, 45 RateLimited, 4 RoundActive. Natychmiastowy Finish z idealnymi czasami, powtórka rundy, NaN, zła liczba czasów, identyczne czasy, 30× Finish — HP bez zmian ✔. Z odległości 80 studs: OutOfRange ✔. Auto Crack (DevAutoCrack) bez tapów → Good×3 ✔.
- Emulacja iPhone 17 Pro (749×381): kółka ~70 px, tap w punkt zaliczony przez serwer jako Perfect ✔. Zrzut: ![[T06 minigra telefon.jpg]]
- selene/stylua czyste, `rojo build` OK, konsola bez błędów z T06.

**Skille:** roblox-luau (+ zasady z roblox-security/ui/input w kodzie).

**Uwagi / problemy:**
- Klient zgłasza czasy, więc bot z idealnym zegarem może bić Perfect — serwer blokuje tylko niemożliwe czasy (za wcześnie, identyczne). Ewentualna heurystyka % Perfect → po premierze.
- Dźwięki minigry (ding/tok/puff, krytyk) **nie zrobione**: `SoundIds.luau` równolegle zmienia T13 — do dorobienia w osobnym tasku (`sfx_gen.py` + upload).
- Brak `assetId` gamepassa `auto_crack` w Monetization.json — Auto Crack działa w grze dopiero po utworzeniu gamepassa (task monetyzacji).
- `tools/balance_check.py` nie istnieje — skill balance-check nie do uruchomienia.
- Ustawienie `cameraShake` dodane do `SETTING_KEYS`; przełącznik w oknie ustawień robi T13.
- W Studio jest drugie, nienazwane okno (prawdopodobnie sesji T13) — nie zamykałem.
