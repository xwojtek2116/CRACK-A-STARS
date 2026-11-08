---
typ: system
status: plan
taski: [T18]
tags: [system]
---
# Live ops i retencja

- **Deszcz Gwiazd** co 60 min: 5 min ×4 częstsze gwiazdy Small (więcej rzadkich rodzajów) + Supernowa na końcu (jedyne źródło Secret). Odliczanie w hubie i HUD.
- **Nagroda dzienna** 7 dni (`Economy.json`), reset serii po 48 h.
- **Kody promocyjne** (decyzja 2026-11-08): okno „Codes” w HUD (ikona prezentu) i tablica Daily/Codes w lobby. Kod raz na gracza, wielkość liter bez znaczenia, limit 5 prób/min, nagrody: kasa, Luck Boost, w przyszłości przedmioty. Bazowe kody w `Codes.json` (`LAUNCH`, `STARS`, `1KLIKES`, `SUPERNOVA`); **nowe kody dodajemy bez aktualizacji gry** przez ConfigService (Experience Configs). Kody ogłaszamy na TikToku, w opisie gry i w grupie. Użyte kody w danych gracza (`codesUsed`).
- **Grupa**: +5% kasy. **Cel polubień** na tablicy w hubie.
- **Weekend**: motyw tygodnia ×2 szans.
- **Odznaki**: pierwszy łup, pierwsza Legendary, Rebirth, komplet motywu.
