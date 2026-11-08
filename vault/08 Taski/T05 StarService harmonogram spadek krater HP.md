---
id: T05
tytul: "StarService harmonogram spadek krater HP"
status: done
dzien: 3
data: 2026-11-09
tor: A
effort: high
zalezy: [T36, T02, T03, T04]
tags: [task, tor/kod]
---
# T05 StarService harmonogram spadek krater HP

**Dzień 3** (2026-11-09) · tor **A** (kod) · Opus 5.5 **high** · zależy od: [[T02]], [[T03]], [[T04]]

## Cel
StarService harmonogram spadek krater HP.

## Kontekst
- [[Gwiazdy i spadanie]]

## Skille
- roblox-luau
- roblox-networking
- roblox-physics

## Pliki
- src/server/Services/StarService.luau, src/client/Controllers/StarFxController.luau, src/shared/Config/StarConfig.luau

## Do zrobienia
- [x] Harmonogram wg Stars.json
- [x] Losowy punkt lądowania na całej planecie (`Stars.json` → `landing`: raycast, odrzucenie hubu/działek/stoków, odstępy, biom pod punktem → boost rodzaju)
- [x] Ogłoszenie + smuga + cień + uderzenie (klient) — wersja podstawowa, pełny cinematic w T12
- [x] Model wbity w grunt pod kątem toru lotu, krater (mesh + przypalenie, Large+ kopie Terrain), ślad przelotu, dym
- [x] Ślad zostaje 180 s po rozbiciu i blednie (`Stars.json` → `impact`, max 14 śladów, odtworzenie terenu)
- [x] HP, strefy, gaśnięcie po lifetime
- [x] Kompas do najbliższej gwiazdy

## Kryteria akceptacji
- [x] W Play gwiazdy spadają wg harmonogramu
- [x] Konsola bez błędów
- [x] Zrzut uderzenia na telefon

## Raport
**Zrobione (2026-11-08):** decyzje użytkownika z planowania → [[2026-11-08 Spadanie gwiazd T05]].

- **StarService** (`game/src/server/Services/StarService.luau`):
  - harmonogram: osobny zegar na rozmiar wg `Stars.json`, max 6 gwiazd naraz, pierwsza Small po 15 s;
  - losowy punkt na pierścieniu r 450–1900 (raycast tylko na Terrain), odrzucane są: woda, stok > 35°, działki, za blisko gwiazdy lub śladu; max 20 prób;
  - rodzaj: waga z `Themes.json` × `rareTypeBoost` × boost biomu (×2); losowane są tylko rodzaje z modelem w `ServerStorage.Stars`;
  - tor lotu pod kątem 25–50° od pionu; model wbity na 35% wysokości i pochylony wzdłuż toru;
  - krater w Terrain: od Large misa (głębokość 0,3 promienia) wyłożona bazaltem z żarem `CrackedLava`, Small/Medium mają tylko przypaloną powierzchnię; do tego przypalony pas przelotu (6× rozmiar), wał z odłamków, żarzące okruchy i dym (45 s);
  - HP i `damageBy`, gaśnięcie po `lifetime`, animacja rozpadu 2,5 s; ślad zostaje 180 s, blednie 20 s, max 14; teren wraca tylko tam, gdzie nikt go później nie zmienił;
  - API dla T06/T07: `damage(userId, starId, amount)`, `getStar(id)` (strefy = `Zone_N` na `PrimaryPart`), `onCracked(cb)`, `drop(size, type?, pos?)` (event Supernowej), `expire(id)`.
- **StarFxController** (`game/src/client/Controllers/StarFxController.luau`):
  - baner „<NAZWA> INCOMING!” z odliczaniem, max 3 naraz;
  - gwiazda w locie: kula, smuga, ogień, poświata i rozbłysk przy pojawieniu się;
  - na ziemi rosnący cień, czerwona strefa odrzutu i licznik;
  - uderzenie: błysk, fala, kurz, iskry, wstrząs kamery i odrzut własnej postaci (PlatformStand 1,2 s, bez obrażeń);
  - nad leżącą gwiazdą nazwa, pasek HP i „Fades in m:ss” (szczegóły z bliska < 260 studs);
  - rozpad i gaśnięcie lokalnie, blednięcie śladów;
  - kompas: strzałka na krawędzi ekranu z nazwą i dystansem, a gdy gwiazda jest w kadrze, znacznik nad nią.
- **Config:** `StarConfig.luau` (typy i wzory: waga rodzaju, nazwa, promienie, pozycja w locie). Nowe pola w `Stars.json`: `landing.rejectMaterials`, `schedule`, `fall`, `impact.digBowlDepth`, `impact.knockback*`, `impact.rimChunks`, `dev.studioTimeScale`.
- **Remotes:** `StarEvent` (Incoming/Landed/Gone), `RequestStars` (limit 3 / 0,5 na s w `NetConfig`). Typ `StarInfo` w `Types.luau`.
- **Tryb dev (tylko Studio):** interwały i czasy śladów ×0,1; `ServerStorage.DevStar:Invoke("drop"|"damage"|"expire"|"list"|"scars", …)`.

**Pliki:** jak w karcie + `shared/Remotes.luau`, `shared/Config/NetConfig.luau`, `shared/Types.luau`, `shared/Config/Data/Stars.json`, `server/init.server.luau`, `client/init.client.luau`, `vault/_img/T05 *.jpg`.

**Użyte skille:** `task`, `roblox-luau`, `roblox-networking`, `roblox-physics`, `roblox-studio-mcp`, `anthropic-skills:computer-use` (otwarcie miejsca po RCC-1025, połączenie Rojo, zrzuty klienta).

**Testy (Studio Play, miejsce 128852283478472, kod z `rojo serve`):**
- `selene src` 0/0, `stylua --check src` OK, `rojo build` OK.
- Gwiazdy spadają według harmonogramu we wszystkich biomach. Limit 6 trzyma, a biom podbija pasujący rodzaj.
- Odrzut: postać 20 studs od Large dostała prędkość 88 i wstała po 1,2 s.
- Rozbicie: `damage` 5000 → HP 7000, potem 7000 → Cracked, model znika.
- Ślad blednie, po czym teren wraca do stanu sprzed uderzenia (Basalt → Snow, Y −3,7).
- Gaśnięcie po lifetime działa (Expired w logu).
- Konsola: bez błędów naszego kodu. Jedyne ostrzeżenia to ten sam co w T03 `rbxassetid://203785492` (wewnętrzny asset Studio) i DataStore w Studio.
- Zrzuty wysłane na telefon: `T05 uderzenie`, `T05 po uderzeniu`, `T05 lot gwiazdy`, `T05 krater`; dodatkowo w `_img`: `T05 krater snieg`, `T05 kompas i banery`.

**Problemy / uwagi:**
- `tools/balance_check.py` nie istnieje (skill `balance-check` nie ma skryptu). Liczby balansu nie zmieniły się, doszły tylko pola efektów i harmonogramu. `sync_vault.py` OK, bez zmian w notatkach.
- Przy Huge pas przelotu czyta ok. 200 tys. voxeli naraz (jednorazowo co 9–12 min). Trzeba to sprawdzić w profilerze w T30 (wydajność), ewentualnie zwęzić region.
- Gwiazda może spaść na drogę z lobby (droga to też Terrain). Decyzja do T15, czy drogi wykluczać.
- HUD (baner, kompas) jest na zwykłych instancjach, nie w React. T13 może go przenieść do systemu UI.
- Kamera Scriptable przez `execute_luau` jest resetowana przez Asystenta Studio. Do zrzutów użyłem `BindToRenderStep`.
