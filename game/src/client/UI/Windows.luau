--!strict
-- Windows — okna otwierane z menu HUD. Sklep narzędzi: zakładki TOOLS (Screens/ToolsScreen, BuyTool/EquipTool)
-- i EXCLUSIVES (Monetization.json → exclusives, Robux — kupowanie podłączy T16, na razie toast; posiadane
-- narzędzia-ekskluzywy mają EQUIP / EQUIPPED przez EquipTool, T09).
-- Baza (T08): MY BASE (postumenty/ekwipunek), PEDESTAL (menu postumentu), SELL STATION, WELCOME BACK.
-- Ekrany T14 (Screens/): GARAGE (okno Rides), STAR INDEX (zakładki INDEX i REBIRTH), SETTINGS.
-- R$ SHOP = „Coming soon” (T16).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Data = ReplicatedStorage:WaitForChild("Shared").Config.Data
local Monetization = require(Data.Monetization) :: any

local UI = script.Parent
local Label = require(UI.Components.Label)
local OfferCard = require(UI.Components.OfferCard)
local SpaceFx = require(UI.Components.SpaceFx)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local Window = require(UI.Components.Window)

local BaseWindow = require(UI.Base.BaseWindow)
local PedestalWindow = require(UI.Base.PedestalWindow)
local SellWindow = require(UI.Base.SellWindow)
local WelcomeWindow = require(UI.Base.WelcomeWindow)

local GarageScreen = require(UI.Screens.GarageScreen)
local IndexScreen = require(UI.Screens.IndexScreen)
local RebirthScreen = require(UI.Screens.RebirthScreen)
local Request = require(UI.Screens.Request)
local SettingsScreen = require(UI.Screens.SettingsScreen)
local ToolsScreen = require(UI.Screens.ToolsScreen)

local e = React.createElement

type WindowInfo = { title: string, icon: string, color: Color3 }

local SHOP_TABS = {
	{ id = "tools", text = "TOOLS" },
	{ id = "exclusives", text = "EXCLUSIVES" },
}

local INFO: { [Store.WindowId]: WindowInfo } = {
	Shop = { title = "TOOLS SHOP", icon = Theme.ICONS.shop, color = Theme.COLORS.shop },
	Base = { title = "MY BASE", icon = Theme.ICONS.base, color = Theme.COLORS.base },
	Index = { title = "STAR INDEX", icon = Theme.ICONS.index, color = Theme.COLORS.index },
	Rides = { title = "GARAGE", icon = Theme.ICONS.rides, color = Theme.COLORS.rides },
	Premium = { title = "R$ SHOP", icon = Theme.ICONS.premium, color = Theme.COLORS.premium },
	Sell = { title = "SELL STATION", icon = Theme.ICONS.coin, color = Theme.COLORS.price },
	Pedestal = { title = "PEDESTAL", icon = Theme.ICONS.base, color = Theme.COLORS.base },
	Welcome = { title = "WELCOME BACK!", icon = Theme.ICONS.coin, color = Theme.COLORS.gold },
	Settings = { title = "SETTINGS", icon = Theme.ICONS.settings, color = Theme.COLORS.neonCyan },
}

local INDEX_TABS = {
	{ id = "index", text = "INDEX" },
	{ id = "rebirth", text = "REBIRTH" },
}

-- Zakładki i rozmiary okien bazy.
local TABS: { [string]: { Window.Tab } } = {
	Shop = SHOP_TABS,
	Base = BaseWindow.TABS,
	Sell = SellWindow.TABS,
	Index = INDEX_TABS,
	Rides = GarageScreen.TABS,
}
local SIZES: { [string]: Vector2 } = {
	Shop = Vector2.new(880, 540),
	Base = Vector2.new(880, 540),
	Sell = Vector2.new(880, 540),
	Pedestal = Vector2.new(800, 500),
	Welcome = Vector2.new(560, 360),
	Index = Vector2.new(880, 540),
	Rides = Vector2.new(880, 540),
	Settings = Vector2.new(720, 520),
}

-- Obrazek oferty Exclusives: własny render narzędzia (T11) albo ikona rodzaju (pojazd/kosmetyki → T24).
local EXCLUSIVE_IMAGES: { [string]: string } = {
	comet_blade = Theme.TOOL_RENDERS.comet_blade,
	galaxy_hammer = Theme.TOOL_RENDERS.galaxy_hammer,
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

local function ExclusivesList()
	local owned = Store.use(function(s)
		return s.tools
	end)
	local equipped = Store.use(function(s)
		return s.equippedTool
	end)
	local cards = {}
	for i, offer in Monetization.exclusives or {} do
		local isOwnedTool = offer.type == "tool" and owned[offer.id] == true
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
			tag = if isOwnedTool then nil else "LIMITED TIME ONLY!",
			actionText = if isOwnedTool then (if equipped == offer.id then "EQUIPPED" else "EQUIP") else nil,
			actionColor = if isOwnedTool
				then (if equipped == offer.id then Theme.COLORS.index else Theme.COLORS.neonCyan)
				else nil,
			layoutOrder = i,
			index = i,
			onBuy = if isOwnedTool and equipped ~= offer.id
				then function()
					Request.send("EquipTool", { offer.id }, `{offer.name} equipped!`)
				end
				elseif isOwnedTool then nil
				else comingSoonToast,
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
	local storedTab = Store.use(function(state)
		return state.tab
	end)
	local setTab = function(id: string)
		Store.set({ tab = id })
	end
	if not window then
		return nil
	end
	local info = INFO[window]
	local isShop = window == "Shop"
	local tabs = TABS[window]
	local tab = storedTab or (if tabs then tabs[1].id else "tools")
	local size = SIZES[window] or Vector2.new(620, 360)
	local body
	if window == "Base" then
		body = e(BaseWindow.Body, { key = `base_{tab}`, tab = tab })
	elseif window == "Sell" then
		body = e(SellWindow.Body, { key = `sell_{tab}`, tab = tab })
	elseif window == "Pedestal" then
		body = e(PedestalWindow.Body, { key = "pedestal" })
	elseif window == "Welcome" then
		body = e(WelcomeWindow.Body, { key = "welcome" })
	elseif window == "Rides" then
		body = e(GarageScreen.Body, { key = `rides_{tab}`, tab = tab })
	elseif window == "Index" then
		body = if tab == "rebirth" then e(RebirthScreen, { key = "rebirth" }) else e(IndexScreen, { key = "index" })
	elseif window == "Settings" then
		body = e(SettingsScreen.Body, { key = "settings" })
	elseif not isShop then
		body = e(ComingSoon, { color = info.color })
	elseif tab == "exclusives" then
		body = e(ExclusivesList, { key = "ex" })
	else
		body = e(ToolsScreen, { key = "tools" })
	end
	local onClose = if window == "Welcome" then WelcomeWindow.collect else Store.closeWindow
	-- Okno + nagłówek/X wystające poza ramkę muszą zmieścić się na ekranie (telefon poziomo).
	local fit = math.min(1, (props.viewport.Y - 40) / (size.Y + 90), (props.viewport.X - 40) / (size.X + 90))
	return e(Window, {
		key = window, -- nowe okno = nowy montaż (animacja pop)
		title = info.title,
		icon = info.icon,
		color = info.color,
		tabs = tabs,
		tab = tab,
		onTab = setTab,
		size = size,
		fit = fit,
		onClose = onClose,
	}, {
		Body = body,
	})
end

return Windows
