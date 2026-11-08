--!strict
-- Banner — ekranowe podsumowanie rundy i licznik serii (T06 v2), tylko u gracza, który rozbija.
--   showRound(): duży napis (PERFECT ROUND! / AWESOME! / GREAT! / NICE TRY), suma obrażeń liczona w górę,
--                znaczki CRITICAL! i WEAK SPOT,
--   setCombo():  „12 COMBO” z prawej — podskakuje przy każdym trafieniu, rozgrzewa się (biały → złoty → pomarańcz),
--                znika po chwili bez trafień. Combo = same efekty (bez wpływu na obrażenia).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AnimConfig = require(Shared.Config.AnimConfig)

local CRACK = AnimConfig.CRACK
local FONT = Enum.Font.FredokaOne
local OUTLINE = Color3.fromRGB(30, 15, 45)

local player = Players.LocalPlayer

local screen: ScreenGui? = nil
local comboLabel: TextLabel? = nil
local comboScale: UIScale? = nil
local comboToken = 0
local bannerToken = 0

local Banner = {}

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService
		:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
end

local function text(parent: Instance, value: string, color: Color3, size: UDim2, position: UDim2, maxSize: number)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.Text = value
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = OUTLINE
	stroke.Parent = label
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.Parent = label
	label.Parent = parent
	return label
end

local function gold(label: TextLabel)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 252, 210)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 205, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 130, 40)),
	})
	gradient.Rotation = 90
	gradient.Parent = label
end

local function getScreen(): ScreenGui
	if screen and screen.Parent then
		return screen
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CrackBanner"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")
	screen = gui
	return gui
end

local function format(n: number): string
	local s = tostring(math.round(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

export type RoundInfo = {
	damage: number,
	grade: string, -- ocena ogólna od serwera
	allPerfect: boolean,
	crit: boolean,
	weak: boolean,
}

function Banner.showRound(info: RoundInfo)
	bannerToken += 1
	local token = bannerToken
	local gui = getScreen()
	local old = gui:FindFirstChild("Round")
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Frame")
	holder.Name = "Round"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.3)
	holder.Size = UDim2.fromScale(0.6, 0.2)
	holder.BackgroundTransparency = 1
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = holder
	holder.Parent = gui

	local title = if info.allPerfect
		then "PERFECT ROUND!"
		elseif info.grade == "Perfect" then "AWESOME!"
		elseif info.grade == "Good" then "GREAT!"
		else "NICE TRY"
	local color = if info.grade == "Miss" then Color3.fromRGB(200, 205, 220) else Color3.new(1, 1, 1)
	local head = text(holder, title, color, UDim2.fromScale(1, 0.55), UDim2.fromScale(0.5, 0.3), 64)
	if info.allPerfect or info.grade == "Perfect" then
		gold(head)
	elseif info.grade == "Good" then
		head.TextColor3 = Color3.fromRGB(130, 240, 150)
	end
	local damage = text(
		holder,
		"-0",
		if info.crit then Color3.fromRGB(255, 190, 40) else Color3.new(1, 1, 1),
		UDim2.fromScale(0.6, 0.35),
		UDim2.fromScale(0.5, 0.78),
		42
	)
	local tags: { string } = {}
	if info.crit then
		table.insert(tags, "CRITICAL!")
	end
	if info.weak then
		table.insert(tags, "WEAK SPOT")
	end
	if #tags > 0 then
		local tag = text(
			holder,
			table.concat(tags, "  ·  "),
			Color3.fromRGB(255, 215, 90),
			UDim2.fromScale(0.7, 0.2),
			UDim2.fromScale(0.5, 1.05),
			26
		)
		tag.Rotation = -3
	end

	tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	head.Rotation = -4
	tween(head, 0.3, { Rotation = 0 }, Enum.EasingStyle.Back)
	-- Licznik obrażeń w górę.
	local started = os.clock()
	local countSeconds = 0.45
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local p = math.clamp((os.clock() - started) / countSeconds, 0, 1)
		damage.Text = `-{format(info.damage * (1 - (1 - p) ^ 3))}`
		if p >= 1 then
			connection:Disconnect()
		end
	end)

	task.delay(CRACK.bannerSeconds, function()
		if token ~= bannerToken or not holder.Parent then
			return
		end
		tween(holder, 0.3, { Position = UDim2.fromScale(0.5, 0.24) })
		for _, child in holder:GetDescendants() do
			if child:IsA("TextLabel") then
				tween(child, 0.3, { TextTransparency = 1 })
			elseif child:IsA("UIStroke") then
				tween(child, 0.3, { Transparency = 1 })
			end
		end
		task.delay(0.35, function()
			holder:Destroy()
		end)
	end)
end

-- Licznik serii (0 = schowaj).
function Banner.setCombo(count: number)
	comboToken += 1
	local token = comboToken
	local gui = getScreen()
	if not comboLabel or not comboLabel.Parent then
		local label = text(gui, "", Color3.new(1, 1, 1), UDim2.fromScale(0.22, 0.08), UDim2.fromScale(0.84, 0.42), 48)
		label.Name = "Combo"
		label.Rotation = 6
		local s = Instance.new("UIScale")
		s.Parent = label
		comboLabel = label
		comboScale = s
	end
	local label = comboLabel :: TextLabel
	local s = comboScale :: UIScale
	if count < 2 then
		tween(label, 0.25, { TextTransparency = 1 })
		return
	end
	label.Text = `{count} COMBO`
	label.TextTransparency = 0
	local heat = math.clamp((count - 2) / 18, 0, 1)
	label.TextColor3 = Color3.new(1, 1, 1)
		:Lerp(Color3.fromRGB(255, 205, 60), math.min(heat * 2, 1))
		:Lerp(Color3.fromRGB(255, 110, 40), math.max(heat * 2 - 1, 0))
	s.Scale = 1.35 + heat * 0.3
	tween(s, 0.2, { Scale = 1 + heat * 0.25 }, Enum.EasingStyle.Back)
	task.delay(CRACK.comboIdleSeconds, function()
		if token == comboToken then
			tween(label, 0.4, { TextTransparency = 1 })
		end
	end)
end

return Banner
