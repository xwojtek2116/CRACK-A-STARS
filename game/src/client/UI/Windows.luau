--!strict
-- Windows — okna otwierane z menu HUD. Sklep narzędzi: zakładki TOOLS (Tools.json, kasa) i EXCLUSIVES
-- (Monetization.json → exclusives, Robux) — wygląd gotowy, kupowanie podłączy T09/T14 (na razie toast).
-- Pozostałe okna (baza, indeks, pojazdy, R$) = „Coming soon” w tym samym stylu, ekrany robi T14.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Data = ReplicatedStorage:WaitForChild("Shared").Config.Data
local Monetization = require(Data.Monetization) :: any
local Tools = require(Data.Tools) :: any

local UI = script.Parent
local Label = require(UI.Components.Label)
local OfferCard = require(UI.Components.OfferCard)
local SpaceFx = require(UI.Components.SpaceFx)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local Window = require(UI.Components.Window)

local e = React.createElement

type WindowInfo = { title: string, icon: string, color: Color3 }

local INFO: { [Store.WindowId]: WindowInfo } = {
	Shop = { title = "TOOLS SHOP", icon = Theme.ICONS.shop, color = Theme.COLORS.shop },
	Base = { title = "MY BASE", icon = Theme.ICONS.base, color = Theme.COLORS.base },
	Index = { title = "STAR INDEX", icon = Theme.ICONS.index, color = Theme.COLORS.index },
	Rides = { title = "RIDES", icon = Theme.ICONS.rides, color = Theme.COLORS.rides },
	Premium = { title = "R$ SHOP", icon = Theme.ICONS.premium, color = Theme.COLORS.premium },
}

local SHOP_TABS = {
	{ id = "tools", text = "TOOLS" },
	{ id = "exclusives", text = "EXCLUSIVES" },
}

-- Obrazek oferty Exclusives: render podobnego narzędzia albo ikona rodzaju (własne rendery → T11/T24).
local EXCLUSIVE_IMAGES: { [string]: string } = {
	comet_blade = Theme.TOOL_RENDERS.laser_sword,
	galaxy_hammer = Theme.TOOL_RENDERS.gravity_hammer,
	comet_board = Theme.ICONS.rides,
	star_trail = Theme.ICONS.star,
	aura_nebula = Theme.ICONS.premium,
}
local EXCLUSIVE_RARITY = { tool = "Legendary", vehicle = "Epic", cosmetic = "Mythic" }

local function List(props: { children: any })
	local children = table.clone(props.children)
	children.List = e("UIListLayout", { Padding = UDim.new(0, 26), SortOrder = Enum.SortOrder.LayoutOrder })
	children.Pad = e("UIPadding", {
		PaddingTop = UDim.new(0, 26),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 12),
	})
	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.COLORS.neonCyan,
		ClipsDescendants = true,
	}, children)
end

local function comingSoonToast()
	Store.toast("The shop opens soon!", "info")
end

local function ToolsList()
	local cards = {}
	for i, id in Tools.order do
		local tool = Tools.tools[id]
		cards[id] = e(OfferCard, {
			name = tool.name,
			rarity = Theme.tierRarity(tool.tier),
			image = Theme.TOOL_RENDERS[id] or Theme.ICONS.star,
			stats = {
				{ label = "DMG", value = tostring(tool.damage) },
				{ label = "CD", value = `{tool.cooldown}s` },
				{ label = "TIER", value = tostring(tool.tier) },
			},
			price = tool.price,
			currency = "cash",
			owned = tool.price == 0,
			tag = if i == #Tools.order then "LEGENDARY!" elseif i == #Tools.order - 1 then "NEW!" else nil,
			layoutOrder = i,
			index = i,
			onBuy = comingSoonToast,
		})
	end
	return e(List, { children = cards })
end

local function ExclusivesList()
	local cards = {}
	for i, offer in Monetization.exclusives or {} do
		local stats = {}
		if offer.stats and offer.stats.damage then
			stats = {
				{ label = "DMG", value = tostring(offer.stats.damage) },
				{ label = "CD", value = `{offer.stats.cooldown}s` },
			}
		elseif offer.stats and offer.stats.speed then
			stats = { { label = "SPEED", value = tostring(offer.stats.speed) } }
		else
			stats = { { label = "TYPE", value = string.upper(offer.type) } }
		end
		cards[offer.id] = e(OfferCard, {
			name = offer.name,
			rarity = EXCLUSIVE_RARITY[offer.type] or "Epic",
			image = EXCLUSIVE_IMAGES[offer.id] or Theme.ICONS.premium,
			stats = stats,
			price = offer.robux,
			currency = "robux",
			tag = "LIMITED TIME ONLY!",
			layoutOrder = i,
			index = i,
			onBuy = comingSoonToast,
		})
	end
	return e(List, { children = cards })
end

local function ComingSoon(props: { color: Color3 })
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Glow = e(SpaceFx.Flare, { color = props.color, size = 260, position = UDim2.fromScale(0.5, 0.45) }),
		Text = e(Label, {
			text = "COMING SOON!",
			textSize = Theme.TEXT_SIZE.big,
			stroke = 4,
			color = Theme.COLORS.starYellow,
			anchorPoint = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.45),
			zIndex = 2,
		}),
	})
end

local function Windows(props: { viewport: Vector2 })
	local window = Store.use(function(state)
		return state.window
	end)
	local tab = Store.use(function(state)
		return state.tab
	end) or "tools"
	local setTab = function(id: string)
		Store.set({ tab = id })
	end
	if not window then
		return nil
	end
	local info = INFO[window]
	local isShop = window == "Shop"
	local size = if isShop then Vector2.new(880, 540) else Vector2.new(620, 360)
	-- Okno + nagłówek/X wystające poza ramkę muszą zmieścić się na ekranie (telefon poziomo).
	local fit = math.min(1, (props.viewport.Y - 40) / (size.Y + 90), (props.viewport.X - 40) / (size.X + 90))
	return e(Window, {
		key = window, -- nowe okno = nowy montaż (animacja pop)
		title = info.title,
		icon = info.icon,
		color = info.color,
		tabs = if isShop then SHOP_TABS else nil,
		tab = tab,
		onTab = setTab,
		size = size,
		fit = fit,
		onClose = Store.closeWindow,
	}, {
		Body = if not isShop
			then e(ComingSoon, { color = info.color })
			elseif tab == "exclusives" then e(ExclusivesList, { key = "ex" })
			else e(ToolsList, { key = "tools" }),
	})
end

return Windows
