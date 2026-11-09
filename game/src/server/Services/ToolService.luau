--!strict
-- ToolService — narzędzia gracza (T09). Serwer jest jedynym źródłem prawdy o posiadaniu i kupnie.
--   • BuyTool(toolId): tylko następny tier z Tools.json (liniowo), saldo sprawdza i pobiera EconomyService,
--     po kupnie narzędzie od razu w ręku (equippedTool = toolId).
--   • EquipTool(toolId): dowolne posiadane — tier albo ekskluzyw (Monetization.json, przyznaje T16 przez grant).
--   • Tool z modelu ServerStorage.Tools/<toolId> (T11): po każdym odrodzeniu do plecaka i od razu do ręki.
--     Atrybut ToolId = klucz z katalogu (CrackService porównuje go z equippedTool).
--   • Schowane narzędzie wisi na plecach (model "BackTool" przyspawany do UpperTorso, widoczny dla innych).
--   • Witryna Tool Shop w lobby: 8 postumentów z modelami tierów przed stacją ToolShop (ToolConfig.SHOWCASE);
--     stan per gracz (cena / OWNED / LOCKED), obrót i prompt robi klient (ToolController).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseConfig = require(Shared.Config.BaseConfig)
local CrackRound = require(Shared.CrackRound)
local DataConfig = require(Shared.Config.DataConfig)
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)
local ToolConfig = require(Shared.Config.ToolConfig)
local Tools = require(Shared.Config.Data.Tools) :: any
local Types = require(Shared.Types)

local Services = script.Parent
local CrackService = require(Services.CrackService)
local DataService = require(Services.DataService)
local EconomyService = require(Services.EconomyService)

type PlayerData = Types.PlayerData
type Result = { ok: boolean, reason: string? }

local BACK = ToolConfig.BACK
local SHOWCASE = ToolConfig.SHOWCASE
local BACK_NAME = "BackTool"
local SHOWCASE_NAME = "ToolShowcase"
local TOOL_ATTR = "ToolId"

local log = Logger.new("ToolService")

local templates: Folder? = nil
local backConnections: { [Player]: { RBXScriptConnection } } = {}

local ToolService = {}

-- ---------------------------------------------------------------- posiadanie

local function owns(data: PlayerData, toolId: string): boolean
	local def = CrackRound.getTool(toolId)
	if not def then
		return false
	end
	if data.tools[toolId] == true then
		return true
	end
	-- Darmowy pierwszy tier (Stone Pickaxe) ma każdy.
	return not CrackRound.isExclusive(toolId) and def.price == 0
end

-- Narzędzie do ręki: equippedTool, jeśli gracz je ma i istnieje model; inaczej narzędzie startowe.
local function resolveEquipped(data: PlayerData): string
	local id = data.equippedTool
	if owns(data, id) and templates and templates:FindFirstChild(id) then
		return id
	end
	return DataConfig.STARTING_TOOL
end

-- ---------------------------------------------------------------- narzędzie na plecach

local function clearBack(character: Model?)
	local existing = character and character:FindFirstChild(BACK_NAME)
	if existing then
		existing:Destroy()
	end
end

-- Kopia części Toola do modelu. Klon całego Toola, żeby spawy (ToolWeld → Handle) wskazywały na kopię Handle.
local function moveParts(template: Instance, model: Model)
	local copy = template:Clone()
	for _, child in copy:GetChildren() do
		if not child:IsA("LuaSourceContainer") then
			child.Parent = model
		end
	end
	copy:Destroy()
end

-- Kierunek od Handle do najdalszej części narzędzia (w układzie Handle) = oś trzonka → głowica.
local function headAxis(template: Tool): (Vector3, number)
	local handle = template:FindFirstChild("Handle") :: BasePart?
	local best, distance = Vector3.yAxis, 0
	if not handle then
		return best, 1
	end
	for _, weld in template:GetDescendants() do
		if weld:IsA("Weld") and weld.Part0 == handle and weld.Part1 then
			local offset = (weld.C0 * weld.C1:Inverse()).Position
			if offset.Magnitude > distance then
				best, distance = offset.Unit, offset.Magnitude
			end
		end
	end
	return best, math.max(distance, 1)
end

-- Kopia modelu narzędzia bez skryptów i kolizji, przyspawana skosem do pleców.
local function showOnBack(character: Model, toolId: string)
	clearBack(character)
	local template = templates and templates:FindFirstChild(toolId)
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not template or not template:IsA("Tool") or not torso or not torso:IsA("BasePart") then
		return
	end
	local model = Instance.new("Model")
	model.Name = BACK_NAME
	moveParts(template, model)
	local handle = model:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		model:Destroy()
		return
	end
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.Anchored = false
			inst.CanCollide = false
			inst.CanQuery = false
			inst.CanTouch = false
			inst.Massless = true
		elseif inst:IsA("Trail") or inst:IsA("ParticleEmitter") then
			inst.Enabled = false
		elseif inst:IsA("Light") then
			inst.Brightness *= BACK.lightBrightness
		end
	end
	-- Oś głowicy narzędzia → ukośnie w górę przez plecy; środek narzędzia na środku pleców.
	local axis, length = headAxis(template)
	local tilt = math.rad(BACK.tiltDeg)
	local along = CFrame.fromRotationBetweenVectors(axis, Vector3.yAxis)
	local placement = CFrame.new(BACK.offset)
		* CFrame.Angles(0, 0, tilt)
		* CFrame.new(0, -length * BACK.centerAlong, 0)
		* along
	local weld = Instance.new("Weld")
	weld.Name = "BackWeld"
	weld.Part0 = torso
	weld.Part1 = handle
	weld.C0 = placement
	weld.Parent = handle
	model.PrimaryPart = handle
	model.Parent = character
end

-- Narzędzie w plecaku → na plecach; w ręku → zdejmij z pleców.
local function watchBack(player: Player, tool: Tool)
	for _, connection in backConnections[player] or {} do
		connection:Disconnect()
	end
	local toolId = tool:GetAttribute(TOOL_ATTR)
	local function update()
		local character = player.Character
		if not character or type(toolId) ~= "string" then
			return
		end
		if tool.Parent == character then
			clearBack(character)
		elseif tool.Parent and tool.Parent:IsA("Backpack") then
			showOnBack(character, toolId)
		end
	end
	backConnections[player] = { tool.AncestryChanged:Connect(update) }
	update()
end

-- ---------------------------------------------------------------- wydawanie Toola

local function removeTools(player: Player)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(TOOL_ATTR) ~= nil then
					child:Destroy()
				end
			end
		end
	end
	clearBack(player.Character)
end

local function makeTool(toolId: string): Tool?
	local template = templates and templates:FindFirstChild(toolId)
	if not template or not template:IsA("Tool") then
		log:warn(`Brak modelu ServerStorage.Tools.{toolId}`)
		return nil
	end
	local tool = template:Clone()
	local def = CrackRound.getTool(toolId)
	local display = tool:GetAttribute("DisplayName")
	tool.Name = if type(display) == "string" then display elseif def then def.name else toolId
	tool.ToolTip = tool.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(TOOL_ATTR, toolId)
	return tool
end

-- Daje graczowi narzędzie z danych (equippedTool). equip = od razu do ręki.
local function give(player: Player, equip: boolean)
	local data = DataService.get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	local toolId = resolveEquipped(data)
	if toolId ~= data.equippedTool then
		DataService.update(player, function(d: PlayerData)
			d.equippedTool = toolId
		end)
	end
	removeTools(player)
	local tool = makeTool(toolId)
	if not tool then
		return
	end
	tool.Parent = backpack
	watchBack(player, tool)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if equip and humanoid and humanoid.Health > 0 then
		humanoid:EquipTool(tool)
	end
end

-- ---------------------------------------------------------------- remoty

local function onBuy(player: Player, toolId: string): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, reason = "NotLoaded" }
	end
	local def = Tools.tools[toolId]
	if not def then
		return { ok = false, reason = "InvalidArgs" }
	end
	if owns(data, toolId) then
		return { ok = false, reason = "Owned" }
	end
	local index = table.find(Tools.order, toolId) :: number
	local previous = Tools.order[index - 1]
	if previous and not owns(data, previous) then
		return { ok = false, reason = "Locked" }
	end
	if CrackService.isInRound(player) then
		return { ok = false, reason = "InMinigame" }
	end
	if not EconomyService.trySpend(player, def.price, `tool:{toolId}`) then
		return { ok = false, reason = "NoCash" }
	end
	DataService.update(player, function(d: PlayerData)
		d.tools[toolId] = true
		d.equippedTool = toolId
	end)
	log:info(`{player.Name} kupił {toolId} za {def.price}`)
	give(player, true)
	return { ok = true }
end

local function onEquip(player: Player, toolId: string): Result
	local data = DataService.get(player)
	if not data then
		return { ok = false, reason = "NotLoaded" }
	end
	if not owns(data, toolId) then
		return { ok = false, reason = "NotOwned" }
	end
	if CrackService.isInRound(player) then
		return { ok = false, reason = "InMinigame" }
	end
	if data.equippedTool ~= toolId then
		DataService.update(player, function(d: PlayerData)
			d.equippedTool = toolId
		end)
	end
	give(player, true)
	return { ok = true }
end

-- ---------------------------------------------------------------- witryna w lobby

local function findStation(): Instance?
	for _, station in CollectionService:GetTagged(BaseConfig.STATION_TAG) do
		if station:GetAttribute("Station") == SHOWCASE.station then
			return station
		end
	end
	return nil
end

-- Kopia modelu narzędzia do witryny: zakotwiczona, bez kolizji, Handle jako PrimaryPart.
local function displayModel(toolId: string): Model?
	local template = templates and templates:FindFirstChild(toolId)
	if not template then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = toolId
	moveParts(template, model)
	local handle = model:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	-- Ustaw części według spawów, potem zakotwicz (bez fizyki — obraca je klient).
	for _, weld in model:GetDescendants() do
		if weld:IsA("Weld") and weld.Part0 == handle and weld.Part1 then
			weld.Part1.CFrame = handle.CFrame * weld.C0 * weld.C1:Inverse()
		end
	end
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.CanQuery = false
			inst.CanTouch = false
		elseif inst:IsA("Trail") then
			inst.Enabled = false
		end
	end
	model.PrimaryPart = handle
	model:SetAttribute(TOOL_ATTR, toolId)
	return model
end

local function buildShowcase()
	local station = findStation()
	local body = station and station:FindFirstChild("Body")
	if not station or not body or not body:IsA("BasePart") then
		log:warn("Brak stacji ToolShop (tag LobbyStation, Station = ToolShop) — witryna pominięta")
		return
	end
	local old = station:FindFirstChild(SHOWCASE_NAME)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = SHOWCASE_NAME
	local front = body.CFrame.LookVector
	-- Patrząc na front sklepu (od strony gracza) jego „prawo” to −RightVector budynku.
	local right = -body.CFrame.RightVector
	local frontCenter = body.Position + front * (body.Size.Z / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain, Workspace:FindFirstChild("Map") :: Instance }
	for i, toolId in Tools.order do
		local lateral = SHOWCASE.lateral[i]
		if not lateral then
			break
		end
		local def = Tools.tools[toolId]
		local spot = frontCenter + front * (SHOWCASE.forward - SHOWCASE.curve * math.abs(lateral)) + right * lateral
		local hit = Workspace:Raycast(spot + Vector3.yAxis * 60, Vector3.yAxis * -160, params)
		local groundY = if hit then hit.Position.Y else body.Position.Y - body.Size.Y / 2
		local slot = Instance.new("Model")
		slot.Name = `Slot_{i}`
		slot:SetAttribute(TOOL_ATTR, toolId)
		slot:SetAttribute("Tier", def.tier)
		slot:SetAttribute("Index", i)

		local h = SHOWCASE.pedestalSize.X
		local pedestal = Instance.new("Part")
		pedestal.Name = "Pedestal"
		pedestal.Shape = Enum.PartType.Cylinder
		pedestal.Size = SHOWCASE.pedestalSize
		pedestal.CFrame = CFrame.new(spot.X, groundY + h / 2, spot.Z) * CFrame.Angles(0, 0, math.rad(90))
		pedestal.Material = Enum.Material.Slate
		pedestal.Color = Color3.fromRGB(32, 28, 54)
		pedestal.Anchored = true
		pedestal.TopSurface = Enum.SurfaceType.Smooth
		pedestal.Parent = slot

		local ring = Instance.new("Part")
		ring.Name = "Ring"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = SHOWCASE.ringSize
		ring.CFrame = CFrame.new(spot.X, groundY + h - SHOWCASE.ringSize.X / 2, spot.Z)
			* CFrame.Angles(0, 0, math.rad(90))
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(120, 120, 140)
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Parent = slot

		local anchor = Instance.new("Attachment")
		anchor.Name = "Display"
		anchor.Parent = pedestal
		anchor.WorldPosition = Vector3.new(spot.X, groundY + h + SHOWCASE.hover, spot.Z)

		local model = displayModel(toolId)
		local template = templates and templates:FindFirstChild(toolId)
		if model and template and template:IsA("Tool") then
			-- Trzonek pionowo, głowica w górę; środek narzędzia na wysokości Display.
			local axis = headAxis(template)
			local cf = CFrame.new(anchor.WorldPosition) * CFrame.fromRotationBetweenVectors(axis, Vector3.yAxis)
			model:PivotTo(cf)
			model:ScaleTo(SHOWCASE.modelScale)
			local boxCf = model:GetBoundingBox()
			model:PivotTo(cf + (anchor.WorldPosition - boxCf.Position))
			model.Name = "Display"
			model.Parent = slot
		end
		slot.Parent = folder
	end
	folder.Parent = station
	log:info(`Witryna Tool Shop: {#folder:GetChildren()} postumentów`)
end

-- ---------------------------------------------------------------- API

-- Przyznaje narzędzie (ekskluzyw za Robux z T16, nagrody). equip = od razu do ręki.
function ToolService.grant(player: Player, toolId: string, equip: boolean?): boolean
	if not CrackRound.getTool(toolId) then
		return false
	end
	local ok = DataService.update(player, function(d: PlayerData)
		d.tools[toolId] = true
		if equip then
			d.equippedTool = toolId
		end
	end)
	if ok and equip then
		give(player, true)
	end
	return ok
end

function ToolService.Init()
	templates = ServerStorage:FindFirstChild("Tools") :: Folder?
	if not templates then
		log:error("Brak ServerStorage.Tools (modele narzędzi z T11)")
	end
	Remotes.onInvoke("BuyTool", onBuy)
	Remotes.onInvoke("EquipTool", onEquip)
end

function ToolService.Start()
	DataService.onLoaded(function(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(give, player, true)
		end)
		if player.Character then
			give(player, true)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, connection in backConnections[player] or {} do
			connection:Disconnect()
		end
		backConnections[player] = nil
	end)
	task.spawn(buildShowcase)

	-- Tylko Studio: hak dla testów przez MCP (execute_luau działa w osobnej VM).
	-- ServerStorage.DebugHooks.ToolService:Invoke("grant", userId, toolId) / ("reset", userId) → dane narzędzi.
	if RunService:IsStudio() then
		local hooks = ServerStorage:FindFirstChild("DebugHooks") or Instance.new("Folder")
		hooks.Name = "DebugHooks"
		local hook = Instance.new("BindableFunction")
		hook.Name = "ToolService"
		hook.OnInvoke = function(command: string, userId: number, toolId: string?)
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				return nil
			end
			if command == "grant" and type(toolId) == "string" then
				ToolService.grant(player, toolId, true)
			elseif command == "reset" then
				DataService.update(player, function(d: PlayerData)
					d.tools = {}
					d.equippedTool = DataConfig.STARTING_TOOL
				end)
				give(player, true)
			end
			local data = DataService.get(player)
			return data and { tools = data.tools, equippedTool = data.equippedTool, cash = data.cash }
		end
		hook.Parent = hooks
		hooks.Parent = ServerStorage
	end
end

return ToolService
