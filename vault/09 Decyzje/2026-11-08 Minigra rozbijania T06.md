---
typ: decyzja
data: 2026-11-08
tags: [decyzja]
---
# Minigra rozbijania T06

**Kontekst:** [[T06 Minigra rozbijania klient i serwer]] — notatka [[Minigra rozbijania]] nie mówiła, jak gracz zaczyna, gdzie jest tarcza i co robią strefy gwiazdy.

**Decyzja (odpowiedzi użytkownika 8.11):**
- Start = narzędzie w ręku (Tool) + klik/tap przy gwieździe. Do T09 gracz dostaje **zastępczy Tool** z części (`CrackService/PlaceholderTool`).
- Tarcza **na gwieździe w świecie** (BillboardGui), punkty w stożku zwróconym do kamery; przy małych gwiazdach min. 7 studs od środka, żeby kółka się nie nakładały.
- **Auto-pętla** rund, dopóki gracz trzyma narzędzie, stoi w zasięgu (`range` = 10 studs od krawędzi) i gwiazda żyje.
- **Słaby punkt**: jeden złoty punkt (★) na rundę, trafiony co najmniej na Good → cała runda ×1,25 (`weakSpotMult`). Strefy `zones` z Stars.json zostają dla wielu graczy przy dużych gwiazdach — tarcza z nich nie korzysta.
- Wejście: mysz/dotyk = tap w kółko, szybki tap obok = Miss najstarszego punktu (przeciąganie kamery nie liczy się); pad = R2/X w odpowiedniej chwili (sam timing).
- Auto Crack: punkty same trafiają w paśmie Good, gracz może przejąć i trafić Perfect; serwer daje każdemu punktowi co najmniej Good.
- Liczby obrażeń: moje duże (złote przy krytyku), cudze małe; wstrząs tylko u siebie (Perfect, krytyk), ustawienie `cameraShake`.
- Okno oceny wyśrodkowane na chwili zamknięcia pierścienia: Perfect ±window/2, Good ±window/2 (window z Tools.json).

**Dlaczego:** krótka runda (2,8–4,6 s), czytelna na telefonie, serwer liczy wszystko z seed i czasów.

**Skutki:** T09 podmienia zastępczy Tool (kontrakt: atrybut `ToolId` na Toolu w ręku). Monetyzacja musi dopisać `assetId` gamepassa `auto_crack` w Monetization.json. Ustawienie `cameraShake` czeka na okno ustawień (T13).
