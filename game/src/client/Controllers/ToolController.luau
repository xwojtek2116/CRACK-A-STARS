--!strict
-- ToolController — narzędzie w ręku po stronie klienta (T09). Tylko wygląd i dźwięk; posiadanie, kupno
-- i obrażenia liczy serwer (ToolService, CrackService).
--   • Zamach: animacja R15 według stylu narzędzia (ToolConfig.STYLE: smash/slash/thrust/blast).
--     Klik w powietrze = pełny zamach (cooldown narzędzia); w minigrze strike() = szybkie uderzenie
--     zsynchronizowane z tapem (animacja startuje tuż przed znacznikiem "Hit"). Animacja własnej postaci
--     replikuje się sama, więc inni widzą zamach bez dodatkowych remote'ów.
--   • Dźwięk zamachu: każdy klient słucha AnimationPlayed na postaciach wszystkich graczy i gra whoosh
--     narzędzia (3D przy Handle) — dźwięk słyszą wszyscy w pobliżu, bez sieci.
--   • Wyjęcie narzędzia: szczęk (2D).
--   • Witryna Tool Shop: obrót i unoszenie modeli, napisy per gracz (cena / NEXT UP / OWNED / EQUIPPED /
--     LOCKED), przyciemnienie zablokowanych, prompt otwierający sklep na zakładce TOOLS.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseConfig = require(Shared.Config.BaseConfig)
local CrackRound = require(Shared.CrackRound)
local ToolConfig = require(Shared.Config.ToolConfig)
local Tools = require(Shared.Config.Data.Tools) :: any

local UI = script.Parent.Parent:WaitForChild("UI")
local Format = require(UI.Format)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local SoundController = require(script.Parent.SoundController)

local SWING = ToolConfig.SWING
local SHOWCASE = ToolConfig.SHOWCASE
local TOOL_ATTR = "ToolId"
local SHOWCASE_NAME = "ToolShowcase"
local EQUIP_QUIET_AFTER_SPAWN = 1.5

local player = Players.LocalPlayer

-- AnimationId → styl (rozpoznawanie animacji zamachu na cudzych postaciach).
local STYLE_BY_ANIM: { [string]: string } = {}
for style, id in ToolConfig.ANIMS do
	STYLE_BY_ANIM[id] = style
end

local tracks: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any
local watchedAnimators: { [Animator]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lastSwing = 0
local lastStrike = 0
local spawnedAt = 0

type Slot = {
	model: Model,
	display: Model?,
	base: CFrame?,
	toolId: string,
	index: number,
	ring: BasePart?,
	highlight: Highlight,
	billboard: BillboardGui,
	status: TextLabel,
	phase: number,
}
local slots: { [Model]: Slot } = {}
local stationPrompt: ProximityPrompt? = nil

local ToolController = {}

-- ---------------------------------------------------------------- zamach

local function heldTool(): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and type(child:GetAttribute(TOOL_ATTR)) == "string" then
			return child
		end
	end
	return nil
end

local function animatorOf(character: Model?): Animator?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

local function styleOf(toolId: string): string
	return ToolConfig.STYLE[toolId] or ToolConfig.DEFAULT_STYLE
end

local function getTrack(animator: Animator, style: string): AnimationTrack?
	local cache = tracks[animator]
	if not cache then
		cache = {}
		tracks[animator] = cache
	end
	local track = cache[style]
	if track then
		return track
	end
	local id = ToolConfig.ANIMS[style]
	if not id then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, loaded = pcall(animator.LoadAnimation, animator, animation)
	if not ok then
		return nil
	end
	loaded.Priority = Enum.AnimationPriority.Action
	loaded.Looped = false
	cache[style] = loaded
	return loaded
end

-- Gra zamach narzędziem w ręku. quick = uderzenie minigry (start tuż przed "Hit").
local function play(quick: boolean): boolean
	local tool = heldTool()
	local animator = animatorOf(player.Character)
	if not tool or not animator then
		return false
	end
	local style = styleOf(tool:GetAttribute(TOOL_ATTR) :: string)
	local track = getTrack(animator, style)
	if not track then
		return false
	end
	if quick then
		track:Play(SWING.fadeIn * 0.5, 1, SWING.strikeSpeed)
		track.TimePosition = math.max(0, (ToolConfig.HIT_TIME[style] or 0) - SWING.strikeLead)
	else
		track:Play(SWING.fadeIn, 1, 1)
	end
	return true
end

-- Uderzenie w minigrze (CrackController przy trafieniu punktu).
function ToolController.strike()
	if play(true) then
		lastStrike = os.clock()
	end
end

-- Klik narzędziem: zamach w powietrze (nie zaraz po uderzeniu w minigrze), cooldown narzędzia.
local function onActivated(tool: Tool)
	local now = os.clock()
	if now - lastStrike < SWING.quietAfterStrike then
		return
	end
	local def = CrackRound.getTool(tool:GetAttribute(TOOL_ATTR) :: string)
	local gap = math.max(SWING.freeGap, if def then def.cooldown else 1)
	if now - lastSwing < gap then
		return
	end
	if play(false) then
		lastSwing = now
	end
end

-- ---------------------------------------------------------------- dźwięk zamachu (wszyscy gracze)

local function watchAnimator(animator: Animator, character: Model)
	if watchedAnimators[animator] then
		return
	end
	watchedAnimators[animator] = true
	animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		local animation = track.Animation
		if not animation or not STYLE_BY_ANIM[animation.AnimationId] then
			return
		end
		local tool = character:FindFirstChildWhichIsA("Tool")
		local toolId = tool and tool:GetAttribute(TOOL_ATTR)
		local handle = tool and tool:FindFirstChild("Handle")
		if type(toolId) ~= "string" or not handle then
			return
		end
		SoundController.attach(ToolConfig.SWING_SOUND[toolId] or "swingStone", handle)
	end)
end

local function watchCharacter(owner: Player, character: Model)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		local animator = humanoid and humanoid:WaitForChild("Animator", 10)
		if animator and animator:IsA("Animator") then
			watchAnimator(animator, character)
		end
	end)
	if owner ~= player then
		return
	end
	spawnedAt = os.clock()
	character.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") or child:GetAttribute(TOOL_ATTR) == nil then
			return
		end
		if os.clock() - spawnedAt > EQUIP_QUIET_AFTER_SPAWN then
			SoundController.play2D("toolEquip")
		end
	end)
end

local function watchPlayer(owner: Player)
	owner.CharacterAdded:Connect(function(character)
		watchCharacter(owner, character)
	end)
	if owner.Character then
		watchCharacter(owner, owner.Character)
	end
end

-- Activated każdego narzędzia gracza (nowy Tool po odrodzeniu, kupnie, zmianie).
local hookedTools: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function hookTool(child: Instance)
	if child:IsA("Tool") and child:GetAttribute(TOOL_ATTR) ~= nil and not hookedTools[child] then
		hookedTools[child] = true
		child.Activated:Connect(function()
			onActivated(child)
		end)
	end
end

local function watchBackpack(container: Instance)
	container.ChildAdded:Connect(hookTool)
	for _, child in container:GetChildren() do
		hookTool(child)
	end
end

-- ---------------------------------------------------------------- witryna Tool Shop

local function owns(state: any, toolId: string): boolean
	local def = Tools.tools[toolId]
	return (state.tools and state.tools[toolId] == true) or (def ~= nil and def.price == 0)
end

local function statusOf(state: any, toolId: string, index: number): (string, Color3, boolean)
	local def = Tools.tools[toolId]
	if state.equippedTool == toolId then
		return "EQUIPPED", Theme.COLORS.index, false
	end
	if owns(state, toolId) then
		return "OWNED", Theme.COLORS.neonCyan, false
	end
	local previous = Tools.order[index - 1]
	if previous == nil or owns(state, previous) then
		return `NEXT UP! {Format.cash(def.price)}`, Theme.COLORS.gold, false
	end
	return `LOCKED · {Format.cash(def.price)}`, Theme.COLORS.textMuted, true
end

local function refreshSlot(slot: Slot, state: any)
	local text, color, locked = statusOf(state, slot.toolId, slot.index)
	slot.status.Text = text
	slot.status.TextColor3 = color
	slot.highlight.Enabled = locked
	if slot.ring then
		local def = Tools.tools[slot.toolId]
		slot.ring.Color = if locked
			then Color3.fromRGB(70, 66, 96)
			else Theme.RARITY_COLORS[Theme.tierRarity(def.tier)] or Theme.COLORS.neonCyan
	end
end

local function label(parent: Instance, name: string, text: string, y: number, h: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, h)
	l.Position = UDim2.fromScale(0, y)
	l.FontFace = Theme.FONTS.display
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Theme.COLORS.ink
	stroke.Parent = l
	l.Parent = parent
	return l
end

local function addSlot(model: Model)
	if slots[model] then
		return
	end
	local toolId = model:GetAttribute(TOOL_ATTR)
	local index = model:GetAttribute("Index")
	local pedestal = model:FindFirstChild("Pedestal")
	local anchor = pedestal and pedestal:FindFirstChild("Display")
	if type(toolId) ~= "string" or type(index) ~= "number" or not anchor or not anchor:IsA("Attachment") then
		return
	end
	local def = Tools.tools[toolId]
	if not def then
		return
	end
	local display = model:FindFirstChild("Display")
	local highlight = Instance.new("Highlight")
	highlight.FillColor = SHOWCASE.lockedFill
	highlight.FillTransparency = SHOWCASE.lockedFillTransparency
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = display
	highlight.Enabled = false
	highlight.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ToolLabel"
	billboard.Size = UDim2.fromScale(SHOWCASE.billboardSize.X, SHOWCASE.billboardSize.Y)
	billboard.StudsOffsetWorldSpace = Vector3.yAxis * SHOWCASE.billboardOffset
	billboard.MaxDistance = SHOWCASE.nearDistance
	billboard.LightInfluence = 0
	billboard.AlwaysOnTop = false
	billboard.Adornee = anchor
	local rarity = Theme.tierRarity(def.tier)
	label(
		billboard,
		"Tier",
		`TIER {def.tier} · {string.upper(rarity)}`,
		0,
		0.26,
		Theme.RARITY_COLORS[rarity] or Theme.COLORS.text
	)
	label(billboard, "Name", def.name, 0.24, 0.42, Theme.COLORS.text)
	local status = label(billboard, "Status", "", 0.66, 0.32, Theme.COLORS.text)
	billboard.Parent = model

	local ring = model:FindFirstChild("Ring")
	local slot: Slot = {
		model = model,
		display = if display and display:IsA("Model") then display else nil,
		toolId = toolId,
		index = index,
		ring = if ring and ring:IsA("BasePart") then ring else nil,
		highlight = highlight,
		billboard = billboard,
		status = status,
		phase = index * 0.7,
	}
	if slot.display then
		slot.base = slot.display:GetPivot()
	end
	slots[model] = slot
	refreshSlot(slot, Store.get())
end

local function ensureShowcase()
	for model, slot in slots do
		if not model:IsDescendantOf(Workspace) then
			slot.billboard:Destroy()
			slot.highlight:Destroy()
			slots[model] = nil
		end
	end
	for _, station in CollectionService:GetTagged(BaseConfig.STATION_TAG) do
		if station:GetAttribute("Station") ~= SHOWCASE.station then
			continue
		end
		local folder = station:FindFirstChild(SHOWCASE_NAME)
		if folder then
			for _, model in folder:GetChildren() do
				if model:IsA("Model") then
					addSlot(model)
				end
			end
		end
		-- Prompt sklepu na PromptAnchor stacji (jak Sell Station w BaseController).
		if not (stationPrompt and stationPrompt.Parent) then
			local anchor = station:FindFirstChild("PromptAnchor", true)
			if anchor and anchor:IsA("BasePart") then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "ToolShopPrompt"
				prompt.ActionText = "Browse Tools"
				prompt.ObjectText = "Tool Shop"
				prompt.MaxActivationDistance = SHOWCASE.promptDistance
				prompt.RequiresLineOfSight = false
				prompt.HoldDuration = 0
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
				prompt.Triggered:Connect(function()
					Store.set({ window = "Shop", tab = "tools" })
				end)
				prompt.Parent = anchor
				stationPrompt = prompt
			end
		end
	end
end

-- Obrót i unoszenie modeli w witrynie (lokalnie; tylko gdy gracz jest blisko).
local function spinShowcase()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local t = os.clock()
	for _, slot in slots do
		local display, base = slot.display, slot.base
		if display and base and (base.Position - root.Position).Magnitude < SHOWCASE.nearDistance then
			local angle = math.rad(SHOWCASE.spinDegPerSec) * t + slot.phase
			local bob = math.sin((t + slot.phase) * math.pi * 2 / SHOWCASE.bobSeconds) * SHOWCASE.bobAmplitude
			local pos = base.Position
			display:PivotTo(CFrame.new(pos.X, pos.Y + bob, pos.Z) * CFrame.Angles(0, angle, 0) * base.Rotation)
		end
	end
end

-- ---------------------------------------------------------------- start

function ToolController.Start()
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	local backpack = player:WaitForChild("Backpack", 10)
	if backpack then
		watchBackpack(backpack)
	end
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchBackpack(child)
		end
	end)
	player.CharacterAdded:Connect(watchBackpack)
	if player.Character then
		watchBackpack(player.Character)
	end

	local lastTools, lastEquipped = nil :: any, nil :: any
	Store.subscribe(function(state)
		if state.tools == lastTools and state.equippedTool == lastEquipped then
			return
		end
		lastTools, lastEquipped = state.tools, state.equippedTool
		for _, slot in slots do
			refreshSlot(slot, state)
		end
	end)

	task.spawn(function()
		while true do
			ensureShowcase()
			task.wait(1)
		end
	end)
	RunService.RenderStepped:Connect(spinShowcase)
end

return ToolController
