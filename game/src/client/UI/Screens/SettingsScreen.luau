--!strict
-- SettingsScreen — okno SETTINGS (zębatka w HUD): przełączniki zapisywane w profilu gracza.
-- Klik = natychmiastowa zmiana w Store (UI reaguje od razu), potem SetSetting do serwera; odmowa = cofnięcie.
-- Klucze i domyślne wartości: DataConfig.SETTING_KEYS / SETTING_DEFAULTS. Odczytują je:
--   music/sfx → SoundController, lowGraphics → efekty (StarFx, Crack, Cinematic), cameraShake → minigra,
--   skipCinematics → CinematicController, hideAnnouncements → Loot/Announce.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local DataConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.DataConfig)

local UI = script.Parent.Parent
local Button = require(UI.Components.Button)
local Label = require(UI.Components.Label)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local Common = require(script.Parent.Common)
local Request = require(script.Parent.Request)

local e = React.createElement

local ROWS = {
	{ key = "music", title = "MUSIC", text = "Background music" },
	{ key = "sfx", title = "SOUND EFFECTS", text = "Hits, loot and UI sounds" },
	{ key = "lowGraphics", title = "PERFORMANCE MODE", text = "Fewer particles and effects for older phones" },
	{ key = "cameraShake", title = "CAMERA SHAKE", text = "Shake when you crack a star" },
	{ key = "skipCinematics", title = "SKIP CINEMATICS", text = "No camera shots when stars fall or rare loot drops" },
	{ key = "hideAnnouncements", title = "HIDE OTHERS' DROPS", text = "No banners when other players find rare loot" },
}

local SettingsScreen = {}

-- Bieżąca wartość ustawienia (brak w danych = domyślna).
function SettingsScreen.value(settings: { [string]: boolean }, key: string): boolean
	local value = settings[key]
	if value == nil then
		return DataConfig.SETTING_DEFAULTS[key] == true
	end
	return value
end

local function setSetting(key: string, value: boolean)
	local before = Store.get().settings
	local patched = table.clone(before)
	patched[key] = value
	Store.set({ settings = patched })
	Request.send("SetSetting", { key, value }, nil, function(result)
		if not result.ok then
			Store.set({ settings = before })
		end
	end)
end

local function Row(props: { settingKey: string, title: string, text: string, on: boolean, order: number })
	return e(Common.Panel, {
		color = if props.on then Theme.COLORS.cash else Theme.COLORS.textMuted,
		size = UDim2.new(1, -8, 0, 70),
		layoutOrder = props.order,
	}, {
		Title = e(Label, {
			text = props.title,
			textSize = Theme.TEXT_SIZE.body,
			xAlignment = Enum.TextXAlignment.Left,
			position = UDim2.fromOffset(18, 10),
		}),
		Text = e(Label, {
			text = props.text,
			font = Theme.FONTS.body,
			textSize = Theme.TEXT_SIZE.small - 1,
			color = Theme.COLORS.textMuted,
			stroke = 0,
			xAlignment = Enum.TextXAlignment.Left,
			position = UDim2.fromOffset(18, 40),
		}),
		Toggle = e(Button, {
			name = props.settingKey,
			text = if props.on then "ON" else "OFF",
			color = if props.on then Theme.COLORS.price else Theme.COLORS.danger,
			size = UDim2.fromOffset(120, 50),
			anchorPoint = Vector2.new(1, 0.5),
			position = UDim2.new(1, -14, 0.5, -2),
			onActivated = function()
				setSetting(props.settingKey, not props.on)
			end,
		}),
	})
end

function SettingsScreen.Body()
	local settings = Store.use(function(s)
		return s.settings
	end)
	local rows: { [string]: any } = {
		List = e("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Pad = e("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 8),
		}),
	}
	for i, row in ROWS do
		rows[row.key] = e(Row, {
			settingKey = row.key,
			title = row.title,
			text = row.text,
			on = SettingsScreen.value(settings, row.key),
			order = i,
		})
	end
	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.COLORS.neonCyan,
		Selectable = false,
	}, rows)
end

return SettingsScreen
