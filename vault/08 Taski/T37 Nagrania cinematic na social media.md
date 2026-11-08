---
id: T37
tytul: "Nagrania cinematic na social media"
status: todo
dzien: 10
data: 2026-11-16
tor: C
effort: high
zalezy: [T36, T15, T12]
tags: [task, tor/swiat-ui-biznes, marketing]
---
# T37 Nagrania cinematic na social media

**Od dnia 4, główna sesja dzień 10–13** (2026-11-16 → 19) · tor **C** · Opus 5.5 **high** · zależy od: [[T36 Powiększenie mapy i lobby|T36]], [[T15 Mapa finalna strefy propsy niebo|T15]], [[T12 VFX i dźwięki spadku i rozbicia|T12]]

## Cel
Filmiki cinematic 9:16 z gry na TikTok / YouTube Shorts / Reels — nagrywane **na bieżąco**, gdy coś zaczyna ładnie wyglądać, nie dopiero przed premierą.

## Referencja (decyzja użytkownika 2026-11-08)
TikTok @bonorostudios: https://vm.tiktok.com/ZN8fttus5/ — styl „devlog showcase”: na czarnym tle **hak tekstem** w 1. sekundzie (np. „you can't make a good looking roblox game”), potem **logo gry**, potem szybkie **płynne ujęcia kamery** pokazujące świat, muzyka w rytm cięć. Robimy własną wersję w kosmicznym stylu gry (bez kopiowania ich materiału).

## Kiedy nagrywamy
| Moment | Po tasku | Klip |
| --- | --- | --- |
| Dzień 4–5 | T36 + T05 | devlog: „robię grę o spadających gwiazdach w 14 dni” — przelot nad mapą, pierwsza gwiazda spada |
| Dzień 8–9 | T15 | beauty shots: każdy biom, lobby, niebo z mgławicą, zachód/wschód |
| Dzień 10–11 | T12, T35 | cinematic spadku i uderzenia gwiazdy, rozbicie, Legendary drop |
| Dzień 12–13 | T29 | trailer 30 s + 5 klipów premierowych, klip na dzień premiery |

## Do zrobienia
- [ ] Narzędzie ujęć w Studio (`tools/` + plugin/skrypt dev): ścieżki kamery (CFrame keyframes + TweenService/spline), dolly, orbit, fly-through, FOV, ukrycie UI i postaci
- [ ] Nagrywanie okna Studio/Playtestu w 1080×1920 (ffmpeg `gdigrab` lub nagrywarka Robloxa), 60 FPS
- [ ] Montaż automatyczny: ffmpeg — plansza z hakiem, logo, cięcia do muzyki, napisy
- [ ] Hak-teksty do testów (EN): „you can't make a good looking roblox game”, „I made a game where stars fall from the sky”, „day 1 vs day 14”
- [ ] Muzyka bez praw autorskich (biblioteka TikToka / własna)
- [ ] Gotowe pliki do `art/renders/marketing/clips/` i wysyłka na telefon do akceptacji

## Kryteria akceptacji
- [ ] Min. 1 klip devlog przed dniem 6 i 5+ klipów przed premierą
- [ ] 9:16, 10–30 s, hak w 1. sekundzie, płynna kamera bez szarpnięć
- [ ] **Publikację na kontach robi użytkownik** (albo ja po jego „tak”)

## Raport
_(uzupełnia Claude po zakończeniu)_
