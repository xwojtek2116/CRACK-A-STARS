---
typ: gdd
wersja: 1.0
premiera: 2026-11-21
freeze: 2026-11-18
tags: [gdd]
---
# Crack a Stars — Game Design Document

> [!abstract] Obietnica
> **Gwiazda spada — wszyscy biegną — kto mocniej uderzy, ten więcej zarobi.**
> Krótkie, głośne cykle co 1–4 minuty, kolekcjonowanie świecących reliktów i baza, która zarabia nawet offline.

## 1. Filary
1. **Wyścig** — każde spadnięcie to mini-wydarzenie dla całego serwera: ostrzeżenie, smuga na niebie, wstrząs, krater.
2. **Uderzenie ma znaczenie** — minigra celowania nagradza skill (Perfect = 2× obrażeń), lepszy sprzęt ją ułatwia.
3. **Łup, którym chce się chwalić** — 7 rzadkości, 7 motywów, mutacje Shiny/Golden, ogłoszenia na cały serwer.
4. **Baza rośnie** — każdy przedmiot stoi na postumencie i sypie kasą; widać postęp.
5. **Robimy wszystko sami** — własne modele (Blender), własny styl, zero gotowców z Creator Store.

## 2. Pętla gry
![[Pętla gry.canvas]]

1. **Ogłoszenie** — banner + dźwięk + znacznik na mapie i kompasie (8–30 s przed uderzeniem, wg klasy).
2. **Spadek** — smuga, cień rosnący na ziemi, uderzenie: wstrząs kamery, krater, odłamki, gwiazda wbita w grunt.
3. **Wyścig** — sprint, jetpack (paliwo), pojazdy. Niska grawitacja = długie skoki.
4. **Rozbijanie** — podchodzisz, klikasz/tapasz gwiazdę → [[Minigra rozbijania]]. Wynik × obrażenia narzędzia → HP gwiazdy spada; pasek udziału każdego gracza.
5. **Rozpad** — gwiazda pęka, łup wylatuje do graczy z min. udziałem → [[Łup i losowanie]].
6. **Baza** — przedmiot na postumencie → $/s → [[Baza i dochód]].
7. **Wydawanie** — [[Narzędzia]], [[Pojazdy i ruch|pojazdy]], sloty, jetpack → większe gwiazdy → **Rebirth**.

## 3. Gwiazdy
Klasy (szczegóły i liczby w `03 Gwiazdy`, źródło: `Stars.json`):

| Klasa | Rola |
| --- | --- |
| [[Dust Star]] | częsta, solo, wprowadzenie |
| [[Bright Star]] | 2–4 graczy, pierwsze Rare |
| [[Nova]] | wymaga tier 3+, kilka stref rozbijania |
| [[Giant Star]] | cały serwer, 6 stref, każdy bije swoją część |
| [[Supernova]] | boss serwera w evencie **Deszcz Gwiazd** co godzinę |

Duże gwiazdy mają **strefy (odłamki)** — osobne punkty rozbijania rozłożone na bryle, żeby wielu graczy biło naraz i nikt nie rozbił całej sam. Łup dzieli się według **% udziału**.

## 4. Minigra
Patrz [[Minigra rozbijania]]. Skrót: tarcza z 3–5 kurczącymi się punktami, Perfect/Good/Miss, mnożnik 0,2–2,0×, krytyk ×2,5. Działa myszką, dotykiem, padem. Serwer waliduje czasy.

## 5. Łup
- Rzadkości: Common 1/1 · Uncommon 1/3 · Rare 1/10 · Epic 1/30 · Legendary 1/100 · Mythic 1/500 · Secret 1/5000.
- Motywy: [[Lava]], [[Frost]], [[Nebula]], [[Diamond]], [[Toxic]], [[Solar]], [[Void]] (tylko event).
- Mutacje: Shiny 1/25 (×2), Golden 1/200 (×5). Pity: Legendary 250, Mythic 1200 rozbić.
- Katalog: `04 Łup` (widok [[Łup.base]]).

## 6. Baza
Działka w pierścieniu wokół hubu. Postumenty (start 6, max 30, kupowane), przedmiot na postumencie = $/s. Zarobek offline 50% przez max 8 h. Indeks kolekcji: komplet motywu = +5% Luck na stałe.

## 7. Narzędzia i pojazdy
- 8 narzędzi (Stone Pickaxe → Starbreaker): obrażenia, cooldown, rozmiar i liczba punktów w minigrze, krytyk. Katalog: `05 Narzędzia`.
- 5 pojazdów (Hoverboard, Moon Rover, Rocket Bike na premierę; Jet Pod, UFO jeśli zdążymy) + jetpack 4 poziomy. Katalog: `06 Pojazdy`.

## 8. Progresja
Cash → narzędzia/sloty/pojazdy → większe gwiazdy → **Rebirth** (koszt 1M × 3ⁿ): reset kasy, narzędzi i bazy, zostają pojazdy, indeks, gamepassy; +0,5× do dochodu za każdy.

## 9. Świat
Patrz [[Mapa]]. Mała planeta-hub (sklepy, garaż pojazdów, tablica eventów, portal Rebirth) + 4 strefy: Pola Lawy, Lodowy Krater, Kryształowy Kanion, Mgławicowy Płaskowyż. Niebo: planety, pierścienie, mgławica. Styl: [[Styl graficzny]].

## 10. Monetyzacja
Patrz [[Monetyzacja]]. Gamepassy: 2× Cash, VIP, Lucky, Auto Crack, Fast Vehicles, +5 Slots. Produkty: paczki kasy, Luck Boost, **Summon a Star** (dla całego serwera), Starter Pack.

## 11. Retencja i live ops
Patrz [[Live ops i retencja]]. Deszcz Gwiazd co godzinę, nagroda dzienna 7 dni, kody z TikToka, grupa, cele polubień, weekendowy motyw ×2.

## 12. Zakres 1.0 (nienaruszalne)
Pętla + spadanie 5 klas · minigra · łup 36 + Void 3 · baza z postumentami · 8 narzędzi · 3 pojazdy + jetpack · sklep · Rebirth · monetyzacja · nagroda dzienna + kody · tutorial · mobile.

**Tniemy w tej kolejności, gdy brakuje czasu:** UFO → Jet Pod → motyw Toxic → Indeks (zostaje licznik) → Rebirth.

## 13. Technika
[[Architektura]] · [[Dane gracza]] · [[Analityka]] · [[Audio i VFX]] · [[UI]]
