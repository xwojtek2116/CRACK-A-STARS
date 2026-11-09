--!strict
-- CrackController — minigra rozbijania po stronie klienta (prezentacja, wejście, auto-pętla rund).
-- Tool w ręku (atrybut ToolId) + Activated przy leżącej gwieździe → pętla: CrackStart → runda (UI/Minigame/Round)
-- → CrackFinish → cooldown narzędzia → kolejna, dopóki gracz trzyma narzędzie, stoi w zasięgu i gwiazda żyje.
-- CrackResult od serwera: liczby obrażeń (UI/Minigame/DamageNumbers), wstrząs u siebie (ustawienie cameraShake).
-- T06 v2: dźwięki trafień (Perfect rośnie z serią), wibracja, zamach narzędziem, iskry/odłamki (Fx/CrackFx),
-- skupienie kamery i winieta (UI/Minigame/Feel), baner rundy i licznik combo (UI/Minigame/Banner, same efekty).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimConfig = require(Shared.Config.AnimConfig)
local CrackRound = require(Shared.CrackRound)
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)
local StarConfig = require(Shared.Config.StarConfig)

local Client = script.Parent.Parent
local CinematicController = require(script.Parent.CinematicController)
local SoundController = require(script.Parent.SoundController)
local StateController = require(script.Parent.StateController)
local ToolController = require(script.Parent.ToolController)
local CrackFx = require(Client.Fx.CrackFx)
local Banner = require(Client.UI.Minigame.Banner)
local DamageNumbers = require(Client.UI.Minigame.DamageNumbers)
local Feel = require(Client.UI.Minigame.Feel)
local Round = require(Client.UI.Minigame.Round)

type Grade = CrackRound.Grade

local MINIGAME = CrackRound.MINIGAME
local FX = MINIGAME.fx
local CRACK = AnimConfig.CRACK
local PERFECT_FLASH = Color3.fromRGB(255, 235, 150)
local RETRY_SECONDS = 0.2
local HINT_SECONDS = 1.6

local log = Logger.new("CrackController")
local player = Players.LocalPlayer

local equipped: Tool? = nil
local looping = false
local currentRound: Round.Handle? = nil
local zoomValue: NumberValue
local zoomApplied = 0
local hintLabel: TextLabel? = nil
local hintToken = 0
local combo = 0
local currentGlow = Color3.new(1, 1, 1)
local currentRadius = 0

local CrackController = {}

local function shakeEnabled(): boolean
	local state = StateController.get()
	return not (state and state.settings and state.settings.cameraShake == false)
end

local function lowGraphics(): boolean
	local state = StateController.get()
	return state ~= nil and state.settings ~= nil and (state.settings :: any).lowGraphics == true
end

local function starGlow(star: Model): Color3
	local typeId = star:GetAttribute("Type")
	return if typeof(typeId) == "string" then StarConfig.glow(typeId) else Color3.new(1, 1, 1)
end

local function showHint(text: string)
	local label = hintLabel
	if not label then
		return
	end
	hintToken += 1
	local token = hintToken
	label.Text = text
	label.TextTransparency = 0
	label.Visible = true
	task.delay(HINT_SECONDS, function()
		if token == hintToken then
			label.Visible = false
		end
	end)
end

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Najbliższa leżąca gwiazda w zasięgu (ten sam warunek co serwer). Zwraca model i promień.
local function nearestStar(): (Model?, number)
	local hrp = root()
	local folder = Workspace:FindFirstChild("ActiveStars")
	if not hrp or not folder then
		return nil, 0
	end
	local best: Model?, bestDistance, bestRadius = nil, math.huge, 0
	for _, model in folder:GetChildren() do
		if not model:IsA("Model") or model:GetAttribute("State") ~= "Landed" then
			continue
		end
		local size = model:GetAttribute("Size")
		local class = if typeof(size) == "string" then StarConfig.CLASSES[size] else nil
		if not class then
			continue
		end
		local radius = class.size / 2
		local distance = (model:GetPivot().Position - hrp.Position).Magnitude - radius
		if distance <= MINIGAME.range and distance < bestDistance then
			best, bestDistance, bestRadius = model, distance, radius
		end
	end
	return best, bestRadius
end

local function stillValid(star: Model): boolean
	if not equipped or equipped.Parent ~= player.Character then
		return false
	end
	if star.Parent == nil or star:GetAttribute("State") ~= "Landed" then
		return false
	end
	local hrp = root()
	local size = star:GetAttribute("Size")
	local class = if typeof(size) == "string" then StarConfig.CLASSES[size] else nil
	return hrp ~= nil
		and class ~= nil
		and (star:GetPivot().Position - hrp.Position).Magnitude - class.size / 2 <= MINIGAME.range
end

local function setZoom(on: boolean)
	TweenService:Create(zoomValue, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { Value = if on then FX.fovZoom else 0 })
		:Play()
end

-- Trafienie jednego punktu (ocena klienta — tylko efekty; obrażenia liczy serwer).
local function onGrade(target: CrackRound.Target, grade: Grade, position: Vector3, normal: Vector3)
	CrackFx.burst(
		position,
		normal,
		if target.weak then Color3.fromRGB(255, 205, 60) else currentGlow,
		grade,
		currentRadius
	)
	Feel.haptic(grade)
	if grade == "Miss" then
		combo = 0
		Banner.setCombo(0)
		SoundController.play2D("hitMiss")
		return
	end
	combo += 1
	Banner.setCombo(combo)
	ToolController.strike()
	if target.weak then
		SoundController.play2D("hitWeak")
	end
	if grade == "Perfect" then
		SoundController.play2D("hitPerfect", nil, math.min(1 + combo * CRACK.comboPitchStep, CRACK.comboPitchMax))
		Feel.flash(PERFECT_FLASH)
		CinematicController.punchFov(CRACK.perfectFov, CRACK.perfectFovSeconds)
		if shakeEnabled() then
			CinematicController.shake(FX.shakePerfect, FX.shakeTime)
		end
	else
		SoundController.play2D("hitGood")
	end
end

-- Auto-pętla rund przy jednej gwieździe.
local function runLoop(star: Model, radius: number)
	looping = true
	setZoom(true)
	currentGlow = starGlow(star)
	currentRadius = radius
	Feel.begin(star:GetPivot().Position, radius, currentGlow, lowGraphics())
	while stillValid(star) do
		local ok, response, reason = pcall(Remotes.invoke, "CrackStart", star.Name)
		if not ok then
			log:warn(`CrackStart: {response}`)
			break
		end
		if type(response) ~= "table" then
			if reason == "Cooldown" or reason == "RoundActive" or reason == "RateLimited" then
				task.wait(RETRY_SECONDS)
				continue
			end
			if reason == "NoTool" then
				showHint("Equip your tool!")
			end
			break
		end
		local round = CrackRound.build(response.seed, response.toolId)
		if not round then
			break
		end
		local handle = Round.play(round, star, radius, currentGlow, response.autoCrack == true)
		handle.onGrade = onGrade
		currentRound = handle
		local times = handle:wait()
		currentRound = nil
		Remotes.fire("CrackFinish", response.roundId, times)
		local tool = CrackRound.getTool(response.toolId)
		task.wait(if tool then tool.cooldown else 1)
	end
	setZoom(false)
	Feel.finish()
	looping = false
end

local function onActivated()
	if looping then
		return
	end
	local star, radius = nearestStar()
	if not star then
		showHint("Get closer to a star!")
		return
	end
	task.spawn(runLoop, star, radius)
end

local function watchTool(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("ToolId") == nil then
		return
	end
	equipped = tool
	local activated = tool.Activated:Connect(onActivated)
	local unequipped: RBXScriptConnection
	unequipped = tool.Unequipped:Connect(function()
		activated:Disconnect()
		unequipped:Disconnect()
		if equipped == tool then
			equipped = nil
		end
		if currentRound then
			currentRound:cancel()
		end
	end)
end

local function onResult(payload: any)
	if type(payload) ~= "table" or typeof(payload.pos) ~= "Vector3" or type(payload.damage) ~= "number" then
		return
	end
	local mine = payload.userId == player.UserId
	local crit = payload.crit == true
	-- Własne obrażenia pokazuje baner rundy; liczby w świecie tylko dla innych graczy.
	if not mine then
		DamageNumbers.show(payload.pos, payload.damage, {
			mine = mine,
			crit = crit,
			grade = payload.grade,
			weak = payload.weak == true,
		})
	end
	if crit then
		SoundController.playAt("hitCrit", payload.pos)
	end
	if not mine then
		-- Trafienie innego gracza: skromny wybuch w jego punkcie.
		local folder = Workspace:FindFirstChild("ActiveStars")
		local star = folder and type(payload.starId) == "string" and folder:FindFirstChild(payload.starId)
		if star and star:IsA("Model") then
			local center = star:GetPivot().Position
			local normal = if (payload.pos - center).Magnitude > 0.01
				then (payload.pos - center).Unit
				else Vector3.yAxis
			CrackFx.burst(payload.pos, normal, starGlow(star), "Other", (payload.pos - center).Magnitude)
		end
		return
	end
	local grades = if type(payload.grades) == "table" then payload.grades else {}
	local allPerfect = #grades > 0
	for _, grade in grades do
		if grade ~= "Perfect" then
			allPerfect = false
		end
	end
	Banner.showRound({
		damage = payload.damage,
		grade = if type(payload.grade) == "string" then payload.grade else "Good",
		allPerfect = allPerfect,
		crit = crit,
		weak = payload.weak == true,
	})
	SoundController.play2D(if allPerfect then "roundPerfect" else "roundEnd")
	if crit then
		Feel.flash(Color3.fromRGB(255, 170, 40))
		Feel.haptic("Crit")
		if shakeEnabled() then
			CinematicController.shake(FX.shakeCrit, FX.shakeTime * 1.5)
		end
	end
end

local function buildHint()
	local screen = Instance.new("ScreenGui")
	screen.Name = "CrackHint"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 0.78)
	label.Size = UDim2.fromScale(0.5, 0.06)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 36
	limit.Parent = label
	label.Parent = screen
	screen.Parent = player:WaitForChild("PlayerGui")
	hintLabel = label
end

-- FOV: przesunięcie dodawane do bieżącego (jak CinematicController), żeby nie dryfował.
local function onCameraStep()
	local camera = Workspace.CurrentCamera
	if camera and zoomValue.Value ~= zoomApplied then
		camera.FieldOfView -= zoomValue.Value - zoomApplied
		zoomApplied = zoomValue.Value
	end
end

local function onCharacter(character: Model)
	equipped = nil
	character.ChildAdded:Connect(watchTool)
	for _, child in character:GetChildren() do
		watchTool(child)
	end
end

function CrackController.Init()
	zoomValue = Instance.new("NumberValue")
	zoomValue.Name = "CrackZoom"
end

function CrackController.Start()
	buildHint()
	Remotes.connect("CrackResult", onResult)
	RunService:BindToRenderStep("CrackZoom", Enum.RenderPriority.Camera.Value + 2, onCameraStep)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return CrackController
