---
typ: system
status: plan
taski: [T04, T05]
tags: [system]
---
# Gwiazdy i spadanie

**StarService** (serwer) planuje spadki według `Stars.json` (osobny zegar dla każdej klasy, losowy czas `intervalMin`–`intervalMax`, Supernowa tylko w evencie).

1. Wybór punktu: losowy punkt w strefach z tagiem `StarLandingZone`, raycast w dół, min. 30 studów od innej gwiazdy i od baz.
2. `Announcement` do wszystkich: klasa, motyw, pozycja, czas uderzenia (`workspace:GetServerTimeNow()`).
3. Klient (StarFxController) rysuje smugę, cień i licznik; serwer po czasie stawia model gwiazdy (klon z `ServerStorage.Stars`), krater i odłamki.
4. Gwiazda ma HP, strefy (Attachmenty na bryle, liczba = `zones`), atrybuty `StarId`, `Class`, `Theme`, `Hp`, `MaxHp`.
5. Udział: `damageBy[userId]`. HP ≤ 0 → LootService rozdaje łup → efekt rozpadu → model znika. Po `lifetime` bez rozbicia gwiazda gaśnie (bez łupu).

**Antyexploit:** obrażenia tylko przez CrackService (odległość ≤ 18 studów od strefy, cooldown narzędzia, limit remote'u).
