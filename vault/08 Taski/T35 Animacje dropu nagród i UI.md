---
id: T35
tytul: "Animacje dropu, nagród i UI"
status: todo
dzien: 11
data: 2026-11-17
tor: B
effort: high
zalezy: [T12, T14, T07]
tags: [task, tor/art]
---
# T35 Animacje dropu, nagród i UI

**Dzień 11** (2026-11-17) · tor **B** (art) · Opus 5.5 **high** · zależy od: [[T12]], [[T14]], [[T07]]

## Cel
Cinematiki nagród: rzadki drop (Legendary+), Secret/Supernowa, przedmiot na postumencie, zakup narzędzia/pojazdu, Rebirth, efekty pojazdów i jetpacka; dopracowanie animacji wszystkich okien UI.

## Kontekst
- [[Animacje i cinematiki]]
- [[UI]]

## Skille
- roblox-characters-animation
- roblox-ui
- roblox-world-building
- roblox-performance

## Pliki
- src/client/Controllers/CinematicController.luau (nowe ujęcia), src/client/UI/Motion.luau, src/client/UI/Components/LootCard*, src/shared/Config/AnimConfig.luau

## Do zrobienia
- [ ] Rzadki drop: przyciemnienie, promienie, orbita kamery 1,5 s
- [ ] Secret / Supernowa: cinematic 3 s ze Skip
- [ ] Postument (opadanie + pierwsze monety), zakup (obrót + konfetti), Rebirth (flash + zoom-out)
- [ ] Pojazdy i jetpack: płomień, smuga, FOV przy prędkości
- [ ] Przegląd wszystkich okien UI: pop, zamknięcie, przyciski, liczniki

## Kryteria akceptacji
- [ ] Każdy moment z tabeli w [[Animacje i cinematiki]] ma animację
- [ ] 60 FPS na telefonie, „Reduce motion” wyłącza ruchy kamery
- [ ] Nagrania wysłane na telefon i zaakceptowane

## Raport
_(uzupełnia Claude po zakończeniu: co zrobiono, pliki, użyte skille, wynik testów, problemy; „Zaległe kroki” tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić)_
