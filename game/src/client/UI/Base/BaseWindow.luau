--!strict
-- BaseWindow — okno „MY BASE” (przycisk BASE w HUD, stacja Upgrades w lobby):
--   • pasek: postumenty zajęte/pojemność, dochód/s, AUTO-PLACE BEST, kupno następnego postumentu,
--   • zakładka PEDESTALS: przedmioty na postumentach (REMOVE do ekwipunku),
--   • zakładka INVENTORY: ekwipunek (PLACE → wolny postument albo zamiana z najsłabszym), licznik limitu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local BaseMath = require(ReplicatedStorage:WaitForChild("Shared").BaseMath)

local UI = script.Parent.Parent
local Format = require(UI.Format)
local PriceButton = require(UI.Components.PriceButton)
local Button = require(UI.Components.Button)
local Store = require(UI.Store)
local Theme = require(UI.Theme)

local Actions = require(script.Parent.Actions)
local Parts = require(script.Parent.Parts)

local e = React.createElement

local BaseWindow = {}

BaseWindow.TABS = {
	{ id = "pedestals", text = "PEDESTALS" },
	{ id = "inventory", text = "INVENTORY" },
}

local function hex(color: Color3): string
	return `#{color:ToHex()}`
end

function BaseWindow.Body(props: { tab: string })
	local state = Store.use(function(s)
		return s
	end)
	local placed = Actions.entries(state, "placed")
	local inventory = Actions.entries(state, "inventory")
	local isInventory = props.tab == "inventory"

	local rows = {}
	if isInventory then
		for i, entry in inventory do
			local target = Actions.targetSlot(state, entry.uid)
			rows[entry.uid] = e(Parts.ItemRow, {
				entry = entry,
				layoutOrder = i,
				buttons = if target
					then {
						{
							text = "PLACE",
							color = Theme.COLORS.base,
							onActivated = function()
								Actions.place(entry.uid, target)
							end,
						},
					}
					else {},
			})
		end
		if #inventory == 0 then
			rows.Empty = e(Parts.Empty, { text = "No items in your inventory. Crack stars to get more!" })
		end
	else
		for i, entry in placed do
			rows[entry.uid] = e(Parts.ItemRow, {
				entry = entry,
				layoutOrder = i,
				note = `#{entry.slot}`,
				buttons = {
					{
						text = "REMOVE",
						color = Theme.COLORS.panelLight,
						onActivated = function()
							Actions.remove(entry.slot :: number)
						end,
					},
				},
			})
		end
		if #placed == 0 then
			rows.Empty = e(Parts.Empty, { text = "Your pedestals are empty. Crack a falling star!" })
		end
	end

	local income = Store.use(function(s)
		return s.incomePerSec
	end)
	local summary = if isInventory
		then `INVENTORY <font color="{hex(Theme.COLORS.neonCyan)}">{#inventory}/{BaseMath.INVENTORY_LIMIT}</font>`
		else `PEDESTALS <font color="{hex(Theme.COLORS.neonCyan)}">{#placed}/{state.capacity}</font>   <font color="{hex(
			Theme.COLORS.cash
		)}">{Format.cash(income)}/s</font>`

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Pad = e("UIPadding", {
			PaddingTop = UDim.new(0, 24),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 8),
		}),
		Bar = e(Parts.Bar, { text = summary }, {
			Auto = e(Button, {
				text = "AUTO-PLACE BEST",
				color = Theme.COLORS.base,
				textSize = Theme.TEXT_SIZE.small + 2,
				size = UDim2.fromOffset(200, 50),
				shine = true,
				layoutOrder = 1,
				onActivated = Actions.autoPlace,
			}),
			Slot = if state.nextSlotPrice
				then e(PriceButton, {
					price = state.nextSlotPrice,
					currency = "cash",
					disabled = state.cash < state.nextSlotPrice,
					size = UDim2.fromOffset(170, 50),
					layoutOrder = 2,
					onActivated = Actions.buySlot,
				})
				else nil,
		}),
		List = e(Parts.List, {
			size = UDim2.new(1, 0, 1, -76),
			position = UDim2.fromOffset(0, 76),
		}, rows),
	})
end

return BaseWindow
