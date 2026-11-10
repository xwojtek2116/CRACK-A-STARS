---
typ: decyzja
data: 2026-11-10
tags: [decyzja]
---
# Modele łupu: styl, rozmiar i „życie” na postumencie (T21)

**Kontekst:** T21: 24 modele łupu dla rodzajów Iron, Lava, Frost i Geode. Ustalenia z użytkownikiem w czacie (10.11), wszystkie opcje rekomendowane. Styl Iron zaakceptował przed resztą („Tak podoba mi się”).

**Decyzja:**
- **Kształt to hybryda.** Drabina rzadkości jest szkieletem: Common kamyk, Uncommon odłamek, Rare klaster, Epic rdzeń w klatce, Legendary kula z pierścieniami, Mythic serce z odłamkami. Każdy przedmiot dostaje też akcent z nazwy: sztabki (Meteor Ingot), magnesy (Magnet Core), pióro feniksa w pierścieniu lawy (Phoenix Ember), skalne jajo (Crystal Egg), pryzmat ze zorzą (Aurora Prism).
- **Styl:** chunky bryły z fazami, flat shading, dużo Neon. Lód we Frost jest nieprzezroczysty (materiał Ice) i świeci od środka.
- **Kolory są zapieczone w modelu** (paleta motywu z `Themes.json` plus dodatki modułu). `Tint` działa już tylko na placeholderze. Przy Golden skorupa jest mieszana ze złotem (`GOLDEN_BLEND`, materiał Metal), a części Neon zostają bez zmian.
- **Rozmiar rośnie z rzadkością:** `BaseConfig.ITEM_RARITY_SCALE` od Common 0,6 do Mythic 1,3 × `ITEM_MAX_SIZE`. Poświata Legendary jest ×1,3, a Mythic ×1,8 (`GLOW_RARITY_BOOST`).
- **Animacja na postumencie, pełny pakiet:** części z atrybutem `FxType` animuje klient (`client/Fx/ItemFx.luau`, wywoływany z `BaseController`):
  - `Spin`: klatki, pierścienie i aureole obracają się wokół osi przez środek przedmiotu,
  - `Orbit`: odłamki krążą,
  - `Pulse`: serce Mythic bije podwójnym „bum-bum” i rozjaśnia światło.
  Serwer zapisuje `PartCount`, a klient czeka, aż dotrą wszystkie części modelu.
- **Ikony:** render hero 3/4 na przezroczystym tle, światło konturowe w kolorze rzadkości, obrys. Trafiają do `Theme.ITEM_RENDERS`, a `Reveal.gem` pokazuje render (klejnot zostaje, gdy brak ID). Rendery są wczytywane zaraz po starcie klienta.
- **Pipeline wspólny dla T22/T23:** `art/items/build_item.py` (szkielet + moduł na rodzaj) → FBX na rodzaj → Open Cloud → `art/items/gen_import.py` + `import_items.template.luau` → `ServerStorage.Items/<id>`.
