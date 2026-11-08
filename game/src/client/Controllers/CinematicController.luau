--!strict
-- CinematicController — kamera w cinematikach: krótkie ujęcia (rzut na wyrwę), wstrząs i „punch” FOV.
-- Zasady (Animacje i cinematiki): gracz nie traci sterowania, ujęcie ≤ 1,5 s, Skip dotknięciem/kliknięciem,
-- wyłączone przy lowGraphics i Reduce Motion, kamera zawsze wraca do Custom. T12 rozbuduje kolejkę ujęć.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimConfig = require(Shared.Config.AnimConfig)
local StateController = require(script.Parent.StateController)

local CAMERA = AnimConfig.CAMERA

local rng = Random.new()
local shakeUntil = 0
local shakeDuration = 1
local shakeStrength = 0
local fovOffset = 0
local fovValue: NumberValue
local shotActive = false
local lastShotAt = -math.huge

local CinematicController = {}

local function reducedMotion(): boolean
	local ok, value = pcall(function()
		return (GuiService :: any).ReducedMotionEnabled
	end)
	if ok and value == true then
		return true
	end
	local state = StateController.get()
	local settings = state and (state :: any).settings
	return typeof(settings) == "table" and settings.lowGraphics == true
end

-- Wstrząs kamery (siła ~0..3, zanika kwadratowo). Słabszy nie nadpisuje trwającego mocniejszego.
function CinematicController.shake(strength: number, duration: number)
	local current = shakeStrength * math.max(0, (shakeUntil - os.clock()) / shakeDuration)
	if strength <= current then
		return
	end
	shakeStrength = strength
	shakeDuration = duration
	shakeUntil = os.clock() + duration
end

-- Chwilowe poszerzenie pola widzenia (uderzenie), wraca samo.
function CinematicController.punchFov(amount: number, seconds: number)
	if amount <= 0 then
		return
	end
	fovValue.Value = amount
	TweenService
		:Create(fovValue, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 0 })
		:Play()
end

-- Krótkie ujęcie: kamera odjeżdża i patrzy na `target`, potem wraca. Zwraca false, gdy pominięte.
function CinematicController.lookAt(target: Vector3): boolean
	local camera = Workspace.CurrentCamera
	if not camera or shotActive or reducedMotion() or os.clock() - lastShotAt < CAMERA.cooldown then
		return false
	end
	shotActive = true
	lastShotAt = os.clock()
	local origin = camera.CFrame
	local from = origin.Position - origin.LookVector * CAMERA.pullBack + Vector3.yAxis * CAMERA.pullBack
	local shot = CFrame.lookAt(from, target)
	local value = Instance.new("NumberValue")
	value.Value = 0
	local skipped = false
	local skipConnection = UserInputService.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
			or input.KeyCode == Enum.KeyCode.Space
		then
			skipped = true
		end
	end)

	camera.CameraType = Enum.CameraType.Scriptable
	local started = os.clock()
	local total = CAMERA.shotSeconds + CAMERA.blendSeconds * 2
	local connection: RBXScriptConnection
	local function finish()
		connection:Disconnect()
		skipConnection:Disconnect()
		value:Destroy()
		camera.CameraType = Enum.CameraType.Custom
		shotActive = false
	end
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - started
		if skipped or elapsed >= total or camera.Parent == nil then
			finish()
			return
		end
		local blendIn = math.clamp(elapsed / CAMERA.blendSeconds, 0, 1)
		local blendOut = math.clamp((total - elapsed) / CAMERA.blendSeconds, 0, 1)
		local k = TweenService:GetValue(math.min(blendIn, blendOut), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		-- Wracamy do kamery z chwili startu; ruch postaci w tle nie jest blokowany.
		camera.CFrame = origin:Lerp(shot, k)
	end)
	return true
end

function CinematicController.isShotActive(): boolean
	return shotActive
end

local function onCameraStep()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local clock = os.clock()
	if clock < shakeUntil then
		local k = (shakeUntil - clock) / shakeDuration
		local s = shakeStrength * k * k
		camera.CFrame *= CFrame.new(rng:NextNumber(-1, 1) * s * 0.35, rng:NextNumber(-1, 1) * s * 0.35, 0) * CFrame.Angles(
			rng:NextNumber(-1, 1) * s * 0.012,
			rng:NextNumber(-1, 1) * s * 0.012,
			rng:NextNumber(-1, 1) * s * 0.008
		)
	end
	-- FOV: dodajemy przesunięcie do bazowego (zdejmujemy poprzednie), żeby nie dryfował.
	local offset = fovValue.Value
	if offset ~= fovOffset then
		camera.FieldOfView += offset - fovOffset
		fovOffset = offset
	end
end

function CinematicController.Init()
	fovValue = Instance.new("NumberValue")
	fovValue.Name = "CinematicFov"
end

function CinematicController.Start()
	RunService:BindToRenderStep("CinematicCamera", Enum.RenderPriority.Camera.Value + 1, onCameraStep)
end

return CinematicController
