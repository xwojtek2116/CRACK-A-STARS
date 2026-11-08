---
id: T12
tytul: "Cinematiki spadku, uderzenia i rozpadu, VFX i dźwięki"
status: todo
dzien: 10
data: 2026-11-16
tor: B
effort: high
zalezy: [T05, T07, T38]
tags: [task, tor/art]
---
# T12 VFX i dźwięki spadku i rozbicia

**Dzień 10** (2026-11-16) · tor **B** (art) · Opus 5.5 **high** · zależy od: [[T05]], [[T07]]

## Cel
Płynne cinematiki świata: wylot gwiazdy z nieba, uderzenie, rozbijanie, rozpad, lot łupu. Plus dźwięki.

## Kontekst
- [[Audio i VFX]]
- [[Animacje i cinematiki]]

## Skille
- roblox-world-building
- roblox-audio
- roblox-characters-animation
- roblox-input

## Pliki
- src/client/Controllers/StarFxController.luau, src/client/Controllers/CinematicController.luau, src/shared/Config/AnimConfig.luau, src/client/Controllers/SoundController.luau, tools/sfx_gen.py

## Do zrobienia
- [ ] `CinematicController` + `AnimConfig` (kolejka, Skip, Reduce motion)
- [ ] ~~Wylot z nieba, uderzenie~~ → przeniesione do [[T38 Cinematic spadku wyrwa VFX dźwięki|T38]] (8.11); tu tylko spójność z T38
- [ ] Rozbijanie: odpryski, liczby obrażeń, slow-mo krytyka
- [ ] Rozpad na płyty i lot łupu łukiem
- [ ] Dźwięki rzadkości, muzyka (dźwięki spadku/uderzenia/wyrwy są w T38 — `SoundController`, `tools/sfx_gen.py`)

## Kryteria akceptacji
- [ ] Efekty nie spadają poniżej 60 FPS na telefonie
- [ ] Gracz nie traci sterowania > 1,5 s; kamera zawsze wraca do Custom
- [ ] Wideo/zrzuty każdego momentu wysłane na telefon do akceptacji

## Raport
_(uzupełnia Claude po zakończeniu: co zrobiono, pliki, użyte skille, wynik testów, problemy; „Zaległe kroki” tylko dla tego, czego żadne narzędzie nie pozwoliło zrobić)_
