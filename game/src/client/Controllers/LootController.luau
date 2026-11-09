--!strict
-- LootController — łup z gwiazd po stronie klienta (T07): karta łupu po własnym rozbiciu (LootDrop)
-- i ogłoszenia rzadkiego łupu innych graczy (Announcement kind = "Loot"). Tylko pokazuje — losuje serwer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LootConfig = require(Shared.Config.LootConfig)
local Remotes = require(Shared.Remotes)

local UI = script.Parent.Parent.UI
local Announce = require(UI.Loot.Announce)
local Reveal = require(UI.Loot.Reveal)

local LootController = {}

function LootController.Init() end

function LootController.Start()
	Remotes.connect("LootDrop", function(payload: Reveal.Payload)
		if type(payload) ~= "table" or type(payload.drops) ~= "table" then
			return
		end
		task.delay(LootConfig.REVEAL.delay, Reveal.show, payload)
	end)
	Remotes.connect("Announcement", function(data: any)
		if type(data) == "table" and data.kind == "Loot" then
			-- Po karcie łupu u zdobywcy, żeby baner nie wyprzedził odkrycia.
			task.delay(LootConfig.REVEAL.delay, Announce.handle, data)
		end
	end)
end

return LootController
