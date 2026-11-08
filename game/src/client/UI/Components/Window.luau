--!strict
-- Window — okno sklepu/ekranu w kosmicznym stylu gry:
--   • rozmycie świata (BlurEffect) i przyciemnienie za oknem,
--   • ramka: czarny kontur + obracający się neonowy gradient (kolor okna ↔ cyjan ↔ magenta),
--   • w środku dryfująca mgławica w kolorze okna, unoszące się iskierki, poświata u góry,
--   • nagłówek-wstążka z ikoną 3D, czerwony X, ozdoby 3D w rogach (unoszą się),
--   • opcjonalne zakładki (tabs) pod nagłówkiem.
-- Otwarcie = pop z overshootem + fala światła z środka + uiPop; zamknięcie (X, klik w tło, ButtonB) =
-- szybki zjazd + uiClose, potem onClose. Treść okna = `children`.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Motion = require(script.Parent.Parent.Motion)
local Sfx = require(script.Parent.Parent.Sfx)
local Theme = require(script.Parent.Parent.Theme)
local Button = require(script.Parent.Button)
local RibbonHeader = require(script.Parent.RibbonHeader)
local SpaceFx = require(script.Parent.SpaceFx)

local e = React.createElement

export type Tab = { id: string, text: string }
export type Props = {
	title: string,
	icon: string,
	color: Color3,
	size: Vector2?,
	onClose: () -> (),
	tabs: { Tab }?,
	tab: string?,
	onTab: ((id: string) -> ())?,
	fit: number?, -- dodatkowa skala, żeby okno zmieściło się na małym ekranie
	children: any?,
}

local DEFAULT_SIZE = Vector2.new(820, 500)
local BLUR_SIZE = 14

-- Ozdoba w rogu: ikona 3D z poświatą, unosi się.
local function Ornament(props: {
	image: string,
	size: number,
	position: UDim2,
	rotation: number,
	delay: number,
	color: Color3,
})
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
			Glow = e(SpaceFx.Flare, { color = props.color, size = props.size * 1.6, transparency = 0.45 }),
			Image = e("ImageLabel", {
				Image = props.image,
				Rotation = props.rotation,
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}),
		}),
	})
end

local function TabButton(props: { tab: Tab, active: boolean, color: Color3, order: number, onTab: (string) -> () })
	return e(Button, {
		text = props.tab.text,
		textSize = Theme.TEXT_SIZE.body,
		size = UDim2.fromOffset(170, 46),
		color = if props.active then props.color else Theme.COLORS.panelLight,
		corner = UDim.new(0, 14),
		layoutOrder = props.order,
		shine = props.active,
		onActivated = function()
			props.onTab(props.tab.id)
		end,
	})
end

local function Window(props: Props)
	local size = props.size or DEFAULT_SIZE
	local scaleRef = Motion.useEnter(0.55)
	local dimRef = React.useRef(nil :: TextButton?)
	local waveRef = React.useRef(nil :: ImageLabel?)
	local closingRef = React.useRef(false)
	local blurRef = React.useRef(nil :: BlurEffect?)

	local close = React.useCallback(function()
		if closingRef.current then
			return
		end
		closingRef.current = true
		Sfx.play("uiClose")
		Motion.tween(scaleRef.current, Theme.MOTION.close, { Scale = 0.6 })
		Motion.tween(dimRef.current, Theme.MOTION.close, { BackgroundTransparency = 1 })
		Motion.tween(blurRef.current, Theme.MOTION.close, { Size = 0 })
		task.delay(Theme.MOTION.close.Time, props.onClose)
	end, { props.onClose })

	React.useEffect(function()
		Sfx.play("uiPop")
		local dim = dimRef.current
		if dim then
			dim.BackgroundTransparency = 1
			Motion.tween(dim, Theme.MOTION.smooth, { BackgroundTransparency = 0.5 })
		end
		-- Fala światła z środka okna.
		local wave = waveRef.current
		if wave then
			wave.Size = UDim2.fromOffset(80, 80)
			wave.ImageTransparency = 0
			Motion.tween(wave, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(size.X * 1.8, size.X * 1.8),
				ImageTransparency = 1,
			})
		end
		local blur = Instance.new("BlurEffect")
		blur.Name = "WindowBlur"
		blur.Size = 0
		blur.Parent = Lighting
		blurRef.current = blur
		Motion.tween(blur, Theme.MOTION.smooth, { Size = BLUR_SIZE })
		local connection = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.ButtonB then
				close()
			end
		end)
		return function()
			connection:Disconnect()
			blur:Destroy()
		end
	end, {})

	local tabs: { [string]: any } = {
		List = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	if props.tabs then
		for i, tab in props.tabs do
			tabs[tab.id] = e(TabButton, {
				tab = tab,
				active = tab.id == props.tab,
				color = props.color,
				order = i,
				onTab = props.onTab or function() end,
			})
		end
	end
	local hasTabs = props.tabs ~= nil and #props.tabs > 0
	local contentTop = if hasTabs then 104 else 70

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 50 }, {
		Dim = e("TextButton", {
			ref = dimRef,
			Text = "",
			AutoButtonColor = false,
			Selectable = false,
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromHex("#05020D"),
			BackgroundTransparency = 0.5,
			ZIndex = 1,
			[React.Event.Activated] = close,
		}),
		Wave = e("ImageLabel", {
			ref = waveRef,
			Image = Theme.FX.flare,
			ImageColor3 = Theme.lighten(props.color, 0.3),
			ImageTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(80, 80),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}),
		Fit = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, {
			FitScale = e("UIScale", { Scale = props.fit or 1 }),
			Window = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 18),
				Size = UDim2.fromOffset(size.X, size.Y),
				BackgroundTransparency = 1,
				ZIndex = 3,
			}, {
				Scale = e("UIScale", { ref = scaleRef }),
				-- Czarna obwódka + obracający się neon (podwójna ramka).
				Outer = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, 16, 1, 16),
					BackgroundColor3 = Theme.COLORS.ink,
					ZIndex = 1,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 36) }),
					Neon = e(SpaceFx.NeonBorder, {
						thickness = 5,
						speed = 6,
						colors = ColorSequence.new({
							ColorSequenceKeypoint.new(0, props.color),
							ColorSequenceKeypoint.new(0.33, Theme.COLORS.neonCyan),
							ColorSequenceKeypoint.new(0.66, Theme.COLORS.neonMagenta),
							ColorSequenceKeypoint.new(1, props.color),
						}),
					}),
				}),
				Body = e("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ClipsDescendants = true,
					ZIndex = 2,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 28) }),
					Gradient = e("UIGradient", {
						Color = ColorSequence.new(Color3.fromHex("#1A0F33"), Color3.fromHex("#05020D")),
						Rotation = 90,
					}),
					InnerLine = e("UIStroke", {
						Color = Theme.lighten(props.color, 0.5),
						Transparency = 0.6,
						Thickness = 1.5,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					Nebula = e(SpaceFx.Nebula, { color = props.color, transparency = 0.6, speed = 45 }),
					NebulaMagenta = e(
						SpaceFx.Nebula,
						{ color = Theme.COLORS.neonMagenta, transparency = 0.82, speed = 70 }
					),
					TopGlow = e(SpaceFx.Flare, {
						color = props.color,
						size = size.X * 0.9,
						position = UDim2.fromScale(0.5, -0.05),
						transparency = 0.55,
						pulse = false,
					}),
					Particles = e(
						SpaceFx.Particles,
						{ count = 18, color = Theme.lighten(props.color, 0.6), seed = 13 }
					),
					Content = e("Frame", {
						Position = UDim2.fromOffset(26, contentTop),
						Size = UDim2.new(1, -52, 1, -(contentTop + 18)),
						BackgroundTransparency = 1,
						ZIndex = 5,
					}, props.children),
				}),
				Tabs = if hasTabs
					then e("Frame", {
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 46),
						Size = UDim2.new(1, -200, 0, 50),
						BackgroundTransparency = 1,
						ZIndex = 6,
					}, tabs)
					else nil,
				Header = e(RibbonHeader, { title = props.title, icon = props.icon, color = props.color }),
				Close = e(Button, {
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
					color = Theme.COLORS.gold,
				}),
				OrnamentStar = e(Ornament, {
					image = Theme.ICONS.star,
					size = 80,
					position = UDim2.new(1, 4, 1, -4),
					rotation = 12,
					delay = 0.9,
					color = Theme.COLORS.starYellow,
				}),
				OrnamentStarSmall = e(Ornament, {
					image = Theme.ICONS.star,
					size = 38,
					position = UDim2.new(1, -62, 1, 16),
					rotation = -20,
					delay = 1.6,
					color = Theme.COLORS.neonMagenta,
				}),
			}),
		}),
	})
end

return Window
