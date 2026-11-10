--!strict
-- BaseConfig — działki i postumenty (T08): nazwy w mapie, układ siatki postumentów na działce, wygląd
-- (obrót, poświata, tabliczka), zasięgi interakcji. Liczby balansu (ceny slotów, offline, limit ekwipunku,
-- sprzedaż) są w Data/Economy.json → base / sell.

return table.freeze({
	-- Mapa: Workspace.Plots/Plot_1..8 (konwencja PlotService z CarImportEmpire).
	PLOTS_FOLDER = "Plots",
	PLOT_PREFIX = "Plot_",
	OWNER_ATTRIBUTE = "OwnerUserId", -- na działce: UserId właściciela, 0 = wolna
	PLAYER_PLOT_ATTRIBUTE = "PlotId", -- na graczu: numer działki
	PEDESTALS_FOLDER = "Pedestals", -- Plot_N.Pedestals: Pedestal_<slot> + Hologram

	SPAWN_HEIGHT_OFFSET = 4,
	CHARACTER_WAIT_TIMEOUT = 10,
	FULL_SERVER_MESSAGE = "All bases on this server are taken. Please join another server.",

	-- Tabliczka nad słupkiem Sign działki.
	SIGN = table.freeze({
		SIZE = UDim2.fromOffset(260, 60),
		STUDS_OFFSET = Vector3.new(0, 8, 0),
		MAX_DISTANCE = 320,
		OWNER_FORMAT = "%s's Base",
		FREE_TEXT = "Free Base",
		TEXT_COLOR = Color3.fromRGB(255, 255, 255),
		BACKGROUND_COLOR = Color3.fromHex("#140C26"),
		BACKGROUND_TRANSPARENCY = 0.25,
	}),

	-- Siatka postumentów w układzie BuildOrigin (LookVector = w stronę lobby, -Z lokalnie).
	-- Slot 1 = przedni rząd, od lewej. Kolumny × rzędy ≥ maxSlots + bonusy gamepassów (30 + 1 + 5).
	GRID = table.freeze({
		COLUMNS = 6,
		ROWS = 6,
		SPACING_X = 13,
		SPACING_Z = 12,
		FRONT = 22, -- odległość pierwszego rzędu od środka działki w stronę lobby
	}),

	-- Modele: ServerStorage.BaseAssets/{Pedestal, Hologram, Placeholder}; modele łupu (T21–T23):
	-- ServerStorage.Items/<itemId> (Model albo MeshPart, import art/items/import_items.luau). Brak modelu = placeholder
	-- w kolorze motywu. Części z atrybutem FxType (Spin/Orbit/Pulse) animuje klient (Fx/ItemFx).
	ASSETS_FOLDER = "BaseAssets",
	ITEMS_FOLDER = "Items",
	ITEM_HEIGHT = 3.2, -- środek przedmiotu nad ItemPoint (wierzch postumentu)
	ITEM_MAX_SIZE = 4.2, -- przedmiot skalowany do tej największej krawędzi (× skala rzadkości)
	-- Rozmiar wg rzadkości (decyzja T21; ta sama tabela w art/items/build_item.py → SIZE, rendery).
	ITEM_RARITY_SCALE = table.freeze({
		Common = 0.6,
		Uncommon = 0.72,
		Rare = 0.85,
		Epic = 1.0,
		Legendary = 1.15,
		Mythic = 1.3,
		Secret = 1.3,
	}),
	-- Mnożnik jasności poświaty (zasięg × pierwiastek) — Mythic ma się wyróżniać na całej bazie.
	GLOW_RARITY_BOOST = table.freeze({ Legendary = 1.3, Mythic = 1.8, Secret = 1.8 }),
	EMPTY_RING_COLOR = Color3.fromHex("#3A2E5C"),
	HOLOGRAM_COLOR = Color3.fromHex("#3DF2FF"),
	GOLDEN_COLOR = Color3.fromHex("#FFC83D"),
	GOLDEN_BLEND = 0.7, -- Golden: skorupa mieszana ze złotem (Neon bez zmian)
	SHINY_SPARKS = 6, -- cząsteczek/s wokół przedmiotu Shiny

	-- Klient: obrót i poświata (tylko postumenty w zasięgu).
	SPIN_DEGREES_PER_SECOND = 45,
	BOB_STUDS = 0.35,
	BOB_SECONDS = 2.4,
	ANIMATE_DISTANCE = 160,
	GLOW_RANGE = 10,
	GLOW_BRIGHTNESS = 1.6,

	-- Tabliczka $/s nad postumentem (BillboardGui, klient). Rozmiar w studs (skaluje się z odległością).
	LABEL = table.freeze({
		SIZE = UDim2.fromScale(11, 3.6),
		STUDS_OFFSET = Vector3.new(0, 10.6, 0),
		MAX_DISTANCE = 90,
	}),

	-- Popupy „+$X” nad postumentami: co ile sekund (zbiorczo za ten czas) i do jakiej odległości.
	POPUP_EVERY_SECONDS = 3,
	POPUP_DISTANCE = 80,

	-- Interakcja: ProximityPrompt na postumencie/hologramie (tylko właściciel) i stacjach lobby.
	PROMPT_DISTANCE = 12,
	STATION_PROMPT_DISTANCE = 16,
	-- Serwer: zasięg akcji z postumentu (od środka działki, z zapasem na lag).
	PLOT_ACTION_RADIUS = 90,

	-- Stacje w lobby (tag LobbyStation, atrybut Station).
	STATION_TAG = "LobbyStation",
	SELL_STATION = "SellStation",
	UPGRADES_STATION = "Upgrades",
})
