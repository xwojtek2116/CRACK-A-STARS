--!strict
-- Feel — odczucie minigry (T06 v2): skupienie kamery na gwieździe (DepthOfField), winieta w kolorze gwiazdy,
-- błysk przy Perfect, wibracja (pad: HapticService, telefon: HapticEffect, jeśli dostępny),
-- zamach narzędziem (lokalny tween Tool.Grip) i obrót postaci do gwiazdy.
-- Wszystko lokalne; przy lowGraphics bez rozmycia. Liczby: AnimConfig.CRACK.

local HapticService = game:GetService("HapticService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AnimConfig = require(Shared.Config.AnimConfig)
local VfxIds = require(Shared.Config.VfxIds)

local CRACK = AnimConfig.CRACK
local RENDER_NAME = "CrackFocus"

local player = Players.LocalPlayer

local focus: DepthOfFieldEffect? = nil
local vignette: ImageLabel? = nil
local focusCenter: Vector3? = nil
local active = false
local swinging: { [Tool]: CFrame } = {}
local shoulderHumanoid: Humanoid? = nil
local hapticEffects: { [string]: Instance } = {}

local Feel = {}

local function tween(instance: Instance, seconds: number, goal: { [string]: any })
	TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

local function ensure(): (DepthOfFieldEffect, ImageLabel)
	if not focus or not focus.Parent then
		local effect = Instance.new("DepthOfFieldEffect")
		effect.Name = "CrackFocus"
		effect.FarIntensity = 0
		effect.NearIntensity = 0
		effect.Enabled = false
		effect.Parent = Lighting
		focus = effect
	end
	if not vignette or not vignette.Parent then
		local screen = Instance.new("ScreenGui")
		screen.Name = "CrackVignette"
		screen.IgnoreGuiInset = true
		screen.ResetOnSpawn = false
		screen.DisplayOrder = -1
		local image = Instance.new("ImageLabel")
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = VfxIds.VIGNETTE
		image.ScaleType = Enum.ScaleType.Stretch
		image.ImageTransparency = 1
		image.Parent = screen
		screen.Parent = player:WaitForChild("PlayerGui")
		vignette = image
	end
	return focus :: DepthOfFieldEffect, vignette :: ImageLabel
end

-- Start skupienia na gwieździe. `lowGraphics` = bez rozmycia (tylko winieta).
function Feel.begin(center: Vector3, radius: number, glow: Color3, lowGraphics: boolean)
	local effect, image = ensure()
	active = true
	focusCenter = center
	image.ImageColor3 = glow:Lerp(Color3.new(0, 0, 0), 0.6)
	tween(image, CRACK.fadeSeconds, { ImageTransparency = CRACK.vignette })
	if not lowGraphics then
		effect.Enabled = true
		effect.InFocusRadius = radius + CRACK.focusMargin
		tween(effect, CRACK.fadeSeconds, { FarIntensity = CRACK.focusFar })
		RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 3, function()
			local camera = Workspace.CurrentCamera
			if camera and focusCenter then
				effect.FocusDistance = (camera.CFrame.Position - focusCenter).Magnitude
			end
		end)
	end
	-- Postać patrzy na gwiazdę, kamera przesuwa się za ramię.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		shoulderHumanoid = humanoid
		tween(humanoid, CRACK.fadeSeconds, { CameraOffset = CRACK.shoulderOffset })
	end
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local flat = Vector3.new(center.X, root.Position.Y, center.Z)
		if (flat - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, flat)
		end
	end
end

function Feel.finish()
	if not active then
		return
	end
	active = false
	focusCenter = nil
	local effect, image = ensure()
	tween(image, CRACK.fadeSeconds, { ImageTransparency = 1 })
	tween(effect, CRACK.fadeSeconds, { FarIntensity = 0 })
	if shoulderHumanoid and shoulderHumanoid.Parent then
		tween(shoulderHumanoid, CRACK.fadeSeconds, { CameraOffset = Vector3.zero })
	end
	shoulderHumanoid = nil
	task.delay(CRACK.fadeSeconds, function()
		if not active then
			effect.Enabled = false
			RunService:UnbindFromRenderStep(RENDER_NAME)
		end
	end)
end

-- Błysk winiety w kolorze (Perfect, krytyk) — „klatka uderzenia”.
function Feel.flash(color: Color3)
	local _, image = ensure()
	local base = if active then CRACK.vignette else 1
	local previous = image.ImageColor3
	image.ImageColor3 = color
	image.ImageTransparency = CRACK.vignetteFlash
	task.delay(0.05, function()
		tween(image, 0.25, { ImageTransparency = base, ImageColor3 = previous })
	end)
end

local function touchHaptic(kind: string)
	-- HapticEffect (telefony): nowsze API — w pcall, bez niego tylko pad.
	pcall(function()
		local effect = hapticEffects[kind]
		if not effect then
			local created = Instance.new("HapticEffect") :: any
			created.Type = if kind == "Crit" or kind == "Perfect"
				then Enum.HapticEffectType.GameplayExplosion
				else Enum.HapticEffectType.GameplayCollision
			created.Parent = Workspace
			hapticEffects[kind] = created
			effect = created
		end
		(effect :: any):Play()
	end)
end

-- Wibracja: siła z CRACK.haptic[kind].
function Feel.haptic(kind: string)
	local strength = CRACK.haptic[kind]
	if not strength then
		return
	end
	if UserInputService.TouchEnabled then
		touchHaptic(kind)
	end
	local pad = Enum.UserInputType.Gamepad1
	local ok, supported = pcall(HapticService.IsMotorSupported, HapticService, pad, Enum.VibrationMotor.Large)
	if ok and supported then
		HapticService:SetMotor(pad, Enum.VibrationMotor.Large, strength)
		HapticService:SetMotor(pad, Enum.VibrationMotor.Small, strength)
		task.delay(CRACK.hapticSeconds, function()
			HapticService:SetMotor(pad, Enum.VibrationMotor.Large, 0)
			HapticService:SetMotor(pad, Enum.VibrationMotor.Small, 0)
		end)
	end
end

-- Zamach narzędziem w ręku: Grip obraca się do tyłu i uderza (lokalnie, wraca do bazowego).
function Feel.swing(tool: Tool?)
	if not tool or tool.Parent ~= player.Character then
		return
	end
	local base = swinging[tool] or tool.Grip
	swinging[tool] = base
	local back = base * CFrame.Angles(-CRACK.swingAngle, 0, 0)
	local hit = base * CFrame.Angles(CRACK.swingAngle * 0.35, 0, 0)
	TweenService:Create(tool, TweenInfo.new(CRACK.swingBack, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Grip = back,
	}):Play()
	task.delay(CRACK.swingBack, function()
		local strike = TweenService:Create(
			tool,
			TweenInfo.new(CRACK.swingHit * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Grip = hit }
		)
		strike:Play()
		strike.Completed:Wait()
		TweenService:Create(
			tool,
			TweenInfo.new(CRACK.swingHit * 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Grip = base }
		):Play()
	end)
	tool.AncestryChanged:Once(function()
		if swinging[tool] then
			tool.Grip = swinging[tool]
			swinging[tool] = nil
		end
	end)
end

return Feel
