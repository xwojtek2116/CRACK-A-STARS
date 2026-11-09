--!strict
-- PriceButton — zielony przycisk ceny z ikoną waluty (moneta kasy albo klejnot premium za Robux) i błyskiem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Format = require(script.Parent.Parent.Format)
local Theme = require(script.Parent.Parent.Theme)
local Button = require(script.Parent.Button)

local e = React.createElement

export type Props = {
	price: number,
	currency: "cash" | "robux",
	onActivated: (() -> ())?,
	disabled: boolean?,
	owned: boolean?,
	size: UDim2?,
	layoutOrder: number?,
	shineDelay: number?,
	label: string?, -- własny napis zamiast ceny (np. "EQUIP", "LOCKED"), bez ikony waluty
	color: Color3?,
}

local function PriceButton(props: Props)
	local text = if props.label
		then props.label
		elseif props.owned then "OWNED"
		elseif props.currency == "cash" then Format.cash(props.price)
		else Format.number(props.price)
	return e(Button, {
		text = text,
		icon = if props.owned or props.label
			then nil
			elseif props.currency == "cash" then Theme.ICONS.coin
			else Theme.ICONS.premium,
		iconSize = 30,
		textSize = Theme.TEXT_SIZE.title - 4,
		color = props.color or (if props.owned then Theme.COLORS.index else Theme.COLORS.price),
		disabled = props.disabled,
		size = props.size or UDim2.fromOffset(170, 54),
		layoutOrder = props.layoutOrder,
		shine = not props.owned and props.label == nil,
		shineDelay = props.shineDelay,
		onActivated = props.onActivated,
	})
end

return PriceButton
