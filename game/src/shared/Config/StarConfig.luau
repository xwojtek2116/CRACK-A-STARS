--!strict
-- StarConfig — typowany dostęp do Stars.json (rozmiary, harmonogram, lądowanie, uderzenie) i Themes.json (rodzaje).
-- Liczby są tylko w JSON-ach; tu same typy i pomocnicze wzory (waga rodzaju, nazwa gwiazdy, kolor).

local RunService = game:GetService("RunService")

local Data = script.Parent.Data
local Stars = require(Data.Stars) :: any
local Themes = require(Data.Themes) :: any

export type SizeClass = {
	displayName: string,
	size: number,
	hp: number,
	intervalMin: number,
	intervalMax: number,
	lifetime: number,
	lootRolls: number,
	luck: number,
	minShare: number,
	zones: number,
	warning: number,
	rareTypeBoost: number,
	event: boolean,
}

export type Theme = {
	displayName: string,
	incomeMult: number,
	weight: number,
	color: string,
	glow: string,
	shell: string,
	zone: string,
	eventOnly: boolean,
}

export type Landing = {
	minRadius: number,
	maxRadius: number,
	plotClearance: number,
	starSpacing: number,
	maxSlopeDeg: number,
	maxTries: number,
	biomeTypeBoost: number,
	rejectMaterials: { string },
}

export type Schedule = {
	maxActive: number,
	firstDropSize: string,
	firstDropDelay: number,
	retryDelay: number,
	dyingSeconds: number,
}

export type Fall = {
	startHeight: number,
	angleMinDeg: number,
	angleMaxDeg: number,
	accelPower: number,
}

export type Impact = {
	embedDepth: number,
	craterRadiusMult: number,
	digTerrainFromSize: string,
	digBowlDepth: number,
	trailLengthMult: number,
	scarSeconds: number,
	scarFadeSeconds: number,
	maxScars: number,
	smokeSeconds: number,
	knockbackRadiusMult: number,
	knockbackSpeed: number,
	knockbackUp: number,
	knockbackRagdollSeconds: number,
	rimChunks: { [string]: number },
}

local SIZE_ORDER: { string } = Stars.order
local CLASSES: { [string]: SizeClass } = Stars.classes
local THEME_ORDER: { string } = Themes.order
local THEMES: { [string]: Theme } = Themes.themes

-- Tryb deweloperski: tylko w Studio (Play). Skaluje interwały spadków i czas śladów.
local IS_DEV = RunService:IsStudio()
local TIME_SCALE: number = if IS_DEV then Stars.dev.studioTimeScale else 1

local sizeIndex: { [string]: number } = {}
for index, sizeId in SIZE_ORDER do
	sizeIndex[sizeId] = index
end

local themeIndex: { [string]: number } = {}
for index, typeId in THEME_ORDER do
	themeIndex[typeId] = index
end

local StarConfig = {
	SIZE_ORDER = SIZE_ORDER,
	CLASSES = CLASSES,
	THEME_ORDER = THEME_ORDER,
	THEMES = THEMES,
	LANDING = Stars.landing :: Landing,
	SCHEDULE = Stars.schedule :: Schedule,
	FALL = Stars.fall :: Fall,
	IMPACT = Stars.impact :: Impact,
	IS_DEV = IS_DEV,
	TIME_SCALE = TIME_SCALE,
}

-- Indeks rozmiaru w `order` (Small = 1). 0 dla nieznanego.
function StarConfig.sizeRank(sizeId: string): number
	return sizeIndex[sizeId] or 0
end

-- Waga losowania rodzaju dla rozmiaru: weight × (1 + (rareTypeBoost − 1) × indeks/11), indeks od 0.
-- Większe gwiazdy częściej są rzadkimi rodzajami (Stars.json → notes).
function StarConfig.typeWeight(typeId: string, sizeId: string): number
	local theme = THEMES[typeId]
	local class = CLASSES[sizeId]
	local index = themeIndex[typeId]
	if not theme or not class or not index then
		return 0
	end
	local last = math.max(#THEME_ORDER - 1, 1)
	return theme.weight * (1 + (class.rareTypeBoost - 1) * (index - 1) / last)
end

-- Nazwa w grze: "<Rozmiar> <displayName rodzaju>", np. "Huge Lava Star".
function StarConfig.displayName(sizeId: string, typeId: string): string
	local class = CLASSES[sizeId]
	local theme = THEMES[typeId]
	local sizeName = if class then class.displayName else sizeId
	local typeName = if theme then theme.displayName else typeId
	return `{sizeName} {typeName}`
end

function StarConfig.color(typeId: string): Color3
	local theme = THEMES[typeId]
	return if theme then Color3.fromHex(theme.color) else Color3.new(1, 1, 1)
end

function StarConfig.glow(typeId: string): Color3
	local theme = THEMES[typeId]
	return if theme then Color3.fromHex(theme.glow) else Color3.new(1, 1, 1)
end

-- Promień krateru w studs (size/2 × craterRadiusMult).
function StarConfig.craterRadius(sizeId: string): number
	local class = CLASSES[sizeId]
	return if class then class.size * 0.5 * StarConfig.IMPACT.craterRadiusMult else 0
end

-- Promień fali uderzeniowej (odrzut graczy).
function StarConfig.knockbackRadius(sizeId: string): number
	return StarConfig.craterRadius(sizeId) * StarConfig.IMPACT.knockbackRadiusMult
end

-- Czy rozmiar kopie prawdziwy teren (od `digTerrainFromSize` w górę).
function StarConfig.digsTerrain(sizeId: string): boolean
	return StarConfig.sizeRank(sizeId) >= StarConfig.sizeRank(StarConfig.IMPACT.digTerrainFromSize)
end

-- Pozycja gwiazdy w locie dla postępu 0..1 (wspólny wzór serwera i klienta).
function StarConfig.fallPosition(startPos: Vector3, impactPos: Vector3, alpha: number): Vector3
	local eased = math.clamp(alpha, 0, 1) ^ StarConfig.FALL.accelPower
	return startPos:Lerp(impactPos, eased)
end

return table.freeze(StarConfig)
