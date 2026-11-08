--!strict
-- Window — okno sklepu/ekranu w stylu gry: przyciemnione tło, gruba czarna ramka z neonowym (oddychającym)
-- obrysem, mgławica i migoczące gwiazdki w tle, ozdoby 3D w rogach (unoszą się), nagłówek-wstążka i czerwony X.
-- Otwarcie = pop z overshootem (0,25 s) + uiPop; zamknięcie (X, klik w tło, ButtonB) = szybki zjazd + uiClose,
-- potem onClose. Treść okna = `children` (np. lista OfferCard).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Motion = require(script.Parent.Parent.Motion)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.Theme)
local Button = require(script.Parent.Button)
local Label = require(script.Parent.Label)
local RibbonHeader = require(script.Parent.RibbonHeader)

local e = React.createElement

export type Props = {
	title: string,
	icon: string,
	color: Color3,
	size: Vector2?,
	onClose: () -> (),
	section: string?, -- belka sekcji pod nagłówkiem
	children: any?,
}

local DEFAULT_SIZE = Vector2.new(820, 500)
-- Gwiazdki tła (stałe pozycje w ułamkach okna, rozmiar px, przesunięcie fazy migotania).
local TWINKLES = {
	{ 0.08, 0.18, 3, 0 },
	{ 0.22, 0.72, 2, 0.6 },
	{ 0.35, 0.12, 3, 1.1 },
	{ 0.5, 0.88, 2, 0.3 },
	{ 0.63, 0.3, 3, 1.5 },
	{ 0.78, 0.65, 2, 0.9 },
	{ 0.9, 0.2, 3, 0.4 },
	{ 0.95, 0.82, 2, 1.3 },
	{ 0.15, 0.45, 2, 1.8 },
	{ 0.7, 0.92, 3, 0.2 },
}

local function Twinkle(props: { x: number, y: number, size: number, delay: number })
	local ref = React.useRef(nil :: Frame?)
	Motion.useLoop(ref :: any, 1.1, { BackgroundTransparency = 0.85 }, { delay = props.delay })
	return e("Frame", {
		ref = ref,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(props.x, props.y),
		Size = UDim2.fromOffset(props.size, props.size),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.1,
		ZIndex = 1,
	}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

-- Ozdoba w rogu: ikona 3D w ramce-opakowaniu, która się unosi.
local function Ornament(props: { image: string, size: number, position: UDim2, rotation: number, delay: number })
	local bobRef = React.useRef(nil :: Frame?)
	Motion.useBob(bobRef :: any, Theme.IDLE.floatPixels, Theme.IDLE.floatTime, props.delay)
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.position,
		Size = UDim2.fromOffset(props.size, props.size),
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, {
		Bob = e("Frame", { ref = bobRef, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
			Image = e("ImageLabel", {
				Image = props.image,
				Rotation = props.rotation,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}),
		}),
	})
end

local function Window(props: Props)
	local size = props.size or DEFAULT_SIZE
	local scaleRef = Motion.useEnter(0.6)
	local neonRef = React.useRef(nil :: UIStroke?)
	local dimRef = React.useRef(nil :: TextButton?)
	local closingRef = React.useRef(false)

	Motion.useLoop(neonRef :: any, Theme.IDLE.breatheTime, { Transparency = 0.5 }, {})

	local close = React.useCallback(function()
		if closingRef.current then
			return
		end
		closingRef.current = true
		Sfx.play("uiClose")
		Motion.tween(scaleRef.current, Theme.MOTION.close, { Scale = 0.7 })
		Motion.tween(dimRef.current, Theme.MOTION.close, { BackgroundTransparency = 1 })
		task.delay(Theme.MOTION.close.Time, props.onClose)
	end, { props.onClose })

	React.useEffect(function()
		Sfx.play("uiPop")
		local dim = dimRef.current
		if dim then
			dim.BackgroundTransparency = 1
			Motion.tween(dim, Theme.MOTION.smooth, { BackgroundTransparency = 0.45 })
		end
		local connection = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.ButtonB then
				close()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	local twinkles = {}
	for i, t in TWINKLES do
		twinkles[`T{i}`] = e(Twinkle, { x = t[1], y = t[2], size = t[3], delay = t[4] })
	end

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 50 }, {
		Dim = e("TextButton", {
			ref = dimRef,
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.COLORS.overlay,
			BackgroundTransparency = 0.45,
			ZIndex = 1,
			[React.Event.Activated] = close,
		}),
		Window = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 20),
			Size = UDim2.fromOffset(size.X, size.Y),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			Scale = e("UIScale", { ref = scaleRef }),
			-- Neon: zewnętrzny kolorowy obrys + czarny kontur na krawędzi.
			Neon = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 14, 1, 14),
				BackgroundColor3 = Theme.COLORS.ink,
				ZIndex = 1,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 34) }),
				Stroke = e("UIStroke", {
					ref = neonRef,
					Color = Theme.COLORS.neonCyan,
					Thickness = 5,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			}),
			Body = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				ZIndex = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 28) }),
				Gradient = e("UIGradient", { Color = Theme.SPACE_GRADIENT, Rotation = 90 }),
				Stroke = e("UIStroke", {
					Color = Theme.COLORS.ink,
					Thickness = 4,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				-- Mgławica w prawym górnym rogu.
				Nebula = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.85, 0.05),
					Size = UDim2.fromOffset(size.X * 0.7, size.Y * 0.6),
					BackgroundColor3 = Theme.COLORS.neonMagenta,
					BackgroundTransparency = 0,
					ZIndex = 1,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Fade = e("UIGradient", {
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0.82),
							NumberSequenceKeypoint.new(1, 1),
						}),
					}),
				}),
				Twinkles = e(
					"Frame",
					{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 },
					twinkles
				),
				Content = e("Frame", {
					Position = UDim2.fromOffset(28, if props.section then 96 else 70),
					Size = UDim2.new(1, -56, 1, if props.section then -116 else -90),
					BackgroundTransparency = 1,
					ZIndex = 3,
				}, props.children),
			}),
			Section = if props.section
				then e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 44),
					Size = UDim2.fromOffset(0, 38),
					AutomaticSize = Enum.AutomaticSize.X,
					BackgroundColor3 = Color3.new(1, 1, 1),
					ZIndex = 6,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
					Gradient = e("UIGradient", { Color = Theme.duo(Theme.COLORS.neonMagenta), Rotation = 90 }),
					Stroke = e("UIStroke", {
						Color = Theme.COLORS.ink,
						Thickness = 3,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 34), PaddingRight = UDim.new(0, 34) }),
					Text = e(Label, {
						text = props.section,
						textSize = Theme.TEXT_SIZE.body + 2,
						size = UDim2.fromScale(0, 1),
						automaticSize = Enum.AutomaticSize.X,
					}),
				})
				else nil,
			Header = e(RibbonHeader, { title = props.title, icon = props.icon, color = props.color }),
			Close = e(Button, {
				name = "Close",
				size = UDim2.fromOffset(62, 62),
				position = UDim2.new(1, 22, 0, -22),
				anchorPoint = Vector2.new(1, 0),
				rotation = 4,
				color = Theme.COLORS.danger,
				corner = UDim.new(0, 16),
				text = "X",
				textSize = Theme.TEXT_SIZE.title + 4,
				sound = false,
				onActivated = close,
			}),
			OrnamentGem = e(Ornament, {
				image = Theme.ICONS.premium,
				size = 74,
				position = UDim2.new(0, -6, 1, 0),
				rotation = -14,
				delay = 0,
			}),
			OrnamentStar = e(Ornament, {
				image = Theme.ICONS.star,
				size = 80,
				position = UDim2.new(1, 4, 1, -4),
				rotation = 12,
				delay = 0.9,
			}),
			OrnamentStarSmall = e(Ornament, {
				image = Theme.ICONS.star,
				size = 38,
				position = UDim2.new(1, -60, 1, 14),
				rotation = -20,
				delay = 1.6,
			}),
		}),
	})
end

return Window
