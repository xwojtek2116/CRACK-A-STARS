---
id: T07
tytul: "LootService losowanie pity mutacje ogłoszenia"
status: done
dzien: 5
data: 2026-11-11
tor: A
effort: high
zalezy: [T06]
tags: [task, tor/kod]
---
# T07 LootService losowanie pity mutacje ogłoszenia

**Dzień 5** (2026-11-11) · tor **A** (kod) · Opus 5.5 **high** · zależy od: [[T06]]

## Cel
LootService losowanie pity mutacje ogłoszenia.

## Kontekst
- [[Łup i losowanie]]

## Skille
- roblox-luau
- roblox-game-systems
- roblox-security

## Pliki
- src/server/Services/LootService.luau, src/shared/LootMath.luau, src/server/Tests/LootMath.spec.luau

## Do zrobienia
- [x] Losowanie wg Rarities/Themes/Stars.json, luck od Rare
- [x] Pity, mutacje
- [x] Zapis items + index
- [x] Ogłoszenia Epic+/Legendary+
- [x] Test statystyczny 1M losowań

## Kryteria akceptacji
- [x] Rozkład losowań zgodny z oneIn ±5%
- [x] Łup trafia do danych gracza i na postument

## Raport
**Zrobione (9.11):**
- **`Shared/LootMath.luau`** — czysta matematyka bez API Roblox: luck gracza, pula motywu (+3 Secret na Supernowej), szanse rzadkości i mutacji, `roll()` z pity, dochód przedmiotu, liczba postumentów i wolny slot, `odds()` do UI szans. Wzór losowania: [[2026-11-09 Losowanie łupu pity i mutacje]].
- **`Shared/Config/LootConfig.luau`** — typowany dostęp do Rarities/Items/Monetization/Economy oraz czasy karty łupu (`REVEAL`).
- **`Services/LootService.luau`** — słucha `StarService.onCracked`. Dla każdego gracza z udziałem ≥ `minShare`: luck, losowanie (`Random.new()`), pity, zapis przez `DataService.update` (`items[uid]` ze `slot` albo ekwipunek, `index`, `pity`, `stats`), `LootDrop` do gracza, `Announcement` do serwera od Epic. Hak Studio `DebugHooks.LootService` („crack”, „pity”, „summary”).
- **Klient:** `LootController` + `UI/Loot/{Reveal,Announce,Fx}`:
  - karta łupu: poświata, promienie, klejnot w kolorze rzadkości, NEW!, PITY!, Shiny/Golden, $/s, postument albo ekwipunek;
  - od Epic zakryta karta z napięciem (max 1,45 s), obrót, iskry, dźwięk wg rzadkości;
  - paski postępu pity, toast przy komplecie motywu w indeksie;
  - u innych: czat od Epic, baner od Legendary (kolejka), błysk ekranu i dźwięk od Mythic.
- **JSON:** `Rarities.json` sekcja `loot`; `Monetization.json` pola `luckBonus`/`slotBonus` (vip, lucky, extra_slots) i `luckMult`/`durationSeconds` (luck_boost).
- Remote `LootDrop` (serwer → klient) w `Shared/Remotes`. Klient nic nie wysyła, więc nie trzeba nowego limitu w `NetConfig`.

**Pliki:** `src/shared/LootMath.luau`, `src/shared/Config/LootConfig.luau`, `src/server/Services/LootService.luau`, `src/server/Tests/LootMath.spec.luau`, `src/client/Controllers/LootController.luau`, `src/client/UI/Loot/*.luau`, `src/shared/Remotes.luau`, `src/server/init.server.luau`, `src/client/init.client.luau`, `Config/Data/Rarities.json`, `Config/Data/Monetization.json`. Poza kartą: `LootConfig`, klient (karta łupu — zgoda użytkownika), pola w `Monetization.json`.

**Użyte skille:** `task`, `roblox-luau`, `roblox-security`, `roblox-studio-mcp`. `roblox-game-systems` nie wczytany — system nie korzysta z jego wzorców sklepu ani waluty.

**Testy:**
- selene 0/0, `stylua --check` OK, `rojo build` OK.
- `LootMath.spec` (Studio, edycja): **48 OK, 0 FAIL**. 1M losowań Iron/Small w 0,53 s, odchyłka od 1/oneIn: Common 0,05%, Uncommon 0,00%, Rare 0,25%, Epic 0,01%, Legendary 0,08%, Mythic 1,15%, Shiny 0,86%, Golden 1,86%. Secret na Supernowej (5M losowań): 1,5%.
- Play (hak debug): Huge Lava z pity 249 → Legendary (pity), 4 losowania przy udziale 40%. Pity Mythic 1199 → Mythic. Po zapełnieniu 6 slotów łup idzie do ekwipunku. Supernova Void/Solar → 6 kart.
- Play, prawdziwa ścieżka: minigra z Auto Crack dobiła gwiazdę Small → `Cracked` → LootService → przedmiot na postumencie 1, indeks 1, `starsCracked` 1.
- Baner i czat cudzego Secret Golden. Nazwa z `<b>` wyświetla się jako tekst (escape RichText działa).
- Zrzuty: ![[T07 karta lupu Supernova.jpg]] ![[T07 karta lupu Huge.jpg]] ![[T07 baner Secret.jpg]] ![[T07 czat lupu.jpg]]

**Problemy / uwagi:**
- Wzór z GDD (osobny rzut na każdą rzadkość) dawał Uncommon −14%. Zmieniony na jeden rzut z progami, szczegóły w decyzji.
- **Mutacje z luck:** Supernova (luck 9) daje Shiny 36% i Golden 4,5%, Huge — Shiny 18%. Do oceny w balansie.
- `tools/balance_check.py` nie istnieje (skill `balance-check` nie ma skryptu) — symulacji ekonomii nie uruchomiłem.
- `items` rośnie bez limitu (ekwipunek), a DataService przy każdej zmianie wysyła klientowi cały klucz `items`. Przy setkach przedmiotów to duży pakiet. Zapisane w [[Pomysły]] dla T08 / Sell Station.
- ~~Wiadomość na czacie bez zrzutu~~ ✔ 9.11: miejsce miało `TextChatService.ChatVersion = LegacyChatService`, więc wiadomości systemowe nie trafiały do okna czatu. Przełączone w Properties na `TextChatService` (Team Create). Czat pokazuje „★ StarHunter found Golden Secret Cosmic Egg…” w kolorze rzadkości: ![[T07 czat lupu.jpg]]
- Ikony przedmiotów to na razie klejnot w kolorze rzadkości. Podmiana na rendery dopisana do kart T21 (mechanizm `Theme.ITEM_RENDERS` + `Reveal.gem`), T22 i T23.
- Plakietki NEW!/PITY! i baner przesunięte (nachodziły na sąsiednie karty i pasek NEXT STAR). ✔ 9.11 nowe zrzuty: plakietki nie nachodzą, baner jest pod paskiem NEXT STAR (zrzuty wyżej podmienione).
- ✔ 9.11 drugie, puste okno Studio zamknięte (sterowanie ekranem). Zostało jedno okno gry.
