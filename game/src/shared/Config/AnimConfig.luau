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
	-- T06 v2: minigra rozbijania — wygląd punktów, efekty trafień, pęknięcia gwiazdy, kamera, baner rundy.
	CRACK = table.freeze({
		ringStart = 2.3, -- średnica pierścienia zbliżania na starcie (× kółko)
		ringSpin = 120, -- °/s obrotu gradientu pierścienia
		popSeconds = 0.22, -- pojawienie punktu (skala Back)
		glowPulse = 3, -- Hz pulsu poświaty punktu
		leakWidth = 0.35, -- × promień: szerokość snopu światła z punktu (rośnie z fazą)
		leakLength = 0.5, -- × promień: jak daleko snop wychodzi ponad powierzchnię
		leakLight = 8, -- zasięg PointLight w punkcie
		burstSparks = table.freeze({ Perfect = 28, Good = 16, Miss = 0, Other = 10 }),
		burstShards = table.freeze({ Perfect = 6, Good = 3, Miss = 0, Other = 2 }),
		shardSpeed = 22, -- studs/s
		shardGravity = 60,
		shardSeconds = 0.9,
		flashRange = 12,
		flashSeconds = 0.25,
		perfectFov = 3, -- uderzenie FOV przy Perfect
		perfectFovSeconds = 0.18,
		-- Pęknięcia gwiazdy (widzą wszyscy): ścieżki odsłaniane wraz z utratą HP.
		crackPaths = bySize(5, 7, 9, 12, 14),
		crackSteps = table.freeze({ 3, 6 }), -- min/max odcinków w ścieżce
		crackStep = 0.22, -- × promień: długość odcinka
		crackWidth = 0.035, -- × promień (min. crackMinWidth)
		crackMinWidth = 0.15,
		crackJitter = 0.6, -- rad: losowe skręcanie ścieżki
		crackGrowSeconds = 0.35,
		crackFlash = 0.3, -- s rozjaśnienia pęknięć po obrażeniach
		innerLight = table.freeze({ 0.3, 1.8 }), -- jasność światła z wnętrza przy 0 i 100% obrażeń
		-- Kamera i ekran w trakcie rundy
		focusFar = 0.35, -- DepthOfField FarIntensity (rozmycie tła)
		focusMargin = 14, -- studs ostrości poza promieniem gwiazdy
		vignette = 0.35, -- przezroczystość winiety w rundzie (1 = brak)
		vignetteFlash = 0.15, -- przezroczystość winiety w błysku Perfect
		fadeSeconds = 0.4,
		shoulderOffset = Vector3.new(2.6, 0.8, 0), -- Humanoid.CameraOffset w rundzie: kamera zza ramienia, gwiazda nie chowa się za postacią
		swingBack = 0.08, -- s zamachu kilofem
		swingHit = 0.14, -- s uderzenia i powrotu
		swingAngle = 1.1, -- rad
		-- Baner rundy i combo
		bannerSeconds = 1.2,
		comboPitchStep = 0.035, -- PlaybackSpeed hitPerfect za każde trafienie w serii
		comboPitchMax = 1.45,
		comboIdleSeconds = 4, -- licznik combo znika po tylu sekundach bez trafień
		haptic = table.freeze({ Perfect = 0.6, Good = 0.35, Miss = 0.15, Crit = 1 }), -- siła wibracji pada
		hapticSeconds = 0.09,
	}),
})
