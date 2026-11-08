--!strict
-- Button — gruby cukierkowy przycisk 3D: ciemny „spód”, wierzch z dwutonowym gradientem, czarny kontur,
-- połysk i opcjonalny błysk przelatujący co kilka sekund (żywe UI). Sprężynuje przy hover/tap
-- (UIScale z overshootem), klik dociska wierzch do spodu i gra uiClick. Activated = mysz, dotyk, pad.
-- Zawartość: `text` (+ opcjonalna `icon`) albo własne dzieci (`content`). Wzór: CarImportEmpire Button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Motion = require(script.Parent.Parent.Motion)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.Theme)
local Label = require(script.Parent.Label)

local e = React.createElement

export type Props = {
	text: string?,
	icon: string?,
	iconSize: number?,
	content: any?, -- własne elementy zamiast tekstu
	onActivated: (() -> ())?,
	color: Color3?,
	disabled: boolean?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	textSize: number?,
	corner: UDim?,
	shine: boolean?, -- okresowy błysk
	shineDelay: number?,
	rotation: number?,
	sound: boolean?, -- false = bez klikania
	name: string?,
}

local HOVER_SCALE = 1.07
local PRESS_SCALE = 0.92

local function Button(props: Props, ref: any)
	local disabled = props.disabled == true
	local color = if disabled then Color3.fromHex("#4A4560") else (props.color or Theme.COLORS.neonCyan)
	local depth = Theme.BUTTON_DEPTH
	local corner = props.corner or Theme.CORNER_SMALL
	local scaleRef = React.useRef(nil :: UIScale?)
	local faceRef = React.useRef(nil :: Frame?)
	local shineRef = React.useRef(nil :: UIGradient?)
	local hoveredRef = React.useRef(false)

	-- Bez pasma błysku (shine = false) ref jest pusty i pętla się nie uruchamia.
	Motion.useShine(shineRef, props.shineDelay)

	local function press(down: boolean)
		Motion.tween(faceRef.current, Theme.MOTION.press, { Position = UDim2.fromOffset(0, if down then depth else 0) })
		Motion.tween(scaleRef.current, if down then Theme.MOTION.press else Theme.MOTION.release, {
			Scale = if down then PRESS_SCALE elseif hoveredRef.current then HOVER_SCALE else 1,
		})
	end

	local function hover(on: boolean)
		hoveredRef.current = on
		Motion.tween(scaleRef.current, Theme.MOTION.release, { Scale = if on and not disabled then HOVER_SCALE else 1 })
		if not on then
			Motion.tween(faceRef.current, Theme.MOTION.press, { Position = UDim2.fromOffset(0, 0) })
		end
	end

	local inner: any = props.content
	if not inner then
		local hasIcon = props.icon ~= nil
		local iconSize = props.iconSize or 34
		inner = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Icon = if hasIcon
				then e("ImageLabel", {
					Image = props.icon,
					Size = UDim2.fromOffset(iconSize, iconSize),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				})
				else nil,
			Text = if props.text
				then e(Label, {
					text = props.text,
					textSize = props.textSize or Theme.TEXT_SIZE.body,
					color = if disabled then Theme.COLORS.textMuted else Theme.COLORS.text,
					layoutOrder = 2,
				})
				else nil,
		})
	end

	return e("TextButton", {
		ref = ref,
		Text = "",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Selectable = not disabled,
		Size = props.size or UDim2.fromOffset(160, 52),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		LayoutOrder = props.layoutOrder,
		Rotation = props.rotation,
		[React.Event.Activated] = function()
			if disabled then
				return
			end
			if props.sound ~= false then
				Sfx.play("uiClick")
			end
			if props.onActivated then
				props.onActivated()
			end
		end,
		[React.Event.MouseEnter] = function()
			hover(true)
		end,
		[React.Event.MouseLeave] = function()
			hover(false)
		end,
		[React.Event.SelectionGained] = function()
			hover(true)
		end,
		[React.Event.SelectionLost] = function()
			hover(false)
		end,
		[React.Event.MouseButton1Down] = function()
			if not disabled then
				press(true)
			end
		end,
		[React.Event.MouseButton1Up] = function()
			press(false)
		end,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Bottom = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.darken(color, 0.5),
			ZIndex = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = corner }),
			Stroke = e("UIStroke", {
				Color = Theme.COLORS.ink,
				Thickness = Theme.FRAME_STROKE,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		Face = e("Frame", {
			ref = faceRef,
			Size = UDim2.new(1, 0, 1, -depth),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = corner }),
			Gradient = e("UIGradient", { Color = Theme.duo(color), Rotation = 90 }),
			Stroke = e("UIStroke", {
				Color = Theme.COLORS.ink,
				Thickness = Theme.FRAME_STROKE,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Gloss = e("Frame", {
				Size = UDim2.new(1, -8, 0.45, 0),
				Position = UDim2.fromOffset(4, 3),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.75,
				ZIndex = 3,
			}, {
				Corner = e("UICorner", { CornerRadius = corner }),
				Fade = e("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }),
			}),
			Shine = if props.shine and not disabled
				then e("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 4,
				}, {
					Corner = e("UICorner", { CornerRadius = corner }),
					Band = e("UIGradient", {
						ref = shineRef,
						Rotation = 20,
						Transparency = Theme.SHINE_BAND,
						Offset = Vector2.new(-1, 0),
					}),
				})
				else nil,
			Content = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }, {
				Inner = inner,
			}),
		}),
	})
end

return React.forwardRef(Button)
