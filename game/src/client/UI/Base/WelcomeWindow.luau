--!strict
-- WelcomeWindow — „WELCOME BACK!” po powrocie do gry: czas nieobecności, kwota zarobiona offline
-- (licznik z animacją od 0), dochód/s i COLLECT. Kasa jest już na koncie (serwer dopisał ją przy wejściu) —
-- COLLECT zamyka okno z monetami w HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local BaseMath = require(ReplicatedStorage:WaitForChild("Shared").BaseMath)

local UI = script.Parent.Parent
local Button = require(UI.Components.Button)
local Format = require(UI.Format)
local Label = require(UI.Components.Label)
local Motion = require(UI.Motion)
local SpaceFx = require(UI.Components.SpaceFx)
local Sfx = require(UI.Sfx)
local Store = require(UI.Store)
local Theme = require(UI.Theme)

local e = React.createElement

local COUNT = TweenInfo.new(1.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local WelcomeWindow = {}

local function awayText(seconds: number): string
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{math.max(minutes, 1)}m`
end

function WelcomeWindow.collect()
	local welcome = Store.get().welcome
	Store.set({ welcome = Store.none, window = Store.none })
	if welcome then
		Sfx.play("uiCoin")
		-- Monety w HUD lecą od przyrostu kasy; kwota już jest w kasie, więc tylko pokaz.
		Store.set({ cashGain = { id = Store.nextId(), amount = welcome.amount } })
	end
end

function WelcomeWindow.Body()
	local welcome = Store.use(function(s)
		return s.welcome
	end)
	local target, setTarget = React.useState(0)
	React.useEffect(function()
		local thread = task.delay(0.35, function()
			setTarget(if welcome then welcome.amount else 0)
		end)
		return function()
			task.cancel(thread)
		end
	end, { welcome })
	local shown = Motion.useCountUp(target, COUNT)
	if not welcome then
		return nil
	end
	local capped = welcome.seconds > BaseMath.OFFLINE_CAP_SECONDS

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Glow = e(SpaceFx.Flare, { color = Theme.COLORS.gold, size = 320, position = UDim2.fromScale(0.5, 0.45) }),
		List = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, {
			Layout = e("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Away = e(Label, {
				text = `You were away for {awayText(welcome.seconds)}{if capped
					then ` (max {BaseMath.OFFLINE_CAP_SECONDS // 3600}h)`
					else ""}`,
				textSize = Theme.TEXT_SIZE.body,
				color = Theme.COLORS.textMuted,
				layoutOrder = 1,
			}),
			Earned = e(Label, {
				text = "Your base earned",
				textSize = Theme.TEXT_SIZE.body,
				layoutOrder = 2,
			}),
			Amount = e(Label, {
				text = `+${Format.number(shown)}`,
				textSize = Theme.TEXT_SIZE.big + 10,
				color = Theme.COLORS.cash,
				stroke = 4,
				layoutOrder = 3,
			}),
			Rate = e(Label, {
				text = `{Format.cash(welcome.income)}/s × {math.round(BaseMath.OFFLINE_RATE * 100)}% while offline`,
				textSize = Theme.TEXT_SIZE.small,
				color = Theme.COLORS.textMuted,
				stroke = 2,
				layoutOrder = 4,
			}),
			Collect = e(Button, {
				text = "COLLECT",
				icon = Theme.ICONS.coin,
				color = Theme.COLORS.price,
				textSize = Theme.TEXT_SIZE.title - 4,
				size = UDim2.fromOffset(240, 62),
				shine = true,
				layoutOrder = 5,
				onActivated = WelcomeWindow.collect,
			}),
		}),
	})
end

return WelcomeWindow
