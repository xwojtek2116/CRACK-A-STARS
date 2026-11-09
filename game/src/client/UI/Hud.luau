--!strict
-- Hud — interfejs w grze: kasa + $/s (lewy górny róg), pasek gwiazdy (góra, środek: Components/StarBar),
-- menu Shop/Base/Index/Rides/R$ (lewa krawędź; na telefonie 2 kolumny), paliwo jetpacka (prawy dół, tylko
-- gdy jest atrybut Fuel) i latające monety przy większym przyroście kasy. Kompas do gwiazdy rysuje Fx/StarHud.
-- Lekkie animacje „życia”: oddychające neonowe obrysy, unoszące się przyciski, błyski, kołysząca się gwiazda.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local UI = script.Parent
local Button = require(UI.Components.Button)
local Format = require(UI.Format)
local Label = require(UI.Components.Label)
local Motion = require(UI.Motion)
local Sfx = require(UI.Sfx)
local StarBar = require(UI.Components.StarBar)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local HudSide = require(UI.Screens.HudSide)

local e = React.createElement

type Ref<T> = { current: T? }

local MENU_BUTTON = Vector2.new(80, 76)
local FUEL_SEGMENTS = 5
local COIN_SIZE = 30
local MAX_COINS = 8

-- Pigułka HUD: kosmiczne tło, neonowy obrys, który powoli „oddycha”.
local function Pill(props: {
	color: Color3,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	padding: number?,
	children: any?,
	breatheDelay: number?,
	layoutOrder: number?,
})
	local strokeRef = React.useRef(nil :: UIStroke?)
	Motion.useLoop(strokeRef :: any, Theme.IDLE.breatheTime, { Transparency = 0.55 }, { delay = props.breatheDelay })
	local auto = if props.size then Enum.AutomaticSize.None else Enum.AutomaticSize.XY
	-- Kontener: czarny cień przesunięty w dół (głębia) + korpus z neonowym obrysem.
	return e("Frame", {
		Size = props.size or UDim2.new(),
		AutomaticSize = auto,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		LayoutOrder = props.layoutOrder,
	}, {
		Shadow = e("Frame", {
			Position = UDim2.fromOffset(0, 5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.COLORS.ink,
			ZIndex = 1,
		}, { Corner = e("UICorner", { CornerRadius = Theme.PILL }) }),
		Body = e("Frame", {
			Size = props.size or UDim2.new(),
			AutomaticSize = auto,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 2,
		}, {
			Corner = e("UICorner", { CornerRadius = Theme.PILL }),
			Gradient = e("UIGradient", { Color = Theme.SPACE_GRADIENT, Rotation = 90 }),
			Neon = e("UIStroke", {
				ref = strokeRef,
				Color = props.color,
				Thickness = 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, props.padding or 14),
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
			Content = e("Frame", {
				Size = UDim2.new(),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
			}, props.children),
		}),
	})
end

local function row(padding: number?): any
	return e("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- ---------------------------------------------------------------- kasa

local function Cash(props: { coinRef: Ref<ImageLabel> })
	local cash = Store.use(function(state)
		return state.cash
	end)
	local income = Store.use(function(state)
		return state.incomePerSec
	end)
	local shown = Motion.useCountUp(cash)
	local pulseRef = Motion.usePulse(cash, 1.12)

	return e("Frame", {
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, {
		List = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Main = e(Pill, { color = Theme.COLORS.neonCyan, layoutOrder = 1, padding = 20 }, {
			Row = row(8),
			Coin = e("ImageLabel", {
				ref = props.coinRef,
				Image = Theme.ICONS.coin,
				Size = UDim2.fromOffset(46, 46),
				BackgroundTransparency = 1,
				LayoutOrder = 1,
			}),
			Amount = e(Label, {
				text = Format.cash(shown),
				textSize = Theme.TEXT_SIZE.big,
				stroke = 4,
				layoutOrder = 2,
			}, { Pulse = e("UIScale", { ref = pulseRef }) }),
		}),
		Income = e("Frame", {
			Size = UDim2.new(),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			LayoutOrder = 2,
		}, {
			Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 18) }),
			Pill = e(Pill, { color = Theme.COLORS.price, padding = 12, breatheDelay = 0.7 }, {
				Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 8) }),
				Text = e(Label, {
					text = `+{Format.cash(income)}/s`,
					textSize = Theme.TEXT_SIZE.body,
					color = Theme.COLORS.cash,
				}),
			}),
		}),
	})
end

-- ---------------------------------------------------------------- menu

local function MenuButton(props: {
	id: Store.WindowId,
	text: string,
	icon: string,
	color: Color3,
	order: number,
	shine: boolean?,
	badge: string?,
})
	local bobRef = React.useRef(nil :: Frame?)
	local badgeRef = React.useRef(nil :: UIScale?)
	Motion.useBob(bobRef :: any, Theme.IDLE.bobPixels, Theme.IDLE.bobTime, props.order * 0.25)
	Motion.useLoop(badgeRef :: any, 0.5, { Scale = 1.15 }, {})
	return e("Frame", {
		Size = UDim2.fromOffset(MENU_BUTTON.X, MENU_BUTTON.Y),
		BackgroundTransparency = 1,
		LayoutOrder = props.order,
	}, {
		Bob = e("Frame", { ref = bobRef, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
			Button = e(Button, {
				name = props.id,
				size = UDim2.fromScale(1, 1),
				color = props.color,
				corner = UDim.new(0, 18),
				shine = props.shine,
				shineDelay = props.order * 0.6,
				onActivated = function()
					Store.openWindow(props.id)
				end,
				content = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
					Icon = e("ImageLabel", {
						Image = props.icon,
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 1),
						Size = UDim2.fromOffset(40, 40),
						BackgroundTransparency = 1,
					}),
					Text = e(Label, {
						text = props.text,
						textSize = Theme.TEXT_SIZE.small,
						anchorPoint = Vector2.new(0.5, 1),
						position = UDim2.new(0.5, 0, 1, -2),
					}),
				}),
			}),
			Badge = if props.badge
				then e(Label, {
					text = props.badge,
					textSize = Theme.TEXT_SIZE.tiny,
					rotation = -8,
					anchorPoint = Vector2.new(0.5, 0.5),
					position = UDim2.new(1, -6, 0, 2),
					zIndex = 5,
				}, { Pulse = e("UIScale", { ref = badgeRef }) })
				else nil,
		}),
	})
end

local MENU = {
	{ id = "Shop", text = "SHOP", icon = "shop", color = "shop", shine = true },
	{ id = "Base", text = "BASE", icon = "base", color = "base" },
	{ id = "Index", text = "INDEX", icon = "index", color = "index" },
	{ id = "Rides", text = "RIDES", icon = "rides", color = "rides" },
	{ id = "Premium", text = "R$", icon = "premium", color = "premium", shine = true },
}

local function Menu(props: { compact: boolean, frameRef: Ref<Frame> })
	local children: { [string]: any } = {
		Layout = if props.compact
			then e("UIGridLayout", {
				CellSize = UDim2.fromOffset(MENU_BUTTON.X, MENU_BUTTON.Y),
				CellPadding = UDim2.fromOffset(10, 10),
				FillDirectionMaxCells = 2,
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			else e("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for i, item in MENU do
		children[item.id] = e(MenuButton, {
			id = item.id :: any,
			text = item.text,
			icon = (Theme.ICONS :: any)[item.icon],
			color = (Theme.COLORS :: any)[item.color],
			order = i,
			shine = item.shine,
		})
	end
	return e("Frame", {
		ref = props.frameRef,
		Position = UDim2.fromOffset(18, if props.compact then 128 else 150),
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
	}, children)
end

-- ---------------------------------------------------------------- paliwo

local function FuelSegment(props: { filled: boolean, low: boolean, order: number })
	local ref = React.useRef(nil :: Frame?)
	Motion.useLoop(ref :: any, 0.25, { BackgroundTransparency = 0.6 }, { enabled = props.low and props.filled })
	return e("Frame", {
		ref = ref,
		Size = UDim2.fromOffset(32, 16),
		BackgroundColor3 = if not props.filled
			then Color3.fromHex("#1C2B40")
			elseif props.low then Theme.COLORS.danger
			else Theme.COLORS.neonCyan,
		BackgroundTransparency = 0,
		LayoutOrder = props.order,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 5) }),
		Stroke = e("UIStroke", { Color = Theme.COLORS.ink, Thickness = 2.5 }),
	})
end

local function Fuel(props: { compact: boolean })
	local fuel = Store.use(function(state)
		return state.fuel
	end)
	local fuelMax = Store.use(function(state)
		return state.fuelMax
	end)
	local shakeRef = React.useRef(nil :: Frame?)
	local fraction = if fuel then math.clamp(fuel / math.max(fuelMax, 0.001), 0, 1) else 0
	local low = fuel ~= nil and fraction < Theme.LOW_FUEL
	Motion.useLoop(shakeRef :: any, 0.06, { Position = UDim2.fromOffset(3, 0) }, { enabled = low })
	React.useEffect(function()
		local shake = shakeRef.current
		if shake and not low then
			shake.Position = UDim2.fromOffset(0, 0)
		end
		return nil
	end, { low })

	local color = if low then Theme.COLORS.danger else Theme.COLORS.neonCyan
	local segments: { [string]: any } = { Row = row(4) }
	for i = 1, FUEL_SEGMENTS do
		-- Segment pełny, gdy paliwo sięga jego połowy; przy niskim zawsze świeci pierwszy.
		local filled = fraction >= (i - 0.5) / FUEL_SEGMENTS or (i == 1 and fraction > 0)
		segments[`S{i}`] = e(FuelSegment, { filled = filled, low = low, order = i })
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = if props.compact then UDim2.new(1, -170, 1, -26) else UDim2.new(1, -24, 1, -24),
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Visible = fuel ~= nil,
	}, {
		Shake = e("Frame", {
			ref = shakeRef,
			Size = UDim2.new(),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
		}, {
			Pill = e(Pill, { color = color, padding = 16, breatheDelay = 1.0 }, {
				Row = row(8),
				Icon = e("ImageLabel", {
					Image = Theme.ICONS.fuel,
					ImageColor3 = if low then Color3.fromHex("#FF8090") else Color3.new(1, 1, 1),
					Size = UDim2.fromOffset(40, 40),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				}),
				Col = e("Frame", {
					Size = UDim2.new(),
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					LayoutOrder = 2,
				}, {
					List = e("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
					Caption = e(Label, {
						text = if low then "LOW FUEL!" else "JETPACK FUEL",
						textSize = Theme.TEXT_SIZE.tiny,
						font = Theme.FONTS.body,
						color = if low then Color3.fromHex("#FF9AA6") else Color3.fromHex("#9FF6FF"),
						stroke = 2,
						xAlignment = Enum.TextXAlignment.Left,
						layoutOrder = 1,
					}),
					Segments = e("Frame", {
						Size = UDim2.new(),
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						LayoutOrder = 2,
					}, segments),
				}),
			}),
		}),
	})
end

-- ---------------------------------------------------------------- latające monety

-- Przy przyroście kasy większym niż zwykły dochód pasywny: monety lecą łukiem do ikony kasy, każda
-- z dźwiękiem, a nad kasą wyskakuje „+$X”. Tworzone imperatywnie (efekt chwilowy).
local function FlyingCoins(props: { coinRef: Ref<ImageLabel> })
	local gain = Store.use(function(state)
		return state.cashGain
	end)
	local layerRef = React.useRef(nil :: Frame?)

	React.useEffect(function()
		local layer = layerRef.current
		local coin = props.coinRef.current
		if not gain or not layer or not coin then
			return nil
		end
		local income = Store.get().incomePerSec
		if gain.amount <= income * 2 then
			return nil -- zwykły tick dochodu: sam licznik i puls, bez monet
		end
		local size = layer.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return nil
		end
		local function toScale(point: Vector2): UDim2
			local rel = (point - layer.AbsolutePosition) / size
			return UDim2.fromScale(rel.X, rel.Y)
		end
		local target = toScale(coin.AbsolutePosition + coin.AbsoluteSize / 2)
		local count = math.clamp(3 + math.floor(math.log10(math.max(gain.amount, 1))), 3, MAX_COINS)
		local rng = Random.new()

		for i = 1, count do
			local image = Instance.new("ImageLabel")
			image.Image = Theme.ICONS.coin
			image.BackgroundTransparency = 1
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.Size = UDim2.fromOffset(COIN_SIZE, COIN_SIZE)
			image.Position = UDim2.fromScale(0.5 + rng:NextNumber(-0.08, 0.08), 0.62 + rng:NextNumber(-0.05, 0.05))
			image.Rotation = rng:NextNumber(-30, 30)
			image.Parent = layer
			local mid = UDim2.fromScale(
				(image.Position.X.Scale + target.X.Scale) / 2 + rng:NextNumber(-0.1, 0.1),
				math.min(image.Position.Y.Scale, target.Y.Scale) + rng:NextNumber(0.05, 0.2)
			)
			task.delay((i - 1) * 0.07, function()
				local up = Motion.tween(image, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = mid,
					Size = UDim2.fromOffset(COIN_SIZE * 1.3, COIN_SIZE * 1.3),
				})
				if not up then
					return
				end
				up.Completed:Wait()
				local fly = Motion.tween(image, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = target,
					Size = UDim2.fromOffset(COIN_SIZE * 0.8, COIN_SIZE * 0.8),
					Rotation = 0,
				})
				if fly then
					fly.Completed:Wait()
				end
				Sfx.play("uiCoin", 0.8)
				image:Destroy()
			end)
		end

		-- „+$X” nad kasą: wyskakuje, unosi się i znika.
		local popup = Instance.new("TextLabel")
		popup.BackgroundTransparency = 1
		popup.Text = `+${Format.number(gain.amount)}`
		popup.FontFace = Theme.FONTS.display
		popup.TextSize = Theme.TEXT_SIZE.title
		popup.TextColor3 = Theme.COLORS.cash
		popup.AutomaticSize = Enum.AutomaticSize.XY
		popup.AnchorPoint = Vector2.new(0, 0.5)
		popup.Rotation = -6
		popup.Position = UDim2.new(target.X.Scale, 30, target.Y.Scale, 60)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = Theme.COLORS.ink
		stroke.Parent = popup
		local scale = Instance.new("UIScale")
		scale.Scale = 0.3
		scale.Parent = popup
		popup.Parent = layer
		Motion.tween(scale, Theme.MOTION.release, { Scale = 1 })
		task.delay(0.9, function()
			Motion.tween(popup, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(target.X.Scale, 30, target.Y.Scale, 30),
				TextTransparency = 1,
			})
			Motion.tween(stroke, TweenInfo.new(0.5), { Transparency = 1 })
		end)
		task.delay(1.5, function()
			popup:Destroy()
		end)
		return nil
	end, { gain })

	return e("Frame", {
		ref = layerRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 90,
	})
end

-- ---------------------------------------------------------------- HUD

-- Krawędzie HUD dla innych warstw UI (Fx/StarHud): banery gwiazd pod licznikiem, strzałka kompasu
-- nie wchodzi na menu. Atrybuty PlayerGui w px ekranu: HudTopInset, HudLeftInset.
local function useInsets(timerRef: Ref<Frame>, menuRef: Ref<Frame>)
	React.useEffect(function()
		local timer, menu = timerRef.current, menuRef.current
		local playerGui = timer and timer:FindFirstAncestorWhichIsA("PlayerGui")
		if not timer or not menu or not playerGui then
			return nil
		end
		local function publish()
			local top = if timer.Visible then timer.AbsolutePosition.Y + timer.AbsoluteSize.Y else 0
			playerGui:SetAttribute("HudTopInset", math.round(top))
			playerGui:SetAttribute("HudLeftInset", math.round(menu.AbsolutePosition.X + menu.AbsoluteSize.X))
		end
		local connections = {
			timer:GetPropertyChangedSignal("AbsoluteSize"):Connect(publish),
			timer:GetPropertyChangedSignal("AbsolutePosition"):Connect(publish),
			timer:GetPropertyChangedSignal("Visible"):Connect(publish),
			menu:GetPropertyChangedSignal("AbsoluteSize"):Connect(publish),
			menu:GetPropertyChangedSignal("AbsolutePosition"):Connect(publish),
		}
		publish()
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {})
end

local function Hud(props: { compact: boolean })
	local coinRef = React.useRef(nil :: ImageLabel?)
	local timerRef = React.useRef(nil :: Frame?)
	local menuRef = React.useRef(nil :: Frame?)
	useInsets(timerRef, menuRef)
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Cash = e(Cash, { coinRef = coinRef }),
		Timer = e(StarBar, { frameRef = timerRef }),
		Menu = e(Menu, { compact = props.compact, frameRef = menuRef }),
		Fuel = e(Fuel, { compact = props.compact }),
		Side = e(HudSide, { compact = props.compact }),
		Coins = e(FlyingCoins, { coinRef = coinRef }),
	})
end

return Hud
