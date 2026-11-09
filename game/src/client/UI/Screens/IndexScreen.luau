--!strict
-- IndexScreen — zakładka INDEX okna STAR INDEX: 12 rodzajów gwiazd × przedmioty (Items.json).
--   • u góry: ile przedmiotów znaleziono i ile kompletów (każdy komplet = +5% Luck na stałe, liczy serwer),
--   • sekcja rodzaju: nazwa w kolorze gwiazdy, pasek kompletu, plakietka „+5% LUCK” / „COMPLETE!”,
--   • kafelki: znaleziony = klejnot w kolorze rzadkości + nazwa; nieznaleziony = czarna sylwetka + „???”
--     (rzadkość widoczna). Secret (tylko z Supernowej) jest w sekcji swojego rodzaju, poza kompletem.
-- Dane: Store.index (itemId → true), komplet = LootConfig.THEME_SET. Rendery przedmiotów: T21–T23.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LootConfig = require(Shared.Config.LootConfig)
local StarConfig = require(Shared.Config.StarConfig)
local Themes = require(Shared.Config.Data.Themes) :: any

local UI = script.Parent.Parent
local Label = require(UI.Components.Label)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local Common = require(script.Parent.Common)

local e = React.createElement

local TILE = Vector2.new(118, 132)
local TILE_GAP = 10
local SILHOUETTE = Color3.fromHex("#05020D")

-- Przedmioty rodzaju w kolejności rzadkości (raz przy starcie).
local THEME_ITEMS: { [string]: { LootConfig.Item } } = {}
for _, item in LootConfig.ITEMS do
	local list = THEME_ITEMS[item.theme] or {}
	THEME_ITEMS[item.theme] = list
	table.insert(list, item)
end
for _, list in THEME_ITEMS do
	table.sort(list, function(a, b)
		return LootConfig.rarityRank(a.rarity) < LootConfig.rarityRank(b.rarity)
	end)
end

local TOTAL_ITEMS = 0
local TOTAL_SETS = 0
for _, themeId in Themes.order do
	TOTAL_ITEMS += #(THEME_ITEMS[themeId] or {})
	if LootConfig.THEME_SET[themeId] then
		TOTAL_SETS += 1
	end
end
local BONUS_PCT = math.round(LootConfig.INDEX_LUCK_BONUS * 100)

local function rarityColor(rarity: string): Color3
	return Theme.RARITY_COLORS[rarity] or Theme.COLORS.textMuted
end

local function Tile(props: { item: LootConfig.Item, found: boolean, order: number })
	local item = props.item
	local color = rarityColor(item.rarity)
	local isSecret = item.rarity == "Secret"
	return e("Frame", {
		Size = UDim2.fromOffset(TILE.X, TILE.Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = props.order,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.CORNER_SMALL }),
		Gradient = e("UIGradient", {
			Color = ColorSequence.new(Theme.darken(color, if props.found then 0.45 else 0.75), Theme.COLORS.space),
			Rotation = 90,
		}),
		Stroke = e("UIStroke", {
			Color = if props.found then color else Theme.darken(color, 0.4),
			Thickness = if props.found then 3 else 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, {
			Rainbow = if isSecret then e("UIGradient", { Color = Theme.SECRET_GRADIENT, Rotation = 45 }) else nil,
		}),
		Glow = if props.found
			then e("ImageLabel", {
				Image = Theme.FX.flare,
				ImageColor3 = color,
				ImageTransparency = 0.45,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, 52),
				Size = UDim2.fromOffset(110, 110),
			})
			else nil,
		Gem = e("ImageLabel", {
			Image = Theme.ICONS.premium,
			ImageColor3 = if props.found then Theme.lighten(color, 0.15) else SILHOUETTE,
			ImageTransparency = if props.found then 0 else 0.1,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 52),
			Size = UDim2.fromOffset(62, 62),
			ZIndex = 2,
		}),
		Unknown = if props.found
			then nil
			else e(Label, {
				text = "?",
				textSize = Theme.TEXT_SIZE.title,
				color = Theme.darken(color, 0.1),
				anchorPoint = Vector2.new(0.5, 0.5),
				position = UDim2.new(0.5, 0, 0, 52),
				zIndex = 3,
			}),
		Name = e(Label, {
			text = if props.found then item.name else "???",
			font = Theme.FONTS.body,
			textSize = Theme.TEXT_SIZE.tiny,
			wrapped = true,
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -24),
			size = UDim2.new(1, -8, 0, 30),
			zIndex = 3,
		}),
		Rarity = e(Label, {
			text = string.upper(item.rarity),
			textSize = 11,
			color = color,
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 1, -6),
			zIndex = 3,
		}),
	})
end

local function ThemeSection(props: { themeId: string, index: { [string]: boolean }, order: number })
	local themeId = props.themeId
	local theme = StarConfig.THEMES[themeId]
	local glow = StarConfig.glow(themeId)
	local set = LootConfig.THEME_SET[themeId] or {}
	local foundInSet = 0
	for _, itemId in set do
		if props.index[itemId] then
			foundInSet += 1
		end
	end
	local complete = #set > 0 and foundInSet == #set

	local tiles: { [string]: any } = {
		Grid = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(TILE.X, TILE.Y),
			CellPadding = UDim2.fromOffset(TILE_GAP, TILE_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, item in THEME_ITEMS[themeId] or {} do
		tiles[item.id] = e(Tile, { item = item, found = props.index[item.id] == true, order = i })
	end

	return e("Frame", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.order,
	}, {
		List = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Header = e(Common.Panel, {
			color = glow,
			size = UDim2.new(1, 0, 0, 48),
			layoutOrder = 1,
		}, {
			Name = e(Label, {
				text = string.upper(if theme then theme.displayName else themeId),
				textSize = Theme.TEXT_SIZE.body,
				color = Theme.lighten(glow, 0.2),
				xAlignment = Enum.TextXAlignment.Left,
				anchorPoint = Vector2.new(0, 0.5),
				position = UDim2.new(0, 14, 0.5, 0),
			}),
			Bar = e(Common.Progress, {
				fraction = if #set > 0 then foundInSet / #set else 0,
				color = if complete then Theme.COLORS.gold else glow,
				text = `{foundInSet}/{#set}`,
				size = UDim2.fromOffset(180, 22),
				anchorPoint = Vector2.new(1, 0.5),
				position = UDim2.new(1, -150, 0.5, 0),
			}),
			Reward = e(Label, {
				text = if complete then "COMPLETE!" else `+{BONUS_PCT}% LUCK`,
				textSize = Theme.TEXT_SIZE.small,
				color = if complete then Theme.COLORS.gold else Theme.COLORS.cash,
				anchorPoint = Vector2.new(1, 0.5),
				position = UDim2.new(1, -14, 0.5, 0),
			}),
		}),
		Tiles = e("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, tiles),
	})
end

local function IndexScreen()
	local index = Store.use(function(s)
		return s.index
	end)
	local found, sets = 0, 0
	for _, themeId in Themes.order do
		for _, item in THEME_ITEMS[themeId] or {} do
			if index[item.id] then
				found += 1
			end
		end
		local set = LootConfig.THEME_SET[themeId]
		if set and #set > 0 then
			local all = true
			for _, itemId in set do
				if not index[itemId] then
					all = false
					break
				end
			end
			if all then
				sets += 1
			end
		end
	end

	local sections: { [string]: any } = {
		List = e("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }),
		Pad = e("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 12),
		}),
	}
	for i, themeId in Themes.order do
		sections[themeId] = e(ThemeSection, { themeId = themeId, index = index, order = i })
	end

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Summary = e(Common.Panel, { color = Theme.COLORS.index, size = UDim2.new(1, -14, 0, 56) }, {
			Found = e(Label, {
				text = `FOUND <font color="#3DF2FF">{found}</font>/{TOTAL_ITEMS}`,
				richText = true,
				textSize = Theme.TEXT_SIZE.body,
				xAlignment = Enum.TextXAlignment.Left,
				anchorPoint = Vector2.new(0, 0.5),
				position = UDim2.new(0, 16, 0.5, 0),
			}),
			Bar = e(Common.Progress, {
				fraction = found / math.max(TOTAL_ITEMS, 1),
				color = Theme.COLORS.index,
				text = `{math.floor(found / math.max(TOTAL_ITEMS, 1) * 100)}%`,
				size = UDim2.fromOffset(220, 22),
				anchorPoint = Vector2.new(0.5, 0.5),
				position = UDim2.fromScale(0.5, 0.5),
			}),
			Luck = e(Label, {
				text = `SETS {sets}/{TOTAL_SETS}  <font color="#5BFF8A">+{sets * BONUS_PCT}% LUCK</font>`,
				richText = true,
				textSize = Theme.TEXT_SIZE.small,
				anchorPoint = Vector2.new(1, 0.5),
				position = UDim2.new(1, -16, 0.5, 0),
			}),
		}),
		Scroll = e("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 68),
			Size = UDim2.new(1, 0, 1, -68),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.COLORS.neonCyan,
			-- Pad: kafelki nie są przyciskami, więc lista sama przyjmuje zaznaczenie i przewija się gałką.
			Selectable = true,
			SelectionImageObject = nil,
		}, sections),
	})
end

return IndexScreen
