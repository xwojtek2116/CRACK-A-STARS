---
typ: decyzja
data: 2026-11-09
tags: [decyzja]
---
# Narzędzia w ręku, sklep i witryna (T09)

**Kontekst:** T09: Tool z modelu, zamach, dźwięk, kupno i wyposażanie. Ustalenia z użytkownikiem w czacie (9.11), wszystkie opcje rekomendowane.

**Decyzja:**
- **Animacje postaci R15 na typ narzędzia:** smash (kilof, młoty), slash (topór, miecz, Starbreaker, Comet Blade), thrust (piła), blast (działo). Każda ma znacznik `Hit`. Generator `tools/tool_anim_gen.py` tworzy pliki KeyframeSequence `.rbxmx`, które idą przez Open Cloud jako asset Animation. Generator AI Roblox (`generate_animation`) zwrócił błąd.
- **Dźwięki:** whoosh na „materiał” narzędzia (8 dźwięków), szczęk wyjęcia i fanfara odblokowania. Generator: `tools/tool_sfx_gen.py`. Dźwięk zamachu gra każdy klient na podstawie `AnimationPlayed` cudzych postaci, więc nie potrzeba remote'ów.
- **Kupno:** liniowo (następny tier) za kasę. Po kupnie narzędzie od razu trafia do ręki, a gracz widzi ekran „NEW TOOL UNLOCKED!” z modelem 3D i porównaniem statystyk.
- **Trzymanie:** po odrodzeniu narzędzie jest od razu w ręku. Standardowy pasek Roblox pozwala je schować i wtedy narzędzie wisi na plecach (widoczne dla innych).
- **Klik w powietrze** daje zamach z cooldownem narzędzia. Przy gwieździe startuje minigra, a każde trafienie gra szybkie uderzenie zsynchronizowane z tapem.
- **Witryna Tool Shop:** 8 obracających się modeli na postumentach przed stacją. Każdy gracz widzi własny stan: OWNED, EQUIPPED, NEXT UP z ceną albo LOCKED (przyciemnione). Prompt „Browse Tools” otwiera sklep.
- **Ekskluzywy** (Comet Blade, Galaxy Hammer) są w katalogu narzędzi (`CrackRound`, statystyki z `Monetization.json`). Wyposaża się je przez EquipTool. Przyznaje je `ToolService.grant` (T16 podłączy gamepass).

**Dlaczego:** każde narzędzie ma inny ruch i dźwięk, a postęp (kupno nowego narzędzia) daje silny moment nagrody. Witryna w lobby pokazuje cel na przyszłość.

**Skutki:** T16 woła `ToolService.grant(player, id, true)` po zakupie gamepassa. T19 (Rebirth) czyści `data.tools` i ustawia `equippedTool = STARTING_TOOL` z wyjątkiem ekskluzywów, a potem wywołuje ponowne wydanie narzędzia (odrodzenie postaci wystarczy).
