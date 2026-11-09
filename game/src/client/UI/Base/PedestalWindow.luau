--!strict
-- PedestalWindow — menu postumentu (prompt na własnym postumencie): przedmiot na nim z REMOVE i SELL
-- (sprzedaż przy postumencie, od Legendary z potwierdzeniem), pod spodem ekwipunek z PLACE HERE (zamiana).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local UI = script.Parent.Parent
local Format = require(UI.Format)
local Store = require(UI.Store)
local Theme = require(UI.Theme)

local Actions = require(script.Parent.Actions)
local Parts = require(script.Parent.Parts)

local e = React.createElement

local PedestalWindow = {}

function PedestalWindow.Body()
	local state = Store.use(function(s)
		return s
	end)
	local confirm, setConfirm = React.useState(nil :: Actions.Entry?)
	local slot = state.pedestal or 1

	local current: Actions.Entry? = nil
	for _, entry in Actions.entries(state, "placed") do
		if entry.slot == slot then
			current = entry
			break
		end
	end

	local function sell(entry: Actions.Entry, confirmed: boolean)
		if entry.confirm and not confirmed then
			setConfirm(entry)
			return
		end
		setConfirm(nil)
		Actions.sell(entry.uid, confirmed)
	end

	local rows = {}
	if current then
		local entry = current
		rows.Current = e(Parts.ItemRow, {
			entry = entry,
			layoutOrder = 0,
			highlight = true,
			buttons = {
				{
					text = "REMOVE",
					color = Theme.COLORS.panelLight,
					onActivated = function()
						Actions.remove(slot)
					end,
				},
				{
					text = Format.cash(entry.price),
					icon = Theme.ICONS.coin,
					color = Theme.COLORS.danger,
					width = 140,
					onActivated = function()
						sell(entry, false)
					end,
				},
			},
		})
	else
		rows.Current = e(Parts.Empty, { text = "This pedestal is empty. Pick an item below!" })
	end

	for i, entry in Actions.entries(state, "inventory") do
		rows[entry.uid] = e(Parts.ItemRow, {
			entry = entry,
			layoutOrder = i,
			buttons = {
				{
					text = "PLACE HERE",
					color = Theme.COLORS.base,
					width = 150,
					onActivated = function()
						Actions.place(entry.uid, slot)
					end,
				},
			},
		})
	end

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Pad = e("UIPadding", {
			PaddingTop = UDim.new(0, 24),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 8),
		}),
		Bar = e(Parts.Bar, { text = `PEDESTAL #{slot}` }),
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

return PedestalWindow
