---
id: T09
tytul: "Narzędzia Tool sklep ekwipowanie"
status: done
dzien: 6
data: 2026-11-12
tor: A
effort: medium
zalezy: [T06, T11]
tags: [task, tor/kod]
---
# T09 Narzędzia Tool sklep ekwipowanie

**Dzień 6** (2026-11-12) · tor **A** (kod) · Opus 5.5 **medium** · zależy od: [[T06]], [[T11]]

## Cel
Narzędzia Tool sklep ekwipowanie.

## Kontekst
- [[Narzędzia]]

## Skille
- roblox-luau
- roblox-characters-animation
- roblox-game-systems

## Pliki
- src/server/Services/ToolService.luau, src/client/Controllers/ToolController.luau

## Do zrobienia
- [x] Tool z modelem z ServerStorage.Tools (+ schowany wisi na plecach)
- [x] Animacja zamachu, dźwięk (4 animacje R15 na typ, 8 whooshów, szczęk wyjęcia, fanfara)
- [x] Kupno następnego tieru, wyposażanie (+ ekran NEW TOOL UNLOCKED, witryna Tool Shop w lobby, ekskluzywy)

## Kryteria akceptacji
- [x] Kupno sprawdza saldo na serwerze
- [x] Statystyki z Tools.json działają w minigrze

## Raport

**Ustalenia z użytkownikiem (9.11, wszystkie rekomendowane):**
- animacje postaci na typ narzędzia;
- zestaw dźwięków na typ;
- witryna z modelami w lobby;
- po kupnie: auto-wyposażenie i ekran odblokowania;
- ekskluzywy przygotowane w T09;
- narzędzie od razu w ręku, schowane wisi na plecach;
- klik w powietrze = zamach.

Decyzja: [[2026-11-09 Narzedzia w reku T09]].

**Co zrobiono:**
- **Serwer `ToolService`:**
  - BuyTool: tylko następny tier, `EconomyService.trySpend`, zakaz w trakcie rundy minigry; po kupnie `equippedTool` i narzędzie od razu w ręku.
  - EquipTool: każde posiadane narzędzie, tiery i ekskluzywy.
  - Tool to klon `ServerStorage.Tools/<id>` z nazwą z `DisplayName`, wydawany po każdym odrodzeniu (`Humanoid:EquipTool`).
  - Schowane narzędzie trafia na plecy jako `BackTool`: kopia przyspawana do UpperTorso, bez kolizji, trail i cząsteczki wyłączone.
  - Witryna `ToolShowcase` przed stacją ToolShop: 8 postumentów z neonowym pierścieniem i modelem ×1,6.
  - `grant()` dla T16 i hak `DebugHooks.ToolService` (tylko Studio).
  - Usunięte: `PlaceholderTool` (T06) i stuby BuyTool/EquipTool w `ShopStubService`.
- **Klient `ToolController`:**
  - Animacje R15 smash / slash / thrust / blast. Klik daje pełny zamach z cooldownem narzędzia. W minigrze `strike()` puszcza animację tuż przed znacznikiem „Hit”, więc uderzenie trafia w tap. To zastępuje tween `Tool.Grip` z T06 (`Feel.swing` usunięty).
  - Whoosh przez `AnimationPlayed` na postaciach wszystkich graczy (inni też słyszą, bez remote'ów), szczęk przy wyjęciu.
  - Witryna: obrót i unoszenie modeli, napisy per gracz (OWNED / EQUIPPED / NEXT UP $ / LOCKED $), przyciemnienie zablokowanych, pierścień w kolorze rzadkości, prompt „Browse Tools” otwierający sklep na zakładce TOOLS.
- **UI:**
  - `UI/Tools/Unlock`: pełny ekran „NEW TOOL UNLOCKED!” z wirującymi promieniami, błyskiem, iskrami, obracającym się modelem 3D (ViewportFrame), porównaniem DMG/CD/TARGETS/CRIT (+%) i fanfarą.
  - `ToolsScreen`: po kupnie zamyka sklep i pokazuje odblokowanie.
  - `Windows` (Exclusives): posiadany ekskluzyw ma przycisk EQUIP / EQUIPPED.
- **Wspólne:**
  - `CrackRound` dołącza ekskluzywy do katalogu (`isExclusive`, `allToolIds`), a remote EquipTool przyjmuje też ich id.
  - Nowy `Config/ToolConfig.luau` (style, ID animacji, dźwięki, plecy, witryna, ekran odblokowania).
  - 10 nowych wpisów w `SoundIds`.
- **Assety (Open Cloud):**
  - 4 animacje: smash `76161377974926`, slash `130688016127723`, thrust `86155996800511`, blast `111240629609905`. Pierwsza wersja (pozy liczone bez kalibracji chwytu) jest porzucona.
  - 10 dźwięków `art/audio/tools/*.wav`; ID w `SoundIds`.

**Pliki:**
- Serwer: `game/src/server/Services/ToolService.luau` (nowy), `CrackService/init.luau`, `CrackService/PlaceholderTool.luau` (usunięty), `ShopStubService.luau`, `init.server.luau`.
- Klient: `game/src/client/Controllers/{ToolController (nowy), CrackController}.luau`, `init.client.luau`, `UI/Tools/Unlock.luau` (nowy), `UI/Screens/ToolsScreen.luau`, `UI/Windows.luau`, `UI/Minigame/Feel.luau`.
- Wspólne: `game/src/shared/{CrackRound, Remotes}.luau`, `Config/{ToolConfig (nowy), SoundIds, AnimConfig}.luau`.
- Narzędzia i assety: `tools/tool_anim_gen.py`, `tools/tool_sfx_gen.py`, `art/anim/*.rbxmx`, `art/audio/tools/*.wav`.
- Vault: decyzja, `02 Systemy/Narzędzia` (implementacja, status gotowy), zrzuty `T09 *.jpg`.

**Użyte skille:** `task`, `roblox-characters-animation` (Animator, priorytety, Tool), `roblox-luau`, `roblox-game-systems` (sklep, serwer liczy kasę), `anthropic-skills:computer-use` (dostęp odrzucony), Studio MCP (`execute_luau`, `open_cloud_invoke`, `start_stop_play`, `screen_capture`, `get_console_output`).

**Testy:** `selene` 0/0, `stylua --check` OK, `rojo build` OK. Studio (Play, prawdziwe remoty z klienta):
- Odmowy:
  - BuyTool bez kasy → NoCash;
  - plasma_saw przed crystal_axe → Locked;
  - zła nazwa → odrzucona walidatorem;
  - stone_pickaxe → Owned;
  - EquipTool galaxy_hammer bez posiadania → NotOwned;
  - comet_blade → NotOwned.
- Kupno iron_hammer przy 600: kasa 100, Iron Hammer od razu w ręku, ponowne kupno → Owned. Plasma Saw za 40 000 ✔.
- Plecy: schowanie → `BackTool` (7 części, ukośnie na plecach), wyjęcie → znika.
- Minigra:
  - Iron Hammer: 3 punkty, 3×Perfect ze słabym punktem = 63 (25 × 2 × 1,25) ✔.
  - Galaxy Hammer (ekskluzyw przez `grant`): 5 punktów, DMG 900 (gwiazda rozbita) ✔.
- Klik narzędziem: animacja smash gra, dźwięk `swingStone` na Handle, drugi klik zablokowany cooldownem ✔.
- Witryna: 8 postumentów, kolejność tier 1 → 8 od lewej, stany per gracz poprawne. Ekran odblokowania z modelem 3D i statystykami ✔.
- Konsola bez błędów z T09. Studio: Play zatrzymany, jedno okno.
- Zrzuty: ![[T09 witryna tool shop.jpg]] ![[T09 odblokowanie.jpg]] ![[T09 zamach pila.jpg]] ![[T09 zamach mlot.jpg]]

**Problemy / uwagi:**
- `generate_animation` (AI Roblox) zwrócił błąd, więc animacje są proceduralne z generatora. Kierunek narzędzia w dłoni zmierzyłem w Studio: oś ψ = ramię + łokieć + nadgarstek (opis w `tool_anim_gen.py`).
- Dźwięki mają status moderacji „Reviewing” i przez kilka minut mogą nie grać.
- T19 (Rebirth) musi zresetować `tools` i `equippedTool` (ekskluzywy zostają). T16 woła `ToolService.grant`.
- Brak notatek vaultu dla ekskluzywów (jak w T11).
- Animacje sprawdzone na postaci R15 z AnimationConstraint (nowe stawy). Na starym rigu Motor6D powinny działać tak samo, ale tego nie sprawdzałem.
- Sterowanie ekranem odrzucone w okienku dostępu, więc zaległa kopia `.rbxm` z T40 nadal czeka.

## Zaległe kroki
- [ ] Kopia `.rbxm` szablonów gwiazd (`ServerStorage.Stars`) do `game/assets/stars/` i narzędzi (`ServerStorage.Tools`) do `game/assets/tools/`. Krok: Studio → Explorer → prawy klik → Save to File. Wymaga sterowania ekranem, a dostęp odrzucono w okienku 9.11. Zaległe z T40/T11.
