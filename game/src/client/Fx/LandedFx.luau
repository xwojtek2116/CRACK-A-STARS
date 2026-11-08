--!strict
-- LandedFx — leżąca gwiazda (T38): pulsujący rdzeń i Highlight, światło na grunt, iskry, świecące pęknięcia
-- w kraterze, krystaliczny szum i skwierczenie (pętle 3D). Koniec: Cracked = wybuch odłamków i światła,
-- Expired = gaśnięcie, kruszenie i syk. Działa lokalnie na modelu z Workspace.ActiveStars.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarConfig = require(Shared.Config.StarConfig)
local VfxIds = require(Shared.Config.VfxIds)

local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local FxUtil = require(script.Parent.FxUtil)

local LANDED = FxUtil.CONFIG.LANDED

export type Landed = {
	update: (dt: number) -> (),
	dying: (reason: string) -> (),
	destroy: () -> (),
}

local rng = Random.new()
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Workspace.Terrain }

local LandedFx = {}

local function burstShards(model: Model, glow: Color3, sizeId: string, size: number)
	local assets = ReplicatedStorage:FindFirstChild("VfxAssets")
	if not assets then
		return
	end
	local pool = {}
	for _, child in assets:GetChildren() do
		if child:IsA("MeshPart") and string.sub(child.Name, 1, 6) == "Shard_" then
			table.insert(pool, child)
		end
	end
	if #pool == 0 then
		return
	end
	local center = model:GetPivot().Position
	for _ = 1, FxUtil.count(FxUtil.bySize(LANDED.shardBurst, sizeId)) do
		local template = pool[rng:NextInteger(1, #pool)]
		local shard = template:Clone()
		shard.Size = template.Size * size * rng:NextNumber(0.12, 0.25)
		shard.Material = Enum.Material.Neon
		shard.Color = FxUtil.lighten(glow, rng:NextNumber(0, 0.4))
		shard.Anchored = false
		shard.CanCollide = true
		shard.CFrame = CFrame.new(center) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.4, 1.2), rng:NextNumber(-1, 1)).Unit
		shard.AssemblyLinearVelocity = dir * size * rng:NextNumber(1.2, 2.4)
		shard.AssemblyAngularVelocity =
			Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
		shard.Parent = FxUtil.folder()
		task.delay(rng:NextNumber(1.6, 2.6), function()
			FxUtil.tween(shard, 0.5, { Transparency = 1, Size = shard.Size * 0.3 })
			task.delay(0.55, function()
				shard:Destroy()
			end)
		end)
	end
end

function LandedFx.attach(model: Model): Landed?
	local sizeId = model:GetAttribute("Size")
	local typeId = model:GetAttribute("Type")
	if typeof(sizeId) ~= "string" or typeof(typeId) ~= "string" or not StarConfig.CLASSES[sizeId] then
		return nil
	end
	local primary = model.PrimaryPart or model:FindFirstChild("Shell")
	if not primary or not primary:IsA("BasePart") then
		return nil
	end
	local size = StarConfig.CLASSES[sizeId].size
	local glow = StarConfig.glow(typeId)
	local color = StarConfig.color(typeId)
	local folder = FxUtil.folder()
	local pivot = model:GetPivot()

	local highlight = Instance.new("Highlight")
	highlight.FillColor = glow
	highlight.OutlineColor = FxUtil.lighten(glow, 0.4)
	highlight.FillTransparency = LANDED.highlightFill[1]
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = folder

	-- Pęknięcia w kraterze i światło na grunt (w punkcie przecięcia z terenem pod gwiazdą).
	local hit = Workspace:Raycast(pivot.Position + Vector3.yAxis * size, Vector3.yAxis * -size * 3, groundParams)
	local groundPos = if hit then hit.Position else pivot.Position - Vector3.yAxis * size * 0.3
	local normal = if hit then hit.Normal else Vector3.yAxis
	local cracksDiameter = StarConfig.craterRadius(sizeId) * LANDED.cracksMult
	local cracks, cracksDecal =
		FxUtil.groundDecal(groundPos + normal * 0.5, normal, cracksDiameter, VfxIds.CRACKS, glow)
	cracksDecal.Transparency = 0.1
	local groundLight = Instance.new("PointLight")
	groundLight.Color = glow
	groundLight.Range = LANDED.glowRange
	groundLight.Brightness = 2
	groundLight.Parent = cracks
	local sparks = FxUtil.emitter(primary, {
		Texture = VfxIds.SPARK,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Rate = LANDED.sparkRate * FxUtil.quality(),
		Lifetime = NumberRange.new(0.6, 1.2),
		Speed = NumberRange.new(size * 0.2, size * 0.6),
		Acceleration = Vector3.new(0, size * 0.3, 0),
		Size = FxUtil.numberSeq(size * 0.08, 0),
		Color = FxUtil.colorSeq(Color3.new(1, 1, 1), glow),
		LightEmission = 1,
	})
	cracks.Parent = folder

	-- T39: słup światła do nieba (widoczny z całej mapy) z błyskiem na szczycie.
	local beaconWidth = math.max(LANDED.beaconMinWidth, size * LANDED.beaconWidth)
	local base = FxUtil.attachment(cracks, Vector3.new(0, 0.5, 0))
	local top = Instance.new("Attachment")
	top.Name = `Beacon_{model.Name}`
	top.WorldPosition = groundPos + Vector3.yAxis * LANDED.beaconHeight
	top.Parent = Workspace.Terrain
	local beams: { Beam } = {}
	for _, layer in { { beaconWidth, glow, 0.35, 1.5 }, { beaconWidth * 0.35, Color3.new(1, 1, 1), 0.2, 2.5 } } do
		table.insert(
			beams,
			FxUtil.beam(cracks, base, top, {
				Texture = VfxIds.LIGHT_SHAFT,
				TextureMode = Enum.TextureMode.Stretch,
				Color = FxUtil.colorSeq(FxUtil.lighten(layer[2] :: Color3, 0.3), layer[2] :: Color3),
				LightEmission = 1,
				Brightness = layer[4] :: number,
				Width0 = layer[1] :: number,
				Width1 = (layer[1] :: number) * 1.6,
				FaceCamera = true,
				Segments = 1,
				Transparency = NumberSequence.new(layer[3] :: number),
			})
		)
	end
	local topGui = Instance.new("BillboardGui")
	topGui.Size = UDim2.new(beaconWidth * 4, 40, beaconWidth * 4, 40)
	topGui.LightInfluence = 0
	topGui.MaxDistance = 6000
	local topImage = Instance.new("ImageLabel")
	topImage.BackgroundTransparency = 1
	topImage.Image = VfxIds.GLINT
	topImage.ImageColor3 = FxUtil.lighten(glow, 0.3)
	topImage.Size = UDim2.fromScale(1, 1)
	topImage.Parent = topGui
	local topAnchor = FxUtil.anchor(Vector3.one, CFrame.new(top.WorldPosition))
	topGui.Adornee = topAnchor
	topGui.Parent = topAnchor
	topAnchor.Parent = folder

	-- T39: orbitujące iskry-komety wokół gwiazdy.
	type Orbiter = { part: Part, phase: number, radius: number, height: number, speed: number }
	local orbiters: { Orbiter } = {}
	local orbitTotal = FxUtil.count(FxUtil.bySize(LANDED.orbitCount, sizeId))
	for index = 1, orbitTotal do
		local orb = FxUtil.part(
			Enum.PartType.Ball,
			Vector3.one * math.max(0.6, size * 0.05),
			pivot,
			FxUtil.lighten(glow, 0.4),
			Enum.Material.Neon
		)
		local a0 = FxUtil.attachment(orb, Vector3.new(0, orb.Size.Y * 0.5, 0))
		local a1 = FxUtil.attachment(orb, Vector3.new(0, -orb.Size.Y * 0.5, 0))
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.5
		trail.Color = FxUtil.colorSeq(Color3.new(1, 1, 1), glow)
		trail.Transparency = FxUtil.numberSeq(0, 1)
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.WidthScale = FxUtil.numberSeq(1, 0)
		trail.Parent = orb
		orb.Parent = folder
		table.insert(orbiters, {
			part = orb,
			phase = index / orbitTotal * 2 * math.pi + rng:NextNumber(0, 1),
			radius = size * LANDED.orbitRadius * rng:NextNumber(0.85, 1.25),
			height = size * rng:NextNumber(-0.15, 0.45),
			speed = LANDED.orbitSpeed * rng:NextNumber(0.7, 1.3) * (if index % 2 == 0 then -1 else 1),
		})
	end
	local waveClock = 0
	local craterRadius = StarConfig.craterRadius(sizeId)
	local function energyWave()
		local wave, decal = FxUtil.groundDecal(groundPos + normal * 0.7, normal, size, VfxIds.ENERGY_WAVE, glow)
		decal.Transparency = 0.15
		wave.Parent = folder
		local final = craterRadius * LANDED.waveMult * 2
		FxUtil.tween(wave, LANDED.waveSeconds, { Size = Vector3.new(final, 0.2, final) })
		FxUtil.tween(decal, LANDED.waveSeconds, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(LANDED.waveSeconds + 0.1, function()
			wave:Destroy()
		end)
	end

	local hum = SoundController.attach("starHum", primary)
	local beaconHum = SoundController.attach("beaconHum", cracks)
	local sizzle = SoundController.attach("craterSizzle", cracks)
	local glowLight = model:FindFirstChild("Glow", true)
	local baseBrightness = if glowLight and glowLight:IsA("PointLight") then glowLight.Brightness else 0

	local clock = rng:NextNumber(0, 10)
	local destroyed = false
	local handle = {} :: Landed

	function handle.update(dt: number)
		if destroyed then
			return
		end
		clock += dt
		local pulse = 0.5 + 0.5 * math.sin(clock * LANDED.pulseSpeed * 2 * math.pi)
		highlight.FillTransparency = LANDED.highlightFill[1]
			+ (LANDED.highlightFill[2] - LANDED.highlightFill[1]) * pulse
		cracksDecal.Transparency = 0.05 + 0.35 * (1 - pulse)
		groundLight.Brightness = 1.5 + 2 * pulse
		local beaconPulse = 0.5 + 0.5 * math.sin(clock * LANDED.beaconPulse * 2 * math.pi)
		beams[1].Transparency = NumberSequence.new(0.25 + 0.25 * (1 - beaconPulse))
		topImage.ImageTransparency = 0.1 + 0.3 * (1 - beaconPulse)
		local center = model:GetPivot().Position
		for _, orbiter in orbiters do
			local angle = orbiter.phase + clock * orbiter.speed * 2 * math.pi
			orbiter.part.Position = center
				+ Vector3.new(
					math.cos(angle) * orbiter.radius,
					orbiter.height + math.sin(angle * 2) * size * 0.08,
					math.sin(angle) * orbiter.radius
				)
		end
		waveClock += dt
		if waveClock >= LANDED.waveInterval then
			waveClock = 0
			energyWave()
		end
		if glowLight and glowLight:IsA("PointLight") then
			glowLight.Brightness = baseBrightness * (0.7 + 0.8 * pulse)
		end
	end

	function handle.destroy()
		if destroyed then
			return
		end
		destroyed = true
		highlight:Destroy()
		sparks.Rate = 0
		task.delay(1.5, function()
			sparks:Destroy()
		end)
		SoundController.fadeOut(hum, 0.4)
		SoundController.fadeOut(beaconHum, 0.8)
		for _, orbiter in orbiters do
			orbiter.part:Destroy()
		end
		table.clear(orbiters)
		-- Słup światła gaśnie: zwęża się i blednie.
		for _, beam in beams do
			FxUtil.tween(beam, 1.2, { Width0 = 0, Width1 = 0 })
		end
		FxUtil.tween(topImage, 1.2, { ImageTransparency = 1 })
		task.delay(1.3, function()
			top:Destroy()
			topAnchor:Destroy()
		end)
		SoundController.fadeOut(sizzle, 1.5)
		FxUtil.tween(cracksDecal, 2, { Transparency = 1 })
		FxUtil.tween(groundLight, 2, { Brightness = 0 })
		task.delay(2.1, function()
			cracks:Destroy()
		end)
	end

	function handle.dying(reason: string)
		local seconds = StarConfig.SCHEDULE.dyingSeconds * 0.9
		local center = model:GetPivot().Position
		if reason == "Cracked" then
			SoundController.playAt("starCrack", center)
			local burst =
				FxUtil.part(Enum.PartType.Ball, Vector3.one * size, CFrame.new(center), glow, Enum.Material.Neon)
			burst.Parent = folder
			FxUtil.tween(burst, 0.5, { Size = Vector3.one * size * 3, Transparency = 1 })
			local flashPart = FxUtil.part(
				Enum.PartType.Ball,
				Vector3.one * size * 0.5,
				CFrame.new(center),
				Color3.new(1, 1, 1),
				Enum.Material.Neon
			)
			flashPart.Parent = folder
			FxUtil.tween(flashPart, 0.2, { Size = Vector3.one * size * 1.8, Transparency = 1 })
			sparks.Rate = 0
			sparks.Speed = NumberRange.new(size * 2, size * 4)
			sparks.SpreadAngle = Vector2.new(180, 180)
			sparks:Emit(FxUtil.count(60))
			burstShards(model, glow, sizeId, size)
			task.delay(0.6, function()
				burst:Destroy()
				flashPart:Destroy()
			end)
		else
			SoundController.playAt("starFade", center)
			sparks.Rate = 0
			FxUtil.tween(highlight, seconds * 0.6, { FillTransparency = 1, OutlineTransparency = 1 })
			local dust = FxUtil.emitter(cracks, {
				Texture = VfxIds.DUST,
				Enabled = false,
				EmissionDirection = Enum.NormalId.Top,
				Shape = Enum.ParticleEmitterShape.Box,
				Lifetime = NumberRange.new(1.2, 2.2),
				Speed = NumberRange.new(2, 6),
				Size = FxUtil.numberSeq(size * 0.2, size * 0.6),
				Color = FxUtil.colorSeq(FxUtil.darken(color, 0.6)),
				LightInfluence = 1,
				Transparency = FxUtil.numberSeq(0.4, 1),
			})
			dust:Emit(FxUtil.count(20))
		end
		-- Model: zanik na kliencie (serwer usuwa go po dyingSeconds).
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				if reason == "Expired" and descendant.Name == "Core" then
					FxUtil.tween(descendant, seconds * 0.5, { Color = Color3.fromRGB(60, 56, 56) })
				end
				FxUtil.tween(descendant, if reason == "Cracked" then 0.15 else seconds, { Transparency = 1 })
			elseif descendant:IsA("PointLight") then
				FxUtil.tween(descendant, seconds * 0.6, { Brightness = 0 })
			elseif descendant:IsA("ParticleEmitter") and descendant ~= sparks then
				descendant.Enabled = false
			end
		end
		handle.destroy()
	end

	return handle
end

return LandedFx
