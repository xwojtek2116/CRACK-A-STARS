---
typ: system
status: plan
taski: [T12, T21]
tags: [system]
---
# Audio i VFX

Scenariusz i czasy animacji: [[Animacje i cinematiki]].

- **Spadek**: narastający świst, smuga (Beam + Trail), cień-znacznik, uderzenie (boom, wstrząs, pierścień pyłu, odłamki).
- **Gwiazda żyje**: pulsująca poświata w kolorze motywu, iskry, pęknięcia świecą mocniej przy niskim HP.
- **Minigra**: ding Perfect, tok Good, puff Miss, krytyk = flash + złota liczba.
- **Rozpad**: eksplozja kryształów, przedmioty lecą łukiem do graczy, dźwięk wg rzadkości.
- **Muzyka**: kosmiczny ambient w hubie, intensywny loop w Deszczu Gwiazd.
- Dźwięki własne (`tools/sfx_gen.py` wzorem CarImportEmpire).

**T38 (2026-11-08):** 20 własnych dźwięków spadku (`tools/sfx_gen.py` → `art/audio/stars/`, ID w `SoundIds.luau`, odtwarzanie `SoundController`) i 16 tekstur VFX (`tools/vfx_gen.py` → `art/vfx/textures/`, ID w `VfxIds.luau`). Meshe wyrwy, odłamków i skał: `art/vfx/build_vfx.py`.

**T39 (2026-11-08):** +6 dźwięków (pękanie nieba, ogon uderzenia, stygnięcie krateru, buczenie słupa światła, motyw napięcia, akord uderzenia; grupa Music), +5 tekstur (snop światła, plazma, pierścień żaru, fala energii, błysk), +7 meshy (pęknięcia nieba, torus fali, stożek żaru, krople lawy).
