---
typ: decyzja
data: 2026-11-09
tags: [decyzja, gwiazdy, art]
---
# Toxic v2: skalno-kryształowa formacja zamiast 5-ramiennej gwiazdy

**Kontekst:** W T40 Toxic miał być 5-ramienną gwiazdą z łańcuchami, fiolkami i emblematem biohazard (`toxic_user_1/2`). 9.11 użytkownik przysłał nowy arkusz referencyjny (`vault/_ref/toxic_user_3.png`) i napisał „zmieńmy Toxic na pewno na takie”.

**Decyzja:** Toxic to korona z ostrych płyt bazaltu wokół świecącego zielonego rdzenia, z kępami kryształów, latającymi skałami, mazią i kraterem z pęknięciami. Arkusz jest źródłem prawdy, nie przeprojektowujemy go. Łańcuchy, fiolki i emblemat odpadają.

**Dlaczego:** Wybór użytkownika. Technicznie forma jest prostsza do animowania: segmenty skorupy, grupy kryształów i gruz to naturalne części ruchome.

**Skutki:**
- Specyfikacja: [[Toxic Star v2 - specyfikacja produkcyjna]], prototyp: Toxic Star Lab (`art/stars/toxic/viewer/ToxicStarLab.html`).
- Świecenie przez geometrię Neon, nie tekstury (SurfaceAppearance nie świeci).
- Latający gruz i VFX tylko na kliencie; serwer ma statyczny model z atrybutami.
- Nowy moduł klienta `StarVisual` z API `SetState` / `PlayAnimation` / `SetEnergyLevel`, wspólny dla wszystkich rodzajów.
- Karta Toxic na płótnie konceptów (5 ramion) jest nieaktualna. Pozostałe 11 gwiazd czeka na decyzję, czy dostaną podobne arkusze.
