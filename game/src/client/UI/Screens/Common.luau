--!strict
-- Common — wspólne klocki ekranów T14: lista kart ofert, panel, pasek postępu, potwierdzenie.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local UI = script.Parent.Parent
local Button = require(UI.Components.Button)
local Label = require(UI.Components.Label)
local Theme = require(UI.Theme)

local e = React.createElement

local Common = {}

-- Przewijana lista kart ofert (OfferCard wystaje render w lewo i nagłówek w górę — stąd marginesy).
function Common.CardList(props: { children: any })
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
		Selectable = false,
	}, children)
end

-- Ciemny panel z obrysem w kolorze.
function Common.Panel(props: {
	color: Color3,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	children: any?,
})
	local children = table.clone(props.children or {})
	children.Corner = e("UICorner", { CornerRadius = Theme.CORNER_SMALL })
	children.Stroke = e("UIStroke", {
		Color = props.color,
		Thickness = 2,
		Transparency = 0.25,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	return e("Frame", {
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = Theme.COLORS.ink,
		BackgroundTransparency = 0.35,
	}, children)
end

-- Pasek postępu (0..1) w kolorze, z napisem na środku.
function Common.Progress(props: {
	fraction: number,
	color: Color3,
	text: string,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
})
	local fraction = math.clamp(props.fraction, 0, 1)
	return e("Frame", {
		Size = props.size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		BackgroundColor3 = Theme.COLORS.space,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.PILL }),
		Stroke = e("UIStroke", { Color = Theme.COLORS.ink, Thickness = 2 }),
		Fill = e("Frame", {
			Size = UDim2.fromScale(fraction, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Visible = fraction > 0,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.PILL }),
			Gradient = e("UIGradient", { Color = Theme.duo(props.color), Rotation = 90 }),
		}),
		Text = e(Label, {
			text = props.text,
			textSize = Theme.TEXT_SIZE.tiny,
			anchorPoint = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			zIndex = 3,
		}),
	})
end

-- Potwierdzenie (np. Rebirth): przyciemnienie okna i karta z dwoma przyciskami. Klik w tło = anuluj.
-- Pad: jeśli zaznaczenie było aktywne, przechodzi na przyciski karty (CANCEL pierwszy).
function Common.Confirm(props: {
	title: string,
	text: string,
	confirmText: string,
	color: Color3,
	onConfirm: () -> (),
	onCancel: () -> (),
})
	local cardRef = React.useRef(nil :: Frame?)
	React.useEffect(function()
		local card = cardRef.current
		if card and GuiService.SelectedObject ~= nil then
			GuiService:Select(card)
		end
		return nil
	end, {})
	return e("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Selectable = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.COLORS.overlay,
		BackgroundTransparency = 0.35,
		ZIndex = 20,
		[React.Event.Activated] = props.onCancel,
	}, {
		Card = e("Frame", {
			ref = cardRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(480, 250),
			BackgroundColor3 = Theme.COLORS.panel,
			ZIndex = 21,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.CORNER }),
			Stroke = e(
				"UIStroke",
				{ Color = props.color, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
			),
			Title = e(Label, {
				text = props.title,
				textSize = Theme.TEXT_SIZE.title,
				color = Theme.COLORS.starYellow,
				anchorPoint = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, 16),
				zIndex = 22,
			}),
			Text = e(Label, {
				text = props.text,
				richText = true,
				wrapped = true,
				font = Theme.FONTS.body,
				textSize = Theme.TEXT_SIZE.body,
				anchorPoint = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, 62),
				size = UDim2.new(1, -40, 0, 90),
				zIndex = 22,
			}),
			Buttons = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -18),
				Size = UDim2.fromOffset(440, 56),
				BackgroundTransparency = 1,
				ZIndex = 22,
			}, {
				List = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 16),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Cancel = e(Button, {
					text = "CANCEL",
					color = Theme.COLORS.panelLight,
					size = UDim2.fromOffset(170, 54),
					layoutOrder = 1,
					onActivated = props.onCancel,
				}),
				Confirm = e(Button, {
					text = props.confirmText,
					color = props.color,
					size = UDim2.fromOffset(220, 54),
					layoutOrder = 2,
					onActivated = props.onConfirm,
				}),
			}),
		}),
	})
end

return Common
