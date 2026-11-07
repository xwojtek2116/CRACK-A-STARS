---
name: blender-asset
description: Model 3D Crack a Stars w Blenderze (skrypt Python → FBX → render → import do Studio). Używaj przy gwiazdach, narzędziach, łupie, pojazdach i propsach mapy — tylko własne assety, bez Creator Store.
---

# Pipeline assetu 3D

Wzorzec: `art/stars/build_star.py` (gwiazdy). Nowa kategoria = własny skrypt `art/<kategoria>/build_<x>.py` w tym samym układzie.

## 1. Skrypt, nie klikanie
- Model powstaje **proceduralnie ze skryptu** (bmesh), uruchamianego w tle:
  `E:\blender\blender.exe -b --factory-startup -P art/<kat>/build_<x>.py -- [--types A,B] [--render]`
  Blender MCP (`execute_blender_code`) tylko do podglądu/debugowania w otwartym Blenderze — wynik ma być w skrypcie.
- Liczby (kolory, rozmiary, liczba stref) czytaj z `game/src/shared/Config/Data/*.json`, nie wpisuj na sztywno.
- Losowość przez `random.Random(seed)` — ten sam seed = ten sam model.
- Jednostka: promień bryły ≈ 1 m; skalę do studów ustawia import w Studio.

## 2. Części = osobne meshe wg roli materiału
Nazwy obiektów `<Wariant>_<Część>` (np. `Huge_Shell`). Gra koloruje części wg motywu, więc:
`Shell` (bryła, kolor `shell`), `Core` (Neon, `glow`), `Accent` (detal, `color`), `Orbit` (odłamki, tylko duże warianty).
Punkty specjalne (strefy, uchwyty) → empties w `.blend` + JSON obok (`art/stars/zones.json`) w układzie Roblox: Blender (x, y, z) → Roblox (x, z, −y).

## 3. Budżet tris (Styl graficzny)
Gwiazda Small ≤ 2k, Huge ≤ 8k · przedmiot ≤ 2k · narzędzie ≤ 3k · pojazd ≤ 10k. Skrypt wypisuje raport tris i flagę `ok` — przekroczenie = popraw podział/gęstość.
Uwaga: `bmesh.ops.create_icosphere(subdivisions=n)` ma 20·4^(n−1) ścian (2 → 80, 3 → 320, 4 → 1280).

## 4. Eksport i render
- FBX: `axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_ALL", mesh_smooth_type="FACE"`, tylko meshe, jeden plik na rodzaj (wszystkie warianty w środku układu).
- `.blend` obok FBX (Git LFS).
- Render EEVEE do `vault/_img/<nazwa>.png` (kolorowy, ciemne tło) + test sylwetki: czarne bryły na białym tle (`star_silhouettes.png`) — rodzaje muszą być rozpoznawalne bez koloru.
- Render wyślij użytkownikowi przez `SendUserFile` do akceptacji.

## 5. Import do Studio (bez klikania)
1. Upload FBX jako Model przez Studio MCP `open_cloud_invoke` (`POST /assets/v1/assets`, `files: fileContent`, creator = `StudioService:GetUserId()`), potem `GET /assets/v1/operations/{id}` aż `done`.
   Folder pliku musi być zatwierdzony w Studio: **Assistant Settings → MCP Permissions → approved upload directories** (`E:\CrackAStars\art`).
2. `insert_asset` (assetType `Model`) do `ServerStorage`, potem `execute_luau`: rozłóż części do `ServerStorage.<Kategoria>/<Rodzaj>/<Wariant>` (Model z `PrimaryPart = Shell`), ustaw materiał/kolor wg motywu, `ScaleTo` do rozmiaru z JSON, `Anchored`, `CanCollide` tylko na Shell, Attachmenty z JSON-a stref.
3. Zapis: `.rbxm` przez `SerializationService` → `game/assets/<kategoria>/`, i Ctrl+S miejsca (sterowanie komputerem). Gdy coś zablokowane → Raport → Zaległe kroki.

## 6. Vault
`python tools/sync_vault.py`, potem `model: gotowy` w notatce katalogu (pole przeżywa sync), render podlinkowany w notatce (`![[<nazwa>.png]]`).
