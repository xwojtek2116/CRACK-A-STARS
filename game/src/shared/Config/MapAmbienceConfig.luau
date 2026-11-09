--!strict
-- MapAmbienceConfig — klimat mapy po stronie klienta (T15): oświetlenie per biom, cząsteczki w powietrzu,
-- planety na niebie przesuwane za kamerą (bez paralaksy na dużej mapie).
-- Biomy = ćwiartki wg kąta atan2(z, x) jak w generatorze terenu T36 (Lava 0°, Frost 90°, Crystal 180°, Nebula 270°).

export type BiomeLook = {
	atmosphereColor: Color3,
	atmosphereDecay: Color3,
	density: number, -- Atmosphere.Density
	tint: Color3, -- ColorCorrection „BiomeTint”
	saturation: number,
	particleColor: Color3,
	particleTexture: string,
	particleRate: number, -- cząsteczki/s wokół kamery
	particleSize: NumberRange,
	particleSpeed: NumberRange,
	particleRise: number, -- przyspieszenie w górę (− = opada, np. śnieg)
}

local LOBBY_RADIUS = 430 -- bliżej środka: neutralny wygląd lobby (bez tintu i cząsteczek biomu)

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local BIOMES: { { id: string, angle: number, look: BiomeLook } } = {
	{
		id = "LavaFields",
		angle = 0,
		look = {
			atmosphereColor = Color3.fromRGB(160, 96, 120),
			atmosphereDecay = Color3.fromRGB(110, 40, 60),
			density = 0.24,
			tint = Color3.fromRGB(255, 232, 222),
			saturation = 0.25,
			particleColor = Color3.fromRGB(255, 130, 60),
			particleTexture = SPARK,
			particleRate = 14,
			particleSize = NumberRange.new(0.25, 0.5),
			particleSpeed = NumberRange.new(1, 3),
			particleRise = 3,
		},
	},
	{
		id = "FrostCrater",
		angle = 90,
		look = {
			atmosphereColor = Color3.fromRGB(150, 170, 220),
			atmosphereDecay = Color3.fromRGB(70, 90, 150),
			density = 0.26,
			tint = Color3.fromRGB(228, 240, 255),
			saturation = 0.1,
			particleColor = Color3.fromRGB(235, 245, 255),
			particleTexture = SPARK,
			particleRate = 26,
			particleSize = NumberRange.new(0.2, 0.4),
			particleSpeed = NumberRange.new(0.5, 1.5),
			particleRise = -4,
		},
	},
	{
		id = "CrystalCanyon",
		angle = 180,
		look = {
			atmosphereColor = Color3.fromRGB(110, 170, 190),
			atmosphereDecay = Color3.fromRGB(40, 100, 120),
			density = 0.22,
			tint = Color3.fromRGB(226, 255, 250),
			saturation = 0.3,
			particleColor = Color3.fromRGB(90, 255, 220),
			particleTexture = SPARK,
			particleRate = 12,
			particleSize = NumberRange.new(0.2, 0.45),
			particleSpeed = NumberRange.new(0.3, 1.2),
			particleRise = 0.6,
		},
	},
	{
		id = "NebulaPlateau",
		angle = 270,
		look = {
			atmosphereColor = Color3.fromRGB(170, 120, 220),
			atmosphereDecay = Color3.fromRGB(90, 50, 150),
			density = 0.24,
			tint = Color3.fromRGB(246, 232, 255),
			saturation = 0.3,
			particleColor = Color3.fromRGB(220, 140, 255),
			particleTexture = SPARK,
			particleRate = 14,
			particleSize = NumberRange.new(0.25, 0.55),
			particleSpeed = NumberRange.new(0.3, 1),
			particleRise = 1.2,
		},
	},
}

return table.freeze({
	LOBBY_RADIUS = LOBBY_RADIUS,
	BIOMES = BIOMES,
	UPDATE_INTERVAL = 0.25, -- s między sprawdzeniami biomu i pozycji kamery
	TWEEN_TIME = 2.5, -- s przejścia wyglądu między biomami
	PARTICLE_BOX = Vector3.new(90, 40, 90), -- obszar emisji wokół kamery
	PARTICLE_LIFETIME = NumberRange.new(4, 7),
	SKY_FOLLOW_STEP = 25, -- studs ruchu kamery, po których planety przesuwają się za nią
	SKY_SPIN_ATTRIBUTE = "SpinDegPerSec", -- atrybut planety (obrót wokół własnej osi)
})
