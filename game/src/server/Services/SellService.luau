--!strict
-- SellService — sprzedaż łupu (T08, decyzja 2026-11-08): cena = $/s przedmiotu (z mutacją) × sell.incomeSeconds.
--   • SellItem(uid, confirm?) — przy Sell Station w lobby albo (przedmiot z postumentu) przy własnym postumencie;
--     od Legendary wzwyż wymaga confirm = true (okno potwierdzenia u klienta),
--   • SellBelow(rarity) — cały ekwipunek poniżej rzadkości, bez mutacji i bez postumentów, przy Sell Station.
-- Wszystko liczy i waliduje serwer; kasa i przedmioty zmieniają się w jednym DataService.update.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseConfig = require(Shared.Config.BaseConfig)
local BaseMath = require(Shared.BaseMath)
local LootConfig = require(Shared.Config.LootConfig)
local LootMath = require(Shared.LootMath)
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

type PlayerData = Types.PlayerData
type Result = { ok: boolean, reason: string?, [string]: any }

local log = Logger.new("SellService")

local stationPoints: { Vector3 } = {}

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function nearStation(position: Vector3): boolean
	for _, point in stationPoints do
		if (point - position).Magnitude <= BaseMath.STATION_DISTANCE then
			return true
		end
	end
	return false
end

-- Gracz stoi przy własnym postumencie z tym slotem.
local function nearPedestal(player: Player, position: Vector3, slot: number): boolean
	local plot = PlotService.getPlot(player)
	local folder = plot and plot:FindFirstChild(BaseConfig.PEDESTALS_FOLDER)
	local pedestal = folder and folder:FindFirstChild(`Pedestal_{slot}`)
	if not pedestal or not pedestal:IsA("Model") then
		return false
	end
	return (pedestal:GetPivot().Position - position).Magnitude <= BaseMath.PEDESTAL_DISTANCE
end

local function collectStations()
	table.clear(stationPoints)
	for _, station in CollectionService:GetTagged(BaseConfig.STATION_TAG) do
		if station:GetAttribute("Station") ~= BaseConfig.SELL_STATION then
			continue
		end
		local anchor = station:FindFirstChild("PromptAnchor", true)
		if anchor and anchor:IsA("BasePart") then
			table.insert(stationPoints, anchor.Position)
		elseif station:IsA("Model") then
			table.insert(stationPoints, station:GetPivot().Position)
		end
	end
	if #stationPoints == 0 then
		log:warn("Brak Sell Station (tag LobbyStation, Station = SellStation) — sprzedaż tylko z postumentów")
	end
end

local function sellItem(player: Player, uid: string, confirm: boolean?): Result
	local position = rootPosition(player)
	if not position then
		return { ok = false, reason = "NoCharacter" }
	end
	local result: Result = { ok = false, reason = "NoData" }
	DataService.update(player, function(data: PlayerData)
		local item = data.items[uid]
		if not item then
			result = { ok = false, reason = "NoItem" }
			return
		end
		local capacity = LootMath.slotCapacity(data.slots, data.purchases)
		local placed = BaseMath.isPlaced(item :: any, capacity)
		local allowed = nearStation(position) or (placed and nearPedestal(player, position, item.slot :: number))
		if not allowed then
			result = { ok = false, reason = "TooFar" }
			return
		end
		if BaseMath.needsConfirm(item.itemId) and confirm ~= true then
			result = { ok = false, reason = "ConfirmRequired" }
			return
		end
		local price = BaseMath.sellPrice(item :: any)
		data.items[uid] = nil
		data.cash += price
		data.stats.itemsSold = (data.stats.itemsSold or 0) + 1
		data.stats.sellEarned = (data.stats.sellEarned or 0) + price
		result = { ok = true, price = price, itemId = item.itemId }
	end)
	if result.ok then
		log:info(`{player.Name}: sprzedał {result.itemId} za {result.price}`)
	end
	return result
end

local function sellBelow(player: Player, rarity: string): Result
	local position = rootPosition(player)
	if not position or not nearStation(position) then
		return { ok = false, reason = "TooFar" }
	end
	local limitRank = LootConfig.rarityRank(rarity)
	local result: Result = { ok = false, reason = "NoData" }
	DataService.update(player, function(data: PlayerData)
		local capacity = LootMath.slotCapacity(data.slots, data.purchases)
		local count, total = 0, 0
		for uid, item in data.items do
			if BaseMath.isPlaced(item :: any, capacity) or item.mutation ~= "None" then
				continue
			end
			if LootConfig.rarityRank(BaseMath.rarity(item.itemId)) >= limitRank then
				continue
			end
			total += BaseMath.sellPrice(item :: any)
			count += 1
			data.items[uid] = nil
		end
		if count == 0 then
			result = { ok = false, reason = "Nothing" }
			return
		end
		data.cash += total
		data.stats.itemsSold = (data.stats.itemsSold or 0) + count
		data.stats.sellEarned = (data.stats.sellEarned or 0) + total
		result = { ok = true, count = count, price = total }
	end)
	if result.ok then
		log:info(`{player.Name}: sprzedał {result.count} przedmiotów poniżej {rarity} za {result.price}`)
	end
	return result
end

local SellService = {}

function SellService.Init() end

function SellService.Start()
	collectStations()
	CollectionService:GetInstanceAddedSignal(BaseConfig.STATION_TAG):Connect(collectStations)
	Remotes.onInvoke("SellItem", sellItem)
	Remotes.onInvoke("SellBelow", sellBelow)
end

return SellService
