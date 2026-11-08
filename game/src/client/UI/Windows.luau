--!strict
-- Windows — okna otwierane z menu HUD. T13: wzorzec okna sklepu (karty narzędzi z Tools.json, bez kupowania)
-- i „Coming soon” dla reszty. Prawdziwe ekrany (sklep, baza, indeks, garaż, Robux) robi T14.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Data = ReplicatedStorage:WaitForChild("Shared").Config.Data
local Rarities = require(Data.Rarities) :: any
local Tools = require(Data.Tools) :: any

local UI = script.Parent
local Label = require(UI.Components.Label)
local OfferCard = require(UI.Components.OfferCard)
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

-- Kolor karty narzędzia = kolor rzadkości o tym samym numerze (tier 1 → Common …).
local function toolColor(tier: number): Color3
	local id = Rarities.order[math.clamp(tier, 1, #Rarities.order)]
	return Theme.RARITY_COLORS[id] or Theme.COLORS.neonCyan
end

local function ToolsList()
	local children: { [string]: any } = {
		List = e("UIListLayout", { Padding = UDim.new(0, 22), SortOrder = Enum.SortOrder.LayoutOrder }),
		Pad = e("UIPadding", {
			PaddingTop = UDim.new(0, 20),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 10),
		}),
	}
	for i, id in Tools.order do
		local tool = Tools.tools[id]
		children[id] = e(OfferCard, {
			name = tool.name,
			description = `DMG {tool.damage} · {tool.cooldown}s · Tier {tool.tier}`,
			color = toolColor(tool.tier),
			image = Theme.ICONS.star, -- render narzędzia podmieni T11/T14
			price = tool.price,
			currency = "cash",
			owned = tool.price == 0,
			tag = if i == #Tools.order then "LIMITED TIME ONLY!" elseif i == #Tools.order - 1 then "NEW!" else nil,
			layoutOrder = i,
			index = i,
			onBuy = function()
				Store.toast("The tool shop opens soon!", "info")
			end,
		})
	end
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

local function ComingSoon()
	return e(Label, {
		text = "COMING SOON!",
		textSize = Theme.TEXT_SIZE.big,
		stroke = 4,
		color = Theme.COLORS.starYellow,
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.45),
	})
end

local function Windows()
	local window = Store.use(function(state)
		return state.window
	end)
	if not window then
		return nil
	end
	local info = INFO[window]
	return e(Window, {
		key = window, -- nowe okno = nowy montaż (animacja pop)
		title = info.title,
		icon = info.icon,
		color = info.color,
		section = if window == "Shop" then "EXCLUSIVES" else nil,
		size = if window == "Shop" then Vector2.new(860, 520) else Vector2.new(620, 360),
		onClose = Store.closeWindow,
	}, {
		Body = if window == "Shop" then e(ToolsList) else e(ComingSoon),
	})
end

return Windows
