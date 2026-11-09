--!strict
-- SellWindow — Sell Station w lobby: cena = $/s × 300 s (z mutacją), liczy serwer.
--   • zakładka INVENTORY: ekwipunek z SELL przy każdym + „SELL ALL BELOW <rzadkość>” (bez mutacji),
--   • zakładka ON BASE: przedmioty z postumentów (sprzedaż zdejmuje je z bazy),
--   • od Legendary okno potwierdzenia.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseMath = require(Shared.BaseMath)
local LootConfig = require(Shared.Config.LootConfig)

local UI = script.Parent.Parent
local Button = require(UI.Components.Button)
local Format = require(UI.Format)
local Store = require(UI.Store)
local Theme = require(UI.Theme)

local Actions = require(script.Parent.Actions)
local Parts = require(script.Parent.Parts)

local e = React.createElement

-- Progi „sell all below” (zgodne z Remotes: SELL_BELOW).
local BELOW = { "Uncommon", "Rare", "Epic", "Legendary" }

local SellWindow = {}

SellWindow.TABS = {
	{ id = "inventory", text = "INVENTORY" },
	{ id = "base", text = "ON BASE" },
}

function SellWindow.Body(props: { tab: string })
	local state = Store.use(function(s)
		return s
	end)
	local confirm, setConfirm = React.useState(nil :: Actions.Entry?)
	local belowIndex, setBelowIndex = React.useState(2) -- domyślnie „below Rare”
	local isBase = props.tab == "base"
	local entries = Actions.entries(state, if isBase then "placed" else "inventory")
	local below = BELOW[belowIndex]

	local function sell(entry: Actions.Entry, confirmed: boolean)
		if entry.confirm and not confirmed then
			setConfirm(entry)
			return
		end
		setConfirm(nil)
		Actions.sell(entry.uid, confirmed)
	end

	-- Suma i liczba dla „sell all below” (to samo filtrowanie co serwer).
	local bulkCount, bulkTotal = 0, 0
	local belowRank = LootConfig.rarityRank(below)
	for _, entry in entries do
		if entry.mutation == "None" and LootConfig.rarityRank(entry.rarity) < belowRank then
			bulkCount += 1
			bulkTotal += entry.price
		end
	end

	local rows = {}
	for i, entry in entries do
		rows[entry.uid] = e(Parts.ItemRow, {
			entry = entry,
			layoutOrder = i,
			note = if entry.slot then `#{entry.slot}` else nil,
			buttons = {
				{
					text = Format.cash(entry.price),
					icon = Theme.ICONS.coin,
					color = if entry.confirm then Theme.COLORS.danger else Theme.COLORS.price,
					width = 150,
					onActivated = function()
						sell(entry, false)
					end,
				},
			},
		})
	end
	if #entries == 0 then
		rows.Empty = e(Parts.Empty, { text = if isBase then "No items on your base." else "Your inventory is empty." })
	end

	local bar = if isBase
		then e(Parts.Bar, { text = "Selling removes the item from its pedestal." })
		else e(Parts.Bar, {
			text = `INVENTORY <font color="#{Theme.COLORS.neonCyan:ToHex()}">{#entries}/{BaseMath.INVENTORY_LIMIT}</font>`,
		}, {
			Rarity = e(Button, {
				text = `BELOW {string.upper(below)}`,
				color = Theme.RARITY_COLORS[below],
				textSize = Theme.TEXT_SIZE.small + 2,
				size = UDim2.fromOffset(200, 50),
				layoutOrder = 1,
				onActivated = function()
					setBelowIndex(belowIndex % #BELOW + 1)
				end,
			}),
			All = e(Button, {
				text = if bulkCount > 0 then `SELL {bulkCount}: {Format.cash(bulkTotal)}` else "SELL ALL",
				color = Theme.COLORS.price,
				disabled = bulkCount == 0,
				textSize = Theme.TEXT_SIZE.small + 2,
				size = UDim2.fromOffset(220, 50),
				shine = bulkCount > 0,
				layoutOrder = 2,
				onActivated = function()
					Actions.sellBelow(below)
				end,
			}),
		})

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Pad = e("UIPadding", {
			PaddingTop = UDim.new(0, 24),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 8),
		}),
		Bar = bar,
		List = e(Parts.List, { size = UDim2.new(1, 0, 1, -76), position = UDim2.fromOffset(0, 76) }, rows),
		Confirm = if confirm
			then e(Parts.Confirm, {
				entry = confirm,
				onConfirm = function()
					sell(confirm, true)
				end,
				onCancel = function()
					setConfirm(nil)
				end,
			})
			else nil,
	})
end

return SellWindow
