--!strict
-- Parts — wspólne elementy okien bazy: wiersz przedmiotu (ItemRow), przewijana lista (List),
-- pasek z informacjami i przyciskami (Bar), okno potwierdzenia sprzedaży (Confirm), pusta lista (Empty).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local UI = script.Parent.Parent
local Button = require(UI.Components.Button)
local Format = require(UI.Format)
local Label = require(UI.Components.Label)
local SpaceFx = require(UI.Components.SpaceFx)
local Theme = require(UI.Theme)

local Actions = require(script.Parent.Actions)

local e = React.createElement

local Parts = {}

local ROW_HEIGHT = 78

local function rarityColor(rarity: string): Color3
	return Theme.RARITY_COLORS[rarity] or Theme.COLORS.text
end

-- Opis rzadkości z mutacją: "LEGENDARY · GOLDEN".
function Parts.rarityText(entry: Actions.Entry): string
	local text = string.upper(entry.rarity)
	if entry.mutation ~= "None" then
		text ..= ` · {string.upper(entry.mutation)}`
	end
	return text
end

export type RowButton = { text: string, color: Color3?, onActivated: () -> (), width: number?, icon: string? }

-- Wiersz przedmiotu: ikona w kolorze rzadkości z poświatą, nazwa, rzadkość/mutacja, $/s, przyciski po prawej.
function Parts.ItemRow(
	props: {
		entry: Actions.Entry,
		buttons: { RowButton },
		layoutOrder: number?,
		highlight: boolean?,
		note: string?, -- dopisek pod $/s (np. „Pedestal 3”)
	}
)
	local entry = props.entry
	local color = rarityColor(entry.rarity)
	local buttons = {}
	for i, button in props.buttons do
		buttons[`B{i}`] = e(Button, {
			text = button.text,
			icon = button.icon,
			iconSize = 24,
			color = button.color,
			textSize = Theme.TEXT_SIZE.small + 2,
			size = UDim2.fromOffset(button.width or 116, 48),
			layoutOrder = i,
			onActivated = button.onActivated,
		})
	end
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundColor3 = if props.highlight then Theme.COLORS.nebula else Theme.COLORS.panelLight,
		BackgroundTransparency = 0.15,
		LayoutOrder = props.layoutOrder,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.CORNER_SMALL }),
		Stroke = e("UIStroke", {
			Color = color,
			Thickness = if props.highlight then 3 else 2,
			Transparency = if props.highlight then 0 else 0.45,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Icon = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(60, 60),
			BackgroundTransparency = 1,
		}, {
			Glow = e(SpaceFx.Flare, { color = color, size = 92, transparency = 0.35 }),
			Image = e("ImageLabel", {
				Image = Theme.ICONS.star,
				ImageColor3 = if entry.mutation == "Golden" then Theme.COLORS.gold else color,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}),
		}),
		Text = e("Frame", {
			Position = UDim2.fromOffset(82, 0),
			Size = UDim2.new(1, -82 - (#props.buttons * 124) - 10, 1, 0),
			BackgroundTransparency = 1,
		}, {
			List = e("UIListLayout", {
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Name = e(Label, {
				text = entry.name,
				textSize = Theme.TEXT_SIZE.body,
				xAlignment = Enum.TextXAlignment.Left,
				size = UDim2.new(1, 0, 0, 24),
				layoutOrder = 1,
			}),
			Info = e(Label, {
				text = `{Parts.rarityText(entry)}   <font color="#{Theme.COLORS.cash:ToHex()}">{Format.cash(
					entry.income
				)}/s</font>{if props.note then `   {props.note}` else ""}`,
				richText = true,
				textSize = Theme.TEXT_SIZE.small,
				color = color,
				stroke = 2,
				xAlignment = Enum.TextXAlignment.Left,
				size = UDim2.new(1, 0, 0, 20),
				layoutOrder = 2,
			}),
		}),
		Buttons = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, -2),
			Size = UDim2.fromOffset(#props.buttons * 124, 54),
			BackgroundTransparency = 1,
		}, {
			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Children = e(React.Fragment, nil, buttons),
		}),
	})
end

-- Przewijana lista wierszy.
function Parts.List(props: { children: any, size: UDim2?, position: UDim2? })
	local children = table.clone(props.children or {})
	children.Layout = e("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	children.Pad = e("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 10),
	})
	return e("ScrollingFrame", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
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

-- Pasek nad listą: tekst po lewej (rich text), elementy po prawej (children).
function Parts.Bar(props: { text: string, children: any? })
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = Theme.COLORS.ink,
		BackgroundTransparency = 0.45,
	}, {
		Corner = e("UICorner", { CornerRadius = Theme.CORNER_SMALL }),
		Text = e(Label, {
			text = props.text,
			richText = true,
			textSize = Theme.TEXT_SIZE.body,
			xAlignment = Enum.TextXAlignment.Left,
			position = UDim2.fromOffset(16, 0),
			size = UDim2.new(0.5, -16, 1, 0),
		}),
		Right = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, -2),
			Size = UDim2.new(0.5, 0, 0, 56),
			BackgroundTransparency = 1,
		}, {
			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Children = if props.children then e(React.Fragment, nil, props.children) else nil,
		}),
	})
end

function Parts.Empty(props: { text: string })
	return e(Label, {
		text = props.text,
		textSize = Theme.TEXT_SIZE.body,
		color = Theme.COLORS.textMuted,
		wrapped = true,
		size = UDim2.new(1, 0, 0, 80),
		layoutOrder = 99,
	})
end

-- Potwierdzenie sprzedaży (Legendary+): przyciemnienie okna i karta z przyciskami.
function Parts.Confirm(props: { entry: Actions.Entry, onConfirm: () -> (), onCancel: () -> () })
	local entry = props.entry
	local color = rarityColor(entry.rarity)
	return e("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.COLORS.overlay,
		BackgroundTransparency = 0.35,
		ZIndex = 20,
		[React.Event.Activated] = props.onCancel,
	}, {
		Card = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(440, 230),
			BackgroundColor3 = Theme.COLORS.panel,
			ZIndex = 21,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.CORNER }),
			Stroke = e("UIStroke", { Color = color, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Title = e(Label, {
				text = "SELL THIS ITEM?",
				textSize = Theme.TEXT_SIZE.title,
				color = Theme.COLORS.starYellow,
				anchorPoint = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, 16),
				zIndex = 22,
			}),
			Item = e(Label, {
				text = `{entry.name}\n<font size="16">{Parts.rarityText(entry)}</font>`,
				richText = true,
				textSize = Theme.TEXT_SIZE.body,
				color = color,
				anchorPoint = Vector2.new(0.5, 0),
				position = UDim2.new(0.5, 0, 0, 62),
				zIndex = 22,
			}),
			Buttons = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -18),
				Size = UDim2.fromOffset(400, 56),
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
					text = "KEEP",
					color = Theme.COLORS.panelLight,
					size = UDim2.fromOffset(160, 54),
					layoutOrder = 1,
					onActivated = props.onCancel,
				}),
				Sell = e(Button, {
					text = `SELL {Format.cash(entry.price)}`,
					color = Theme.COLORS.danger,
					size = UDim2.fromOffset(210, 54),
					layoutOrder = 2,
					onActivated = props.onConfirm,
				}),
			}),
		}),
	})
end

return Parts
