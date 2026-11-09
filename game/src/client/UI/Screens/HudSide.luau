--!strict
-- HudSide — prawa strona HUD (nad paskiem paliwa): RETURN TO LOBBY i zębatka SETTINGS.
-- Lobby: ekran gaśnie (0,15 s), prośba ReturnToLobby (serwer: cooldown, nie w trakcie minigry, teleport),
-- ekran wraca; po teleporcie przycisk odlicza cooldown (readyAt = czas serwera).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local UI = script.Parent.Parent
local Button = require(UI.Components.Button)
local Label = require(UI.Components.Label)
local Motion = require(UI.Motion)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local Request = require(script.Parent.Request)

local e = React.createElement

local FADE_IN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local BUTTON = Vector2.new(150, 58)
local GEAR = 58

-- Sekundy do końca cooldownu (0 = gotowe); odświeża się co 0,25 s tylko w trakcie odliczania.
local function useCooldown(readyAt: number?): number
	local now, setNow = React.useState(Workspace:GetServerTimeNow())
	React.useEffect(function()
		if not readyAt or readyAt <= Workspace:GetServerTimeNow() then
			return nil
		end
		local alive = true
		task.spawn(function()
			while alive and readyAt > Workspace:GetServerTimeNow() do
				setNow(Workspace:GetServerTimeNow())
				task.wait(0.25)
			end
			if alive then
				setNow(Workspace:GetServerTimeNow())
			end
		end)
		return function()
			alive = false
		end
	end, { readyAt })
	return if readyAt then math.max(0, math.ceil(readyAt - now)) else 0
end

local function HudSide(props: { compact: boolean })
	local readyAt = Store.use(function(s)
		return s.lobbyReadyAt
	end)
	local busy, setBusy = React.useState(false)
	local fadeRef = React.useRef(nil :: Frame?)
	local left = useCooldown(readyAt)

	local function goLobby()
		if busy then
			return
		end
		if left > 0 then
			Store.toast(`Lobby ready in {left}s`, "info")
			return
		end
		setBusy(true)
		local fade = fadeRef.current
		if fade then
			fade.Visible = true
			fade.BackgroundTransparency = 1
			Motion.tween(fade, FADE_IN, { BackgroundTransparency = 0 })
		end
		task.delay(FADE_IN.Time, function()
			Request.send("ReturnToLobby", {}, nil, function(result)
				if result.readyAt then
					Store.set({ lobbyReadyAt = result.readyAt })
				end
				local current = fadeRef.current
				if current then
					Motion.tween(current, FADE_OUT, { BackgroundTransparency = 1 })
					task.delay(FADE_OUT.Time, function()
						if fadeRef.current then
							fadeRef.current.Visible = false
						end
					end)
				end
				setBusy(false)
			end)
		end)
	end

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Row = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			-- Nad paskiem paliwa (Hud.Fuel: kompakt = obok przycisków skoku, PC = prawy dół).
			Position = if props.compact then UDim2.new(1, -170, 1, -100) else UDim2.new(1, -24, 1, -104),
			Size = UDim2.fromOffset(BUTTON.X + GEAR + 10, BUTTON.Y + Theme.BUTTON_DEPTH),
			BackgroundTransparency = 1,
		}, {
			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Lobby = e(Button, {
				name = "ReturnToLobby",
				size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
				color = if left > 0 then Theme.COLORS.panelLight else Theme.COLORS.base,
				corner = UDim.new(0, 16),
				layoutOrder = 1,
				onActivated = goLobby,
				content = e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
					Icon = e("ImageLabel", {
						Image = Theme.ICONS.base,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 6, 0.5, 0),
						Size = UDim2.fromOffset(42, 42),
						BackgroundTransparency = 1,
					}),
					Text = e(Label, {
						text = if left > 0 then `{left}s` else "LOBBY",
						textSize = Theme.TEXT_SIZE.body,
						anchorPoint = Vector2.new(0, 0.5),
						position = UDim2.new(0, 52, 0.5, 0),
					}),
				}),
			}),
			Settings = e(Button, {
				name = "Settings",
				size = UDim2.fromOffset(GEAR, GEAR),
				color = Theme.COLORS.panelLight,
				corner = UDim.new(0, 16),
				icon = Theme.ICONS.settings,
				iconSize = 34,
				layoutOrder = 2,
				onActivated = function()
					Store.openWindow("Settings")
				end,
			}),
		}),
		-- Zaciemnienie ekranu przy teleporcie (ponad HUD i oknami).
		Fade = e("Frame", {
			ref = fadeRef,
			Visible = false,
			Size = UDim2.fromScale(4, 4),
			Position = UDim2.fromScale(-1.5, -1.5),
			BackgroundColor3 = Theme.COLORS.space,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 200,
		}),
	})
end

return HudSide
