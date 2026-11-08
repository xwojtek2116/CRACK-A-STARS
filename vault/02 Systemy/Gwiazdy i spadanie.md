---
typ: system
status: plan
taski: [T04, T05]
tags: [system]
---
# Gwiazdy i spadanie

**StarService** (serwer) planuje spadki według `Stars.json` (osobny zegar dla każdego **rozmiaru**, losowy czas `intervalMin`–`intervalMax`, Supernowa tylko w evencie). Przy spadku losuje **rodzaj** z `Themes.json` (waga `weight` przesunięta przez `rareTypeBoost` rozmiaru; strefa mapy zwiększa szansę rodzajów z pasującym `zone` ×2).

1. **Wybór punktu — losowo po całej planecie** (decyzja 2026-11-08), nie w wyznaczonych miejscach: losowy kąt i promień między hubem a granicą mapy (`Stars.json` → `landing`), raycast w dół na teren. Odrzucamy punkty: w hubie, przy działkach, w wodzie/lawie, za stromo, za blisko innej gwiazdy; wtedy nowe losowanie (max 20 prób). Strefa (biom) pod punktem lądowania tylko zwiększa szansę pasujących rodzajów ×2 — części `StarLandingZone` z T03 służą jako mapa biomów, nie jako jedyne miejsca spadku.
2. `Announcement` do wszystkich: rozmiar, rodzaj, pozycja, czas uderzenia (`workspace:GetServerTimeNow()`).
3. Klient (StarFxController) odgrywa **cinematic spadku** ([[Animacje i cinematiki]]): rozbłysk na niebie, smuga, rosnący cień i licznik, wstrząs kamery przy uderzeniu; serwer po czasie stawia model gwiazdy (klon `ServerStorage.Stars/<Rodzaj>/<Rozmiar>`), krater i odłamki.
**Uderzenie i ślad (decyzja 2026-11-08, `Stars.json` → `impact`):**
- Gwiazda spada **pod kątem** (tor z losowego kierunku) i **wbija się w grunt** na ~35% swojej wysokości, przechylona zgodnie z torem lotu.
- **Krater**: wał z odłamków + przypalona ziemia (mesh + Decal); od Large serwer **naprawdę kopie teren** (`Terrain:FillBall` z Air) i odtwarza go, gdy ślad zniknie.
- **Ślad przelotu**: przypalony pas na ziemi przed kraterem (długość = 6× rozmiar), żarzące się odłamki i dym.
- Po rozbiciu albo zgaśnięciu gwiazdy **ślad zostaje 180 s**, potem blednie przez 20 s. Max 14 śladów naraz (najstarszy znika pierwszy) — mapa „pamięta” ostatnie spadki, a wydajność jest pod kontrolą.

4. Gwiazda ma HP, strefy (Attachmenty na bryle, liczba = `zones`), atrybuty `StarId`, `Size`, `Type`, `Hp`, `MaxHp`.
5. Udział: `damageBy[userId]`. HP ≤ 0 → LootService rozdaje łup → efekt rozpadu → model znika. Po `lifetime` bez rozbicia gwiazda gaśnie (bez łupu).

**Antyexploit:** obrażenia tylko przez CrackService (odległość ≤ 18 studów od strefy, cooldown narzędzia, limit remote'u).
