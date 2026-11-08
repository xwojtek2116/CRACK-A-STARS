--!strict
-- OfferCard — karta oferty w sklepie: szeroki baner z gradientem w kolorze rzadkości/rodzaju, render przedmiotu
-- wychodzący poza kartę (unosi się), nazwa dużym fontem z konturem, krótki opis, żółty dopisek
-- („NEW!”, „LIMITED TIME ONLY!”, pulsuje) i zielony przycisk ceny po prawej.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Motion = require(script.Parent.Parent.Motion)
local Theme = require(script.Parent.Parent.Theme)
local Label = require(script.Parent.Label)
local PriceButton = require(script.Parent.PriceButton)

local e = React.createElement

export type Props = {
	name: string,
	description: string,
	color: Color3,
	image: string,
	price: number,
	currency: "cash" | "robux",
	tag: string?,
	owned: boolean?,
	disabled: boolean?,
	onBuy: (() -> ())?,
	layoutOrder: number?,
	index: number?, -- kolejność na liście → przesunięcie faz animacji
}

local HEIGHT = 112
local IMAGE = 132

local function OfferCard(props: Props)
	local phase = (props.index or 0) * 0.35
	local bobRef = React.useRef(nil :: Frame?)
	local tagRef = React.useRef(nil :: UIScale?)
	local enterRef = Motion.useEnter(0.85)
	Motion.useBob(bobRef :: any, 4, 1.8, phase)
	Motion.useLoop(tagRef :: any, 0.5, { Scale = 1.1 }, { delay = phase })

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Enter = e("UIScale", { ref = enterRef }),
		Card = e("Frame", {
			Size = UDim2.new(1, 0, 1, -5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.CORNER }),
			Gradient = e("UIGradient", { Color = Theme.banner(props.color) }),
			Stroke = e("UIStroke", {
				Color = Theme.COLORS.ink,
				Thickness = 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Info = e("Frame", {
				Position = UDim2.fromOffset(IMAGE + 18, 0),
				Size = UDim2.new(1, -(IMAGE + 18 + 200), 1, 0),
				BackgroundTransparency = 1,
			}, {
				List = e("UIListLayout", {
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 2),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Name = e(Label, {
					text = string.upper(props.name),
					textSize = Theme.TEXT_SIZE.title,
					stroke = 4,
					rotation = -2,
					layoutOrder = 1,
				}),
				Description = e(Label, {
					text = props.description,
					textSize = Theme.TEXT_SIZE.small,
					font = Theme.FONTS.body,
					color = Theme.lighten(props.color, 0.75),
					stroke = 2,
					xAlignment = Enum.TextXAlignment.Left,
					layoutOrder = 2,
				}),
			}),
			Right = e("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0.5, 0),
				Size = UDim2.fromOffset(180, 92),
				BackgroundTransparency = 1,
			}, {
				List = e("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 4),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Tag = if props.tag
					then e(Label, {
						text = props.tag,
						textSize = Theme.TEXT_SIZE.small + 2,
						color = Color3.fromHex("#FFE34D"),
						layoutOrder = 1,
					}, { Pulse = e("UIScale", { ref = tagRef }) })
					else nil,
				Price = e(PriceButton, {
					price = props.price,
					currency = props.currency,
					owned = props.owned,
					disabled = props.disabled,
					layoutOrder = 2,
					shineDelay = phase,
					onActivated = props.onBuy,
				}),
			}),
		}),
		-- Render przedmiotu wystaje poza kartę (górę i lewą krawędź).
		Art = e("Frame", {
			Position = UDim2.fromOffset(4, -16),
			Size = UDim2.fromOffset(IMAGE, IMAGE),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			Bob = e("Frame", { ref = bobRef, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
				Shadow = e("ImageLabel", {
					Image = props.image,
					ImageColor3 = Color3.new(0, 0, 0),
					ImageTransparency = 0.55,
					Position = UDim2.fromOffset(0, 6),
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
				}),
				Image = e("ImageLabel", {
					Image = props.image,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ZIndex = 2,
				}),
			}),
		}),
	})
end

return OfferCard
