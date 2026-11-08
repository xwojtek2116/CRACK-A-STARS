---
typ: decyzja
data: 2026-11-08
tags: [decyzja]
---
# Styl UI: kosmiczna czerń, HUD i „żywe” UI

**Decyzje (użytkownik, T13):**
1. **Paleta „kosmiczna czerń”** zamiast granat → fiolet z [[UI]]: prawie czarne tła z mgławicami, neonowe obrysy (cyjan `#3DF2FF`, magenta `#FF3DCB`), grube czarne kontury tekstu, zielone ceny `#3DDC6A`, czerwony X `#FF3B4E`. Wszystko w `game/src/client/UI/Theme.luau`.
2. **Font Luckiest Guy** (wbudowany w Roblox: `Enum.Font.LuckiestGuy`, bez uploadu) do liczb, nagłówków i przycisków; Fredoka One do małych opisów.
3. **Ikony 3D z Blendera** (moneta, gwiazda, paliwo, sklep, baza, indeks, pojazdy, klejnot premium): `art/ui/build_icons.py`, ID w `Theme.ICONS`. Klejnot zamiast logo Robux (własny symbol).
4. **Układ HUD „klasyczny simulator”**: kasa + $/s w lewym górnym rogu, licznik gwiazdy na górze pośrodku, menu Shop/Base/Index/Rides/R$ po lewej (na telefonie 2 kolumny), paliwo w prawym dolnym rogu (tylko podczas lotu jetpackiem), kompas zostaje z `Fx/StarHud`.
5. **Kontrakt danych HUD**: atrybuty gracza `IncomePerSec` (T08), `Fuel` / `FuelMax` (T10) i `Workspace.NextStarAt` (StarService). Brak `Fuel` = pasek ukryty.
6. **Kasa w skrócie** `$1.25M`, `$3.4B`; popupy `+$1,200` pełną liczbą.
7. **Efekty**: latające monety + `+$X` (tylko przy przyroście większym niż 2× dochód/s), błysk na przyciskach i cenach, pulsujący „NEW!”, paliwo < 20% mruga na czerwono i trzęsie się. Dźwięki UI: klik, pop, zamknięcie, moneta (`tools/ui_sfx_gen.py`).
8. **Lekkie animacje w tle** (prośba po akceptacji makiet): oddychające neonowe obrysy, unoszące się przyciski menu (fala), kołysząca się gwiazda w liczniku, unoszące się ozdoby i migoczące gwiazdki w oknach, unoszące się rendery na kartach ofert. Parametry: `Theme.IDLE`.

Makiety: Claude Design „Crack a Stars UI” (HUD PC, HUD telefon, okno sklepu) — zaakceptowane z telefonu 8.11. Task [[T13 System UI HUD i makiety|T13]].
