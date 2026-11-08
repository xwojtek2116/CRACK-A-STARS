--!strict
-- AnimConfig — czasy, rozmiary i siła efektów cinematiku spadku gwiazdy (T38). Kontrolery i moduły Fx
-- nie mają własnych liczb. Rozmiary w studs, czasy w sekundach. Klucze rozmiarów = Stars.json → order.

local function bySize(
	small: number,
	medium: number,
	large: number,
	huge: number,
	supernova: number?
): { [string]: number }
	return table.freeze({
		Small = small,
		Medium = medium,
		Large = large,
		Huge = huge,
		Supernova = supernova or huge,
	})
end

return table.freeze({
	-- Jakość: mnożnik liczby cząsteczek i odłamków. Low przy ustawieniu lowGraphics albo słabym FPS.
	QUALITY = table.freeze({ High = 1, Medium = 0.6, Low = 0.3 }),
	AUTO_QUALITY = table.freeze({ sampleSeconds = 3, lowFps = 38, mediumFps = 50 }),
	-- Ile wyrw naraz dostaje pełne efekty (błyskawice, cząsteczki); reszta tylko mesh + poświata.
	MAX_FULL_RIFTS = 2,

	RIFT = table.freeze({
		widthMult = bySize(15, 12, 11, 9.5, 8), -- szerokość wyrwy = rozmiar gwiazdy × mnożnik
		openSeconds = 1.6, -- rozdarcie rośnie od rysy do pełnego oka
		lineSeconds = 0.25, -- najpierw cienka jasna rysa
		emergeAt = 1.25, -- s od ogłoszenia: gwiazda wyłania się z wyrwy
		closeDelay = 1.0, -- s po uderzeniu: wyrwa zaczyna się zapadać
		closeSeconds = 0.9,
		lightningCount = bySize(3, 4, 6, 8),
		lightningInterval = table.freeze({ 0.06, 0.28 }),
		lightningWidth = 0.035, -- × szerokość wyrwy
		shardCount = bySize(4, 6, 10, 14),
		shardFallSeconds = 4,
		shardGravity = 40,
		swirlSpeed = 0.6, -- obroty wiru na sekundę
		nebulaSpeed = 0.12, -- przesuw tekstury mgławicy
		wispRate = 30,
		stormRate = 6,
		flareSize = 1.2, -- × szerokość wyrwy (billboard)
		flarePixels = 60, -- minimalny rozmiar poświaty na ekranie
		pulseSpeed = 2.2,
		-- T39: głębia, pęknięcia nieba, snopy światła, aura
		crackCount = bySize(3, 4, 5, 6),
		crackLength = table.freeze({ 0.45, 0.9 }), -- × szerokość wyrwy
		crackGrowSeconds = 0.7,
		crackThickness = 0.5, -- spłaszczenie rys (mniej grube na niebie)
		shaftCount = bySize(2, 3, 4, 5),
		shaftWidth = table.freeze({ 0.18, 0.55 }), -- × szerokość wyrwy (przy wyrwie / przy ziemi)
		shaftSpread = 2.5, -- × promień krateru: rozrzut końców snopów na ziemi
		nebulaDisc = 1.6, -- × wysokość wyrwy (najgłębsza warstwa mgławicy)
		auraRate = 22,
		particleBrightness = 3, -- HDR cząsteczek i beamów (z Bloom „palą się”)
	}),

	SKY = table.freeze({
		fromSize = "Large", -- od tego rozmiaru niebo się barwi, słychać grzmot i błyski oświetlają teren
		tintStrength = bySize(0, 0, 0.35, 0.55),
		darken = bySize(0, 0, -0.08, -0.14),
		approach = 1.6, -- szybkość dochodzenia do koloru (1/s)
		lightningAmbient = 0.55, -- siła błysku światła otoczenia przy wyładowaniu
		lightningChance = 0.35, -- szansa, że wyładowanie wyrwy rozświetli cały teren
	}),

	FALL = table.freeze({
		spinSpeed = 1.4, -- rad/s
		heatShell = 1.3, -- × rozmiar (otoczka ForceField)
		trailLifetime = bySize(0.8, 1.1, 1.5, 2.0),
		smokeRate = 26,
		fireRate = 40,
		sparkRate = 18,
		sonicBoomAt = 0.45, -- postęp lotu (po krzywej), przy którym pęka bariera dźwięku
		sonicBoomGrow = 7, -- × rozmiar
		flybyDistance = 140, -- przelot bliżej kamery = świst
		dustSeconds = 3.5, -- ostatnie sekundy: pył unosi się z ziemi
		tickSeconds = 3, -- ostatnie sekundy: tyk licznika
		groundGlowRange = 60,
		warnSpin = 0.25, -- obroty pierścienia ostrzegawczego na sekundę
		-- T39: ogon plazmy, stożek żaru, odpadające kawałki, pierścienie, Doppler
		plasmaLength = 12, -- × rozmiar gwiazdy (przy pełnej prędkości)
		plasmaWidth = 1.5, -- × rozmiar gwiazdy (przy gwieździe)
		plasmaSpeed = 2.5, -- przesuw tekstury plazmy
		bowCone = 1.7, -- × rozmiar gwiazdy
		chunkInterval = 0.3,
		chunkScale = table.freeze({ 0.06, 0.14 }), -- × rozmiar gwiazdy
		chunkLifetime = 3,
		ringsAt = table.freeze({ 0.2, 0.45, 0.72 }), -- postęp lotu: pierścienie przyspieszenia (środkowy = sonic boom)
		doppler = table.freeze({ 0.8, 1.35 }), -- PlaybackSpeed pętli lotu: start → uderzenie
	}),

	IMPACT = table.freeze({
		flashReach = bySize(250, 400, 700, 1100), -- dalej flash słabnie do zera
		flashStrength = bySize(0.25, 0.4, 0.65, 0.9),
		fireballMult = 2.2, -- × promień krateru
		pillarMult = 7, -- wysokość słupa ognia × rozmiar gwiazdy
		shockwaveMult = 2.6, -- × promień odrzutu
		shockwaveSeconds = 0.75,
		debrisCount = bySize(6, 10, 16, 24),
		debrisScale = table.freeze({ 0.05, 0.13 }), -- × rozmiar gwiazdy
		debrisSpeed = table.freeze({ 0.9, 1.9 }), -- × rozmiar gwiazdy (studs/s)
		debrisLifetime = 3.5,
		debrisTrails = bySize(1, 2, 4, 6),
		dustCount = bySize(12, 20, 32, 48),
		emberCount = bySize(25, 40, 70, 110),
		fovPunch = bySize(2, 4, 7, 10),
		fovSeconds = 0.6,
		shakeReach = 250, -- + shakePerSize × rozmiar
		shakePerSize = 15,
		shakeMax = 3,
		lightBrightness = 12,
		lightSeconds = 1.6,
		-- T39: etapy uderzenia
		torusMult = 2.8, -- × promień odrzutu: końcowy promień fali-torusa
		torusSeconds = 1.1,
		ringDustCount = bySize(16, 26, 40, 60),
		mushroomDelay = 0.55,
		mushroomCount = bySize(6, 10, 16, 24),
		splashCount = bySize(4, 6, 10, 14),
		splashScale = table.freeze({ 0.05, 0.1 }), -- × rozmiar gwiazdy
		splashSpeed = table.freeze({ 1.4, 2.6 }), -- × rozmiar gwiazdy (studs/s)
		emberSeconds = 7, -- unoszący się żar nad kraterem
		emberRate = 14,
		coolDelay = 3, -- s: dźwięk stygnięcia krateru
	}),

	LANDED = table.freeze({
		pulseSpeed = 1.8,
		glowRange = 40,
		sparkRate = 4,
		cracksMult = 2.8, -- × promień krateru (Decal pęknięć)
		highlightFill = table.freeze({ 0.92, 0.75 }), -- przezroczystość wypełnienia Highlight (min/max pulsu)
		shardBurst = bySize(6, 10, 16, 24),
		-- T39: słup światła, orbitujące iskry, fale energii
		beaconHeight = 650,
		beaconWidth = 0.9, -- × rozmiar gwiazdy (min. beaconMinWidth)
		beaconMinWidth = 8,
		beaconPulse = 0.6,
		orbitCount = bySize(4, 6, 8, 12),
		orbitRadius = 0.95, -- × rozmiar gwiazdy
		orbitSpeed = 0.35, -- obroty na sekundę
		waveInterval = 2.2,
		waveSeconds = 1.6,
		waveMult = 3, -- × promień krateru
	}),

	-- T39: dynamiczny Bloom (mocniej tylko w trakcie spadku i uderzenia)
	BLOOM = table.freeze({
		intensity = 1.7,
		size = 40,
		threshold = 0.85,
		flashIntensity = 3.5, -- skok przy uderzeniu (zanika z flashem)
		approach = 2.5,
	}),

	HITSTOP = table.freeze({ seconds = 0.12, fromSize = "Medium" }),

	CINEMA = table.freeze({
		fromSize = "Large", -- pasy kinowe, karta tytułowa, muzyka
		barHeight = 0.085, -- część wysokości ekranu (góra i dół)
		titleSeconds = 2.6,
		barsAfterEmerge = 1.8, -- s po wylocie gwiazdy pasy się chowają
		musicFadeIn = 1.5,
		musicFadeOut = 0.5,
	}),

	CAMERA = table.freeze({
		fromSize = "Large", -- rzut kamery na wyrwę tylko od tego rozmiaru
		shotSeconds = 1.2,
		blendSeconds = 0.35,
		pullBack = 18, -- studs do tyłu i w górę od obecnej kamery
		cooldown = 8, -- min. przerwa między ujęciami
	}),
})
