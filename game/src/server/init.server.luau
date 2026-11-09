--!strict
-- Punkt startowy serwera. Ładuje serwisy z listy (kolejność = zależności),
-- woła Init() wszystkich po kolei, potem Start() każdego w task.spawn. Błąd jednego serwisu nie zatrzymuje reszty.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameInfo = require(Shared.GameInfo)
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)

type Service = {
	Init: (() -> ())?,
	Start: (() -> ())?,
}

-- Kolejność ładowania. Nowy serwis dopisz we właściwym miejscu.
local SERVICES = {
	"DataService",
	"EconomyService",
	"PlotService",
	"BaseService",
	"SellService",
	"StarService",
	"CrackService",
	"LootService",
	"LobbyService",
	"ShopStubService", -- tymczasowy (T14): usuwają go T09/T10/T19
}

local log = Logger.new("Boot")
local servicesFolder = script:WaitForChild("Services")

log:info(`{GameInfo.NAME} {GameInfo.VERSION} — start serwera`)
Remotes.setup()

local loaded: { { name: string, module: Service } } = {}

for _, name in SERVICES do
	local moduleScript = servicesFolder:FindFirstChild(name)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		log:error(`Brak modułu {name}`)
		continue
	end
	local ok, result = pcall(require, moduleScript)
	if ok then
		table.insert(loaded, { name = name, module = result :: Service })
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

log:info(`Serwisy gotowe: {#loaded}/{#SERVICES}`)
