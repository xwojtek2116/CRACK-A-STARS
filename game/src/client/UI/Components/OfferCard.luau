--!strict
-- OfferCard — karta oferty w kosmicznym stylu:
--   • ciemne „szkło” z ukośnym banerem w kolorze rzadkości (Secret = tęcza) i świecącym obrysem,
--   • render przedmiotu na podeście z kręcącą się aurą, wychodzi poza kartę i unosi się,
--   • plakietka rzadkości, nazwa z konturem, chipy statystyk, żółty dopisek (pulsuje),
--   • zielony przycisk ceny; co kilka sekund przelatuje błysk; najechanie = lekkie powiększenie.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Motion = require(script.Parent.Parent.Motion)
local Theme = require(script.Parent.Parent.Theme)
local Label = require(script.Parent.Label)
local PriceButton = require(script.Parent.PriceButton)
local SpaceFx = require(script.Parent.SpaceFx)

local e = React.createElement

export type Stat = { label: string, value: string }
export type Props = {
	name: string,
	rarity: string, -- klucz z Rarities.json (kolor + plakietka)
	image: string,
	price: number,
	currency: "cash" | "robux",
	stats: { Stat }?,
	tag: string?,
	owned: boolean?,
	disabled: boolean?,
	onBuy: (() -> ())?,
	actionText: string?, -- napis na przycisku zamiast ceny ("EQUIP", "EQUIPPED", "LOCKED")
	actionColor: Color3?,
	dimmed: boolean?, -- zablokowana oferta: przyciemniony render
	layoutOrder: number?,
	index: number?, -- kolejność na liście → przesunięcie faz animacji
}

local HEIGHT = 120
local ART = 140

local function StatChip(props: { stat: Stat, order: number, color: Color3 })
	return e("Frame", {
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.COLORS.ink,
		BackgroundTransparency = 0.35,
		LayoutOrder = props.order,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.PILL }),
		Stroke = e("UIStroke", {
			Color = props.color,
			Transparency = 0.5,
			Thickness = 1.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		Row = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 5),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Key = e(Label, {
			text = props.stat.label,
			textSize = Theme.TEXT_SIZE.tiny,
			font = Theme.FONTS.body,
			color = Theme.COLORS.textMuted,
			stroke = 0,
			layoutOrder = 1,
		}),
		Value = e(Label, {
			text = props.stat.value,
			textSize = Theme.TEXT_SIZE.small,
			stroke = 2,
			layoutOrder = 2,
		}),
	})
end

local function OfferCard(props: Props)
	local phase = (props.index or 0) * 0.35
	local color = Theme.RARITY_COLORS[props.rarity] or Theme.COLORS.neonCyan
	local secret = props.rarity == "Secret"
	local bannerColors = if secret then Theme.SECRET_GRADIENT else Theme.banner(color)
	local bobRef = React.useRef(nil :: Frame?)
	local tagRef = React.useRef(nil :: UIScale?)
	local shineRef = React.useRef(nil :: UIGradient?)
	local hoverRef = React.useRef(nil :: UIScale?)
	local enterRef = Motion.useEnter(0.85)
	Motion.useBob(bobRef :: any, 5, 1.8, phase)
	Motion.useLoop(tagRef :: any, 0.5, { Scale = 1.1 }, { delay = phase })
	Motion.useShine(shineRef, phase * 2)

	local stats: { [string]: any } = {
		Row = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, stat in props.stats or {} do
		stats[`S{i}`] = e(StatChip, { stat = stat, order = i, color = color })
	end

	return e("Frame", {
		Size = UDim2.new(1, 0, 0, HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
		[React.Event.MouseEnter] = function()
			Motion.tween(hoverRef.current, Theme.MOTION.release, { Scale = 1.025 })
		end,
		[React.Event.MouseLeave] = function()
			Motion.tween(hoverRef.current, Theme.MOTION.release, { Scale = 1 })
		end,
	}, {
		Enter = e("UIScale", { ref = enterRef }),
		Inner = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
			Hover = e("UIScale", { ref = hoverRef }),
			Shadow = e("Frame", {
				Position = UDim2.fromOffset(0, 5),
				Size = UDim2.new(1, 0, 1, -5),
				BackgroundColor3 = Theme.COLORS.ink,
				ZIndex = 1,
			}, { Corner = e("UICorner", { CornerRadius = Theme.CORNER }) }),
			Card = e("Frame", {
				Size = UDim2.new(1, 0, 1, -5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				ZIndex = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.CORNER }),
				Glass = e("UIGradient", {
					Color = ColorSequence.new(Color3.fromHex("#20143D"), Color3.fromHex("#0A0618")),
					Rotation = 90,
				}),
				Glow = if secret
					then e(SpaceFx.NeonBorder, { thickness = 3, colors = Theme.SECRET_GRADIENT, speed = 3 })
					else e("UIStroke", {
						Color = color,
						Thickness = 3,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				-- Ukośny baner w kolorze rzadkości pod renderem.
				Banner = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 110, 0.5, 0),
					Size = UDim2.new(0, 300, 2, 0),
					Rotation = 14,
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 1,
				}, {
					Gradient = e("UIGradient", {
						Color = bannerColors,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.05),
							NumberSequenceKeypoint.new(0.75, 0.2),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),
				}),
				Nebula = e(SpaceFx.Nebula, { color = color, transparency = 0.85, speed = 60 }),
				Shine = e("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 8,
				}, {
					Band = e("UIGradient", {
						ref = shineRef,
						Rotation = 20,
						Transparency = Theme.SHINE_BAND,
						Offset = Vector2.new(-1, 0),
					}),
				}),
				Info = e("Frame", {
					Position = UDim2.fromOffset(ART + 36, 0),
					Size = UDim2.new(1, -(ART + 36 + 200), 1, 0),
					BackgroundTransparency = 1,
					ZIndex = 5,
				}, {
					List = e("UIListLayout", {
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Rarity = e("Frame", {
						Size = UDim2.fromOffset(0, 22),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundColor3 = Color3.new(1, 1, 1),
						LayoutOrder = 1,
					}, {
						Corner = e("UICorner", { CornerRadius = Theme.PILL }),
						Gradient = e("UIGradient", {
							Color = if secret then Theme.SECRET_GRADIENT else Theme.duo(color),
							Rotation = if secret then 0 else 90,
						}),
						Stroke = e("UIStroke", {
							Color = Theme.COLORS.ink,
							Thickness = 2,
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						}),
						Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
						Text = e(Label, {
							text = string.upper(props.rarity),
							textSize = Theme.TEXT_SIZE.tiny,
							stroke = 2,
							size = UDim2.fromScale(0, 1),
							automaticSize = Enum.AutomaticSize.X,
						}),
					}),
					Name = e(Label, {
						text = string.upper(props.name),
						textSize = Theme.TEXT_SIZE.title,
						stroke = 4,
						rotation = -2,
						xAlignment = Enum.TextXAlignment.Left,
						layoutOrder = 2,
					}),
					Stats = e("Frame", {
						Size = UDim2.new(1, 0, 0, 26),
						BackgroundTransparency = 1,
						LayoutOrder = 3,
					}, stats),
				}),
				Right = e("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -16, 0.5, 0),
					Size = UDim2.fromOffset(180, 96),
					BackgroundTransparency = 1,
					ZIndex = 6,
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
						label = props.actionText,
						color = props.actionColor,
					}),
				}),
			}),
			-- Render na podeście z aurą — wystaje poza kartę.
			Art = e("Frame", {
				Position = UDim2.fromOffset(8, -22),
				Size = UDim2.fromOffset(ART, ART),
				BackgroundTransparency = 1,
				ZIndex = 3,
			}, {
				Pedestal = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 1, -8),
					Size = UDim2.fromOffset(ART * 0.8, 22),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 1,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
					Gradient = e("UIGradient", {
						Color = ColorSequence.new(Theme.lighten(color, 0.4), Theme.darken(color, 0.5)),
						Rotation = 90,
					}),
					Stroke = e("UIStroke", { Color = Theme.COLORS.ink, Thickness = 2.5 }),
				}),
				Aura = e(SpaceFx.Flare, {
					color = color,
					size = ART * 1.15,
					position = UDim2.fromScale(0.5, 0.45),
					transparency = 0.2,
				}),
				Bob = e("Frame", {
					ref = bobRef,
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ZIndex = 3,
				}, {
					Image = e("ImageLabel", {
						Image = props.image,
						ImageColor3 = if props.dimmed then Color3.fromRGB(30, 24, 48) else Color3.new(1, 1, 1),
						ImageTransparency = if props.dimmed then 0.25 else 0,
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
					}),
				}),
			}),
		}),
	})
end

return OfferCard
