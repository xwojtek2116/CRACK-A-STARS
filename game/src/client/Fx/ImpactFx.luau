--!strict
-- ImpactFx — uderzenie gwiazdy (T38): biały flash zależny od odległości, kula ognia, fala po ziemi i bańka
-- ciśnienia, ściana pyłu, lecące odłamki skał (niektóre z ognistą smugą), deszcz żaru, puls światła,
-- wstrząs i FOV punch kamery, odrzut własnej postaci (bez obrażeń), dźwięki wg rozmiaru.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundIds = require(Shared.Config.SoundIds)
local StarConfig = require(Shared.Config.StarConfig)
local Types = require(Shared.Types)
local VfxIds = require(Shared.Config.VfxIds)

local CinematicController = require(script.Parent.Parent.Controllers.CinematicController)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local FxUtil = require(script.Parent.FxUtil)
local SkyFx = require(script.Parent.SkyFx)

type StarInfo = Types.StarInfo

local IMPACT = FxUtil.CONFIG.IMPACT
local HITSTOP = FxUtil.CONFIG.HITSTOP
local STAR_IMPACT = StarConfig.IMPACT

local rng = Random.new()
local player = Players.LocalPlayer

local ImpactFx = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function knockback(info: StarInfo)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local radius = StarConfig.knockbackRadius(info.size)
	local offset = root.Position - info.impactPos
	local distance = offset.Magnitude
	if distance > radius then
		return
	end
	local strength = 1 - (distance / radius) * 0.5
	local away = flat(offset)
	if away.Magnitude < 0.1 then
		away = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
	end
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = away.Unit * STAR_IMPACT.knockbackSpeed * strength
		+ Vector3.yAxis * STAR_IMPACT.knockbackUp * strength
	root.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-2, 2), rng:NextNumber(-4, 4))
	task.delay(STAR_IMPACT.knockbackRagdollSeconds, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function debris(info: StarInfo, glow: Color3, folder: Folder)
	local assets = ReplicatedStorage:FindFirstChild("VfxAssets")
	if not assets then
		return
	end
	local rocks = {}
	for _, child in assets:GetChildren() do
		if child:IsA("MeshPart") and string.sub(child.Name, 1, 5) == "Rock_" then
			table.insert(rocks, child)
		end
	end
	if #rocks == 0 then
		return
	end
	local size = StarConfig.CLASSES[info.size].size
	local count = FxUtil.count(FxUtil.bySize(IMPACT.debrisCount, info.size))
	local trails = FxUtil.bySize(IMPACT.debrisTrails, info.size)
	for index = 1, count do
		local template = rocks[rng:NextInteger(1, #rocks)]
		local rock = template:Clone()
		local scale = size * rng:NextNumber(IMPACT.debrisScale[1], IMPACT.debrisScale[2])
		rock.Size = template.Size * scale
		rock.Material = Enum.Material.Basalt
		rock.Color = Color3.fromRGB(46, 40, 38)
		rock.Anchored = false
		rock.CanCollide = true
		rock.CastShadow = true
		local angle = rng:NextNumber(0, 2 * math.pi)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		rock.CFrame = CFrame.new(info.impactPos + outward * size * 0.3 + Vector3.yAxis * size * 0.4)
			* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		local speed = size * rng:NextNumber(IMPACT.debrisSpeed[1], IMPACT.debrisSpeed[2])
		rock.AssemblyLinearVelocity = outward * speed + Vector3.yAxis * speed * rng:NextNumber(0.8, 1.6)
		rock.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
		if index <= trails then
			-- Kilka odłamków leci w ogniu.
			local a0 = FxUtil.attachment(rock, Vector3.new(0, rock.Size.Y * 0.3, 0))
			local a1 = FxUtil.attachment(rock, Vector3.new(0, -rock.Size.Y * 0.3, 0))
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Texture = VfxIds.FIRE_TRAIL
			trail.Lifetime = 0.6
			trail.Color = FxUtil.colorSeq(FxUtil.lighten(glow, 0.4), glow)
			trail.Transparency = FxUtil.numberSeq(0, 1)
			trail.LightEmission = 1
			trail.FaceCamera = true
			trail.Parent = rock
		end
		rock.Parent = folder
		task.delay(IMPACT.debrisLifetime, function()
			FxUtil.tween(rock, 0.6, { Transparency = 1 })
			task.delay(0.65, function()
				rock:Destroy()
			end)
		end)
	end
end

-- T39: kolejne etapy uderzenia — fala-torus ze ścianą pyłu, grzyb, rozbryzgi, unoszący się żar, stygnięcie.
local function stages(info: StarInfo, full: boolean, glow: Color3, color: Color3, folder: Folder)
	local size = StarConfig.CLASSES[info.size].size
	local knockRadius = StarConfig.knockbackRadius(info.size)
	local pos = info.impactPos
	local assets = ReplicatedStorage:FindFirstChild("VfxAssets")

	-- Fala-torus pędząca po ziemi.
	local torusTemplate = assets and assets:FindFirstChild("ShockTorus") :: MeshPart?
	if torusTemplate then
		local torus = torusTemplate:Clone()
		local start = size / torusTemplate.Size.X
		local finish = knockRadius * IMPACT.torusMult * 2 / torusTemplate.Size.X
		torus.Size = torusTemplate.Size * start * Vector3.new(1, 6, 1)
		torus.CFrame = CFrame.new(pos + info.normal * 1.5)
		torus.Material = Enum.Material.Neon
		torus.Color = FxUtil.lighten(glow, 0.4)
		torus.Transparency = 0.15
		torus.Parent = folder
		FxUtil.tween(
			torus,
			IMPACT.torusSeconds,
			{ Size = torusTemplate.Size * finish * Vector3.new(1, 3, 1), Transparency = 1 }
		)
		task.delay(IMPACT.torusSeconds + 0.1, function()
			torus:Destroy()
		end)
	end

	-- Ściana pyłu: spłaszczona elipsoida, cząstki uciekają poziomo i hamują.
	local ringAnchor = FxUtil.anchor(Vector3.new(size * 2, 0.6, size * 2), CFrame.new(pos + info.normal * 2))
	local ringDust = FxUtil.emitter(ringAnchor, {
		Texture = VfxIds.SMOKE_SHEET,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Enabled = false,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		Lifetime = NumberRange.new(1.8, 3),
		Speed = NumberRange.new(size * 3.5, size * 5),
		Drag = 3,
		Size = FxUtil.numberSeq(size * 0.6, size * 1.8),
		Color = FxUtil.colorSeq(Color3.fromRGB(210, 195, 180), Color3.fromRGB(130, 120, 115)),
		LightInfluence = 0.4,
		Transparency = FxUtil.numberSeq(0.15, 1),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-50, 50),
	})
	ringAnchor.Parent = folder
	ringDust:Emit(FxUtil.count(FxUtil.bySize(IMPACT.ringDustCount, info.size)))

	-- Grzyb: kapelusz z ciemnych kłębów nad słupem ognia (z opóźnieniem).
	task.delay(IMPACT.mushroomDelay, function()
		local capHeight = size * IMPACT.pillarMult * 0.7
		local cap =
			FxUtil.anchor(Vector3.new(size * 1.5, size * 0.6, size * 1.5), CFrame.new(pos + Vector3.yAxis * capHeight))
		local capSmoke = FxUtil.emitter(cap, {
			Texture = VfxIds.SMOKE_SHEET,
			FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
			FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
			Enabled = false,
			Shape = Enum.ParticleEmitterShape.Sphere,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			Lifetime = NumberRange.new(3.5, 5.5),
			Speed = NumberRange.new(size * 0.5, size * 1.1),
			Drag = 0.9,
			Acceleration = Vector3.new(0, size * 0.15, 0),
			Size = FxUtil.numberSeq(size * 1.2, size * 3.4),
			Color = FxUtil.colorSeq(FxUtil.lighten(glow, 0.1), FxUtil.darken(color, 0.5), Color3.fromRGB(50, 46, 52)),
			LightEmission = 0.25,
			LightInfluence = 0.6,
			Transparency = FxUtil.numberSeq(0.15, 0.4, 1),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-25, 25),
		})
		cap.Parent = folder
		capSmoke:Emit(FxUtil.count(FxUtil.bySize(IMPACT.mushroomCount, info.size)))
		task.delay(6, function()
			cap:Destroy()
		end)
	end)

	-- Roztopione rozbryzgi: krople Neon z ognistą smugą lecące łukiem.
	local blobs = {}
	if assets then
		for _, child in assets:GetChildren() do
			if child:IsA("MeshPart") and string.sub(child.Name, 1, 9) == "LavaBlob_" then
				table.insert(blobs, child)
			end
		end
	end
	if full and #blobs > 0 then
		for _ = 1, FxUtil.count(FxUtil.bySize(IMPACT.splashCount, info.size)) do
			local template = blobs[rng:NextInteger(1, #blobs)]
			local blob = template:Clone()
			blob.Size = template.Size * size * rng:NextNumber(IMPACT.splashScale[1], IMPACT.splashScale[2])
			blob.Material = Enum.Material.Neon
			blob.Color = FxUtil.lighten(glow, rng:NextNumber(0, 0.3))
			blob.Anchored = false
			blob.CanCollide = false
			local angle = rng:NextNumber(0, 2 * math.pi)
			local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local speed = size * rng:NextNumber(IMPACT.splashSpeed[1], IMPACT.splashSpeed[2])
			local velocity = outward * speed + Vector3.yAxis * speed * rng:NextNumber(0.9, 1.5)
			blob.CFrame = CFrame.lookAlong(pos + Vector3.yAxis * size * 0.3, -velocity.Unit)
			blob.AssemblyLinearVelocity = velocity
			local a0 = FxUtil.attachment(blob, Vector3.new(blob.Size.X * 0.3, 0, 0))
			local a1 = FxUtil.attachment(blob, Vector3.new(-blob.Size.X * 0.3, 0, 0))
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Texture = VfxIds.FIRE_TRAIL
			trail.Lifetime = 0.45
			trail.Color = FxUtil.colorSeq(Color3.new(1, 1, 1), glow)
			trail.Transparency = FxUtil.numberSeq(0, 1)
			trail.LightEmission = 1
			trail.Brightness = 3
			trail.FaceCamera = true
			trail.Parent = blob
			blob.Parent = folder
			task.delay(rng:NextNumber(1.8, 2.6), function()
				FxUtil.tween(blob, 0.4, { Size = blob.Size * 0.2, Transparency = 1 })
				task.delay(0.45, function()
					blob:Destroy()
				end)
			end)
		end
	end

	-- Unoszący się żar nad kraterem przez kilka sekund.
	local emberAnchor = FxUtil.anchor(Vector3.new(size * 1.6, 1, size * 1.6), CFrame.new(pos + Vector3.yAxis * 2))
	local floating = FxUtil.emitter(emberAnchor, {
		Texture = VfxIds.EMBER,
		Shape = Enum.ParticleEmitterShape.Box,
		EmissionDirection = Enum.NormalId.Top,
		Rate = IMPACT.emberRate * FxUtil.quality(),
		Lifetime = NumberRange.new(2.5, 4.5),
		Speed = NumberRange.new(size * 0.15, size * 0.45),
		SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, size * 0.05, 0),
		Size = FxUtil.numberSeq(math.max(0.4, size * 0.05), 0),
		Color = FxUtil.colorSeq(Color3.new(1, 1, 1), glow, color),
		LightEmission = 1,
		Brightness = 2.5,
	})
	emberAnchor.Parent = folder
	task.delay(IMPACT.emberSeconds, function()
		floating.Enabled = false
		task.delay(5, function()
			emberAnchor:Destroy()
			ringAnchor:Destroy()
		end)
	end)
	SoundController.playAt("craterCool", pos, nil, IMPACT.coolDelay)
end

local function explode(info: StarInfo, full: boolean)
	local class = StarConfig.CLASSES[info.size]
	local size = class.size
	local glow = StarConfig.glow(info.type)
	local color = StarConfig.color(info.type)
	local folder = FxUtil.folder()
	local radius = StarConfig.craterRadius(info.size)
	local knockRadius = StarConfig.knockbackRadius(info.size)
	local pos = info.impactPos

	local camera = Workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - pos).Magnitude else math.huge

	-- Kula ognia: biały rdzeń + kolorowa otoczka
	local fireball = FxUtil.part(Enum.PartType.Ball, Vector3.one * size, CFrame.new(pos), glow, Enum.Material.Neon)
	fireball.Parent = folder
	FxUtil.tween(fireball, 0.9, { Size = Vector3.one * radius * IMPACT.fireballMult * 2, Transparency = 1 })
	-- Słup ognia wystrzeliwujący w górę z krateru.
	local pillarHeight = size * IMPACT.pillarMult
	local pillar = FxUtil.part(
		Enum.PartType.Cylinder,
		Vector3.new(size * 0.5, size * 1.4, size * 1.4),
		CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
		FxUtil.lighten(glow, 0.3),
		Enum.Material.Neon
	)
	pillar.Parent = folder
	FxUtil.tween(pillar, 0.35, {
		Size = Vector3.new(pillarHeight, size * 0.5, size * 0.5),
		CFrame = CFrame.new(pos + Vector3.yAxis * pillarHeight / 2) * CFrame.Angles(0, 0, math.pi / 2),
	})
	FxUtil.tween(pillar, 0.8, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local core = FxUtil.part(
		Enum.PartType.Ball,
		Vector3.one * size * 0.6,
		CFrame.new(pos),
		Color3.new(1, 1, 1),
		Enum.Material.Neon
	)
	core.Parent = folder
	FxUtil.tween(core, 0.25, { Size = Vector3.one * radius * 1.6, Transparency = 1 })

	-- Bańka ciśnienia (ForceField) i fala po ziemi (Decal pierścienia)
	local bubble = FxUtil.part(
		Enum.PartType.Ball,
		Vector3.one * size,
		CFrame.new(pos),
		FxUtil.lighten(glow, 0.5),
		Enum.Material.ForceField
	)
	bubble.Parent = folder
	FxUtil.tween(bubble, IMPACT.shockwaveSeconds, { Size = Vector3.one * knockRadius * 2.2, Transparency = 1 })
	local wavePart, waveDecal =
		FxUtil.groundDecal(pos + info.normal * 0.6, info.normal, size, VfxIds.SHOCK_RING, FxUtil.lighten(glow, 0.3))
	wavePart.Parent = folder
	local waveSize = knockRadius * IMPACT.shockwaveMult
	FxUtil.tween(wavePart, IMPACT.shockwaveSeconds, { Size = Vector3.new(waveSize, 0.2, waveSize) })
	FxUtil.tween(
		waveDecal,
		IMPACT.shockwaveSeconds,
		{ Transparency = 1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)

	-- Puls światła
	local holder = FxUtil.anchor(Vector3.new(radius * 2, 1, radius * 2), CFrame.new(pos + Vector3.yAxis * 2))
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 60
	light.Brightness = IMPACT.lightBrightness
	light.Parent = holder
	FxUtil.tween(light, IMPACT.lightSeconds, { Brightness = 0 })

	-- Ściana pyłu, żar, iskry (jednorazowe Emit)
	local dust = FxUtil.emitter(holder, {
		Texture = VfxIds.SMOKE_SHEET,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Enabled = false,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(85, 85),
		Lifetime = NumberRange.new(2.5, 4),
		Speed = NumberRange.new(size * 1.8, size * 3.5),
		Drag = 2.2,
		Size = FxUtil.numberSeq(size * 0.8, size * 2.4),
		Color = FxUtil.colorSeq(Color3.fromRGB(205, 190, 175), Color3.fromRGB(120, 110, 105)),
		LightInfluence = 0.35,
		Transparency = FxUtil.numberSeq(0.1, 1),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-40, 40),
	})
	local embers = FxUtil.emitter(holder, {
		Texture = VfxIds.EMBER,
		Enabled = false,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(60, 60),
		Lifetime = NumberRange.new(1.2, 2.6),
		Speed = NumberRange.new(size * 1.5, size * 3.2),
		Acceleration = Vector3.new(0, -70, 0),
		Drag = 0.6,
		Size = FxUtil.numberSeq(math.max(0.8, size * 0.12), 0),
		Color = FxUtil.colorSeq(Color3.new(1, 1, 1), glow, color),
		LightEmission = 1,
		Brightness = 3,
	})
	local sparks = FxUtil.emitter(holder, {
		Texture = VfxIds.SPARK,
		Enabled = false,
		SpreadAngle = Vector2.new(180, 180),
		Lifetime = NumberRange.new(0.4, 0.9),
		Speed = NumberRange.new(size * 2, size * 4),
		Drag = 2,
		Size = FxUtil.numberSeq(size * 0.25, 0),
		Color = FxUtil.colorSeq(Color3.new(1, 1, 1), glow),
		LightEmission = 1,
	})
	-- Grzyb dymu: ciemne kłęby wolno unoszące się nad kraterem.
	local plume = FxUtil.emitter(holder, {
		Texture = VfxIds.SMOKE_SHEET,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Enabled = false,
		EmissionDirection = Enum.NormalId.Top,
		SpreadAngle = Vector2.new(25, 25),
		Lifetime = NumberRange.new(3.5, 5),
		Speed = NumberRange.new(size * 0.6, size * 1.4),
		Drag = 0.8,
		Size = FxUtil.numberSeq(size * 1.0, size * 3.2),
		Color = FxUtil.colorSeq(FxUtil.darken(color, 0.4), Color3.fromRGB(55, 50, 55)),
		LightInfluence = 0.5,
		Transparency = FxUtil.numberSeq(0.2, 1),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20),
	})
	holder.Parent = folder
	plume:Emit(FxUtil.count(FxUtil.bySize(IMPACT.dustCount, info.size) * 0.5))
	dust:Emit(FxUtil.count(FxUtil.bySize(IMPACT.dustCount, info.size)))
	embers:Emit(FxUtil.count(FxUtil.bySize(IMPACT.emberCount, info.size)))
	sparks:Emit(FxUtil.count(FxUtil.bySize(IMPACT.emberCount, info.size) * 0.5))

	if full then
		debris(info, glow, folder)
	end

	-- Kamera
	local shakeReach = IMPACT.shakeReach + IMPACT.shakePerSize * size
	local shake = math.clamp(size / 10, 0.4, IMPACT.shakeMax) * math.clamp(1 - distance / shakeReach, 0, 1)
	if shake > 0.02 then
		CinematicController.shake(shake, 0.45 + size * 0.015)
		CinematicController.punchFov(
			FxUtil.bySize(IMPACT.fovPunch, info.size) * math.clamp(1 - distance / shakeReach, 0, 1),
			IMPACT.fovSeconds
		)
	end
	knockback(info)
	stages(info, full, glow, color, folder)

	task.delay(5, function()
		pillar:Destroy()
		fireball:Destroy()
		core:Destroy()
		bubble:Destroy()
		wavePart:Destroy()
		holder:Destroy()
	end)
end

-- Uderzenie: dźwięk i flash od razu, potem hit-stop (zamrożony biały rdzeń), potem eksplozja etapami.
function ImpactFx.play(info: StarInfo, full: boolean)
	local pos = info.impactPos
	local size = StarConfig.CLASSES[info.size].size
	local glow = StarConfig.glow(info.type)
	SoundController.playAt(SoundIds.IMPACT_BY_SIZE[info.size] or "impactMedium", pos)
	SoundController.playAt("shockwave", pos, nil, 0.05)
	SoundController.playAt("debrisRain", pos, nil, 0.35)
	if FxUtil.atLeast(info.size, "Large") then
		SoundController.playAt("impactTail", pos, nil, 0.6)
	end

	local camera = Workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - pos).Magnitude else math.huge
	local reach = FxUtil.bySize(IMPACT.flashReach, info.size)
	SkyFx.flash(FxUtil.bySize(IMPACT.flashStrength, info.size) * math.clamp(1 - distance / reach, 0, 1), 0.6)

	local hold = if FxUtil.atLeast(info.size, HITSTOP.fromSize) then HITSTOP.seconds else 0
	if hold <= 0 then
		explode(info, full)
		return
	end
	-- Hit-stop: biały rdzeń „zamrożony” na moment, zanim wszystko eksploduje.
	local freeze = FxUtil.part(
		Enum.PartType.Ball,
		Vector3.one * size * 1.3,
		CFrame.new(pos),
		Color3.new(1, 1, 1),
		Enum.Material.Neon
	)
	freeze.Parent = FxUtil.folder()
	local freezeLight = Instance.new("PointLight")
	freezeLight.Color = FxUtil.lighten(glow, 0.6)
	freezeLight.Range = 60
	freezeLight.Brightness = IMPACT.lightBrightness * 1.5
	freezeLight.Parent = freeze
	task.delay(hold, function()
		freeze:Destroy()
		explode(info, full)
	end)
end

return ImpactFx
