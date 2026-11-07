---
typ: system
status: plan
taski: [T03]
tags: [system]
---
# Styl graficzny

**Stylizowany, świecący, czytelny z daleka.** Mocne bryły z fazami, emisyjne pęknięcia, nasycone kolory motywów, ciemne niebo.
- **Gwiazdy: 12 rodzajów, każdy z własnym generatorem sylwetki** (pole `shape` w `Themes.json`) — np. Lava = płyty bazaltu na magmie, Frost = klaster lodowych kolców, Geode = pęknięte jajo z ametystami, Comet = jądro z ogonem, Ringed = planeta z pierścieniami, Void = czarna kula z dyskiem. Rozmiar zmienia skalę **i** gęstość detali (Small: prosta bryła, Huge: dużo kryształów, odłamki na orbicie, 8 stref). Wspólny pipeline: `art/stars/build_star.py` (moduł na rodzaj).
- Łup: kształt wg rzadkości (kamyk → odłamek → klaster → rdzeń w klatce → kula z pierścieniami → serce z odłamkami → czarna dziura), materiał motywu.
- Narzędzia: „chunky”, przesadzone proporcje, poświata wg tieru.
- Budżet: gwiazda Small ≤ 2k, Huge ≤ 8k tris, przedmiot ≤ 2k, narzędzie ≤ 3k, pojazd ≤ 10k.
