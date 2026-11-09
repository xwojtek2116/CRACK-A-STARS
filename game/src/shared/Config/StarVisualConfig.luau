--!strict
-- StarVisualConfig — stany i animacje „żyjących” gwiazd v2 (T40, prototyp: Toxic Star Lab).
-- Odległości w jednostkach modelu (1 = szerokość skorupy / ~2,4; StarVisual mnoży przez StudsPerUnit), czasy w s.
-- Stan = zestaw parametrów pozy; przejście między stanami to lerp z prędkością BLEND_SPEED.

export type Pose = {
	energy: number, -- jasność Neon i światła (0..1.5)
	pulseRate: number, -- Hz pulsu rdzenia
	pulseAmp: number,
	debrisSpeed: number, -- mnożnik prędkości orbit gruzu
	debrisRadius: number,
	debrisLift: number,
	debrisPull: number, -- 0..1 ściąganie gruzu do rdzenia
	debrisFall: number, -- 0..1 gruz leży na dnie krateru
	explode: number, -- rozlot segmentów skorupy i kryształów
	shake: number,
	smoke: number, -- mnożniki emiterów
	sparks: number,
	spores: number,
	drops: number,
	desat: number, -- 0..1 wygaszenie kolorów
	broken: number, -- 0..1 próg znikania grup kryształów (wg rangi)
	flicker: number,
}

local DEFAULT: Pose = {
	energy = 0.85,
	pulseRate = 0.9,
	pulseAmp = 0.35,
	debrisSpeed = 1,
	debrisRadius = 1,
	debrisLift = 0,
	debrisPull = 0,
	debrisFall = 0,
	explode = 0,
	shake = 0,
	smoke = 0.05,
	sparks = 0.4,
	spores = 0.8,
	drops = 1,
	desat = 0,
	broken = 0,
	flicker = 0,
}

local function state(overrides: { [string]: number }): Pose
	local pose = table.clone(DEFAULT) :: any
	for key, value in overrides do
		pose[key] = value
	end
	return table.freeze(pose) :: Pose
end

return table.freeze({
	DEFAULT = table.freeze(DEFAULT),
	STATES = table.freeze({
		Dormant = state({
			energy = 0.2,
			pulseRate = 0.35,
			pulseAmp = 0.25,
			debrisSpeed = 0.35,
			debrisRadius = 0.95,
			debrisLift = -0.1,
			smoke = 0,
			sparks = 0,
			spores = 0.15,
			drops = 0.2,
			desat = 0.35,
		}),
		Active = state({}),
		Charging = state({
			energy = 1.25,
			pulseRate = 2.6,
			pulseAmp = 0.5,
			debrisSpeed = 3,
			debrisLift = 0.15,
			debrisPull = 0.45,
			shake = 0.02,
			smoke = 0.1,
			sparks = 1.1,
			spores = 1.5,
			drops = 1.3,
		}),
		Burst = state({
			energy = 1.45,
			pulseRate = 2,
			pulseAmp = 0.4,
			debrisSpeed = 2,
			debrisRadius = 1.3,
			debrisLift = 0.25,
			explode = 0.18,
			smoke = 0.55,
			sparks = 1.5,
			spores = 2,
			drops = 1.5,
		}),
		Damaged = state({
			energy = 0.55,
			pulseRate = 1.5,
			pulseAmp = 0.7,
			debrisSpeed = 0.8,
			debrisRadius = 1.05,
			explode = 0.07,
			shake = 0.006,
			smoke = 0.35,
			sparks = 0.7,
			spores = 0.5,
			drops = 0.7,
			desat = 0.15,
			broken = 0.35,
			flicker = 0.55,
		}),
		Depleted = state({
			energy = 0.05,
			pulseRate = 0.5,
			pulseAmp = 0.6,
			debrisSpeed = 0,
			debrisFall = 1,
			explode = 0.04,
			smoke = 0.45,
			sparks = 0,
			spores = 0,
			drops = 0,
			desat = 0.85,
			broken = 0.5,
		}),
	}),
	ANIM_SECONDS = table.freeze({
		CorePulse = 1.2,
		CrystalPulse = 1.6,
		CrystalGrowth = 1.4,
		EnergyCharge = 2.5,
		ToxicBurst = 1.8,
		ImpactLanding = 1.4,
		DamageReaction = 0.6,
		Collapse = 2.2,
	}),
	BLEND_SPEED = 2.5, -- 1/s
	CHARGING_SECONDS = 3, -- po ostatniej zmianie Hp gwiazda jest w stanie Charging
	DAMAGED_HP = 0.4, -- Hp/MaxHp poniżej → Damaged
	DORMANT_DISTANCE = 260, -- studs od kamery → Dormant i rzadsze odświeżanie
	FAR_UPDATE_SECONDS = 0.1,
	DEBRIS_COUNT = table.freeze({ Small = 4, Medium = 6, Large = 8, Huge = 10, Supernova = 12 }),
	DEBRIS_ORBIT = table.freeze({ radius = { 1.9, 3.0 }, height = { 0.6, 3.4 }, speed = { 0.12, 0.35 } }),
	EXPLODE_DISTANCE = 1.8, -- jednostki modelu przy explode = 1
	FADE_SECONDS = 0.6, -- zanik części przed usunięciem modelu przez serwer
	-- Kolejność znikania grup kryształów w Damaged/Depleted (niższa = znika pierwsza).
	CRYSTAL_RANK = table.freeze({
		CrystalG01 = 0.1,
		CrystalG02 = 0.2,
		CrystalA = 0.3,
		CrystalB = 0.5,
		CrystalG03 = 0.62,
		CrystalG04 = 0.78,
		CrystalC = 0.95,
	}),
	GROWING = table.freeze({
		CrystalA = true,
		CrystalB = true,
		CrystalG01 = true,
		CrystalG02 = true,
		CrystalG03 = true,
		CrystalG04 = true,
	}),
	EMITTERS = table.freeze({ spores = 6, sparks = 5, smoke = 2.5, drops = 1.5 }), -- Rate przy mnożniku 1 (Large, przed jakością)
	DEAD_COLOR = Color3.fromRGB(52, 58, 48),
})
