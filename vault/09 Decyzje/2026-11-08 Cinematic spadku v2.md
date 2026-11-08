---
typ: decyzja
data: 2026-11-08
tags: [decyzja]
---
# Cinematic spadku v2 (T39)

**Prośba użytkownika (8.11):** „1000× lepiej” — bardziej efektownie i lepiej wizualnie.

**Decyzje (użytkownik):**
1. Podkręcić wszystkie 4 momenty: wyrwa, lot, uderzenie, leżąca gwiazda.
2. **Kinowy styl od Large:** czarne pasy, karta tytułowa na środku ekranu (zamiast banera zasłaniającego wyrwę), hit-stop przy uderzeniu.
3. **Bloom mocniejszy tylko w trakcie spadku** — na co dzień gra wygląda jak dotąd.
4. **Więcej warstw dźwięku i muzyka** od Large: motyw napięcia od ogłoszenia, akord przy uderzeniu.

**Decyzje techniczne (Claude):**
- Nad leżącą gwiazdą słup światła do nieba (y≈650), widoczny z całej mapy — pomaga ją znaleźć (gameplay i wygląd).
- Hit-stop bez spowalniania gry: 0,12 s zamrożonego białego rdzenia przed eksplozją (od Medium).
- Wszystkie liczby w `AnimConfig.luau` (BLOOM, HITSTOP, CINEMA i rozszerzone sekcje); assety z tych samych generatorów co T38.

Zrzuty: ![[T39 wyrwa i pekniecia.jpg]] ![[T39 uderzenie.jpg]] ![[T39 slup swiatla.jpg]]
