---
typ: decyzja
data: 2026-11-09
tags: [decyzja, narzedzia, art]
---
# Modele narzędzi T11: nowe projekty, skala z tierem, efekty od tieru

**Kontekst:** [[T11 Modele narzędzi tier 1-8]] — 8 narzędzi z `Tools.json` i 2 ekskluzywy za Robux z `Monetization.json` (Comet Blade, Galaxy Hammer). Wcześniej sklep miał rendery z T13 (osobne modele tylko do UI), a ekskluzywy pożyczały ikony Laser Sword i Gravity Hammer.

**Decyzja (użytkownik, pytania przed startem + akceptacja szkiców):**
- Nowe projekty od zera; ikony sklepu to rendery tych samych modeli, które są w ręku (też Comet Blade i Galaxy Hammer).
- Skala rośnie z tierem: Stone Pickaxe ~3,3 studs → Starbreaker ~6,8 studs.
- Tier 1–2 bez poświaty, neon od tieru 3, smuga (Trail) od tieru 5; kolory poświaty wg motywu narzędzia.
- Ruchome części: tarcza Plasma Saw, pierścienie Gravity Hammer, galaktyka Galaxy Hammer (klient, `ToolFxController`).
- Nova Cannon = młot hybrydowy (lufa jako obuch z przodu), więc zamach minigry działa bez zmian w kodzie.

**Technicznie:**
- Kontrakt dla T09: `ServerStorage.Tools/<toolId>` — Tool z `Handle`, atrybuty `ToolId`, `DisplayName`, `Tier`, `Exclusive`, `TextureId` = ikona. Nazwa Toola = id (T09 ustawia `Name = DisplayName` przy wydawaniu, żeby hotbar pokazał ładną nazwę).
- Części na `Weld` (nie `WeldConstraint`), bo klient kręci części `Spin*` przez `C0`.
- `Tool.Grip` = środek owijki + obrót 180° wokół trzonka (model uderza w −Z, a przód postaci R15 to +Z Handle). Sprawdzone w Play z `Feel.swing`.

**Skutki:** T09 klonuje gotowe Toole zamiast `PlaceholderTool`. Ikony: `Theme.TOOL_RENDERS` (10 kluczy), źródła w `art/ui/tools/` z `art/tools/build_tools.py --icons`.
