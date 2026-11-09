--!strict
-- MapAmbienceController — klimat mapy (T15), tylko wizualnie po stronie klienta:
--  • biom pod kamerą (kąt jak w T36) → płynne przejście Atmosphere (kolor, zanik, gęstość) i korekcji koloru
--    „BiomeTint” (własny efekt; SkyFx ma osobny, nie kolidują), w lobby wygląd bazowy z Lighting;
--  • cząsteczki w powietrzu wokół kamery (iskry lawy, śnieg, pył kryształów, zarodniki mgławicy);
--  • planety Workspace.Map.Sky przesuwane za kamerą co SKY_FOLLOW_STEP studs (brak paralaksy na dużej mapie)
--    i powoli obracane (atrybut SpinDegPerSec).
-- Liczby: Shared/Config/MapAmbienceConfig.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.Logger)
local MapAmbienceConfig = require(Shared.Config.MapAmbienceConfig)

type BiomeLook = MapAmbienceConfig.BiomeLook

local log = Logger.new("MapAmbienceController")

local MapAmbienceController = {}

local atmosphere: Atmosphere? = nil
local base: { color: Color3, decay: Color3, density: number }? = nil
local tint: ColorCorrectionEffect
local emitterPart: Part
local emitter: ParticleEmitter
local currentBiome: string? = "?"
local tweens: { Tween } = {}

local skyParts: { { part: BasePart, offset: CFrame, spin: number } } = {}
local skyAnchor: Vector3? = nil
local skyClock = 0

local function angDiff(a: number, b: number): number
	return math.abs((a - b + 180) % 360 - 180)
end

local function biomeAt(pos: Vector3): (string?, BiomeLook?)
	if Vector2.new(pos.X, pos.Z).Magnitude < MapAmbienceConfig.LOBBY_RADIUS then
		return nil, nil
	end
	local angle = math.deg(math.atan2(pos.Z, pos.X)) % 360
	local best, bestD = nil, math.huge
	for _, biome in MapAmbienceConfig.BIOMES do
		local d = angDiff(angle, biome.angle)
		if d < bestD then
			best, bestD = biome, d
		end
	end
	if best then
		return best.id, best.look
	end
	return nil, nil
end

local function playTween(instance: Instance, goal: { [string]: any })
	local t = TweenService:Create(instance, TweenInfo.new(MapAmbienceConfig.TWEEN_TIME, Enum.EasingStyle.Sine), goal)
	table.insert(tweens, t)
	t:Play()
end

local function applyLook(look: BiomeLook?)
	for _, t in tweens do
		t:Cancel()
	end
	table.clear(tweens)
	local atm = atmosphere
	if atm and base then
		playTween(atm, {
			Color = if look then look.atmosphereColor else base.color,
			Decay = if look then look.atmosphereDecay else base.decay,
			Density = if look then look.density else base.density,
		})
	end
	playTween(tint, {
		TintColor = if look then look.tint else Color3.new(1, 1, 1),
		Saturation = if look then look.saturation else 0,
	})
	if look then
		emitter.Color = ColorSequence.new(look.particleColor)
		emitter.Texture = look.particleTexture
		emitter.Rate = look.particleRate
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.15, look.particleSize.Min),
			NumberSequenceKeypoint.new(0.8, look.particleSize.Max),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Speed = look.particleSpeed
		emitter.Acceleration = Vector3.new(0, look.particleRise, 0)
		emitter.Enabled = true
	else
		emitter.Enabled = false
	end
end

local function collectSky()
	local map = Workspace:FindFirstChild("Map")
	local sky = map and map:FindFirstChild("Sky")
	if not sky then
		return
	end
	table.clear(skyParts)
	for _, d in sky:GetDescendants() do
		if d:IsA("BasePart") then
			local spin = d:GetAttribute(MapAmbienceConfig.SKY_SPIN_ATTRIBUTE)
			table.insert(skyParts, {
				part = d,
				offset = d.CFrame, -- pozycje z serwera są względem środka mapy (0, 0, 0)
				spin = if typeof(spin) == "number" then spin else 0,
			})
		end
	end
	skyAnchor = nil
end

local function updateSky(camPos: Vector3, dt: number)
	if #skyParts == 0 then
		return
	end
	skyClock += dt
	local moved = skyAnchor == nil or ((skyAnchor :: Vector3) - camPos).Magnitude > MapAmbienceConfig.SKY_FOLLOW_STEP
	if moved then
		skyAnchor = Vector3.new(camPos.X, 0, camPos.Z)
	end
	local anchor = skyAnchor :: Vector3
	for _, entry in skyParts do
		if entry.spin ~= 0 then
			local rot = CFrame.Angles(0, math.rad(entry.spin * skyClock), 0)
			entry.part.CFrame = (entry.offset + anchor) * rot
		elseif moved then
			entry.part.CFrame = entry.offset + anchor
		end
	end
end

function MapAmbienceController.Init()
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "BiomeTint"
	tint.Parent = Lighting

	emitterPart = Instance.new("Part")
	emitterPart.Name = "AmbienceEmitter"
	emitterPart.Size = MapAmbienceConfig.PARTICLE_BOX
	emitterPart.Transparency = 1
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.CastShadow = false
	emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Lifetime = MapAmbienceConfig.PARTICLE_LIFETIME
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Enabled = false
	emitter.Parent = emitterPart
end

function MapAmbienceController.Start()
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local atm = atmosphere
	if atm then
		base = { color = atm.Color, decay = atm.Decay, density = atm.Density }
	end
	emitterPart.Parent = Workspace.CurrentCamera

	local map = Workspace:WaitForChild("Map", 30)
	if map then
		local sky = map:WaitForChild("Sky", 30)
		if sky then
			collectSky()
		else
			log:warn("Brak Workspace.Map.Sky — planety nie podążają za kamerą")
		end
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < MapAmbienceConfig.UPDATE_INTERVAL then
			return
		end
		local step = acc
		acc = 0
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position
		if emitterPart.Parent ~= camera then
			emitterPart.Parent = camera
		end
		emitterPart.CFrame = CFrame.new(camPos)
		local id, look = biomeAt(camPos)
		if id ~= currentBiome then
			currentBiome = id
			applyLook(look)
		end
		updateSky(camPos, step)
	end)
end

return MapAmbienceController
