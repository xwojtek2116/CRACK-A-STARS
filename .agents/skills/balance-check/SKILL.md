---
name: balance-check
description: Uruchom symulację ekonomii Crack a Stars (tools/balance_check.py) i oceń tempo progresji, dochód i szanse łupu. Używaj po każdej zmianie liczb w Config/Data/*.json.
---

# Balance check

1. `python tools/balance_check.py` w katalogu projektu (czyta `game/src/shared/Config/Data/*.json`; kod wyjścia 1 = cel niespełniony). Jeśli skryptu jeszcze nie ma — napisz go (task T27) na wzór `E:\CarImportEmpire\tools\balance_check.py`.
2. Cele (gracz bez Robux, średni skill minigry = 70% Good, 20% Perfect):
   - Iron Hammer ≤ 3 min, Crystal Axe ≤ 15 min, pierwszy pojazd (Hoverboard) ≤ 25 min, Plasma Saw ≤ 1 h;
   - pierwszy Rebirth 2–3 h; Starbreaker ≥ 15 h;
   - pierwsza Legendary: mediana 2–4 h; Mythic: > 20 h;
   - 2× Cash skraca czasy o ~45%, nie więcej.
3. Tabela: etap, czas mediany, czas p90.
4. Propozycje zmian liczb w JSON; wprowadzaj bez pytania tylko, jeśli karta taska na to pozwala. Potem `python tools/sync_vault.py`.
5. Wynik w `vault/09 Decyzje/RRRR-MM-DD balans.md`.
