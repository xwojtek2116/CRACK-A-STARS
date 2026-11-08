---
typ: decyzja
data: 2026-11-08
tags: [decyzja]
---
# Wyrwa w niebie i cinematic spadku (T38)

**Prośba użytkownika (8.11):** „50× lepiej” — gwiazdy wylatują z ogromnej wyrwy w niebie, dużo światła i VFX, własne assety i własne dźwięki całego procesu.

**Decyzje (użytkownik):**
1. Wyrwa = **rozdarcie nieba**: poszarpana świecąca szczelina, w środku pustka z wirem w kolorze gwiazdy, błyskawice po krawędziach, odpadające odłamki nieba.
2. **Rzut kamery na wyrwę tylko od Large** (1,2 s, ruch postaci zostaje, Skip dotknięciem, wyłączone przy lowGraphics/Reduce Motion).
3. Od Large reaguje **cały świat**:
   - niebo ciemnieje i barwi się kolorem gwiazdy;
   - błyski wyrwy rozświetlają teren;
   - daleki grzmot słychać na całej mapie;
   - uderzenie daje biały flash.
4. Zakres z T12 dotyczący spadku i uderzenia przeniesiony do nowej karty [[T38 Cinematic spadku wyrwa VFX dźwięki|T38]], robionej w czacie T05. T12 zostaje z rozbijaniem, rozpadem, łupem i muzyką.

**Decyzje techniczne (Claude):**
- Wszystkie assety własne i generowane skryptami (powtarzalne):
  - tekstury: `tools/vfx_gen.py`;
  - meshe: `art/vfx/build_vfx.py`;
  - dźwięki: `tools/sfx_gen.py`, wzorem CarImportEmpire.
- Liczby efektów w `Shared/Config/AnimConfig.luau`, ID w `VfxIds.luau` / `SoundIds.luau`.
- Szerokość wyrwy = rozmiar gwiazdy × 15/12/11/9,5 (Small→Huge). Mniejsze wyrwy z ziemi wyglądały na zbyt małe.
- Max 2 wyrwy z pełnymi efektami naraz, reszta uproszczona; jakość cząsteczek zależna od lowGraphics i FPS.
- Klient pokazuje w locie prawdziwy model gwiazdy (`ReplicatedStorage.StarVisuals`, kopia robiona przez serwer przy starcie).

Zrzuty: ![[T38 wyrwa.jpg]] ![[T38 uderzenie.jpg]]
