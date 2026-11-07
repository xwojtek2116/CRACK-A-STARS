--!strict
-- PlayerSchema — szablon danych gracza i migracje między wersjami schematu.
-- Czysty moduł (bez usług Roblox poza Config), żeby dało się go testować w izolacji.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataConfig = require(Shared.Config.DataConfig)
local Economy = require(Shared.Config.Data.Economy) :: any
local Types = require(Shared.Types)

type PlayerData = Types.PlayerData

-- Krok migracji: dostaje dane w wersji (target - 1) i zmienia je do wersji target (w miejscu).
export type Migration = (data: { [string]: any }) -> ()

-- MIGRATIONS[n] przenosi dane z wersji n-1 do n. Nowe pola dokłada też Profile:Reconcile().
local MIGRATIONS: { [number]: Migration } = {}

local PlayerSchema = {}

function PlayerSchema.template(): PlayerData
	return {
		schemaVersion = DataConfig.SCHEMA_VERSION,
		cash = Economy.startingCash,
		rebirths = 0,
		tools = { [DataConfig.STARTING_TOOL] = true },
		equippedTool = DataConfig.STARTING_TOOL,
		vehicles = {},
		jetpackLevel = DataConfig.STARTING_JETPACK,
		items = {},
		slots = Economy.base.startSlots,
		index = {},
		pity = {},
		boosts = {},
		stats = {},
		daily = { lastClaim = 0, streak = 0 },
		codesUsed = {},
		tutorialStep = 0,
		settings = {},
		purchases = {},
		lastOnline = 0,
	}
end

-- Podnosi dane do targetVersion (domyślnie SCHEMA_VERSION), krok po kroku. Zwraca (ok, wersja startowa).
-- Dane z przyszłej wersji (np. po rollbacku serwera) zostają nietknięte.
function PlayerSchema.migrate(
	data: { [string]: any },
	targetVersion: number?,
	migrations: { [number]: Migration }?
): (boolean, number)
	local target = targetVersion or DataConfig.SCHEMA_VERSION
	local steps = migrations or MIGRATIONS
	local fromVersion = if type(data.schemaVersion) == "number" then data.schemaVersion else 1

	if fromVersion > target then
		return false, fromVersion
	end

	for version = fromVersion + 1, target do
		local step = steps[version]
		if step then
			step(data)
		end
		data.schemaVersion = version
	end
	data.schemaVersion = target
	return true, fromVersion
end

return PlayerSchema
