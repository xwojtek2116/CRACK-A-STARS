--!strict
-- BaseController — baza po stronie klienta (T08):
--   • postumenty wszystkich działek (Workspace.Plots/Plot_N/Pedestals, budowane przez BaseService):
--     obrót i unoszenie przedmiotu, pulsująca poświata (tylko w zasięgu kamery), tabliczka z nazwą i $/s,
--   • hologram następnego postumentu: tabliczka z ceną; u właściciela prompt „Buy” (BuySlot),
--   • własne postumenty: prompt „Manage” → okno PEDESTAL, popupy „+$X” co kilka sekund,
--   • stacje w lobby (tag LobbyStation): Sell Station → okno SELL, Upgrades → okno MY BASE,
--   • Store: items/slots z PlayerState, BaseCapacity/NextSlotPrice/IncomeMult z atrybutów gracza,
--   • BaseNotice → toasty, WelcomeInfo po wejściu → okno WELCOME BACK.
-- Obce bazy można oglądać, ale prompty są tylko na własnej działce (serwer i tak sprawdza właściciela).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseConfig = require(Shared.Config.BaseConfig)
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)

local StateController = require(script.Parent.StateController)
local ItemFx = require(script.Parent.Parent:WaitForChild("Fx"):WaitForChild("ItemFx"))

local UI = script.Parent.Parent:WaitForChild("UI")
local Actions = require(UI.Base.Actions)
local Format = require(UI.Format)
local Store = require(UI.Store)
local Theme = require(UI.Theme)

local log = Logger.new("BaseController")
local player = Players.LocalPlayer

type Entry = {
	model: Model,
	item: Model?,
	itemCFrame: CFrame?, -- położenie przedmiotu od serwera (oś obrotu)
	fx: { ItemFx.Part }, -- części animowane modelu (klatki, pierścienie, orbity, puls serca)
	ready: boolean, -- dotarły wszystkie części przedmiotu (atrybut PartCount) — dopiero wtedy ruszamy model
	light: PointLight?,
	baseBrightness: number,
	label: BillboardGui?,
	prompt: ProximityPrompt?,
	phase: number,
	connections: { RBXScriptConnection },
}

local entries: { [Model]: Entry } = {}
local stationPrompts: { [Instance]: ProximityPrompt } = {}

local function isOwn(model: Instance): boolean
	return model:GetAttribute("OwnerUserId") == player.UserId
end

local function anchorPart(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

-- ---------------------------------------------------------------- tabliczka i prompt

local function makeLabel(model: Model, part: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "PedestalLabel"
	gui.Size = BaseConfig.LABEL.SIZE
	gui.StudsOffset = BaseConfig.LABEL.STUDS_OFFSET
	gui.MaxDistance = BaseConfig.LABEL.MAX_DISTANCE
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = part

	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui

	for i, name in { "Title", "Value" } do
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, if i == 1 then 0.42 else 0.58)
		label.TextScaled = true
		label.FontFace = Theme.FONTS.display
		label.TextColor3 = Theme.COLORS.text
		label.LayoutOrder = i
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Theme.COLORS.ink
		stroke.Parent = label
		label.Parent = gui
	end
	gui.Parent = model
	return gui
end

local function setLabel(entry: Entry)
	local gui = entry.label
	if not gui then
		return
	end
	local title = gui:FindFirstChild("Title") :: TextLabel
	local value = gui:FindFirstChild("Value") :: TextLabel
	local model = entry.model
	if model:GetAttribute("Hologram") then
		local price = model:GetAttribute("Price")
		title.Text = "NEW PEDESTAL"
		title.TextColor3 = Theme.COLORS.neonCyan
		value.Text = if type(price) == "number" then Format.cash(price) else ""
		value.TextColor3 = Theme.COLORS.cash
		return
	end
	local uid = model:GetAttribute("ItemUid")
	if type(uid) ~= "string" or uid == "" then
		title.Text = "EMPTY"
		title.TextColor3 = Theme.COLORS.textMuted
		value.Text = ""
		return
	end
	local rarity = model:GetAttribute("Rarity")
	local mutation = model:GetAttribute("Mutation")
	local name = model:GetAttribute("ItemName")
	local prefix = if type(mutation) == "string" and mutation ~= "None" and mutation ~= "" then `{mutation} ` else ""
	title.Text = `{prefix}{if type(name) == "string" then name else ""}`
	title.TextColor3 = if mutation == "Golden"
		then Theme.COLORS.gold
		else Theme.RARITY_COLORS[if type(rarity) == "string" then rarity else ""] or Theme.COLORS.text
	local income = model:GetAttribute("Income")
	value.Text = `{Format.cash(if type(income) == "number" then income else 0)}/s`
	value.TextColor3 = Theme.COLORS.cash
end

local function setPrompt(entry: Entry)
	local prompt = entry.prompt
	if not prompt then
		return
	end
	local model = entry.model
	if model:GetAttribute("Hologram") then
		local price = model:GetAttribute("Price")
		prompt.ActionText = `Buy {if type(price) == "number" then Format.cash(price) else ""}`
		prompt.ObjectText = "New Pedestal"
	else
		local name = model:GetAttribute("ItemName")
		prompt.ActionText = "Manage"
		prompt.ObjectText = if type(name) == "string" and name ~= "" then name else "Empty Pedestal"
	end
end

local function makePrompt(entry: Entry, part: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BasePrompt"
	prompt.MaxActivationDistance = BaseConfig.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = part
	entry.prompt = prompt
	table.insert(
		entry.connections,
		prompt.Triggered:Connect(function()
			local model = entry.model
			if model:GetAttribute("Hologram") then
				Actions.buySlot()
			else
				local slot = model:GetAttribute("Slot")
				if type(slot) == "number" then
					Store.set({ pedestal = slot, window = "Pedestal", tab = Store.none })
				end
			end
		end)
	)
end

-- ---------------------------------------------------------------- przedmiot

local function refreshItem(entry: Entry)
	local item = entry.model:FindFirstChild("Item")
	if item and item:IsA("Model") then
		if entry.item ~= item then
			entry.item = item
			entry.itemCFrame = item:GetPivot()
			entry.fx = {}
			entry.ready = false
			local light = item:FindFirstChildWhichIsA("PointLight", true)
			entry.light = if light and light:IsA("PointLight") then light else nil
			entry.baseBrightness = if entry.light then entry.light.Brightness else 0
		end
	else
		entry.item = nil
		entry.itemCFrame = nil
		entry.fx = {}
		entry.ready = false
		entry.light = nil
	end
end

local function untrack(model: Model)
	local entry = entries[model]
	if not entry then
		return
	end
	for _, connection in entry.connections do
		connection:Disconnect()
	end
	if entry.label then
		entry.label:Destroy()
	end
	if entry.prompt then
		entry.prompt:Destroy()
	end
	entries[model] = nil
end

local function track(model: Instance)
	if not model:IsA("Model") or entries[model] or type(model:GetAttribute("Slot")) ~= "number" then
		return
	end
	local part = anchorPart(model)
	if not part then
		return
	end
	local entry: Entry = {
		model = model,
		item = nil,
		itemCFrame = nil,
		fx = {},
		ready = false,
		light = nil,
		baseBrightness = 0,
		label = nil,
		prompt = nil,
		phase = (model:GetAttribute("Slot") :: number) * 0.7,
		connections = {},
	}
	entries[model] = entry
	entry.label = makeLabel(model, part)
	if isOwn(model) then
		makePrompt(entry, part)
	end
	refreshItem(entry)
	setLabel(entry)
	setPrompt(entry)
	table.insert(
		entry.connections,
		model.AttributeChanged:Connect(function()
			setLabel(entry)
			setPrompt(entry)
		end)
	)
	table.insert(
		entry.connections,
		model.ChildAdded:Connect(function()
			refreshItem(entry)
		end)
	)
	table.insert(
		entry.connections,
		model.ChildRemoved:Connect(function()
			refreshItem(entry)
		end)
	)
	table.insert(
		entry.connections,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then
				untrack(model)
			end
		end)
	)
end

-- ---------------------------------------------------------------- animacja i popupy

local function animate()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local t = os.clock()
	local spin = math.rad(BaseConfig.SPIN_DEGREES_PER_SECOND) * t
	local maxDistance = BaseConfig.ANIMATE_DISTANCE
	local bobOmega = math.pi * 2 / BaseConfig.BOB_SECONDS
	for _, entry in entries do
		local item, base = entry.item, entry.itemCFrame
		if not item or not base then
			continue
		end
		if (base.Position - eye).Magnitude > maxDistance then
			continue
		end
		if not entry.ready then
			-- Model jeszcze w pozycji z serwera: czekamy na wszystkie części, potem zbieramy części animowane.
			local expected = item:GetAttribute("PartCount")
			local count = 0
			for _, part in item:GetDescendants() do
				if part:IsA("BasePart") then
					count += 1
				end
			end
			if type(expected) == "number" and count < expected then
				continue
			end
			entry.fx = ItemFx.collect(item)
			entry.ready = true
			local light = item:FindFirstChildWhichIsA("PointLight", true)
			entry.light = if light and light:IsA("PointLight") then light else nil
			entry.baseBrightness = if entry.light then entry.light.Brightness else 0
		end
		local wave = math.sin(t * bobOmega + entry.phase)
		local pivot = CFrame.new(base.Position + Vector3.new(0, wave * BaseConfig.BOB_STUDS, 0))
			* CFrame.Angles(0, spin + entry.phase, 0)
			* base.Rotation
		item:PivotTo(pivot)
		local beat = if #entry.fx > 0 then ItemFx.apply(entry.fx, pivot, t + entry.phase) else 0
		if entry.light then
			entry.light.Brightness = entry.baseBrightness * (0.75 + 0.35 * (wave + 1) / 2 + 0.6 * beat)
		end
	end
end

local POPUP_TWEEN = TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function popup(entry: Entry, amount: number)
	local part = anchorPart(entry.model)
	if not part then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 1.8)
	gui.StudsOffset = BaseConfig.LABEL.STUDS_OFFSET + Vector3.new(0, 3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = BaseConfig.POPUP_DISTANCE
	gui.Adornee = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.FontFace = Theme.FONTS.display
	label.TextColor3 = Theme.COLORS.cash
	label.Text = `+{Format.cash(amount)}`
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Theme.COLORS.ink
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = part
	TweenService:Create(gui, POPUP_TWEEN, { StudsOffset = gui.StudsOffset + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, POPUP_TWEEN, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, POPUP_TWEEN, { Transparency = 1 }):Play()
	task.delay(POPUP_TWEEN.Time, function()
		gui:Destroy()
	end)
end

local function popups()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local i = 0
	for _, entry in entries do
		if not isOwn(entry.model) or not entry.item then
			continue
		end
		local income = entry.model:GetAttribute("Income")
		if type(income) ~= "number" or income <= 0 then
			continue
		end
		if (entry.model:GetPivot().Position - eye).Magnitude > BaseConfig.POPUP_DISTANCE then
			continue
		end
		i += 1
		-- Rozłożone w czasie, żeby nie wyskakiwały wszystkie naraz.
		task.delay(i * 0.06, popup, entry, income * BaseConfig.POPUP_EVERY_SECONDS)
	end
end

-- ---------------------------------------------------------------- stacje lobby

-- Prompt stacji (Sell Station / Upgrades). Przy streamingu stacja może dojść bez dzieci albo zniknąć
-- i wrócić — dlatego ensureStations co sekundę dorabia brakujące prompty.
local function ensureStation(station: Instance)
	local existing = stationPrompts[station]
	if existing and existing.Parent then
		return
	end
	local kind = station:GetAttribute("Station")
	if kind ~= BaseConfig.SELL_STATION and kind ~= BaseConfig.UPGRADES_STATION then
		return
	end
	local anchor = station:FindFirstChild("PromptAnchor", true)
	local attachment = anchor and anchor:FindFirstChild("Prompt")
	local parent: Instance? = if attachment and attachment:IsA("Attachment")
		then attachment
		elseif anchor and anchor:IsA("BasePart") then anchor
		else nil
	if not parent then
		return
	end
	local isSell = kind == BaseConfig.SELL_STATION
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StationPrompt"
	prompt.ActionText = if isSell then "Sell Items" else "Upgrade Base"
	prompt.ObjectText = if isSell then "Sell Station" else "Upgrades"
	prompt.MaxActivationDistance = BaseConfig.STATION_PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Triggered:Connect(function()
		Store.set({ window = if isSell then "Sell" else "Base", tab = Store.none })
	end)
	prompt.Parent = parent
	stationPrompts[station] = prompt
end

local function ensureStations()
	for station in stationPrompts do
		if not station:IsDescendantOf(Workspace) then
			stationPrompts[station] = nil
		end
	end
	for _, station in CollectionService:GetTagged(BaseConfig.STATION_TAG) do
		ensureStation(station)
	end
end

-- ---------------------------------------------------------------- Store

local function number(value: any): number?
	return if type(value) == "number" and value == value then value else nil
end

local function syncAttributes()
	local price = number(player:GetAttribute("NextSlotPrice"))
	Store.set({
		capacity = number(player:GetAttribute("BaseCapacity")) or 0,
		nextSlotPrice = if price and price >= 0 then price else Store.none,
		incomeMult = number(player:GetAttribute("IncomeMult")) or 1,
	})
end

local function onNotice(notice: { [string]: any })
	if type(notice) ~= "table" then
		return
	end
	if notice.kind == "Replaced" then
		Store.toast(`Better loot! {notice.name} moved to inventory.`, "info")
	elseif notice.kind == "AutoSold" then
		Store.toast(`Inventory full: auto-sold {notice.count} items for {Format.cash(notice.cash)}`, "info")
	end
end

local BaseController = {}

function BaseController.Init() end

function BaseController.Start()
	-- Postumenty (działki są w mapie; Pedestals i modele dochodzą przez replikację/streaming).
	local plots = Workspace:WaitForChild(BaseConfig.PLOTS_FOLDER, 30)
	if plots then
		for _, descendant in plots:GetDescendants() do
			track(descendant)
		end
		plots.DescendantAdded:Connect(function(descendant)
			-- Atrybuty i dzieci modelu mogą dojść klatkę później.
			task.defer(track, descendant)
		end)
	else
		log:warn(`Brak Workspace.{BaseConfig.PLOTS_FOLDER}`)
	end

	RunService.RenderStepped:Connect(animate)
	task.spawn(function()
		while true do
			task.wait(BaseConfig.POPUP_EVERY_SECONDS)
			popups()
		end
	end)
	task.spawn(function()
		while true do
			ensureStations()
			task.wait(1)
		end
	end)

	-- Store: przedmioty i sloty z PlayerState, pojemność/cena/mnożnik z atrybutów gracza.
	local function syncItems(items: any)
		Store.set({ items = if type(items) == "table" then items else {} })
	end
	StateController.onLoaded(function(state)
		syncItems(state.items)
		Store.set({ slots = state.slots })
	end)
	StateController.onChanged("items", syncItems)
	StateController.onChanged("slots", function(slots)
		Store.set({ slots = slots })
	end)
	for _, name in { "BaseCapacity", "NextSlotPrice", "IncomeMult" } do
		player:GetAttributeChangedSignal(name):Connect(syncAttributes)
	end
	syncAttributes()

	Remotes.connect("BaseNotice", onNotice)

	-- Welcome back: serwer już dopisał kasę przy wejściu, tu tylko okno (raz).
	local function fetchWelcome()
		local info = Remotes.invoke("WelcomeInfo")
		if type(info) == "table" and type(info.amount) == "number" and info.amount > 0 then
			Store.set({ welcome = info, window = "Welcome", tab = Store.none })
		end
	end
	StateController.onLoaded(function()
		task.wait(1.5) -- po starcie HUD i pierwszym przyroście kasy
		fetchWelcome()
	end)
	-- Tylko Studio: atrybut DevWelcome (dowolna zmiana) pobiera okno ponownie — test po hooku „rejoin”.
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("DevWelcome"):Connect(function()
			task.spawn(fetchWelcome)
		end)
	end

	log:debug("gotowy")
end

return BaseController
