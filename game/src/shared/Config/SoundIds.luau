--!strict
-- SoundIds — własne dźwięki spadku gwiazdy (T38). Źródło: `python tools/sfx_gen.py` → art/audio/stars/<plik>.wav,
-- upload przez Open Cloud (Assets API). Wszystkie mono, pik -1 dBFS; głośność i zasięg 3D ustawia się tutaj.
-- rolloff = { min, max } w studs (InverseTapered); brak = dźwięk 2D (interfejs, cała mapa).

export type SoundDef = {
	id: string,
	volume: number,
	rolloff: { number }?,
	looped: boolean?,
	pitchVariance: number?, -- ± losowa zmiana PlaybackSpeed, żeby powtórki nie brzmiały identycznie
}

local SOUNDS: { [string]: SoundDef } = {
	-- Ogłoszenie i odliczanie
	announceSting = { id = "rbxassetid://96602880878912", volume = 0.55 }, -- announce_sting.wav (2D)
	countdownTick = { id = "rbxassetid://100777689307095", volume = 0.5, rolloff = { 60, 500 } }, -- countdown_tick.wav
	thunderFar = { id = "rbxassetid://70492911375618", volume = 0.6 }, -- thunder_far.wav (2D, cała mapa, od Large)
	-- Wyrwa
	riftOpen = { id = "rbxassetid://72732776031328", volume = 1.0, rolloff = { 250, 3200 }, pitchVariance = 0.06 }, -- rift_open.wav
	riftLoop = { id = "rbxassetid://96344650148614", volume = 0.55, rolloff = { 150, 1800 }, looped = true }, -- rift_loop.wav
	riftClose = { id = "rbxassetid://96271113220482", volume = 0.8, rolloff = { 200, 2600 } }, -- rift_close.wav
	-- Lot
	emergeRoar = { id = "rbxassetid://99268682064718", volume = 0.9, rolloff = { 200, 2400 }, pitchVariance = 0.08 }, -- emerge_roar.wav
	fallLoop = { id = "rbxassetid://121895649274523", volume = 0.8, rolloff = { 60, 1400 }, looped = true }, -- fall_loop.wav
	flyby = { id = "rbxassetid://126922429177736", volume = 0.9, rolloff = { 40, 500 }, pitchVariance = 0.1 }, -- flyby.wav
	sonicBoom = { id = "rbxassetid://104044549133790", volume = 0.9, rolloff = { 200, 2500 }, pitchVariance = 0.08 }, -- sonic_boom.wav
	-- Uderzenie (wariant wg rozmiaru)
	impactSmall = { id = "rbxassetid://78142362817821", volume = 0.9, rolloff = { 40, 900 }, pitchVariance = 0.06 }, -- impact_s.wav
	impactMedium = { id = "rbxassetid://80347070662937", volume = 1.0, rolloff = { 60, 1400 }, pitchVariance = 0.06 }, -- impact_m.wav
	impactLarge = { id = "rbxassetid://73864226634941", volume = 1.0, rolloff = { 90, 2200 }, pitchVariance = 0.05 }, -- impact_l.wav
	impactHuge = { id = "rbxassetid://99704051121925", volume = 1.0, rolloff = { 140, 3500 }, pitchVariance = 0.04 }, -- impact_xl.wav
	shockwave = { id = "rbxassetid://89818166566332", volume = 0.8, rolloff = { 50, 900 } }, -- shockwave.wav
	debrisRain = { id = "rbxassetid://127087514578677", volume = 0.7, rolloff = { 30, 400 }, pitchVariance = 0.08 }, -- debris_rain.wav
	-- Leżąca gwiazda i koniec
	starHum = { id = "rbxassetid://91026232978549", volume = 0.45, rolloff = { 12, 160 }, looped = true }, -- star_hum.wav
	craterSizzle = { id = "rbxassetid://125347553197965", volume = 0.35, rolloff = { 10, 110 }, looped = true }, -- crater_sizzle.wav
	starCrack = { id = "rbxassetid://119139469957662", volume = 1.0, rolloff = { 40, 700 } }, -- star_crack.wav
	starFade = { id = "rbxassetid://133818079410745", volume = 0.8, rolloff = { 30, 400 } }, -- star_fade.wav
	-- T39: warstwy i muzyka
	skyCrack = { id = "rbxassetid://121621480644788", volume = 0.9, rolloff = { 250, 3200 }, pitchVariance = 0.06 }, -- sky_crack.wav
	impactTail = { id = "rbxassetid://117390235909618", volume = 0.8, rolloff = { 120, 3000 } }, -- impact_tail.wav
	craterCool = { id = "rbxassetid://107753704892417", volume = 0.5, rolloff = { 15, 160 } }, -- crater_cool.wav
	beaconHum = { id = "rbxassetid://129191615321540", volume = 0.35, rolloff = { 20, 260 }, looped = true }, -- beacon_hum.wav
	musicTension = { id = "rbxassetid://90038145810674", volume = 0.4, looped = true }, -- music_tension.wav (2D, pętla 16 s)
	musicImpact = { id = "rbxassetid://74551511793377", volume = 0.6 }, -- music_impact.wav (2D stinger)
	-- T41: muzyka w tle całej rozgrywki (tools/music_gen.py → art/audio/music/), 2D, pętla 96 s
	musicAmbient = { id = "rbxassetid://90257014702117", volume = 0.15, looped = true }, -- music_ambient.wav
	-- Interfejs (T13, tools/ui_sfx_gen.py → art/audio/ui/), 2D
	uiClick = { id = "rbxassetid://71710572047303", volume = 0.5, pitchVariance = 0.04 }, -- ui_click.wav
	uiPop = { id = "rbxassetid://75915657998732", volume = 0.5 }, -- ui_pop.wav (otwarcie okna)
	uiClose = { id = "rbxassetid://85310015334687", volume = 0.45 }, -- ui_close.wav
	uiCoin = { id = "rbxassetid://90231723581600", volume = 0.45, pitchVariance = 0.06 }, -- ui_coin.wav
	-- Minigra rozbijania (T06 v2, tools/crack_sfx_gen.py → art/audio/crack/), 2D — tylko u gracza, który rozbija
	crackSpawn = { id = "rbxassetid://105993902744220", volume = 0.3, pitchVariance = 0.08 }, -- crack_spawn.wav
	hitPerfect = { id = "rbxassetid://111670019299420", volume = 0.6 }, -- hit_perfect.wav (wysokość rośnie z serią)
	hitGood = { id = "rbxassetid://123923203042598", volume = 0.55, pitchVariance = 0.06 }, -- hit_good.wav
	hitMiss = { id = "rbxassetid://116122785777867", volume = 0.5, pitchVariance = 0.06 }, -- hit_miss.wav
	hitWeak = { id = "rbxassetid://88460091463079", volume = 0.6 }, -- hit_weak.wav
	hitCrit = { id = "rbxassetid://76102274344653", volume = 0.8, rolloff = { 20, 260 } }, -- hit_crit.wav (3D, słyszą inni)
	roundPerfect = { id = "rbxassetid://72160258473855", volume = 0.5 }, -- round_perfect.wav
	roundEnd = { id = "rbxassetid://130704310366274", volume = 0.3 }, -- round_end.wav
	-- Narzędzia (T09, tools/tool_sfx_gen.py → art/audio/tools/). Zamachy 3D przy narzędziu, słyszą inni.
	swingStone = { id = "rbxassetid://138814038252293", volume = 0.5, rolloff = { 8, 120 }, pitchVariance = 0.08 },
	swingMetal = { id = "rbxassetid://137646814951668", volume = 0.5, rolloff = { 8, 120 }, pitchVariance = 0.08 },
	swingCrystal = { id = "rbxassetid://72363291579877", volume = 0.5, rolloff = { 8, 130 }, pitchVariance = 0.06 },
	swingPlasma = { id = "rbxassetid://108705179473948", volume = 0.5, rolloff = { 8, 130 }, pitchVariance = 0.05 },
	swingLaser = { id = "rbxassetid://126789616200488", volume = 0.55, rolloff = { 8, 140 }, pitchVariance = 0.05 },
	swingGravity = { id = "rbxassetid://87431207171072", volume = 0.6, rolloff = { 10, 160 }, pitchVariance = 0.05 },
	swingCannon = { id = "rbxassetid://116784056364838", volume = 0.6, rolloff = { 12, 220 }, pitchVariance = 0.05 },
	swingLegend = { id = "rbxassetid://134460698555237", volume = 0.6, rolloff = { 12, 200 }, pitchVariance = 0.04 },
	toolEquip = { id = "rbxassetid://130240915563874", volume = 0.45, pitchVariance = 0.05 }, -- tool_equip.wav (2D)
	toolUnlock = { id = "rbxassetid://92666381671661", volume = 0.6 }, -- tool_unlock.wav (2D, ekran NEW TOOL)
}

-- Dźwięk uderzenia dla rozmiaru gwiazdy.
local IMPACT_BY_SIZE: { [string]: string } = {
	Small = "impactSmall",
	Medium = "impactMedium",
	Large = "impactLarge",
	Huge = "impactHuge",
	Supernova = "impactHuge",
}

-- Muzyka w tle (T41): startuje po wczytaniu danych, przycisza się, gdy gra inna muzyka (motyw napięcia, stinger).
local BACKGROUND_MUSIC = table.freeze({
	name = "musicAmbient",
	fadeIn = 4, -- s narastania po wejściu do gry
	duckTo = 0.2, -- mnożnik głośności, gdy gra inna muzyka
	duckTime = 0.8, -- s przyciszenia
	restoreTime = 3, -- s powrotu do pełnej głośności
})

return table.freeze({
	SOUNDS = table.freeze(SOUNDS),
	BACKGROUND_MUSIC = BACKGROUND_MUSIC,
	IMPACT_BY_SIZE = table.freeze(IMPACT_BY_SIZE),
})
