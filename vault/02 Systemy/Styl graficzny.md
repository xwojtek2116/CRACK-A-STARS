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
- **Gwiazdy v2 (T40):** wszystkie rodzaje na szkielecie Toxic v2 — skorupa w 6 segmentach z żyłami Neon, rdzeń, kępy kryształów, krater, latający gruz; „żyją” dzięki `StarVisual` (stany, animacje). Generator `art/stars/build_star_v2.py`, specyfikacja [[Toxic Star v2 - specyfikacja produkcyjna]].
- Budżet: gwiazda v2 Small ≤ 5k, Huge ≤ 20k tris (T40; v1: 2k/8k), przedmiot ≤ 2k, narzędzie ≤ 3k, pojazd ≤ 10k.
