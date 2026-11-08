--!strict
-- DamageNumbers — liczby obrażeń nad gwiazdą. Moje: duże (złote przy krytyku), cudze: małe i półprzezroczyste.
-- Billboard na Attachmencie w Terrain, wznosi się i znika (czas i wysokość z Tools.json → minigame.fx).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CrackRound = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").CrackRound)

local FX = CrackRound.MINIGAME.fx
local FONT = Enum.Font.FredokaOne
local MAX_ALIVE = 24 -- przy 8 graczach na jednej gwieździe najstarsze znikają wcześniej

local COLORS = {
	normal = Color3.fromRGB(255, 255, 255),
	perfect = Color3.fromRGB(255, 230, 120),
	crit = Color3.fromRGB(255, 190, 40),
	other = Color3.fromRGB(220, 225, 235),
}

local rng = Random.new()
local alive: { Attachment } = {}

local DamageNumbers = {}

local function format(n: number): string
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.round(n))
end

export type Options = {
	mine: boolean,
	crit: boolean,
	grade: CrackRound.Grade,
	weak: boolean,
}

function DamageNumbers.show(position: Vector3, amount: number, options: Options)
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	if #alive >= MAX_ALIVE then
		local oldest = table.remove(alive, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "DamageNumber"
	attachment.WorldPosition = position
		+ Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(0, 1.5), rng:NextNumber(-1.5, 1.5))
	attachment.Parent = Workspace.Terrain
	table.insert(alive, attachment)

	local size = if not options.mine then 34 elseif options.crit then 78 else 56
	local gui = Instance.new("BillboardGui")
	gui.Adornee = attachment
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(size * 4, size)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.Text = if options.crit then `CRIT {format(amount)}!` else format(amount)
	label.TextColor3 = if not options.mine
		then COLORS.other
		elseif options.crit then COLORS.crit
		elseif options.grade == "Perfect" then COLORS.perfect
		else COLORS.normal
	label.TextTransparency = if options.mine then 0 else 0.35
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if options.mine then 3 else 1.5
	stroke.Transparency = label.TextTransparency
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = playerGui

	if options.mine then
		label.Size = UDim2.fromScale(0.4, 0.4)
		label.Position = UDim2.fromScale(0.3, 0.3)
		TweenService:Create(label, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0),
		}):Play()
	end
	local info = TweenInfo.new(FX.numberTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, FX.numberRise, 0) }):Play()
	local fade = TweenInfo.new(
		FX.numberTime * 0.4,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.In,
		0,
		false,
		FX.numberTime * 0.6
	)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()

	task.delay(FX.numberTime + 0.05, function()
		gui:Destroy()
		local index = table.find(alive, attachment)
		if index then
			table.remove(alive, index)
		end
		attachment:Destroy()
	end)
end

return DamageNumbers
