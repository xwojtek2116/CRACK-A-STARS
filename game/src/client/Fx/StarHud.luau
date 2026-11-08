--!strict
-- StarHud — interfejs gwiazd: baner ogłoszenia (wjazd z glitchem, pasek do uderzenia), napis nad leżącą
-- gwiazdą (nazwa, HP, czas do zgaśnięcia) i kompas (strzałka na krawędzi ekranu albo znacznik w kadrze).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarConfig = require(Shared.Config.StarConfig)
local Types = require(Shared.Types)
local VfxIds = require(Shared.Config.VfxIds)

local FxUtil = require(script.Parent.FxUtil)
local Store = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Store"))

type StarInfo = Types.StarInfo

type Banner = { info: StarInfo, removeAt: number }

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
local FONT = Enum.Font.FredokaOne
local PANEL_COLOR = Color3.fromRGB(22, 16, 44)
local DETAILS_DISTANCE = 260 -- bliżej: pasek HP i licznik nad gwiazdą
local LABEL_HIDE_MARKER = 300 -- leżąca gwiazda bliżej niż to: znacznik kompasu chowa się
local LABEL_MAX_DISTANCE = 1500 -- dalej gwiazdę wskazuje tylko kompas
local EDGE_MARGIN = 72
local BANNER_LINGER = 3 -- s po uderzeniu

local player = Players.LocalPlayer

local banners: { [string]: Banner } = {}
local labels: { [Model]: Label } = {}
local compassArrow: Frame
local compassArrowStroke: UIStroke
local compassArrowLabel: TextLabel
local compassMarker: Frame
local compassMarkerLabel: TextLabel

local StarHud = {}

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

local function corner(parent: Instance, radius: UDim)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = radius
	uiCorner.Parent = parent
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

-- ===== Pasek gwiazdy (T13) =====
-- Ogłoszenia spadających gwiazd rysuje pasek w HUD (UI/Hud → StarBar). Tu tylko lista w UI/Store
-- i usuwanie wpisu BANNER_LINGER s po uderzeniu.

local function removeBanner(id: string)
	if banners[id] then
		banners[id] = nil
		Store.removeIncoming(id)
	end
end

function StarHud.showBanner(info: StarInfo)
	if banners[info.id] then
		return
	end
	banners[info.id] = { info = info, removeAt = info.impactAt + BANNER_LINGER }
	Store.addIncoming({
		id = info.id,
		name = StarConfig.displayName(info.size, info.type),
		color = StarConfig.color(info.type),
		glow = StarConfig.glow(info.type),
		launchedAt = info.launchedAt,
		impactAt = info.impactAt,
	})
end

function StarHud.hideBanner(id: string)
	removeBanner(id)
end

local function updateBanners(serverNow: number)
	for id, banner in banners do
		if serverNow >= banner.removeAt then
			removeBanner(id)
		end
	end
end

-- ===== Napis nad leżącą gwiazdą =====

function StarHud.removeLabel(model: Model)
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
	FxUtil.tween(entry.fill, 0.15, { Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1) })
	entry.hpText.Text = `{formatNumber(hp)} / {formatNumber(maxHp)}`
end

function StarHud.addLabel(model: Model)
	if labels[model] then
		return
	end
	local sizeId = model:GetAttribute("Size")
	local typeId = model:GetAttribute("Type")
	if typeof(sizeId) ~= "string" or typeof(typeId) ~= "string" or not CLASSES[sizeId] then
		return
	end
	local part = model.PrimaryPart or model:FindFirstChild("Shell")
	if not part or not part:IsA("BasePart") or not model.Parent or model:GetAttribute("State") == "Dying" then
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
	updateHp(model)
end

local function updateLabels(serverNow: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	for model, entry in labels do
		if not model:IsDescendantOf(Workspace) then
			StarHud.removeLabel(model)
			continue
		end
		local distance = (camera.CFrame.Position - entry.part.Position).Magnitude
		entry.details.Visible = distance < DETAILS_DISTANCE
		local expiresAt = model:GetAttribute("ExpiresAt")
		if typeof(expiresAt) == "number" then
			entry.timer.Text = `Fades in {formatTime(expiresAt - serverNow)}`
		end
	end
end

-- ===== Kompas =====

local function hideCompass()
	compassArrow.Visible = false
	compassArrowLabel.Visible = false
	compassMarker.Visible = false
	compassMarkerLabel.Visible = false
end

local function updateCompass(serverNow: number, stars: { StarInfo })
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local origin = if root then root.Position else camera.Focus.Position

	local best: StarInfo? = nil
	local bestDistance = math.huge
	for _, info in stars do
		local distance = (info.impactPos - origin).Magnitude
		if distance < bestDistance then
			best, bestDistance = info, distance
		end
	end
	if not best then
		hideCompass()
		return
	end

	local info = best
	local class = CLASSES[info.size]
	local color = StarConfig.color(info.type)
	local falling = serverNow < info.impactAt
	local target = info.impactPos + Vector3.yAxis * (if falling then 2 else class.size * 0.5)
	local meters = `{formatNumber(bestDistance)}m`
	local viewport = camera.ViewportSize
	local point, onScreen = camera:WorldToViewportPoint(target)

	-- Lewa krawędź: za menu HUD (atrybut HudLeftInset z UI/Hud), żeby strzałka nie wchodziła na przyciski.
	local leftMargin = math.max(EDGE_MARGIN, (tonumber(player.PlayerGui:GetAttribute("HudLeftInset")) or 0) + 40)
	local inView = onScreen
		and point.Z > 0
		and point.X > leftMargin
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
	-- Środek obszaru strzałki (prostokąt od leftMargin do prawej krawędzi), nie ekranu.
	local center = Vector2.new((leftMargin + viewport.X - EDGE_MARGIN) / 2, viewport.Y / 2)
	local dx, dy = point.X - viewport.X / 2, point.Y - center.Y
	if point.Z < 0 then
		dx, dy = -dx, -dy
	end
	if math.abs(dx) < 1e-3 and math.abs(dy) < 1e-3 then
		dy = 1
	end
	local scale = math.min(
		(center.X - leftMargin) / math.max(math.abs(dx), 1e-3),
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

function StarHud.update(serverNow: number, stars: { StarInfo })
	updateBanners(serverNow)
	updateCompass(serverNow, stars)
end

function StarHud.updateLabels(serverNow: number)
	updateLabels(serverNow)
end

-- ===== Kino (Large+): pasy i karta tytułowa =====

local cinemaGui: ScreenGui
local barTop: Frame
local barBottom: Frame
local cinemaHolds: { [string]: boolean } = {}
local CINEMA = FxUtil.CONFIG.CINEMA

local function setBars(visible: boolean)
	local height = if visible then CINEMA.barHeight else 0
	FxUtil.tween(barTop, 0.5, { Size = UDim2.fromScale(1, height) }, Enum.EasingStyle.Quint)
	FxUtil.tween(barBottom, 0.5, { Size = UDim2.fromScale(1, height) }, Enum.EasingStyle.Quint)
end

-- Pasy trzymane przez źródło `id` do czasu `untilServer` (GetServerTimeNow).
function StarHud.holdBars(id: string, untilServer: number)
	cinemaHolds[id] = true
	setBars(true)
	task.delay(math.max(0, untilServer - Workspace:GetServerTimeNow()), function()
		cinemaHolds[id] = nil
		if next(cinemaHolds) == nil then
			setBars(false)
		end
	end)
end

-- Karta tytułowa na środku ekranu; po zniknięciu w rogu zostaje mały baner.
function StarHud.showTitle(info: StarInfo)
	local color = StarConfig.color(info.type)
	local glow = StarConfig.glow(info.type)
	local card = Instance.new("Frame")
	card.Name = `Title_{info.id}`
	card.BackgroundTransparency = 1
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.36)
	card.Size = UDim2.fromScale(0.86, 0.22)
	local scale = Instance.new("UIScale")
	scale.Scale = 1.6
	scale.Parent = card
	local flare = Instance.new("ImageLabel")
	flare.BackgroundTransparency = 1
	flare.Image = VfxIds.FLARE
	flare.ImageColor3 = glow
	flare.AnchorPoint = Vector2.new(0.5, 0.5)
	flare.Position = UDim2.fromScale(0.5, 0.45)
	flare.Size = UDim2.fromScale(1.2, 2.2)
	flare.ImageTransparency = 0.2
	flare.Parent = card
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = FONT
	title.TextScaled = true
	title.Text = StarConfig.displayName(info.size, info.type):upper()
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Size = UDim2.fromScale(1, 0.62)
	title.TextTransparency = 1
	local gradient = Instance.new("UIGradient")
	gradient.Color = FxUtil.colorSeq(FxUtil.lighten(glow, 0.5), color, FxUtil.lighten(glow, 0.5))
	gradient.Rotation = 90
	gradient.Parent = title
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 1
	stroke.Parent = title
	title.Parent = card
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Font = FONT
	sub.TextScaled = true
	sub.Text = "IS TEARING THROUGH THE SKY!"
	sub.TextColor3 = Color3.new(1, 1, 1)
	sub.Position = UDim2.fromScale(0.15, 0.64)
	sub.Size = UDim2.fromScale(0.7, 0.26)
	sub.TextTransparency = 1
	local subStroke = stroke:Clone()
	subStroke.Thickness = 3
	subStroke.Parent = sub
	sub.Parent = card
	card.Parent = cinemaGui

	FxUtil.tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	FxUtil.tween(title, 0.25, { TextTransparency = 0 })
	FxUtil.tween(stroke, 0.25, { Transparency = 0 })
	FxUtil.tween(flare, 1.2, { Size = UDim2.fromScale(2, 0.6), ImageTransparency = 1 })
	task.delay(0.25, function()
		FxUtil.tween(sub, 0.3, { TextTransparency = 0 })
		FxUtil.tween(subStroke, 0.3, { Transparency = 0 })
	end)
	task.delay(CINEMA.titleSeconds, function()
		FxUtil.tween(scale, 0.35, { Scale = 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		for _, item in { title, sub } do
			FxUtil.tween(item, 0.3, { TextTransparency = 1 })
		end
		FxUtil.tween(stroke, 0.3, { Transparency = 1 })
		FxUtil.tween(subStroke, 0.3, { Transparency = 1 })
		task.delay(0.4, function()
			card:Destroy()
			if Workspace:GetServerTimeNow() < info.impactAt then
				StarHud.showBanner(info)
			end
		end)
	end)
end

function StarHud.build()
	local playerGui = player:WaitForChild("PlayerGui")

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

	-- Kino: pasy i karta tytułowa nad wszystkim.
	cinemaGui = Instance.new("ScreenGui")
	cinemaGui.Name = "StarCinema"
	cinemaGui.ResetOnSpawn = false
	cinemaGui.IgnoreGuiInset = true
	cinemaGui.ScreenInsets = Enum.ScreenInsets.None
	cinemaGui.DisplayOrder = 8
	barTop = Instance.new("Frame")
	barTop.BackgroundColor3 = Color3.new(0, 0, 0)
	barTop.BorderSizePixel = 0
	barTop.Size = UDim2.fromScale(1, 0)
	barTop.Parent = cinemaGui
	barBottom = barTop:Clone()
	barBottom.AnchorPoint = Vector2.new(0, 1)
	barBottom.Position = UDim2.fromScale(0, 1)
	barBottom.Parent = cinemaGui
	cinemaGui.Parent = playerGui
end

return StarHud
