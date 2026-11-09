--!strict
-- BaseService — baza gracza na działce (T08):
--   • postumenty: siatka od BuildOrigin działki (BaseConfig.GRID), tyle ile pojemność (sloty + gamepassy),
--     na każdym model przedmiotu (ServerStorage.Items/<itemId>) albo placeholder w kolorze motywu,
--     pierścień w kolorze rzadkości, światło; atrybuty dla klienta (Slot, ItemUid, ItemName, Rarity, Mutation,
--     Income). Obrót, poświata, tabliczki i popupy „+$X” robi klient (BaseController),
--   • hologram następnego postumentu z ceną (atrybut Price) — klient pokazuje prompt „Buy”,
--   • akcje gracza (Remotes): PlaceItem, RemoveItem, AutoPlace, BuySlot — wszystko liczy serwer,
--   • atrybuty gracza BaseCapacity, NextSlotPrice (−1 = maksimum) i IncomeMult dla UI.
-- Postumenty przebudowują się różnicowo po każdej zmianie items/slots/rebirths.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseConfig = require(Shared.Config.BaseConfig)
local BaseMath = require(Shared.BaseMath)
local LootConfig = require(Shared.Config.LootConfig)
local LootMath = require(Shared.LootMath)
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)
local StarConfig = require(Shared.Config.StarConfig)
local Types = require(Shared.Types)
local VfxIds = require(Shared.Config.VfxIds) :: any

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

type PlayerData = Types.PlayerData
type Result = { ok: boolean, reason: string?, [string]: any }

local GRID = BaseConfig.GRID
local CELLS = GRID.COLUMNS * GRID.ROWS

local log = Logger.new("BaseService")

local BaseService = {}

-- ---------------------------------------------------------------- modele

local function assetsFolder(): Instance?
	return ServerStorage:FindFirstChild(BaseConfig.ASSETS_FOLDER)
end

local function setPartDefaults(model: Instance, collide: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = collide
			part.CanTouch = false
			if not collide then
				part.CanQuery = false
			end
		end
	end
end

-- Postument z części, gdy w ServerStorage.BaseAssets nie ma modelu (Studio bez assetów, testy).
-- Korzeń bez obrotu (Root, pivot u dołu) — cylindry obrócone są tylko dekoracją.
local function fallbackPedestal(): Model
	local model = Instance.new("Model")
	model.Name = "Pedestal"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(6.4, 0.2, 6.4)
	root.CFrame = CFrame.new(0, 0.1, 0)
	root.Transparency = 1
	root.Parent = model
	local function cylinder(name: string, diameter: number, height: number, y: number, color: Color3, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(height, diameter, diameter)
		part.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
		part.Color = color
		part.Material = material
		part.Parent = model
		return part
	end
	cylinder("Base", 6.4, 1.2, 0.6, Color3.fromHex("#2A2440"), Enum.Material.Slate)
	cylinder("Column", 4.2, 2.4, 2.4, Color3.fromHex("#3A3358"), Enum.Material.Slate)
	cylinder("Ring", 5.2, 0.35, 3.45, BaseConfig.EMPTY_RING_COLOR, Enum.Material.Neon)
	cylinder("Top", 5.6, 0.5, 3.85, Color3.fromHex("#2A2440"), Enum.Material.Slate)
	local point = Instance.new("Attachment")
	point.Name = "ItemPoint"
	point.Position = Vector3.new(0, 4.0, 0) -- wierzch Top (y = 4,1) w układzie Root (środek y = 0,1)
	point.Parent = root
	model.PrimaryPart = root
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

local function pedestalTemplate(): Model
	local folder = assetsFolder()
	local template = folder and folder:FindFirstChild("Pedestal")
	if template and template:IsA("Model") then
		return template:Clone()
	end
	return fallbackPedestal()
end

local function hologramTemplate(): Model
	local folder = assetsFolder()
	local template = folder and folder:FindFirstChild("Hologram")
	if template and template:IsA("Model") then
		return template:Clone()
	end
	local model = pedestalTemplate()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Material = Enum.Material.ForceField
			part.Color = BaseConfig.HOLOGRAM_COLOR
			part.Transparency = 0.2
		end
	end
	return model
end

local function placeholderTemplate(): Model
	local folder = assetsFolder()
	local template = folder and folder:FindFirstChild("Placeholder")
	if template and template:IsA("Model") then
		return template:Clone()
	end
	local model = Instance.new("Model")
	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Size = Vector3.new(2.2, 3.6, 2.2)
	crystal.Material = Enum.Material.Glass
	crystal.Transparency = 0.15
	crystal.CFrame = CFrame.Angles(math.rad(45), 0, math.rad(45))
	crystal:SetAttribute("Tint", true)
	crystal.Parent = model
	model.PrimaryPart = crystal
	return model
end

-- Model przedmiotu: ServerStorage.Items/<itemId> (T21–T23) albo placeholder w kolorze poświaty motywu
-- (glow — jasny także dla ciemnych motywów jak Void).
local function itemModel(itemId: string, mutation: string): Model
	local items = ServerStorage:FindFirstChild(BaseConfig.ITEMS_FOLDER)
	local source = items and items:FindFirstChild(itemId)
	local model: Model
	local isPlaceholder = false
	if source and source:IsA("Model") then
		model = source:Clone()
	elseif source and source:IsA("BasePart") then
		model = Instance.new("Model")
		local part = source:Clone()
		part.Parent = model
		model.PrimaryPart = part
	else
		model = placeholderTemplate()
		isPlaceholder = true
	end
	model.Name = "Item"

	local item = LootConfig.ITEMS[itemId]
	local tint = if mutation == "Golden"
		then BaseConfig.GOLDEN_COLOR
		elseif item then StarConfig.glow(item.theme)
		else Color3.new(1, 1, 1)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and (part:GetAttribute("Tint") or (isPlaceholder and part.Name == "Crystal")) then
			part.Color = tint
		elseif part:IsA("BasePart") and mutation == "Golden" and not isPlaceholder then
			part.Color = part.Color:Lerp(BaseConfig.GOLDEN_COLOR, 0.65)
		end
	end
	setPartDefaults(model, false)

	local extents = model:GetExtentsSize()
	local largest = math.max(extents.X, extents.Y, extents.Z)
	if largest > 0 then
		model:ScaleTo(model:GetScale() * BaseConfig.ITEM_MAX_SIZE / largest)
	end

	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		local rarity = BaseMath.rarity(itemId)
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = LootConfig.rarityColor(rarity)
		light.Range = BaseConfig.GLOW_RANGE
		light.Brightness = BaseConfig.GLOW_BRIGHTNESS
		light.Shadows = false
		light.Parent = primary
		if mutation == "Shiny" then
			local sparks = Instance.new("ParticleEmitter")
			sparks.Name = "Shiny"
			sparks.Texture = VfxIds.GLINT
			sparks.Rate = BaseConfig.SHINY_SPARKS
			sparks.Lifetime = NumberRange.new(0.6, 1.1)
			sparks.Speed = NumberRange.new(0.5, 1.5)
			sparks.SpreadAngle = Vector2.new(180, 180)
			sparks.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, 0.7),
				NumberSequenceKeypoint.new(1, 0),
			})
			sparks.LightEmission = 1
			sparks.Parent = primary
		end
	end
	return model
end

-- ---------------------------------------------------------------- budowa bazy

local function slotCFrame(origin: CFrame, slot: number): CFrame
	local x, z = BaseMath.gridOffset(slot, GRID.COLUMNS, GRID.SPACING_X, GRID.SPACING_Z, GRID.FRONT)
	return origin * CFrame.new(x, 0, -z)
end

local function pedestalsFolder(plot: Instance): Folder
	local folder = plot:FindFirstChild(BaseConfig.PEDESTALS_FOLDER)
	if folder and folder:IsA("Folder") then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = BaseConfig.PEDESTALS_FOLDER
	created.Parent = plot
	return created
end

local function itemPoint(pedestal: Model): Vector3
	local point = pedestal:FindFirstChild("ItemPoint", true)
	if point and point:IsA("Attachment") then
		return point.WorldPosition
	end
	return pedestal:GetPivot().Position + Vector3.new(0, 4, 0)
end

local function ringParts(pedestal: Model): { BasePart }
	local list = {}
	for _, part in pedestal:GetDescendants() do
		if part:IsA("BasePart") and (part.Name == "Ring" or part:GetAttribute("Ring")) then
			table.insert(list, part)
		end
	end
	return list
end

local function setPedestalItem(pedestal: Model, uid: string?, item: Types.OwnedItem?, mult: number)
	local current = pedestal:GetAttribute("ItemUid")
	local wanted = uid or ""
	local income = if item then BaseMath.itemIncome(item :: any) * mult else 0
	pedestal:SetAttribute("Income", income)
	if current == wanted and (uid == nil or pedestal:FindFirstChild("Item")) then
		return
	end
	local old = pedestal:FindFirstChild("Item")
	if old then
		old:Destroy()
	end
	pedestal:SetAttribute("ItemUid", wanted)
	if not item or not uid then
		pedestal:SetAttribute("ItemId", "")
		pedestal:SetAttribute("ItemName", "")
		pedestal:SetAttribute("Rarity", "")
		pedestal:SetAttribute("Mutation", "")
		for _, ring in ringParts(pedestal) do
			ring.Color = BaseConfig.EMPTY_RING_COLOR
		end
		return
	end
	local rarity = BaseMath.rarity(item.itemId)
	local def = LootConfig.ITEMS[item.itemId]
	pedestal:SetAttribute("ItemId", item.itemId)
	pedestal:SetAttribute("ItemName", if def then def.name else item.itemId)
	pedestal:SetAttribute("Rarity", rarity)
	pedestal:SetAttribute("Mutation", item.mutation)
	for _, ring in ringParts(pedestal) do
		ring.Color = LootConfig.rarityColor(rarity)
	end
	local model = itemModel(item.itemId, item.mutation)
	local rotation = pedestal:GetPivot().Rotation
	model:PivotTo(CFrame.new(itemPoint(pedestal) + Vector3.new(0, BaseConfig.ITEM_HEIGHT, 0)) * rotation)
	model.Parent = pedestal
end

local function newPedestal(origin: CFrame, slot: number, ownerId: number, hologram: boolean): Model
	local model = if hologram then hologramTemplate() else pedestalTemplate()
	model.Name = if hologram then "Hologram" else `Pedestal_{slot}`
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	setPartDefaults(model, not hologram)
	model:PivotTo(slotCFrame(origin, slot))
	model:SetAttribute("Slot", slot)
	model:SetAttribute("OwnerUserId", ownerId)
	model:SetAttribute("Hologram", hologram)
	if not hologram then
		model:SetAttribute("ItemUid", "")
		model:SetAttribute("Income", 0)
		for _, ring in ringParts(model) do
			ring.Color = BaseConfig.EMPTY_RING_COLOR
		end
	end
	return model
end

-- Przebudowa bazy gracza (różnicowo): postumenty 1..pojemność, przedmioty, hologram, atrybuty gracza.
function BaseService.render(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	local origin = plot and PlotService.getBuildOrigin(plot)
	if not data or not plot or not origin then
		return
	end
	local capacity = LootMath.slotCapacity(data.slots, data.purchases)
	local shown = math.min(capacity, CELLS)
	local mult = BaseMath.incomeMultiplier(data.rebirths, data.purchases)
	local price = BaseMath.slotPrice(data.slots)
	player:SetAttribute("BaseCapacity", capacity)
	player:SetAttribute("NextSlotPrice", price or -1)
	player:SetAttribute("IncomeMult", mult)

	local bySlot: { [number]: string } = {}
	for uid, item in data.items do
		if item.slot and item.slot <= shown then
			bySlot[item.slot] = uid
		end
	end

	local folder = pedestalsFolder(plot)
	for slot = 1, shown do
		local pedestal = folder:FindFirstChild(`Pedestal_{slot}`) :: Model?
		local created = false
		if not pedestal then
			pedestal = newPedestal(origin, slot, player.UserId, false)
			created = true
		end
		local uid = bySlot[slot]
		setPedestalItem(pedestal :: Model, uid, if uid then data.items[uid] else nil, mult)
		if created then
			(pedestal :: Model).Parent = folder
		end
	end
	for _, child in folder:GetChildren() do
		local slot = child:GetAttribute("Slot")
		if child.Name ~= "Hologram" and (type(slot) ~= "number" or slot > shown) then
			child:Destroy()
		end
	end

	local hologram = folder:FindFirstChild("Hologram") :: Model?
	local nextSlot = capacity + 1
	if price and nextSlot <= CELLS then
		if hologram and hologram:GetAttribute("Slot") ~= nextSlot then
			hologram:Destroy()
			hologram = nil
		end
		if not hologram then
			hologram = newPedestal(origin, nextSlot, player.UserId, true);
			(hologram :: Model).Parent = folder
		end
		(hologram :: Model):SetAttribute("Price", price)
	elseif hologram then
		hologram:Destroy()
	end
end

local function clear(plot: Instance)
	local folder = plot:FindFirstChild(BaseConfig.PEDESTALS_FOLDER)
	if folder then
		folder:Destroy()
	end
end

-- ---------------------------------------------------------------- akcje gracza

local function capacityOf(data: PlayerData): number
	return LootMath.slotCapacity(data.slots, data.purchases)
end

local function placeItem(player: Player, uid: string, slot: number): Result
	local result: Result = { ok = false, reason = "NoData" }
	DataService.update(player, function(data: PlayerData)
		local capacity = capacityOf(data)
		local item = data.items[uid]
		if not item then
			result = { ok = false, reason = "NoItem" }
			return
		end
		if slot < 1 or slot > math.min(capacity, CELLS) then
			result = { ok = false, reason = "BadSlot" }
			return
		end
		local from = if BaseMath.isPlaced(item :: any, capacity) then item.slot else nil
		for otherUid, other in data.items do
			if otherUid ~= uid and other.slot == slot then
				other.slot = from -- zamiana: stary idzie na miejsce nowego (albo do ekwipunku)
			end
		end
		item.slot = slot
		result = { ok = true }
	end)
	return result
end

local function removeItem(player: Player, slot: number): Result
	local result: Result = { ok = false, reason = "NoData" }
	DataService.update(player, function(data: PlayerData)
		local capacity = capacityOf(data)
		if BaseMath.inventoryCount(data.items :: any, capacity) >= BaseMath.INVENTORY_LIMIT then
			result = { ok = false, reason = "InventoryFull" }
			return
		end
		for _, item in data.items do
			if item.slot == slot then
				item.slot = nil
				result = { ok = true }
				return
			end
		end
		result = { ok = false, reason = "Empty" }
	end)
	return result
end

local function autoPlace(player: Player): Result
	local moved = 0
	local ok = DataService.update(player, function(data: PlayerData)
		moved = BaseMath.autoPlace(data.items :: any, math.min(capacityOf(data), CELLS))
	end)
	return { ok = ok, moved = moved }
end

local function buySlot(player: Player): Result
	local result: Result = { ok = false, reason = "NoData" }
	DataService.update(player, function(data: PlayerData)
		local price = BaseMath.slotPrice(data.slots)
		if not price then
			result = { ok = false, reason = "Max" }
			return
		end
		if data.cash < price then
			result = { ok = false, reason = "NoCash", price = price }
			return
		end
		data.cash -= price
		data.slots += 1
		data.stats.slotsBought = (data.stats.slotsBought or 0) + 1
		-- Nowy postument od razu z najlepszym przedmiotem z ekwipunku.
		local capacity = math.min(capacityOf(data), CELLS)
		local best: string? = nil
		for uid, item in data.items do
			if not BaseMath.isPlaced(item :: any, capacity) then
				if best == nil or BaseMath.itemIncome(item :: any) > BaseMath.itemIncome(data.items[best] :: any) then
					best = uid
				end
			end
		end
		if best then
			BaseMath.placeNew(data.items :: any, best, capacity)
		end
		result = { ok = true, price = price, slots = data.slots }
	end)
	if result.ok then
		log:info(`{player.Name}: slot {result.slots} za {result.price}`)
	end
	return result
end

-- ---------------------------------------------------------------- start

function BaseService.Init() end

function BaseService.Start()
	PlotService.onAssigned(function(player)
		BaseService.render(player)
	end)
	PlotService.onReleased(function(_player, plot)
		clear(plot)
	end)
	DataService.onLoaded(function(player)
		BaseService.render(player)
	end)
	for _, key in { "items", "slots", "rebirths" } do
		DataService.onChanged(key, function(player)
			BaseService.render(player)
		end)
	end

	Remotes.onInvoke("PlaceItem", placeItem)
	Remotes.onInvoke("RemoveItem", removeItem)
	Remotes.onInvoke("AutoPlace", autoPlace)
	Remotes.onInvoke("BuySlot", buySlot)

	-- Gamepass (T16) zmienia pojemność — wtedy wołaj BaseService.render + EconomyService.refresh.
	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("BaseCapacity", nil)
	end)

	-- Tylko Studio: hak testów przez MCP. ServerStorage.DebugHooks.BaseService:Invoke(cmd, userId, ...):
	-- ("give", userId, itemId, mutation?, count?) — jak łup (wolny postument / zamiana / limit ekwipunku),
	-- ("away", userId, seconds) — lastOnline = teraz − seconds (test offline po ponownym wejściu),
	-- ("state", userId) → { cash, slots, items, inventory, capacity, income }.
	if RunService:IsStudio() then
		local hooks = ServerStorage:FindFirstChild("DebugHooks") or Instance.new("Folder")
		hooks.Name = "DebugHooks"
		local hook = Instance.new("BindableFunction")
		hook.Name = "BaseService"
		hook.OnInvoke = function(command: string, userId: number, a: any, b: any, c: any)
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				return nil
			end
			if command == "give" and LootConfig.ITEMS[a] then
				DataService.update(player, function(data: PlayerData)
					local capacity = capacityOf(data)
					for _ = 1, (if type(c) == "number" then c else 1) do
						local uid = HttpService:GenerateGUID(false)
						data.items[uid] = {
							itemId = a,
							mutation = if type(b) == "string" then b :: any else "None",
							obtainedAt = os.time(),
						}
						BaseMath.placeNew(data.items :: any, uid, capacity)
						for _, sold in BaseMath.trimInventory(data.items :: any, capacity, nil, { [uid] = true }) do
							data.cash += sold.price
						end
					end
				end)
			elseif command == "away" and type(a) == "number" then
				DataService.update(player, function(data: PlayerData)
					data.lastOnline = os.time() - a
				end)
			end
			local data = DataService.get(player)
			if not data then
				return nil
			end
			local count, inventory = 0, 0
			local capacity = capacityOf(data)
			for _, item in data.items do
				count += 1
				if not BaseMath.isPlaced(item :: any, capacity) then
					inventory += 1
				end
			end
			return {
				cash = data.cash,
				slots = data.slots,
				items = count,
				inventory = inventory,
				capacity = capacity,
				income = BaseMath.incomePerSec(data),
				lastOnline = data.lastOnline,
			}
		end
		hook.Parent = hooks
		hooks.Parent = ServerStorage
	end
end

return BaseService
