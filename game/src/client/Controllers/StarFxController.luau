--!strict
-- StarFxController — efekty gwiazd po stronie klienta (wersja podstawowa, pełny cinematic w T12):
-- baner ogłoszenia, gwiazda w locie (kula + smuga + poświata), rosnący cień i strefa uderzenia z licznikiem,
-- uderzenie (błysk, fala, kurz, wstrząs kamery, odrzut własnej postaci), napis nad leżącą gwiazdą
-- (nazwa, HP, czas do zgaśnięcia), rozpad/zgaśnięcie, blednięcie śladów i kompas do najbliższej gwiazdy.
-- Stan przychodzi z StarService (StarEvent + RequestStars); klient niczego nie rozstrzyga.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)
local StarConfig = require(Shared.Config.StarConfig)
local Types = require(Shared.Types)

type StarInfo = Types.StarInfo

type FallFx = {
	orb: Part,
	shadow: Part,
	danger: Part,
	countdown: TextLabel,
	direction: Vector3,
}

type Banner = {
	frame: Frame,
	sub: TextLabel,
	removeAt: number,
}

type ClientStar = {
	info: StarInfo,
	fall: FallFx?,
	banner: Banner?,
	impacted: boolean,
}

type Label = {
	billboard: BillboardGui,
	details: Frame,
	fill: Frame,
	hpText: TextLabel,
	timer: TextLabel,
	part: BasePart,
	connections: { RBXScriptConnection },
}

local CLASSES = StarConfig.CLASSES
local IMPACT = StarConfig.IMPACT
local SCHEDULE = StarConfig.SCHEDULE

local FONT = Enum.Font.FredokaOne
local PANEL_COLOR = Color3.fromRGB(22, 16, 44)
local DANGER_COLOR = Color3.fromRGB(255, 72, 48)
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local DETAILS_DISTANCE = 260 -- bliżej: pasek HP i licznik nad gwiazdą
local LABEL_HIDE_MARKER = 300 -- leżąca gwiazda bliżej niż to: znacznik kompasu chowa się (wystarczy napis)
local EDGE_MARGIN = 72
local LABEL_MAX_DISTANCE = 1500 -- dalej gwiazdę wskazuje tylko kompas
local LABEL_UPDATE_SECONDS = 0.2
local MAX_BANNERS = 3

local log = Logger.new("StarFxController")
local rng = Random.new()
local player = Players.LocalPlayer

local known: { [string]: ClientStar } = {}
local labels: { [Model]: Label } = {}
local fxFolder: Folder
local bannerList: Frame
local compassArrow: Frame
local compassArrowStroke: UIStroke
local compassArrowLabel: TextLabel
local compassMarker: Frame
local compassMarkerLabel: TextLabel
local labelClock = 0

local shakeUntil = 0
local shakeDuration = 1
local shakeStrength = 0

local StarFxController = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function formatNumber(value: number): string
	local text = tostring(math.max(0, math.floor(value)))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if result:sub(1, 1) == "," then
		result = result:sub(2)
	end
	return result
end

local function formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- CFrame płaskiego walca (oś X walca = normalna terenu).
local function discCFrame(pos: Vector3, normal: Vector3): CFrame
	local other = if math.abs(normal:Dot(Vector3.zAxis)) > 0.9 then Vector3.xAxis else Vector3.zAxis
	local up = normal:Cross(other).Unit
	return CFrame.fromMatrix(pos, normal, up)
end

local function fxPart(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	return part
end

local function label(
	parent: Instance,
	text: string,
	size: UDim2,
	position: UDim2,
	color: Color3,
	maxSize: number
): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Font = FONT
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextScaled = true
	textLabel.Size = size
	textLabel.Position = position
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.Parent = textLabel
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.2
	stroke.Parent = textLabel
	textLabel.Parent = parent
	return textLabel
end

local function corner(parent: Instance, radius: UDim)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = radius
	uiCorner.Parent = parent
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService
		:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
end

-- ===== Baner ogłoszenia =====

local function removeBanner(banner: Banner)
	tween(banner.frame, 0.3, { BackgroundTransparency = 1 })
	for _, child in banner.frame:GetDescendants() do
		if child:IsA("TextLabel") then
			tween(child, 0.3, { TextTransparency = 1 })
		elseif child:IsA("UIStroke") then
			tween(child, 0.3, { Transparency = 1 })
		end
	end
	task.delay(0.35, function()
		banner.frame:Destroy()
	end)
end

local function showBanner(star: ClientStar)
	local info = star.info
	local color = StarConfig.color(info.type)
	-- Przy komplecie banerów chowamy ten, którego uderzenie było najwcześniej.
	local count = 0
	local oldest: ClientStar? = nil
	for _, other in known do
		if other.banner then
			count += 1
			if not oldest or other.info.impactAt < oldest.info.impactAt then
				oldest = other
			end
		end
	end
	if count >= MAX_BANNERS and oldest and oldest.banner then
		removeBanner(oldest.banner)
		oldest.banner = nil
	end

	local frame = Instance.new("Frame")
	frame.Name = info.id
	frame.Size = UDim2.new(1, 0, 0, 58)
	frame.BackgroundColor3 = PANEL_COLOR
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = math.floor(info.impactAt * 10) % 1e6
	corner(frame, UDim.new(0, 14))
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local title = label(
		frame,
		`{StarConfig.displayName(info.size, info.type):upper()} INCOMING!`,
		UDim2.new(1, -20, 0, 30),
		UDim2.fromOffset(10, 4),
		color,
		28
	)
	local sub = label(frame, "", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 34), Color3.new(1, 1, 1), 20)
	frame.Parent = bannerList
	tween(frame, 0.25, { BackgroundTransparency = 0.15 })
	title.TextTransparency = 1
	tween(title, 0.25, { TextTransparency = 0 })

	star.banner = { frame = frame, sub = sub, removeAt = info.impactAt + 3 }
end

-- ===== Lot i uderzenie =====

local function createFall(star: ClientStar)
	local info = star.info
	local class = CLASSES[info.size]
	local glow = StarConfig.glow(info.type)
	local color = StarConfig.color(info.type)
	local direction = (info.impactPos - info.startPos).Unit
	local orbSize = math.max(3, class.size * 0.7)

	local orb = fxPart(
		Enum.PartType.Ball,
		Vector3.one * orbSize,
		CFrame.lookAlong(info.startPos, direction),
		glow,
		Enum.Material.Neon
	)
	orb.Name = `Fall_{info.id}`
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(orbSize * 0.45, 0, 0)
	a0.Parent = orb
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-orbSize * 0.45, 0, 0)
	a1.Parent = orb
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.8 + class.size * 0.02
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(glow, color)
	trail.Transparency = NumberSequence.new(0.05, 1)
	trail.WidthScale = NumberSequence.new(1, 0.1)
	trail.Parent = orb
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = FIRE_TEXTURE
	fire.Color = ColorSequence.new(glow, color)
	fire.LightEmission = 1
	fire.Rate = 30
	fire.Lifetime = NumberRange.new(0.4, 0.8)
	fire.Speed = NumberRange.new(1, 3)
	fire.Size = NumberSequence.new(orbSize * 0.9, 0)
	fire.Transparency = NumberSequence.new(0.2, 1)
	fire.Parent = orb
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Brightness = 4
	light.Range = math.min(60, class.size * 2 + 20)
	light.Parent = orb
	-- Poświata widoczna z daleka: billboard w studs + minimum w pikselach.
	local halo = Instance.new("BillboardGui")
	halo.Size = UDim2.new(orbSize * 2.2, 24, orbSize * 2.2, 24)
	halo.LightInfluence = 0
	halo.Adornee = orb
	local glowDot = Instance.new("Frame")
	glowDot.Size = UDim2.fromScale(1, 1)
	glowDot.BackgroundColor3 = glow
	glowDot.BackgroundTransparency = 0.72
	corner(glowDot, UDim.new(1, 0))
	glowDot.Parent = halo
	-- rozbłysk na niebie przy pojawieniu się
	local flash = glowDot:Clone()
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0
	flash.Size = UDim2.fromScale(0.3, 0.3)
	flash.Position = UDim2.fromScale(0.35, 0.35)
	flash.Parent = halo
	tween(
		flash,
		0.9,
		{ Size = UDim2.fromScale(2, 2), Position = UDim2.fromScale(-0.5, -0.5), BackgroundTransparency = 1 }
	)
	halo.Parent = orb

	local diameter = StarConfig.craterRadius(info.size) * 2
	local shadow = fxPart(
		Enum.PartType.Cylinder,
		Vector3.new(0.6, diameter * 0.3, diameter * 0.3),
		discCFrame(info.impactPos + info.normal * 0.3, info.normal),
		Color3.new(0, 0, 0),
		Enum.Material.SmoothPlastic
	)
	shadow.Transparency = 0.85
	shadow.Name = `Shadow_{info.id}`
	local dangerDiameter = StarConfig.knockbackRadius(info.size) * 2
	local danger = fxPart(
		Enum.PartType.Cylinder,
		Vector3.new(0.4, dangerDiameter, dangerDiameter),
		discCFrame(info.impactPos + info.normal * 0.15, info.normal),
		DANGER_COLOR,
		Enum.Material.Neon
	)
	danger.Transparency = 0.88
	danger.Name = `Danger_{info.id}`

	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(130, 48)
	board.StudsOffsetWorldSpace = Vector3.new(0, 6 + class.size * 0.4, 0)
	board.AlwaysOnTop = true
	board.MaxDistance = 1500
	board.LightInfluence = 0
	board.Adornee = shadow
	local countdown = label(board, "", UDim2.fromScale(1, 1), UDim2.new(), Color3.new(1, 1, 1), 40)
	countdown.TextStrokeTransparency = 1
	board.Parent = shadow

	orb.Parent = fxFolder
	shadow.Parent = fxFolder
	danger.Parent = fxFolder
	star.fall = { orb = orb, shadow = shadow, danger = danger, countdown = countdown, direction = direction }
end

local function destroyFall(star: ClientStar)
	local fall = star.fall
	if fall then
		fall.orb:Destroy()
		fall.shadow:Destroy()
		fall.danger:Destroy()
		star.fall = nil
	end
end

local function shakeCamera(strength: number, duration: number)
	if strength <= shakeStrength * math.max(0, (shakeUntil - os.clock()) / shakeDuration) then
		return
	end
	shakeStrength = strength
	shakeDuration = duration
	shakeUntil = os.clock() + duration
end

local function knockback(info: StarInfo)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local radius = StarConfig.knockbackRadius(info.size)
	local offset = root.Position - info.impactPos
	local distance = offset.Magnitude
	if distance > radius then
		return
	end
	local strength = 1 - (distance / radius) * 0.5
	local away = flat(offset)
	if away.Magnitude < 0.1 then
		away = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	end
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = away.Unit * IMPACT.knockbackSpeed * strength
		+ Vector3.yAxis * IMPACT.knockbackUp * strength
	root.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-2, 2), rng:NextNumber(-4, 4))
	task.delay(IMPACT.knockbackRagdollSeconds, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function playImpact(star: ClientStar)
	local info = star.info
	star.impacted = true
	destroyFall(star)
	local class = CLASSES[info.size]
	local glow = StarConfig.glow(info.type)
	local radius = StarConfig.craterRadius(info.size)

	local flash =
		fxPart(Enum.PartType.Ball, Vector3.one * class.size, CFrame.new(info.impactPos), glow, Enum.Material.Neon)
	flash.Parent = fxFolder
	tween(flash, 0.4, { Size = Vector3.one * radius * 3, Transparency = 1 })

	local knockDiameter = StarConfig.knockbackRadius(info.size) * 2
	local wave = fxPart(
		Enum.PartType.Cylinder,
		Vector3.new(0.6, class.size, class.size),
		discCFrame(info.impactPos + info.normal * 0.5, info.normal),
		glow,
		Enum.Material.Neon
	)
	wave.Transparency = 0.2
	wave.Parent = fxFolder
	tween(wave, 0.55, { Size = Vector3.new(0.6, knockDiameter, knockDiameter), Transparency = 1 })

	-- Kurz i iskry: jednorazowe Emit na niewidocznej części.
	local holder =
		fxPart(Enum.PartType.Block, Vector3.one, CFrame.new(info.impactPos), glow, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = SMOKE_TEXTURE
	dust.Color = ColorSequence.new(Color3.fromRGB(120, 108, 100))
	dust.Enabled = false
	dust.Lifetime = NumberRange.new(1.5, 3)
	dust.Speed = NumberRange.new(class.size * 0.8, class.size * 1.6)
	dust.SpreadAngle = Vector2.new(80, 80)
	dust.Drag = 3
	dust.Size = NumberSequence.new(class.size * 0.3, class.size * 0.9)
	dust.Transparency = NumberSequence.new(0.3, 1)
	dust.Parent = holder
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(glow)
	sparks.LightEmission = 1
	sparks.Enabled = false
	sparks.Lifetime = NumberRange.new(0.6, 1.4)
	sparks.Speed = NumberRange.new(class.size * 1.5, class.size * 3)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Acceleration = Vector3.new(0, -60, 0)
	sparks.Size = NumberSequence.new(math.max(0.6, class.size * 0.08), 0)
	sparks.Parent = holder
	holder.Parent = fxFolder
	dust:Emit(math.min(10 + class.size, 50))
	sparks:Emit(math.min(15 + class.size * 2, 80))
	task.delay(4, function()
		holder:Destroy()
		flash:Destroy()
		wave:Destroy()
	end)

	local camera = Workspace.CurrentCamera
	if camera then
		local distance = (camera.CFrame.Position - info.impactPos).Magnitude
		local reach = 250 + class.size * 15
		local strength = math.clamp(class.size / 10, 0.4, 3) * math.clamp(1 - distance / reach, 0, 1)
		if strength > 0.02 then
			shakeCamera(strength, 0.45 + class.size * 0.015)
		end
	end
	knockback(info)
end

local function removeStar(id: string)
	local star = known[id]
	if not star then
		return
	end
	destroyFall(star)
	if star.banner then
		removeBanner(star.banner)
		star.banner = nil
	end
	known[id] = nil
end

local function addStar(info: StarInfo)
	local existing = known[info.id]
	if existing then
		existing.info = info
		return
	end
	local star: ClientStar = { info = info, fall = nil, banner = nil, impacted = info.state ~= "Falling" }
	known[info.id] = star
	if info.state == "Falling" and now() < info.impactAt then
		createFall(star)
		showBanner(star)
	end
end

-- ===== Napis nad leżącą gwiazdą =====

local function removeLabel(model: Model)
	local entry = labels[model]
	if not entry then
		return
	end
	for _, connection in entry.connections do
		connection:Disconnect()
	end
	entry.billboard:Destroy()
	labels[model] = nil
end

local function updateHp(model: Model)
	local entry = labels[model]
	if not entry then
		return
	end
	local hp = model:GetAttribute("Hp")
	local maxHp = model:GetAttribute("MaxHp")
	if typeof(hp) ~= "number" or typeof(maxHp) ~= "number" or maxHp <= 0 then
		return
	end
	tween(entry.fill, 0.15, { Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1) })
	entry.hpText.Text = `{formatNumber(hp)} / {formatNumber(maxHp)}`
end

local function playDying(model: Model)
	local reason = model:GetAttribute("EndReason")
	local seconds = SCHEDULE.dyingSeconds * 0.9
	local typeId = model:GetAttribute("Type")
	local glow = StarConfig.glow(if typeof(typeId) == "string" then typeId else "")
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if reason == "Expired" and descendant.Name == "Core" then
				tween(descendant, seconds * 0.5, { Color = Color3.fromRGB(60, 56, 56) })
			end
			tween(descendant, seconds, { Transparency = 1 }, Enum.EasingStyle.Quad)
		elseif descendant:IsA("PointLight") then
			tween(descendant, seconds * 0.6, { Brightness = 0 })
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end
	if reason == "Cracked" then
		local pivot = model:GetPivot()
		local size = model:GetExtentsSize().Magnitude * 0.5
		local burst = fxPart(Enum.PartType.Ball, Vector3.one * size, pivot, glow, Enum.Material.Neon)
		burst.Parent = fxFolder
		tween(burst, 0.5, { Size = Vector3.one * size * 2.5, Transparency = 1 })
		task.delay(0.6, function()
			burst:Destroy()
		end)
	end
end

local function addLabel(model: Model)
	if labels[model] then
		return
	end
	local sizeId = model:GetAttribute("Size")
	local typeId = model:GetAttribute("Type")
	if typeof(sizeId) ~= "string" or typeof(typeId) ~= "string" or not CLASSES[sizeId] then
		return
	end
	local part = model.PrimaryPart or model:WaitForChild("Shell", 5)
	if not part or not part:IsA("BasePart") or not model.Parent then
		return
	end
	local class = CLASSES[sizeId]
	local color = StarConfig.color(typeId)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = `StarLabel_{model.Name}`
	billboard.Size = UDim2.fromOffset(230, 80)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, class.size * 0.7 + 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = LABEL_MAX_DISTANCE
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false
	billboard.Adornee = part
	label(billboard, StarConfig.displayName(sizeId, typeId), UDim2.new(1, 0, 0, 30), UDim2.new(), color, 28)

	local details = Instance.new("Frame")
	details.BackgroundTransparency = 1
	details.Size = UDim2.new(1, 0, 0, 46)
	details.Position = UDim2.fromOffset(0, 32)
	details.Parent = billboard
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -20, 0, 20)
	bar.Position = UDim2.fromOffset(10, 0)
	bar.BackgroundColor3 = PANEL_COLOR
	bar.BackgroundTransparency = 0.1
	corner(bar, UDim.new(0, 8))
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = Color3.new(0, 0, 0)
	barStroke.Thickness = 2
	barStroke.Parent = bar
	bar.Parent = details
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	corner(fill, UDim.new(0, 8))
	fill.Parent = bar
	local hpText = label(bar, "", UDim2.fromScale(1, 1), UDim2.new(), Color3.new(1, 1, 1), 16)
	hpText.ZIndex = 2
	local timer = label(details, "", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 24), Color3.fromRGB(255, 236, 170), 18)

	billboard.Parent = player:WaitForChild("PlayerGui")

	local entry: Label = {
		billboard = billboard,
		details = details,
		fill = fill,
		hpText = hpText,
		timer = timer,
		part = part,
		connections = {},
	}
	labels[model] = entry
	table.insert(
		entry.connections,
		model:GetAttributeChangedSignal("Hp"):Connect(function()
			updateHp(model)
		end)
	)
	table.insert(
		entry.connections,
		model:GetAttributeChangedSignal("State"):Connect(function()
			if model:GetAttribute("State") == "Dying" then
				removeLabel(model)
				playDying(model)
			end
		end)
	)
	table.insert(
		entry.connections,
		model.AncestryChanged:Connect(function()
			if not model:IsDescendantOf(Workspace) then
				removeLabel(model)
			end
		end)
	)
	updateHp(model)
	if model:GetAttribute("State") == "Dying" then
		removeLabel(model)
	end
end

local function updateLabels()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local serverNow = now()
	for model, entry in labels do
		local distance = (camera.CFrame.Position - entry.part.Position).Magnitude
		entry.details.Visible = distance < DETAILS_DISTANCE
		local expiresAt = model:GetAttribute("ExpiresAt")
		if typeof(expiresAt) == "number" then
			entry.timer.Text = `Fades in {formatTime(expiresAt - serverNow)}`
		end
	end
end

-- ===== Ślady: blednięcie =====

local function scheduleScarFade(folder: Instance)
	local fadeAt = folder:GetAttribute("FadeAt")
	local fadeSeconds = folder:GetAttribute("FadeSeconds")
	if typeof(fadeAt) ~= "number" or typeof(fadeSeconds) ~= "number" then
		return
	end
	task.delay(math.max(0, fadeAt - now()), function()
		if not folder.Parent then
			return
		end
		local remaining = math.max(0.1, fadeAt + fadeSeconds - now())
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("BasePart") then
				tween(descendant, remaining, { Transparency = 1 }, Enum.EasingStyle.Linear)
			elseif descendant:IsA("ParticleEmitter") then
				descendant.Enabled = false
			end
		end
	end)
end

local function watchScar(folder: Instance)
	folder:GetAttributeChangedSignal("FadeAt"):Once(function()
		scheduleScarFade(folder)
	end)
	scheduleScarFade(folder)
end

-- ===== Kompas =====

local function buildHud()
	local playerGui = player:WaitForChild("PlayerGui")

	local bannerGui = Instance.new("ScreenGui")
	bannerGui.Name = "StarBanner"
	bannerGui.ResetOnSpawn = false
	bannerGui.DisplayOrder = 6
	bannerGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	bannerList = Instance.new("Frame")
	bannerList.BackgroundTransparency = 1
	bannerList.AnchorPoint = Vector2.new(0.5, 0)
	bannerList.Position = UDim2.new(0.5, 0, 0, 8)
	bannerList.Size = UDim2.new(0.62, 0, 0, 200)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(520, 200)
	sizeLimit.Parent = bannerList
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = bannerList
	bannerList.Parent = bannerGui
	bannerGui.Parent = playerGui

	-- Kompas w pikselach viewportu (IgnoreGuiInset + bez wcięć), żeby pasował do WorldToViewportPoint.
	local compassGui = Instance.new("ScreenGui")
	compassGui.Name = "StarCompass"
	compassGui.ResetOnSpawn = false
	compassGui.IgnoreGuiInset = true
	compassGui.ScreenInsets = Enum.ScreenInsets.None
	compassGui.DisplayOrder = 5

	compassArrow = Instance.new("Frame")
	compassArrow.Name = "Arrow"
	compassArrow.AnchorPoint = Vector2.new(0.5, 0.5)
	compassArrow.Size = UDim2.fromOffset(52, 52)
	compassArrow.BackgroundColor3 = PANEL_COLOR
	compassArrow.BackgroundTransparency = 0.25
	compassArrow.Visible = false
	corner(compassArrow, UDim.new(1, 0))
	compassArrowStroke = Instance.new("UIStroke")
	compassArrowStroke.Thickness = 3
	compassArrowStroke.Parent = compassArrow
	-- Grot „>” z dwóch belek; cały kontener obraca się w stronę gwiazdy.
	for _, sign in { -1, 1 } do
		local arm = Instance.new("Frame")
		arm.AnchorPoint = Vector2.new(0.5, 0.5)
		arm.Size = UDim2.fromOffset(22, 7)
		arm.Position = UDim2.new(0.5, 2, 0.5, sign * 7)
		arm.Rotation = -sign * 40
		arm.BackgroundColor3 = Color3.new(1, 1, 1)
		arm.BorderSizePixel = 0
		corner(arm, UDim.new(1, 0))
		arm.Parent = compassArrow
	end
	compassArrow.Parent = compassGui
	compassArrowLabel = label(compassGui, "", UDim2.fromOffset(170, 40), UDim2.new(), Color3.new(1, 1, 1), 18)
	compassArrowLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	compassArrowLabel.Visible = false

	compassMarker = Instance.new("Frame")
	compassMarker.Name = "Marker"
	compassMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	compassMarker.Size = UDim2.fromOffset(20, 20)
	compassMarker.Rotation = 45
	compassMarker.Visible = false
	local markerStroke = Instance.new("UIStroke")
	markerStroke.Color = Color3.new(1, 1, 1)
	markerStroke.Thickness = 2
	markerStroke.Parent = compassMarker
	compassMarker.Parent = compassGui
	compassMarkerLabel = label(compassGui, "", UDim2.fromOffset(170, 22), UDim2.new(), Color3.new(1, 1, 1), 18)
	compassMarkerLabel.AnchorPoint = Vector2.new(0.5, 0)
	compassMarkerLabel.Visible = false

	compassGui.Parent = playerGui
end

local function hideCompass()
	compassArrow.Visible = false
	compassArrowLabel.Visible = false
	compassMarker.Visible = false
	compassMarkerLabel.Visible = false
end

local function updateCompass(serverNow: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local origin = if root then root.Position else camera.Focus.Position

	local best: ClientStar? = nil
	local bestDistance = math.huge
	for _, star in known do
		local distance = (star.info.impactPos - origin).Magnitude
		if distance < bestDistance then
			best, bestDistance = star, distance
		end
	end
	if not best then
		hideCompass()
		return
	end

	local info = best.info
	local class = CLASSES[info.size]
	local color = StarConfig.color(info.type)
	local falling = serverNow < info.impactAt
	local target = info.impactPos + Vector3.yAxis * (if falling then 2 else class.size * 0.5)
	local meters = `{formatNumber(bestDistance)}m`
	local viewport = camera.ViewportSize
	local point, onScreen = camera:WorldToViewportPoint(target)

	local inView = onScreen
		and point.Z > 0
		and point.X > EDGE_MARGIN
		and point.X < viewport.X - EDGE_MARGIN
		and point.Y > EDGE_MARGIN
		and point.Y < viewport.Y - EDGE_MARGIN
	if inView then
		compassArrow.Visible = false
		compassArrowLabel.Visible = false
		-- Spadająca gwiazda ma licznik nad punktem uderzenia, więc pokazujemy tylko etykietę pod nim.
		local showLabel = falling or bestDistance > LABEL_HIDE_MARKER
		compassMarker.Visible = showLabel and not falling
		compassMarkerLabel.Visible = showLabel
		if showLabel then
			compassMarker.BackgroundColor3 = color
			compassMarker.Position = UDim2.fromOffset(point.X, point.Y)
			compassMarkerLabel.Position = UDim2.fromOffset(point.X, point.Y + (if falling then 26 else 16))
			compassMarkerLabel.TextColor3 = color
			compassMarkerLabel.Text = if falling
				then `Impact {math.ceil(info.impactAt - serverNow)}s · {meters}`
				else meters
		end
		return
	end

	compassMarker.Visible = false
	compassMarkerLabel.Visible = false
	local center = viewport / 2
	local dx, dy = point.X - center.X, point.Y - center.Y
	if point.Z < 0 then
		dx, dy = -dx, -dy
	end
	if math.abs(dx) < 1e-3 and math.abs(dy) < 1e-3 then
		dy = 1
	end
	local scale = math.min(
		(center.X - EDGE_MARGIN) / math.max(math.abs(dx), 1e-3),
		(center.Y - EDGE_MARGIN) / math.max(math.abs(dy), 1e-3)
	)
	local px, py = center.X + dx * scale, center.Y + dy * scale
	local length = math.sqrt(dx * dx + dy * dy)
	compassArrow.Visible = true
	compassArrow.Position = UDim2.fromOffset(px, py)
	compassArrow.Rotation = math.deg(math.atan2(dy, dx))
	compassArrowStroke.Color = color
	compassArrowLabel.Visible = true
	compassArrowLabel.Position = UDim2.fromOffset(px - dx / length * 62, py - dy / length * 44)
	compassArrowLabel.TextColor3 = color
	compassArrowLabel.Text = `{StarConfig.displayName(info.size, info.type)}\n{meters}`
end

-- ===== Pętla =====

local function onRender(dt: number)
	local serverNow = now()
	for _, star in known do
		local info = star.info
		local fall = star.fall
		if fall then
			local alpha = (serverNow - info.launchedAt) / math.max(info.impactAt - info.launchedAt, 0.01)
			local position = StarConfig.fallPosition(info.startPos, info.impactPos, alpha)
			fall.orb.CFrame = CFrame.lookAlong(position, fall.direction)
			local diameter = StarConfig.craterRadius(info.size) * 2 * (0.3 + 0.7 * math.clamp(alpha, 0, 1))
			fall.shadow.Size = Vector3.new(0.6, diameter, diameter)
			fall.shadow.Transparency = 0.85 - 0.5 * math.clamp(alpha, 0, 1)
			fall.danger.Transparency = 0.8 + 0.1 * math.sin(serverNow * 8)
			fall.countdown.Text = string.format("%.1f", math.max(0, info.impactAt - serverNow))
		end
		if not star.impacted and serverNow >= info.impactAt then
			playImpact(star)
		end
		local banner = star.banner
		if banner then
			if serverNow >= banner.removeAt then
				removeBanner(banner)
				star.banner = nil
			elseif serverNow < info.impactAt then
				banner.sub.Text = `Impact in {math.ceil(info.impactAt - serverNow)}s`
			else
				banner.sub.Text = "LANDED! Go crack it!"
			end
		end
	end

	updateCompass(serverNow)

	labelClock += dt
	if labelClock >= LABEL_UPDATE_SECONDS then
		labelClock = 0
		updateLabels()
	end
end

local function onShake()
	local clock = os.clock()
	if clock >= shakeUntil then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local k = (shakeUntil - clock) / shakeDuration
	local s = shakeStrength * k * k
	camera.CFrame *= CFrame.new(rng:NextNumber(-1, 1) * s * 0.35, rng:NextNumber(-1, 1) * s * 0.35, 0) * CFrame.Angles(
		rng:NextNumber(-1, 1) * s * 0.012,
		rng:NextNumber(-1, 1) * s * 0.012,
		rng:NextNumber(-1, 1) * s * 0.008
	)
end

local function onStarEvent(kind: unknown, payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local data = payload :: any
	if kind == "Incoming" or kind == "Landed" then
		addStar(data :: StarInfo)
	elseif kind == "Gone" and typeof(data.id) == "string" then
		removeStar(data.id)
	end
end

function StarFxController.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "StarFx"
	fxFolder.Parent = Workspace
	buildHud()
	Remotes.connect("StarEvent", onStarEvent)
end

function StarFxController.Start()
	RunService.RenderStepped:Connect(onRender)
	RunService:BindToRenderStep("StarShake", Enum.RenderPriority.Camera.Value + 1, onShake)

	task.spawn(function()
		local activeStars = Workspace:WaitForChild("ActiveStars")
		activeStars.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				addLabel(child)
			end
		end)
		for _, child in activeStars:GetChildren() do
			if child:IsA("Model") then
				task.spawn(addLabel, child)
			end
		end
	end)
	task.spawn(function()
		local scars = Workspace:WaitForChild("StarScars")
		scars.ChildAdded:Connect(watchScar)
		for _, child in scars:GetChildren() do
			watchScar(child)
		end
	end)

	local list = Remotes.invoke("RequestStars")
	if typeof(list) == "table" then
		for _, info in list :: { StarInfo } do
			addStar(info)
		end
		log:debug(`Aktywne gwiazdy przy wejściu: {#(list :: { any })}`)
	end
end

return StarFxController
