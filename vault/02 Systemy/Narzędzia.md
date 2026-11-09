---
typ: system
status: gotowy
taski: [T09]
tags: [system]
---
# Narzędzia

- Narzędzie = `Tool` z własnym modelem (Blender), animacją zamachu i dźwiękiem. Statystyki w `Tools.json`.
- Sklep w hubie + okno UI: kup następny tier (liniowo), wyposaż dowolny posiadany.
- Każdy tier ma inny kształt i kolor poświaty — z daleka widać, kto ma lepszy sprzęt.

## Implementacja (T09)
- Serwer: `ToolService` — BuyTool (następny tier, saldo przez EconomyService), EquipTool (posiadane: tiery i ekskluzywy), `grant` dla T16. Tool z `ServerStorage.Tools/<id>` po każdym odrodzeniu, od razu w ręku. Schowany wisi na plecach (`BackTool`).
- Klient: `ToolController` — animacje R15 (smash / slash / thrust / blast) i whoosh na „materiał”, witryna Tool Shop w lobby (8 postumentów, stan gracza), prompt „Browse Tools”. Ekran `UI/Tools/Unlock` po kupnie.
- Liczby wyglądu: `Shared/Config/ToolConfig.luau`. Statystyki: `Tools.json` + `Monetization.json → exclusives`.
- Decyzja: [[2026-11-09 Narzedzia w reku T09]]. Zrzuty: ![[T09 witryna tool shop.jpg]] ![[T09 odblokowanie.jpg]]
