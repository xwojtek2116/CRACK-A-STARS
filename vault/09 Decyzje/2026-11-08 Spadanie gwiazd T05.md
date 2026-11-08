---
typ: decyzja
data: 2026-11-08
tags: [decyzja]
---
# Spadanie gwiazd (T05)

**Decyzje (użytkownik, planowanie T05):**
1. **Spadają tylko rodzaje z gotowym modelem** (teraz Iron, Lava, Frost, Geode). Kolejne rodzaje dochodzą same, gdy ich model pojawi się w `ServerStorage.Stars`.
2. **Gwiazda widoczna na niebie cały czas** od ogłoszenia do uderzenia: sunie pod kątem i przyspiesza, a na ziemi rośnie jej cień i działa licznik. `Stars.json` → `fall`.
3. **Kompas**: strzałka na krawędzi ekranu w kolorze rodzaju, z nazwą i dystansem. Gdy gwiazda jest w kadrze, pokazuje się znacznik nad nią.
4. **Uderzenie odrzuca graczy** w promieniu krateru × 2,2, **bez obrażeń**. `Stars.json` → `impact.knockback*`.
5. **Nad gwiazdą**: nazwa w kolorze rodzaju, pasek HP i licznik do zgaśnięcia.
6. **Max 6 gwiazd naraz** (bez Supernowej); przy komplecie zegar rozmiaru czeka. `Stars.json` → `schedule`.
7. **Pierwsza Small 15 s po starcie serwera**, żeby nowy gracz od razu zobaczył spadek.
8. **Tryb dev tylko w Studio**: czasy ×0,1 i `ServerStorage.DevStar` do ręcznego zrzutu. `Stars.json` → `dev`.

**Decyzje techniczne (Claude):**
- Przypalenie krateru i pasa robione jest **w Terrain** (bazalt, w środku żar `CrackedLava`), a nie płaskimi częściami, bo te na nierównym terenie lewitowały. Teren wraca tylko tam, gdzie nikt go później nie zmienił; pas przelotu omija kratery innych śladów.
- Misa od Large ma głębokość 0,3 promienia (`impact.digBowlDepth`). Wbicie 35% liczone jest od pierwotnego gruntu, bo przy głębszej misie gwiazda znikała w dziurze.
- Lot jest liczony u klienta ze wspólnego wzoru `StarConfig.fallPosition`; serwer wysyła tylko start, cel i czasy (`GetServerTimeNow`).

Task: [[T05 StarService harmonogram spadek krater HP|T05]]. System: [[Gwiazdy i spadanie]].
