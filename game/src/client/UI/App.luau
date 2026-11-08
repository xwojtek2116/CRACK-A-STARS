--!strict
-- App — korzeń UI: skala do bezpiecznego obszaru ekranu (UIScale, ScreenInsets), HUD, okna i toasty.
-- Logiczna wysokość < Theme.COMPACT_HEIGHT (telefon poziomo) → układ kompaktowy (menu w 2 kolumnach).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local UI = script.Parent
local Hud = require(UI.Hud)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local Toasts = require(UI.Components.Toasts)
local Windows = require(UI.Windows)

local e = React.createElement

export type Props = {
	screen: ScreenGui, -- AbsoluteSize = obszar po ScreenInsets (bez paska Roblox i wcięć telefonu)
}

local function computeScale(size: Vector2): number
	if size.X <= 0 or size.Y <= 0 then
		return 1
	end
	local scale = math.min(size.X / Theme.BASE_SIZE.X, size.Y / Theme.BASE_SIZE.Y)
	return math.clamp(scale, Theme.MIN_SCALE, Theme.MAX_SCALE)
end

local function App(props: Props)
	local hudHidden = Store.use(function(state)
		return state.hudHidden
	end)
	local size, setSize = React.useState(props.screen.AbsoluteSize)

	React.useEffect(function()
		local connection = props.screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			setSize(props.screen.AbsoluteSize)
		end)
		setSize(props.screen.AbsoluteSize)
		return function()
			connection:Disconnect()
		end
	end, {})

	local scale = computeScale(size)
	local compact = size.Y / scale < Theme.COMPACT_HEIGHT

	-- Ramka o rozmiarze ekranu / skala, żeby po UIScale wypełniała cały ekran.
	return e("Frame", {
		Size = UDim2.fromScale(1 / scale, 1 / scale),
		BackgroundTransparency = 1,
		Visible = not hudHidden,
	}, {
		Scale = e("UIScale", { Scale = scale }),
		Hud = e(Hud, { compact = compact }),
		Windows = e(Windows, { viewport = size / scale }),
		Toasts = e(Toasts),
	})
end

return App
