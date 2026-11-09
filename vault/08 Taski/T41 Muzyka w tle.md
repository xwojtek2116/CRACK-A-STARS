---
id: T41
tytul: "Muzyka w tle rozgrywki"
status: done
dzien: 4
data: 2026-11-09
tor: A
effort: medium
zalezy: [T39]
tags: [task, tor/kod]
---
# T41 Muzyka w tle rozgrywki

**Tor A (kod) · Opus 5.5 medium · zależy od: [[T39]]**

## Cel
Delikatna, cicha muzyka, która gra cały czas w tle rozgrywki (prośba użytkownika 9.11). Wg [[Audio i VFX]]: „kosmiczny ambient”.

## Pliki
- `tools/music_gen.py` (nowy) → `art/audio/music/music_ambient.wav` (+ podgląd `music_ambient_preview.mp3`)
- `game/src/shared/Config/SoundIds.luau` — `musicAmbient`, `BACKGROUND_MUSIC`
- `game/src/client/Controllers/SoundController.luau` — start tła i przyciszanie

## Zakres
- [x] Synteza: pady D-dur (Dmaj9 → Bm9 → Gmaj9 → Asus, po 24 s), dron basu, rzadkie dzwoneczki pentatoniki, cichy szum „wiatru kosmosu”, pogłos. 96 s, idealna pętla (zdarzenia i pogłos liczone po okręgu).
- [x] Upload przez Open Cloud → `rbxassetid://90257014702117`
- [x] Start po wczytaniu stanu gracza, narastanie 4 s, głośność 0.15, grupa Music (wyłącza ją ustawienie MUSIC)
- [x] Przyciszanie do ×0.2, gdy gra inna muzyka przez `playMusic` (motyw napięcia, stinger uderzenia), powrót w 3 s
- [x] Test w Studio

## Raport
- Test w Studio (9.11): `musicAmbient` gra w pętli (IsLoaded, Looped, Volume 0.15, grupa Music). Spadek Large: tło 0.15 → 0.03 w czasie cinematicu i stingera, powrót do 0.15 w ok. 3 s. Brak nowych błędów w konsoli.
- Moderacja audio w chwili uploadu: „Reviewing” — w Studio gra; jeśli Roblox odrzuci, wygenerować ponownie (`python tools/music_gen.py`) i wgrać jeszcze raz.
- Wszystkie liczby w `SoundIds.BACKGROUND_MUSIC` (głośność, czasy, mnożnik przyciszenia).
- Poza zakresem: osobny „intensywny loop w Deszczu Gwiazd” z GDD — nie robione.
