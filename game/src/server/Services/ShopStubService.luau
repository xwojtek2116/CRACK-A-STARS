--!strict
-- ShopStubService — TYMCZASOWE odpowiedzi na prośby z ekranów T14, zanim powstaną właściwe serwisy:
--   BuyTool / EquipTool → ToolService (T09), BuyVehicle / BuyJetpack → VehicleService (T10),
--   Rebirth → RebirthService (T19).
-- Remote ma jeden handler: task, który robi właściwy serwis, usuwa swoją nazwę z STUBBED
-- (a gdy lista będzie pusta — cały plik i wpis w init.server.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local STUBBED: { Remotes.RemoteName } = { "BuyTool", "EquipTool", "BuyVehicle", "BuyJetpack", "Rebirth" }

local ShopStubService = {}

function ShopStubService.Init()
	for _, name in STUBBED do
		Remotes.onInvoke(name, function()
			return { ok = false, reason = "ComingSoon" }
		end)
	end
end

return ShopStubService
