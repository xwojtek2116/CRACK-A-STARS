--!strict
-- ToolConfig — wygląd i zachowanie narzędzi w ręku (T09). Statystyki (obrażenia, cena, cooldown) są w
-- Config/Data/Tools.json, ekskluzywy w Monetization.json → exclusives (type = "tool").
-- Animacje: tools/tool_anim_gen.py → art/anim/*.rbxmx → Open Cloud (Animation). Dźwięki: SoundIds.

return table.freeze({
	-- Styl zamachu narzędzia → animacja i chwila uderzenia (znacznik "Hit" w animacji).
	STYLE = table.freeze({
		stone_pickaxe = "smash",
		iron_hammer = "smash",
		crystal_axe = "slash",
		plasma_saw = "thrust",
		laser_sword = "slash",
		gravity_hammer = "smash",
		nova_cannon = "blast",
		starbreaker = "slash",
		comet_blade = "slash",
		galaxy_hammer = "smash",
	}) :: { [string]: string },
	DEFAULT_STYLE = "smash",

	ANIMS = table.freeze({
		smash = "rbxassetid://76161377974926",
		slash = "rbxassetid://130688016127723",
		thrust = "rbxassetid://86155996800511",
		blast = "rbxassetid://111240629609905",
	}) :: { [string]: string },
	-- Czas znacznika "Hit" w animacji (s) — zgodny z tool_anim_gen.py.
	HIT_TIME = table.freeze({ smash = 0.29, slash = 0.26, thrust = 0.25, blast = 0.16 }) :: { [string]: number },
	HIT_MARKER = "Hit",

	-- Dźwięk zamachu (klucz SoundIds) — 3D przy narzędziu, słyszą wszyscy w pobliżu.
	SWING_SOUND = table.freeze({
		stone_pickaxe = "swingStone",
		iron_hammer = "swingMetal",
		crystal_axe = "swingCrystal",
		plasma_saw = "swingPlasma",
		laser_sword = "swingLaser",
		gravity_hammer = "swingGravity",
		nova_cannon = "swingCannon",
		starbreaker = "swingLegend",
		comet_blade = "swingCrystal",
		galaxy_hammer = "swingGravity",
	}) :: { [string]: string },

	SWING = table.freeze({
		fadeIn = 0.06, -- s wejścia animacji
		fadeOut = 0.15,
		strikeLead = 0.06, -- minigra: animacja startuje tyle s przed "Hit", więc uderzenie trafia w tap
		strikeSpeed = 1.15, -- minigra: lekko szybsze uderzenie
		freeGap = 0.35, -- min. s między zamachami w powietrze (poza tym cooldown narzędzia)
		quietAfterStrike = 0.6, -- s po uderzeniu w minigrze bez zamachu „w powietrze” z tego samego kliknięcia
	}),

	-- Narzędzie schowane w plecaku wisi na plecach (model bez skryptów, przyspawany do UpperTorso).
	BACK = table.freeze({
		offset = Vector3.new(0, 0.1, 0.75), -- od środka UpperTorso (Z+ = za plecami)
		tiltDeg = -35, -- pochylenie po skosie (trzonek przez plecy)
		centerAlong = 0.5, -- przesunięcie wzdłuż trzonka × długość głowicy (środek narzędzia na plecach)
		lightBrightness = 0.4, -- przygaszone światło narzędzia na plecach
	}),

	-- Witryna Tool Shop w lobby (stacja z tagiem LobbyStation, atrybut Station = "ToolShop").
	SHOWCASE = table.freeze({
		station = "ToolShop",
		forward = 12, -- studs przed frontem budynku
		curve = 0.14, -- łuk: skrajne postumenty bliżej budynku (× |odsunięcie w bok|)
		-- odsunięcie w bok dla kolejnych tierów (patrząc na sklep: tier 1 po lewej, 8 po prawej)
		lateral = { -33, -25.5, -18, -10.5, 10.5, 18, 25.5, 33 },
		modelScale = 1.6, -- modele w witrynie większe niż w ręku
		pedestalSize = Vector3.new(1.6, 5, 5), -- walec (oś X = wysokość)
		ringSize = Vector3.new(0.35, 5.8, 5.8),
		hover = 5.2, -- studs nad postumentem (środek narzędzia)
		spinDegPerSec = 45,
		bobAmplitude = 0.35,
		bobSeconds = 2.4,
		nearDistance = 160, -- klient kręci modele tylko, gdy gracz jest blisko
		lockedFill = Color3.fromRGB(10, 8, 30),
		lockedFillTransparency = 0.35,
		billboardOffset = 6.2, -- studs nad środkiem narzędzia
		billboardSize = Vector2.new(7, 2.4), -- studs (napis maleje z odległością)
		promptDistance = 16,
	}),

	-- Ekran „NEW TOOL UNLOCKED!” po kupnie.
	UNLOCK = table.freeze({
		delay = 0.15,
		autoClose = 5.5, -- s, potem zamyka się sam
		spinDegPerSec = 70,
		viewportFov = 30,
		bursts = 28,
		flashAlpha = 0.55,
	}),
})
