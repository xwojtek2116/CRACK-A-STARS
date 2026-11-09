--!strict
-- Tools/Unlock — ekran „NEW TOOL UNLOCKED!” po kupnie narzędzia (T09), tylko u kupującego.
--   przyciemnienie, rozbłysk w kolorze rzadkości tieru, wirujące promienie i iskry, obracający się model 3D
--   narzędzia (ViewportFrame z kopią Toola, który serwer właśnie dał do ręki), nazwa, porównanie statystyk
--   z poprzednim narzędziem (DMG, CD, TARGETS, CRIT) i fanfara. Tap / klik zamyka, po UNLOCK.autoClose sam.
-- Na instancjach (jak Loot/Reveal): krótki, samosprzątający się efekt bez React.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrackRound = require(Shared.CrackRound)
local ToolConfig = require(Shared.Config.ToolConfig)

local UI = script.Parent.Parent
local Fx = require(UI.Loot.Fx)
local Theme = require(UI.Theme)
local SoundController = require(UI.Parent.Controllers.SoundController)

local UNLOCK = ToolConfig.UNLOCK
local COLORS = Theme.COLORS
local TOOL_ATTR = "ToolId"

local player = Players.LocalPlayer
local current: ScreenGui? = nil

local Unlock = {}

-- Kopia narzędzia gracza (z ręki albo plecaka) do ViewportFrame; czeka chwilę, aż serwer je da.
local function findTool(toolId: string): Tool?
	local deadline = os.clock() + 2
	while os.clock() < deadline do
		for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
			if container then
				for _, child in container:GetChildren() do
					if child:IsA("Tool") and child:GetAttribute(TOOL_ATTR) == toolId then
						return child
					end
				end
			end
		end
		task.wait(0.05)
	end
	return nil
end

local function viewportModel(tool: Tool): (Model?, BasePart?)
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return nil, nil
	end
	local model = Instance.new("Model")
	local copies: { [Instance]: Instance } = {}
	for _, child in tool:GetChildren() do
		if child:IsA("BasePart") then
			local copy = child:Clone()
			for _, inst in copy:GetDescendants() do
				if not (inst:IsA("SurfaceAppearance") or inst:IsA("DataModelMesh") or inst:IsA("Decal")) then
					inst:Destroy()
				end
			end
			copy.Anchored = true
			copy.Parent = model
			copies[child] = copy
		end
	end
	-- Ułóż części jak w dłoni: względem Handle (spawy narzędzia).
	local base = handle.CFrame
	for original, copy in copies do
		(copy :: BasePart).CFrame = base:ToObjectSpace((original :: BasePart).CFrame)
	end
	local root = copies[handle] :: BasePart
	model.PrimaryPart = root
	return model, root
end

-- Oś trzonek → głowica w układzie modelu (najdalsza część od Handle).
local function headAxis(model: Model, root: BasePart): Vector3
	local best, distance = Vector3.yAxis, 0
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= root then
			local offset = part.Position - root.Position
			if offset.Magnitude > distance then
				best, distance = offset.Unit, offset.Magnitude
			end
		end
	end
	return best
end

local function statRow(parent: Instance, order: number, name: string, old: string, new: string, better: boolean?)
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 34)
	row.LayoutOrder = order
	row.Parent = parent
	Fx.text(row, {
		text = name,
		size = UDim2.fromScale(0.3, 1),
		position = UDim2.fromScale(0, 0.5),
		anchor = Vector2.new(0, 0.5),
		align = Enum.TextXAlignment.Left,
		color = COLORS.textMuted,
		maxSize = 26,
	})
	Fx.text(row, {
		text = `{old}  →  <font color="#{(if better then COLORS.cash else COLORS.text):ToHex()}">{new}</font>`,
		rich = true,
		size = UDim2.fromScale(0.7, 1),
		position = UDim2.fromScale(1, 0.5),
		anchor = Vector2.new(1, 0.5),
		align = Enum.TextXAlignment.Right,
		maxSize = 28,
	})
end

local function close(gui: ScreenGui)
	if current ~= gui then
		return
	end
	current = nil
	local root = gui:FindFirstChild("Root")
	if root then
		local scale = root:FindFirstChildOfClass("UIScale")
		if scale then
			Fx.tween(scale, 0.25, { Scale = 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		end
		for _, inst in root:GetDescendants() do
			if inst:IsA("TextLabel") then
				Fx.tween(inst, 0.25, { TextTransparency = 1 })
			elseif inst:IsA("ImageLabel") then
				Fx.tween(inst, 0.25, { ImageTransparency = 1 })
			end
		end
	end
	local dim = gui:FindFirstChild("Dim")
	if dim then
		Fx.tween(dim, 0.3, { BackgroundTransparency = 1 })
	end
	task.delay(0.35, function()
		gui:Destroy()
	end)
end

-- Pokazuje odblokowanie narzędzia toolId; previousId = narzędzie przed kupnem (do porównania statystyk).
function Unlock.show(toolId: string, previousId: string?)
	local def = CrackRound.getTool(toolId)
	if not def then
		return
	end
	if current then
		current:Destroy()
	end
	local rarity = if def.tier > 0 then Theme.tierRarity(def.tier) else "Legendary"
	local color = Theme.RARITY_COLORS[rarity] or COLORS.gold

	local gui = Instance.new("ScreenGui")
	gui.Name = "ToolUnlock"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	current = gui

	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = COLORS.space
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Parent = gui
	Fx.tween(dim, 0.3, { BackgroundTransparency = 0.25 })

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.56)
	root.Size = UDim2.fromOffset(560, 640)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = root
	local fit = Fx.screenScale(gui)
	Fx.tween(scale, 0.45, { Scale = fit * 0.8 }, Enum.EasingStyle.Back)

	-- Promienie: wirujące snopy + błysk-gwiazdka za modelem.
	local back = Instance.new("Frame")
	back.Name = "Rays"
	back.AnchorPoint = Vector2.new(0.5, 0.5)
	back.Position = UDim2.fromScale(0.5, 0.36)
	back.Size = UDim2.fromOffset(820, 820)
	back.BackgroundTransparency = 1
	back.Parent = root
	for i = 1, 12 do
		local beam = Instance.new("Frame")
		beam.AnchorPoint = Vector2.new(0.5, 0.5)
		beam.Position = UDim2.fromScale(0.5, 0.5)
		beam.Size = UDim2.new(0, 26, 1, 0)
		beam.Rotation = i * 15
		beam.BackgroundColor3 = color
		beam.BorderSizePixel = 0
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.25),
			NumberSequenceKeypoint.new(0.65, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = beam
		beam.Parent = back
	end
	Fx.loop(back, 12, { Rotation = 360 }, false)
	local glint = Instance.new("ImageLabel")
	glint.Image = Theme.FX.glint
	glint.ImageColor3 = color
	glint.BackgroundTransparency = 1
	glint.AnchorPoint = Vector2.new(0.5, 0.5)
	glint.Position = UDim2.fromScale(0.5, 0.36)
	glint.Size = UDim2.fromOffset(520, 520)
	glint.ImageTransparency = 0.2
	glint.Parent = root
	Fx.loop(glint, 7, { Rotation = -360 }, false)

	-- Nagłówek
	local title = Fx.text(root, {
		text = "NEW TOOL UNLOCKED!",
		size = UDim2.new(1, 0, 0, 64),
		position = UDim2.fromScale(0.5, 0.0),
		anchor = Vector2.new(0.5, 0),
		color = COLORS.starYellow,
		maxSize = 60,
		stroke = 4,
	})
	Fx.gradient(
		title,
		ColorSequence.new({
			ColorSequenceKeypoint.new(0, COLORS.starYellow),
			ColorSequenceKeypoint.new(1, COLORS.gold:Lerp(COLORS.shop, 0.5)),
		})
	)

	-- Model 3D w ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Model"
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.Position = UDim2.fromScale(0.5, 0.36)
	viewport.Size = UDim2.fromOffset(340, 340)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 200, 220)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = root
	local camera = Instance.new("Camera")
	camera.FieldOfView = UNLOCK.viewportFov
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Nazwa i rzadkość
	Fx.text(root, {
		text = string.upper(def.name),
		size = UDim2.new(1, 0, 0, 56),
		position = UDim2.fromScale(0.5, 0.64),
		color = color,
		maxSize = 54,
		stroke = 4,
	})
	Fx.text(root, {
		text = if def.tier > 0 then `TIER {def.tier} · {string.upper(rarity)}` else "EXCLUSIVE",
		size = UDim2.new(1, 0, 0, 28),
		position = UDim2.fromScale(0.5, 0.71),
		color = COLORS.text,
		font = Theme.FONTS.body,
		maxSize = 26,
	})

	-- Porównanie statystyk
	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.AnchorPoint = Vector2.new(0.5, 0)
	stats.Position = UDim2.fromScale(0.5, 0.75)
	stats.Size = UDim2.new(0.72, 0, 0, 150)
	stats.BackgroundTransparency = 1
	stats.Parent = root
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = stats
	local old = previousId and CrackRound.getTool(previousId)
	if old then
		local gain = math.round((def.damage / math.max(old.damage, 1) - 1) * 100)
		statRow(stats, 1, "DAMAGE", tostring(old.damage), `{def.damage} (+{gain}%)`, def.damage > old.damage)
		statRow(stats, 2, "COOLDOWN", `{old.cooldown}s`, `{def.cooldown}s`, def.cooldown < old.cooldown)
		statRow(stats, 3, "TARGETS", tostring(old.targets), tostring(def.targets), def.targets > old.targets)
		statRow(stats, 4, "CRIT", `{math.round(old.crit * 100)}%`, `{math.round(def.crit * 100)}%`, def.crit > old.crit)
	else
		statRow(stats, 1, "DAMAGE", "-", tostring(def.damage), true)
		statRow(stats, 2, "COOLDOWN", "-", `{def.cooldown}s`, true)
	end

	local hint = Fx.text(root, {
		text = "TAP TO CONTINUE",
		size = UDim2.new(1, 0, 0, 24),
		position = UDim2.fromScale(0.5, 1.02),
		color = COLORS.textMuted,
		font = Theme.FONTS.body,
		maxSize = 22,
	})
	Fx.loop(hint, 0.8, { TextTransparency = 0.6 })

	-- Efekty i dźwięk
	SoundController.play2D("toolUnlock")
	Fx.flash(gui, color, UNLOCK.flashAlpha, 0.6)
	task.delay(0.35, function()
		if gui.Parent then
			Fx.burst(root, UNLOCK.bursts, color, UDim2.fromScale(0.5, 0.36), 300)
		end
	end)

	-- Model narzędzia: kopia Toola, którego serwer właśnie dał do ręki. Obrót wokół pionowej osi.
	task.spawn(function()
		local tool = findTool(toolId)
		if not tool or gui.Parent == nil then
			return
		end
		local model, rootPart = viewportModel(tool)
		if not model or not rootPart then
			return
		end
		local upright = CFrame.fromRotationBetweenVectors(headAxis(model, rootPart), Vector3.yAxis)
		model:PivotTo(upright)
		local box, size = model:GetBoundingBox()
		model:PivotTo(upright - box.Position)
		model.Parent = viewport
		local radius = size.Magnitude / 2
		local distance = radius / math.tan(math.rad(UNLOCK.viewportFov / 2)) * 1.05
		local base = model:GetPivot()
		local started = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			if gui.Parent == nil then
				connection:Disconnect()
				return
			end
			local t = os.clock() - started
			local angle = math.rad(UNLOCK.spinDegPerSec) * t
			local tilt = math.sin(t * 1.3) * 0.12
			model:PivotTo(CFrame.Angles(tilt, angle, 0) * base)
			camera.CFrame = CFrame.lookAt(Vector3.new(0, radius * 0.15, distance), Vector3.zero)
		end)
	end)

	dim.Activated:Connect(function()
		close(gui)
	end)
	task.delay(UNLOCK.autoClose, close, gui)
end

return Unlock
