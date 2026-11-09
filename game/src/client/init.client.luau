--!strict
-- Punkt startowy klienta. Ładuje kontrolery z listy (kolejność = zależności),
-- woła Init() wszystkich po kolei, potem Start() każdego w task.spawn. Błąd jednego kontrolera nie zatrzymuje reszty.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameInfo = require(Shared.GameInfo)
local Logger = require(Shared.Logger)

type Controller = {
	Init: (() -> ())?,
	Start: (() -> ())?,
}

-- Kolejność ładowania. Nowy kontroler dopisz we właściwym miejscu.
local CONTROLLERS = {
	"StateController",
	"SoundController",
	"CinematicController",
	"StarFxController",
	"ToolFxController",
	"CrackController",
	"LootController",
	"BaseController",
	"UIController",
}

local log = Logger.new("Boot")
local controllersFolder = script:WaitForChild("Controllers")

log:info(`{GameInfo.NAME} {GameInfo.VERSION} — start klienta`)

local loaded: { { name: string, module: Controller } } = {}

for _, name in CONTROLLERS do
	local moduleScript = controllersFolder:WaitForChild(name, 10)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		log:error(`Brak modułu {name}`)
		continue
	end
	local ok, result = pcall(require, moduleScript)
	if ok then
		table.insert(loaded, { name = name, module = result :: Controller })
	else
		log:error(`require {name}: {result}`)
	end
end

for _, entry in loaded do
	local init = entry.module.Init
	if init then
		local startedAt = os.clock()
		local ok, err = pcall(init)
		local ms = (os.clock() - startedAt) * 1000
		if ok then
			log:info(`Init {entry.name} {string.format("%.2f", ms)} ms`)
		else
			log:error(`Init {entry.name}: {err}`)
		end
	end
end

for _, entry in loaded do
	local start = entry.module.Start
	if start then
		task.spawn(function()
			local startedAt = os.clock()
			local ok, err = pcall(start)
			local ms = (os.clock() - startedAt) * 1000
			if ok then
				log:info(`Start {entry.name} {string.format("%.2f", ms)} ms`)
			else
				log:error(`Start {entry.name}: {err}`)
			end
		end)
	end
end

log:info(`Kontrolery gotowe: {#loaded}/{#CONTROLLERS}`)
