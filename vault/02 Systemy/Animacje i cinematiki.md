---
typ: system
status: plan
taski: [T05, T06, T07, T12, T35]
tags: [system]
---
# Animacje i cinematiki

> [!abstract] Zasada
> Każdy ważny moment ma krótką, płynną animację, która go „sprzedaje”. Gracz nigdy nie traci sterowania na dłużej niż 1,5 s (wyjątek: Supernowa i Secret, max 3 s, z przyciskiem Skip). Wszystko po stronie **klienta** (TweenService, kamera, cząsteczki), serwer tylko wysyła zdarzenie i czas.

## Kluczowe momenty
| Moment | Animacja | Kamera |
| --- | --- | --- |
| **Ogłoszenie gwiazdy** | rozbłysk na niebie, banner zjeżdża z góry z nazwą „HUGE LAVA STAR”, pulsujący znacznik na mapie | — |
| **Wylot z nieba** | gwiazda wyłania się z rozbłysku, obraca się, ciągnie smugę i iskry, nad celem rośnie cień i pierścień ostrzegawczy | Large+: krótki zoom-out w stronę nieba (0,8 s), potem wraca |
| **Uderzenie** | flash, fala uderzeniowa po ziemi, pył, odłamki, krater, gwiazda wbija się i „osiada” | wstrząs zależny od rozmiaru i odległości |
| **Rozbijanie** | odpryski przy każdym trafieniu, liczby obrażeń wyskakują łukiem, pęknięcia świecą mocniej z HP, przy krytyku slow-mo 0,15 s | lekki punch kamery przy Perfect |
| **Rozpad** | gwiazda pęka na płyty, które się rozlatują, środek wybucha światłem | krótki zoom na gwiazdę |
| **Drop łupu** | przedmiot wylatuje łukiem i obraca się w powietrzu, potem karta łupu: rozbłysk w kolorze rzadkości, tilt i shine | — |
| **Rzadki drop (Legendary+)** | ekran przyciemnia się, promienie światła, karta wjeżdża powoli, ogłoszenie na cały serwer | orbitowanie wokół gracza 1,5 s |
| **Secret / Supernowa** | pełny cinematic 3 s: zatrzymanie czasu, kolorowa eksplozja, tytuł | ujęcie z kilku kątów, Skip |
| **Przedmiot na postumencie** | przedmiot opada na postument, „pop”, pierwsze monety wylatują | — |
| **Zakup narzędzia/pojazdu** | obrót przedmiotu na tle promieni, konfetti | — |
| **Rebirth** | biały flash, gracz unosi się, licznik mnożnika rośnie | zoom-out na planetę |
| **Wsiadanie do pojazdu / jetpack** | dmuchnięcie płomieniem, smuga | FOV +10 przy prędkości |
| **UI** | okna pop z overshootem, przyciski sprężynują, kasa liczy się w górę | — |

## Technika
- `Shared/Config/AnimConfig.luau`: wszystkie czasy, krzywe (Easing), siła wstrząsów. Żadnych liczb w kontrolerach.
- `CinematicController`: kolejka cinematik (nie nakładają się), Skip, wyłączenie przy „Reduce motion” w ustawieniach, limit na telefonie.
- Kamera: `Camera.CameraType = Scriptable` tylko na czas ujęcia, zawsze powrót do `Custom`.
- Wydajność: cząsteczki z pulą, max 1 duży cinematic naraz, na `lowGraphics` mniej cząsteczek. Cel 60 FPS.
