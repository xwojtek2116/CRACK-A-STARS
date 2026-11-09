--!strict
-- Loot/Reveal — karta łupu po rozbiciu gwiazdy (T07), tylko u gracza, który dostał łup.
--   nagłówek „<GWIAZDA> CRACKED!” + luck, rząd kart (po jednej na losowanie), pod spodem postęp pity.
--   Karta: poświata i promienie w kolorze rzadkości, klejnot (do czasu renderów przedmiotów), pigułka
--   rzadkości, nazwa, $/s, mutacja (Shiny = błysk, Golden = złota ramka), NEW!, PITY!, postument/ekwipunek.
--   Od Epic karta najpierw jest zakryta i pulsuje kolorem rzadkości (napięcie, max 1,5 s — GDD), potem obrót.
--   T14: karta przechyla się za kursorem/palcem (tilt) z odbłyskiem, który wędruje po karcie, przy odkryciu
--   rozbłysk na karcie i fala światła; od Rare co chwilę przelatuje shine; od Legendary drugie, przeciwbieżne
--   promienie, które pulsują (Mythic/Secret większe). Liczby: LootConfig.REVEAL.tilt / rays.
-- Nie blokuje sterowania; dotknięcie kart zamyka wcześniej. Pełne animacje dropu (kamera): T35.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LootConfig = require(Shared.Config.LootConfig)
local StarConfig = require(Shared.Config.StarConfig)

local UI = script.Parent.Parent
local Format = require(UI.Format)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local Fx = require(script.Parent.Fx)
local SoundController = require(UI.Parent.Controllers.SoundController)

local REVEAL = LootConfig.REVEAL
local COLORS = Theme.COLORS
local CARD = Vector2.new(150, 214)
local GAP = 30
local MAX_ROW_WIDTH = 940 -- szerszy rząd (Supernova, 6 kart) dostaje mniejszą skalę
local TILT = REVEAL.tilt
local RAYS = REVEAL.rays

local player = Players.LocalPlayer

export type Drop = {
	uid: string,
	itemId: string,
	name: string,
	rarity: string,
	mutation: string,
	income: number,
	slot: number?,
	isNew: boolean,
	pity: string?,
}

export type Payload = {
	starId: string,
	star: string,
	size: string,
	type: string,
	share: number,
	luck: number,
	drops: { Drop },
	pity: { [string]: { count: number, max: number } },
	themesCompleted: { string }?,
}

local screen: ScreenGui? = nil
local token = 0
-- Ostatnia pozycja dotyku (telefon nie ma kursora) — do przechyłu kart.
local pointer: Vector2? = nil

local Reveal = {}

local function getScreen(): ScreenGui
	if screen and screen.Parent then
		return screen
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LootReveal"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	screen = gui
	return gui
end

local function rank(rarity: string): number
	return LootConfig.rarityRank(rarity)
end

-- Dźwięk odkrycia wg rzadkości (wysokość rośnie z rzadkością).
local function revealSound(rarity: string)
	local r = rank(rarity)
	if r >= rank("Mythic") then
		SoundController.play2D("musicImpact", 0.9)
		SoundController.play2D("roundPerfect", 1, 1.12)
	elseif r >= rank("Legendary") then
		SoundController.play2D("roundPerfect", 1)
		SoundController.play2D("hitWeak", 0.7, 1.2)
	elseif r >= rank("Epic") then
		SoundController.play2D("hitWeak", 0.9)
	elseif r >= rank("Rare") then
		SoundController.play2D("hitPerfect", 0.7, 1.1)
	else
		SoundController.play2D("uiCoin", 0.8, 0.9 + r * 0.08)
	end
end

local function pill(
	parent: Instance,
	text: string,
	fill: ColorSequence,
	size: UDim2,
	position: UDim2,
	maxSize: number
): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	Fx.corner(frame, Theme.PILL)
	Fx.gradient(frame, fill)
	Fx.stroke(frame, COLORS.ink, 2)
	Fx.text(frame, {
		text = text,
		size = UDim2.fromScale(0.86, 0.78),
		position = UDim2.fromScale(0.5, 0.5),
		maxSize = maxSize,
		stroke = 2,
	})
	frame.Parent = parent
	return frame
end

-- Klejnot w kolorze rzadkości (zastępczy obrazek przedmiotu): romb z połyskiem, kształt rośnie z rzadkością.
local function gem(parent: Instance, rarity: string, mutation: string): Frame
	local color = Fx.rarityColor(rarity)
	local holder = Instance.new("Frame")
	holder.Name = "Gem"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.42)
	holder.Size = UDim2.fromOffset(92, 92)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local halo = Instance.new("ImageLabel")
	halo.Image = Theme.FX.flare
	halo.ImageColor3 = color
	halo.ImageTransparency = 0.25
	halo.BackgroundTransparency = 1
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(1.9, 1.9)
	halo.Parent = holder
	Fx.loop(halo, 1.3, { ImageTransparency = 0.5, Size = UDim2.fromScale(1.6, 1.6) })

	local r = rank(rarity)
	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	local side = 42 + r * 4
	body.Size = UDim2.fromOffset(side, side)
	body.Rotation = 45
	body.BackgroundColor3 = Color3.new(1, 1, 1)
	Fx.corner(body, UDim.new(0, 6 + r))
	Fx.gradient(
		body,
		if mutation == "Golden" then Fx.GOLD elseif mutation == "Shiny" then Fx.SHINY else Fx.rarityFill(rarity),
		-45
	)
	Fx.stroke(body, COLORS.ink, 3)
	body.Parent = holder

	-- Fasetka i odblask.
	local facet = Instance.new("Frame")
	facet.AnchorPoint = Vector2.new(0.5, 0.5)
	facet.Position = UDim2.fromScale(0.5, 0.5)
	facet.Size = UDim2.fromScale(0.52, 0.52)
	facet.BackgroundColor3 = Color3.new(1, 1, 1)
	facet.BackgroundTransparency = 0.55
	Fx.corner(facet, UDim.new(0, 4))
	facet.Parent = body
	local glare = Instance.new("Frame")
	glare.Position = UDim2.fromScale(0.12, 0.12)
	glare.Size = UDim2.fromScale(0.22, 0.22)
	glare.BackgroundColor3 = Color3.new(1, 1, 1)
	glare.BackgroundTransparency = 0.1
	Fx.corner(glare, Theme.PILL)
	glare.Parent = body

	-- Orbitujące odłamki od Legendary (jak opis kształtu w Items.json → shapes).
	if r >= rank("Legendary") then
		local orbit = Instance.new("Frame")
		orbit.AnchorPoint = Vector2.new(0.5, 0.5)
		orbit.Position = UDim2.fromScale(0.5, 0.5)
		orbit.Size = UDim2.fromScale(1.15, 1.15)
		orbit.BackgroundTransparency = 1
		orbit.Parent = holder
		for i = 1, r - 3 do
			local bit = Instance.new("Frame")
			bit.AnchorPoint = Vector2.new(0.5, 0.5)
			local angle = i / (r - 3) * math.pi * 2
			bit.Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.5, 0.5 + math.sin(angle) * 0.5)
			bit.Size = UDim2.fromOffset(9, 9)
			bit.Rotation = 45
			bit.BackgroundColor3 = Theme.lighten(color, 0.35)
			Fx.stroke(bit, COLORS.ink, 2)
			bit.Parent = orbit
		end
		Fx.loop(orbit, 5 - r * 0.4, { Rotation = 360 }, false)
	end

	local twinkle = Instance.new("ImageLabel")
	twinkle.Image = Theme.FX.glint
	twinkle.BackgroundTransparency = 1
	twinkle.AnchorPoint = Vector2.new(0.5, 0.5)
	twinkle.Position = UDim2.fromScale(0.68, 0.3)
	twinkle.Size = UDim2.fromOffset(26, 26)
	twinkle.ImageTransparency = 1
	twinkle.ZIndex = 3
	twinkle.Parent = holder
	Fx.loop(twinkle, 0.9, { ImageTransparency = 0.05, Rotation = 90 })

	-- Unoszenie.
	Fx.loop(holder, 1.4, { Position = UDim2.fromScale(0.5, 0.39) })
	return holder
end

local function buildCard(drop: Drop): (Frame, Frame, Frame?)
	local color = Fx.rarityColor(drop.rarity)
	local r = rank(drop.rarity)

	-- Wrapper (stały rozmiar w rzędzie) → poświata za kartą + karta (obraca się przy odkryciu).
	local wrapper = Instance.new("Frame")
	wrapper.Name = drop.uid
	wrapper.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	wrapper.BackgroundTransparency = 1
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = wrapper

	if r >= rank("Rare") then
		local rays = Instance.new("ImageLabel")
		rays.Name = "Rays"
		rays.Image = Theme.FX.glint
		rays.ImageColor3 = color
		rays.ImageTransparency = 0.35
		rays.BackgroundTransparency = 1
		rays.AnchorPoint = Vector2.new(0.5, 0.5)
		rays.Position = UDim2.fromScale(0.5, 0.45)
		rays.SizeConstraint = Enum.SizeConstraint.RelativeXX
		rays.Size = UDim2.fromScale(1.6 + r * 0.12, 1.6 + r * 0.12)
		rays.Parent = wrapper
		Fx.loop(rays, 9 - r, { Rotation = 360 }, false)
	end
	if r >= rank("Legendary") then
		-- Promienie „sunburst” z pasków (niezależne od tekstur): obracają się w drugą stronę i pulsują,
		-- Mythic/Secret mają ich więcej i dłuższe; Secret w tęczy.
		local back = Instance.new("Frame")
		back.Name = "RaysBack"
		back.BackgroundTransparency = 1
		back.AnchorPoint = Vector2.new(0.5, 0.5)
		back.Position = UDim2.fromScale(0.5, 0.45)
		back.SizeConstraint = Enum.SizeConstraint.RelativeXX
		local size = RAYS.backSize + (r - rank("Legendary")) * RAYS.backGrowth
		back.Size = UDim2.fromScale(size, size)
		back.ZIndex = 0
		local beams = RAYS.beams + (r - rank("Legendary")) * 2
		local fade = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, RAYS.backTransparency),
			NumberSequenceKeypoint.new(0.5, RAYS.backTransparency - 0.2),
			NumberSequenceKeypoint.new(0.8, RAYS.backTransparency),
			NumberSequenceKeypoint.new(1, 1),
		})
		for i = 1, beams do
			local beam = Instance.new("Frame")
			beam.Name = `Beam{i}`
			beam.AnchorPoint = Vector2.new(0.5, 0.5)
			beam.Position = UDim2.fromScale(0.5, 0.5)
			beam.Size = UDim2.new(0, RAYS.beamWidth, 1, 0)
			beam.Rotation = (i - 1) * 180 / beams
			beam.BackgroundColor3 = Theme.lighten(color, 0.3)
			beam.BorderSizePixel = 0
			beam.ZIndex = 0
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = 90
			gradient.Transparency = fade
			if drop.rarity == "Secret" then
				gradient.Color = Theme.SECRET_GRADIENT
			end
			gradient.Parent = beam
			beam.Parent = back
		end
		local backScale = Instance.new("UIScale")
		backScale.Parent = back
		back.Parent = wrapper
		Fx.loop(back, RAYS.backSpin, { Rotation = -360 }, false)
		Fx.loop(backScale, RAYS.pulse, { Scale = 1.12 })
	end
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.Image = Theme.FX.flare
	glow.ImageColor3 = color
	glow.ImageTransparency = if r >= rank("Epic") then 0.2 else 0.55
	glow.BackgroundTransparency = 1
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.SizeConstraint = Enum.SizeConstraint.RelativeXX
	glow.Size = UDim2.fromScale(1.5 + r * 0.1, 1.5 + r * 0.1)
	glow.Parent = wrapper

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.ClipsDescendants = false
	card.ZIndex = 2
	Fx.corner(card)
	Fx.gradient(card, Theme.SPACE_GRADIENT)
	local frameStroke = Fx.stroke(
		card,
		if drop.mutation == "Golden" then COLORS.gold else color,
		if r >= rank("Legendary") then 4 else 3
	)
	if drop.rarity == "Secret" or drop.mutation == "Golden" then
		Fx.gradient(frameStroke, if drop.rarity == "Secret" then Theme.SECRET_GRADIENT else Fx.GOLD, 45)
	end
	card.Parent = wrapper

	-- Mgławica w tle karty, podbarwiona rzadkością.
	local nebula = Instance.new("ImageLabel")
	nebula.Image = Theme.FX.nebula
	nebula.ImageColor3 = color
	nebula.ImageTransparency = 0.7
	nebula.BackgroundTransparency = 1
	nebula.Size = UDim2.fromScale(1, 1)
	nebula.ScaleType = Enum.ScaleType.Crop
	nebula.ZIndex = 2
	Fx.corner(nebula)
	nebula.Parent = card

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.ZIndex = 3
	content.Parent = card

	pill(
		content,
		string.upper(drop.rarity),
		Fx.rarityFill(drop.rarity),
		UDim2.fromOffset(104, 26),
		UDim2.fromScale(0.5, 0.08),
		18
	)
	gem(content, drop.rarity, drop.mutation)

	local name = Fx.text(content, {
		text = drop.name,
		size = UDim2.new(0.9, 0, 0, 30),
		position = UDim2.fromScale(0.5, 0.7),
		maxSize = 22,
	})
	if drop.mutation == "Golden" then
		Fx.gradient(name, Fx.GOLD)
	elseif drop.mutation == "Shiny" then
		Fx.gradient(name, Fx.SHINY)
	end
	Fx.text(content, {
		text = `+{Format.cash(drop.income)}/s`,
		size = UDim2.new(0.8, 0, 0, 22),
		position = UDim2.fromScale(0.5, 0.82),
		color = COLORS.cash,
		maxSize = 20,
	})
	Fx.text(content, {
		text = if drop.slot then `→ Pedestal {drop.slot}` else "→ Inventory (base full)",
		size = UDim2.new(0.86, 0, 0, 16),
		position = UDim2.fromScale(0.5, 0.92),
		color = if drop.slot then COLORS.textMuted else COLORS.compass,
		font = Theme.FONTS.body,
		maxSize = 14,
		stroke = 2,
	})

	if drop.mutation ~= "None" then
		local tag = pill(
			content,
			string.upper(drop.mutation),
			if drop.mutation == "Golden" then Fx.GOLD else Fx.SHINY,
			UDim2.fromOffset(78, 22),
			UDim2.fromScale(0.5, 0.58),
			15
		)
		tag.Rotation = -4
		tag.ZIndex = 6
		Fx.shine(tag, 0.6, 1.2)
	end
	if drop.mutation == "Shiny" or r >= rank("Rare") then
		Fx.shine(
			card,
			0.8,
			if drop.mutation == "Shiny" then 0.9 elseif r >= rank("Legendary") then 2.2 else TILT.rareShinePause
		)
	end

	-- Odbłysk „tilt”: miękka smuga światła przesuwana za kursorem/palcem (Reveal.show → tiltStep).
	local sheen = Instance.new("Frame")
	sheen.Name = "Sheen"
	sheen.Size = UDim2.fromScale(1, 1)
	sheen.BackgroundColor3 = Color3.new(1, 1, 1)
	sheen.BackgroundTransparency = 0
	sheen.ZIndex = 7
	Fx.corner(sheen)
	local sheenGradient = Instance.new("UIGradient")
	sheenGradient.Name = "SheenGradient"
	sheenGradient.Rotation = 35
	sheenGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, TILT.sheenAlpha),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sheenGradient.Offset = Vector2.new(0.6, 0)
	sheenGradient.Parent = sheen
	sheen.Parent = card

	local badges = Instance.new("Frame")
	badges.Name = "Badges"
	badges.Size = UDim2.fromScale(1, 1)
	badges.BackgroundTransparency = 1
	badges.Visible = false
	badges.ZIndex = 8
	badges.Parent = card
	if drop.isNew then
		local new =
			pill(badges, "NEW!", Theme.duo(COLORS.neonMagenta), UDim2.fromOffset(58, 26), UDim2.new(1, -16, 0, -6), 17)
		new.Rotation = 12
		Fx.loop(new, 0.5, { Rotation = 4 })
	end
	if drop.pity then
		local pity = pill(badges, "PITY!", Fx.GOLD, UDim2.fromOffset(58, 24), UDim2.fromOffset(16, -6), 16)
		pity.Rotation = -12
	end

	-- Zasłona od Epic: znak zapytania pulsujący kolorem rzadkości.
	local cover: Frame? = nil
	if REVEAL.suspense[drop.rarity] then
		local veil = Instance.new("Frame")
		veil.Name = "Cover"
		veil.Size = UDim2.fromScale(1, 1)
		veil.BackgroundColor3 = Color3.new(1, 1, 1)
		veil.ZIndex = 10
		Fx.corner(veil)
		Fx.gradient(veil, ColorSequence.new(Theme.darken(color, 0.35), Theme.darken(color, 0.85)))
		local veilStroke = Fx.stroke(veil, color, 4)
		Fx.loop(veilStroke, 0.22, { Thickness = 7 })
		local mark = Fx.text(veil, {
			text = "?",
			size = UDim2.fromScale(0.6, 0.5),
			position = UDim2.fromScale(0.5, 0.48),
			maxSize = 96,
		})
		mark.ZIndex = 11
		Fx.loop(mark, 0.18, { Rotation = 8 })
		local starIcon = Instance.new("ImageLabel")
		starIcon.Image = Theme.FX.glint
		starIcon.ImageColor3 = color
		starIcon.BackgroundTransparency = 1
		starIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		starIcon.Position = UDim2.fromScale(0.5, 0.48)
		starIcon.Size = UDim2.fromScale(1.1, 0.8)
		starIcon.ZIndex = 10
		starIcon.Parent = veil
		Fx.loop(starIcon, 1.2, { Rotation = 360 }, false)
		veil.Parent = card
		cover = veil
	end

	return wrapper, card, cover
end

-- Obrót karty: zwężenie do zera, zdjęcie zasłony, rozszerzenie z odbiciem.
local function flip(card: Frame, cover: Frame?, onFlipped: () -> ())
	Fx.tween(card, 0.12, { Size = UDim2.fromScale(0.02, 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.12, function()
		if cover then
			cover:Destroy()
		end
		onFlipped()
		Fx.tween(card, 0.3, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Back)
	end)
end

local function pityBars(parent: Instance, pity: { [string]: { count: number, max: number } })
	local row = Instance.new("Frame")
	row.Name = "Pity"
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 1, 18)
	row.Size = UDim2.fromOffset(420, 22)
	row.BackgroundTransparency = 1
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 16)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local tiers = {}
	for tier in pity do
		table.insert(tiers, tier)
	end
	table.sort(tiers, function(a, b)
		return rank(a) < rank(b)
	end)
	for order, tier in tiers do
		local entry = pity[tier]
		local bar = Instance.new("Frame")
		bar.LayoutOrder = order
		bar.Size = UDim2.fromOffset(200, 20)
		bar.BackgroundColor3 = COLORS.panel
		Fx.corner(bar, Theme.PILL)
		Fx.stroke(bar, COLORS.ink, 2)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = Color3.new(1, 1, 1)
		Fx.corner(fill, Theme.PILL)
		Fx.gradient(fill, Fx.rarityFill(tier))
		fill.Parent = bar
		Fx.tween(
			fill,
			0.8,
			{ Size = UDim2.fromScale(math.clamp(entry.count / entry.max, 0, 1), 1) },
			Enum.EasingStyle.Quint
		)
		Fx.text(bar, {
			text = `{string.upper(tier)} GUARANTEE {entry.count}/{entry.max}`,
			size = UDim2.fromScale(0.94, 0.8),
			position = UDim2.fromScale(0.5, 0.5),
			font = Theme.FONTS.body,
			maxSize = 13,
			stroke = 2,
		}).ZIndex =
			2
		bar.Parent = row
	end
end

local function close(holder: Frame)
	if holder:GetAttribute("Closing") then
		return
	end
	holder:SetAttribute("Closing", true)
	Fx.tween(
		holder,
		0.28,
		{ Position = holder.Position + UDim2.fromScale(0, 0.12) },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	for _, child in holder:GetDescendants() do
		if child:IsA("TextLabel") then
			Fx.tween(child, 0.25, { TextTransparency = 1 })
		elseif child:IsA("ImageLabel") then
			Fx.tween(child, 0.25, { ImageTransparency = 1 })
		elseif child:IsA("Frame") and child.BackgroundTransparency < 1 then
			Fx.tween(child, 0.25, { BackgroundTransparency = 1 })
		elseif child:IsA("UIStroke") then
			Fx.tween(child, 0.25, { Transparency = 1 })
		end
	end
	task.delay(0.3, function()
		holder:Destroy()
	end)
end

-- Rozbłysk przy odkryciu: biała klatka na karcie gaśnie, fala światła w kolorze rzadkości rośnie zza karty.
local function cardFlash(wrapper: Frame, card: Frame, rarity: string)
	local r = rank(rarity)
	local flash = Instance.new("Frame")
	flash.Name = "RevealFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.1
	flash.ZIndex = 12
	Fx.corner(flash)
	flash.Parent = card
	Fx.tween(flash, 0.35 + r * 0.03, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
	local ring = Instance.new("ImageLabel")
	ring.Name = "RevealWave"
	ring.Image = Theme.FX.flare
	ring.ImageColor3 = Theme.lighten(Fx.rarityColor(rarity), 0.3)
	ring.ImageTransparency = 0.05
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.45)
	ring.SizeConstraint = Enum.SizeConstraint.RelativeXX
	ring.Size = UDim2.fromScale(0.4, 0.4)
	ring.ZIndex = 1
	ring.Parent = wrapper
	local reach = 2 + r * 0.25
	Fx.tween(ring, 0.6, { Size = UDim2.fromScale(reach, reach), ImageTransparency = 1 }, Enum.EasingStyle.Quart)
	task.delay(0.7, function()
		flash:Destroy()
		ring:Destroy()
	end)
end

local function pointerPosition(): Vector2?
	if UserInputService.MouseEnabled then
		local inset = GuiService:GetGuiInset()
		return UserInputService:GetMouseLocation() - inset
	end
	return pointer
end

type TiltCard = { wrapper: Frame, card: Frame, rank: number, ready: boolean }

-- Przechył kart i odbłysk: karta pod wskaźnikiem przechyla się w jego stronę, reszta (od Epic) lekko się kołysze.
local function tiltStep(cards: { TiltCard }, alpha: number)
	local at = pointerPosition()
	local t = os.clock()
	for i, entry in cards do
		if not entry.ready or not entry.wrapper.Parent then
			continue
		end
		local card = entry.card
		local half = card.AbsoluteSize / 2
		local center = card.AbsolutePosition + half
		local rel = Vector2.zero
		local hovered = false
		if at and half.X > 0 and half.Y > 0 then
			rel = (at - center) / half
			hovered = math.abs(rel.X) <= TILT.reach and math.abs(rel.Y) <= TILT.reach
		end
		local targetRotation, targetOffset
		if hovered then
			targetRotation = math.clamp(rel.X, -1, 1) * TILT.degrees
			targetOffset = math.clamp(rel.X * 0.5 + rel.Y * 0.3, -0.9, 0.9)
		else
			local sway = if entry.rank >= rank("Epic") then TILT.idleDegrees else 0
			targetRotation = math.sin(t * TILT.idleSpeed + i) * sway
			targetOffset = 0.6 + math.sin(t * TILT.idleSpeed * 0.5 + i) * 0.15
		end
		entry.wrapper.Rotation += (targetRotation - entry.wrapper.Rotation) * alpha
		local sheen = card:FindFirstChild("Sheen")
		local gradient = sheen and sheen:FindFirstChild("SheenGradient") :: UIGradient?
		if gradient then
			local x = gradient.Offset.X + (targetOffset - gradient.Offset.X) * alpha
			gradient.Offset = Vector2.new(x, 0)
		end
	end
end

function Reveal.show(payload: Payload)
	token += 1
	local myToken = token
	local gui = getScreen()
	for _, child in gui:GetChildren() do
		if child.Name == "Loot" then
			child:Destroy()
		end
	end

	local drops = table.clone(payload.drops)
	while #drops > REVEAL.maxCards do
		table.remove(drops)
	end
	local best = "Common"
	for _, drop in drops do
		if rank(drop.rarity) > rank(best) then
			best = drop.rarity
		end
	end
	local bestColor = Fx.rarityColor(best)

	local root = Instance.new("Frame")
	root.Name = "Loot"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.56)
	root.Size = UDim2.fromOffset(#drops * CARD.X + (#drops - 1) * GAP, CARD.Y)
	root.BackgroundTransparency = 1
	local uiScale = Instance.new("UIScale")
	local rowWidth = #drops * CARD.X + (#drops - 1) * GAP
	uiScale.Scale = Fx.screenScale(gui) * math.min(1, MAX_ROW_WIDTH / rowWidth)
	uiScale.Parent = root
	root.Parent = gui

	-- Nagłówek: nazwa gwiazdy + luck.
	local header = Fx.text(root, {
		text = `{string.upper(payload.star)} CRACKED!`,
		size = UDim2.fromOffset(560, 40),
		position = UDim2.new(0.5, 0, 0, -50),
		maxSize = 34,
		color = StarConfig.glow(payload.type),
	})
	Fx.gradient(header, ColorSequence.new(Color3.new(1, 1, 1), StarConfig.glow(payload.type)))
	header.TextTransparency = 1
	Fx.tween(header, 0.3, { TextTransparency = 0 })
	local headerScale = Instance.new("UIScale")
	headerScale.Scale = 1.4
	headerScale.Parent = header
	Fx.tween(headerScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	if payload.luck > 1.001 then
		local luckPill = pill(
			root,
			string.format("LUCK x%.1f", payload.luck),
			Theme.duo(COLORS.rides),
			UDim2.fromOffset(110, 24),
			UDim2.new(0.5, 0, 0, -86),
			15
		)
		luckPill.Rotation = -3
	end

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.Size = UDim2.fromScale(1, 1)
	row.BackgroundTransparency = 1
	row.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	pityBars(root, payload.pity)

	-- Dotknięcie kart zamyka (nie blokuje reszty ekranu).
	local catcher = Instance.new("TextButton")
	catcher.Name = "Dismiss"
	catcher.Text = ""
	catcher.BackgroundTransparency = 1
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.ZIndex = 30
	catcher.Parent = root
	catcher.Activated:Connect(function()
		close(root)
	end)

	local tiltCards: { TiltCard } = {}
	local connections = {
		RunService.RenderStepped:Connect(function(dt)
			tiltStep(tiltCards, math.min(1, dt * TILT.follow))
		end),
		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				pointer = Vector2.new(input.Position.X, input.Position.Y)
			end
		end),
		UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				pointer = Vector2.new(input.Position.X, input.Position.Y)
			end
		end),
	}
	root.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		pointer = nil
	end)

	local lastReveal = 0
	for i, drop in drops do
		local wrapper, card, cover = buildCard(drop)
		local tiltEntry: TiltCard = { wrapper = wrapper, card = card, rank = rank(drop.rarity), ready = false }
		table.insert(tiltCards, tiltEntry)
		wrapper.LayoutOrder = i
		wrapper.Parent = row
		local scale = wrapper:FindFirstChildOfClass("UIScale") :: UIScale
		local enterAt = (i - 1) * REVEAL.stagger
		local suspense = REVEAL.suspense[drop.rarity] or 0
		local revealAt = enterAt + 0.3 + suspense
		lastReveal = math.max(lastReveal, revealAt)
		wrapper.Rotation = if i % 2 == 0 then 8 else -8
		local badges = card:FindFirstChild("Badges") :: Frame

		task.delay(enterAt, function()
			if myToken ~= token or not wrapper.Parent then
				return
			end
			SoundController.play2D("uiPop", 0.7, 1 + i * 0.04)
			Fx.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			Fx.tween(wrapper, 0.35, { Rotation = 0 }, Enum.EasingStyle.Back)
			if cover then
				-- Drżenie zasłony narasta do odkrycia.
				Fx.loop(card, 0.06, { Rotation = 2.5 })
			end
		end)
		task.delay(revealAt, function()
			if myToken ~= token or not wrapper.Parent then
				return
			end
			local function onFlipped()
				card.Rotation = 0
				badges.Visible = true
				revealSound(drop.rarity)
				cardFlash(wrapper, card, drop.rarity)
				local color = Fx.rarityColor(drop.rarity)
				local sparks = REVEAL.sparks[drop.rarity]
				if sparks then
					Fx.burst(wrapper, sparks, color, UDim2.fromScale(0.5, 0.42), 120 + rank(drop.rarity) * 12)
				end
				if rank(drop.rarity) >= rank(LootConfig.ANNOUNCE.effectFrom) then
					Fx.flash(gui, color, REVEAL.flashAlpha, 0.7)
				end
				scale.Scale = 1.12
				Fx.tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end
			if cover then
				-- Zatrzymaj drżenie: nowy tween Rotation nadpisuje pętlę.
				Fx.tween(card, 0.05, { Rotation = 0 })
				flip(card, cover, onFlipped)
			else
				onFlipped()
			end
			-- Od odkrycia karta reaguje na wskaźnik (wcześniej obrót wejścia i drżenie zasłony).
			task.delay(0.35, function()
				tiltEntry.ready = true
			end)
		end)
	end

	-- Komplet motywu w indeksie.
	if payload.themesCompleted then
		task.delay(lastReveal + 0.4, function()
			for _, themeId in payload.themesCompleted :: { string } do
				local theme = StarConfig.THEMES[themeId]
				local bonus = math.round(LootConfig.INDEX_LUCK_BONUS * 100)
				Store.toast(
					`{if theme then theme.displayName else themeId} complete! +{bonus}% Luck forever`,
					"success"
				)
			end
		end)
	end

	-- Od Legendary nagłówek przejmuje kolor najlepszego łupu.
	if rank(best) >= rank("Legendary") then
		task.delay(lastReveal, function()
			local gradient = header:FindFirstChildOfClass("UIGradient")
			if myToken == token and gradient then
				gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), bestColor)
				headerScale.Scale = 1.25
				Fx.tween(headerScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end)
	end

	local hold = lastReveal + REVEAL.holdSeconds + (#drops - 1) * REVEAL.extraHoldPerCard
	task.delay(hold, function()
		if myToken == token and root.Parent then
			close(root)
		end
	end)
end

return Reveal
