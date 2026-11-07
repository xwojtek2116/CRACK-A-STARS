---
typ: system
status: plan
taski: [T10]
tags: [system]
---
# Pojazdy i ruch

- **Ruch**: grawitacja 98 (niska), sprint (Shift / przycisk dotykowy), skok wg `Vehicles.json → world`.
- **Jetpack**: przytrzymaj skok w powietrzu → ciąg, paliwo `fuel` s, odnawia się na ziemi. 4 poziomy.
- **Pojazdy**: garaż w hubie + przycisk w HUD (cooldown 10 s, jeden pojazd na gracza). Constrainty (`roblox-physics`), wzór `VehicleService` z CarImportEmpire. Latające: `AlignPosition`/`LinearVelocity` z limitem wysokości.
- Pojazd znika przy wejściu w strefę rozbijania gwiazdy.
