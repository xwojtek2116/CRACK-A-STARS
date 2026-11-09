--!strict
-- FallFx — gwiazda w locie i strefa uderzenia na ziemi (T38).
-- Ziemia (od ogłoszenia): wirujący pierścień ostrzegawczy z runami, rosnący miękki cień, licznik, światło
-- i pył podnoszący się w ostatnich sekundach, tyk licznika. Niebo (od RIFT.emergeAt): prawdziwy model gwiazdy
-- z ReplicatedStorage.StarVisuals w żarzącej otoczce, z ognistą smugą, ogniem, dymem, iskrami i flarą;
-- pętla ryku ognia, świst przelotu, sonic boom w połowie toru.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarConfig = require(Shared.Config.StarConfig)
local Types = require(Shared.Types)
local SoundIds = require(Shared.Config.SoundIds)
local VfxIds = require(Shared.Config.VfxIds)

local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local FxUtil = require(script.Parent.FxUtil)

type StarInfo = Types.StarInfo

local FALL = FxUtil.CONFIG.FALL
local RIFT = FxUtil.CONFIG.RIFT
local FONT = Enum.Font.FredokaOne
local DANGER_COLOR = Color3.fromRGB(255, 72, 48)
local FALL_LOOP_VOLUME = SoundIds.SOUNDS.fallLoop.volume

export type Fall = {
	update: (now: number, dt: number) -> (),
	finish: () -> (),
	emerged: () -> boolean,
}

local FallFx = {}

local function starTemplate(info: StarInfo): Model?
	local visuals = ReplicatedStorage:FindFirstChild("StarVisuals")
	local folder = visuals and visuals:FindFirstChild(info.type)
	local model = folder and folder:FindFirstChild(info.size)
	return if model and model:IsA("Model") then model else nil
end

function FallFx.create(info: StarInfo, full: boolean): Fall
	local class = StarConfig.CLASSES[info.size]
	local glow = StarConfig.glow(info.type)
	local color = StarConfig.color(info.type)
	local folder = FxUtil.folder()
	local direction = (info.impactPos - info.startPos).Unit
	local craterDiameter = StarConfig.craterRadius(info.size) * 2
	local dangerDiameter = StarConfig.knockbackRadius(info.size) * 2

	-- ===== Ziemia =====
	local ground = FxUtil.anchor(Vector3.one, CFrame.new(info.impactPos))
	ground.Name = `Impact_{info.id}`
	local warnPart, warnDecal = FxUtil.groundDecal(
		info.impactPos + info.normal * 1.2,
		info.normal,
		dangerDiameter,
		VfxIds.WARN_RING,
		DANGER_COLOR
	)
	warnDecal.Transparency = 0.15
	warnPart.Parent = ground
	local warnBase = warnPart.CFrame
	local shadowPart, shadowDecal = FxUtil.groundDecal(
		info.impactPos + info.normal * 1.0,
		info.normal,
		craterDiameter,
		VfxIds.EMBER,
		Color3.new(0, 0, 0)
	)
	shadowDecal.Transparency = 0.9
	shadowPart.Parent = ground
	local groundLight = Instance.new("PointLight")
	groundLight.Color = glow
	groundLight.Range = FALL.groundGlowRange
	groundLight.Brightness = 0
	groundLight.Parent = warnPart
	local dust = FxUtil.emitter(warnPart, {
		Texture = VfxIds.DUST,
		EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box,
		Rate = 0,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(3, 9),
		SpreadAngle = Vector2.new(25, 25),
		Size = FxUtil.numberSeq(class.size * 0.15, class.size * 0.45),
		Color = FxUtil.colorSeq(Color3.fromRGB(150, 140, 130)),
		Transparency = FxUtil.numberSeq(1, 0.55, 1),
		RotSpeed = NumberRange.new(-30, 30),
		LightInfluence = 1,
	})
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(140, 52)
	board.StudsOffsetWorldSpace = Vector3.new(0, 6 + class.size * 0.4, 0)
	board.AlwaysOnTop = true
	board.MaxDistance = 1500
	board.LightInfluence = 0
	board.Adornee = warnPart
	local countdown = Instance.new("TextLabel")
	countdown.BackgroundTransparency = 1
	countdown.Size = UDim2.fromScale(1, 1)
	countdown.Font = FONT
	countdown.TextScaled = true
	countdown.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = DANGER_COLOR
	stroke.Parent = countdown
	countdown.Parent = board
	board.Parent = ground
	ground.Parent = folder

	-- ===== Gwiazda (tworzona przy wylocie z wyrwy) =====
	local starModel: Model? = nil
	local shell: Part? = nil
	local emitters: { ParticleEmitter } = {}
	local fireLoop: Sound? = nil
	local spin = 0
	local ringsDone = 0
	-- T39: ogon plazmy, stożek żaru, odpadające kawałki
	local tail: Attachment? = nil
	local plasmaBeams: { Beam } = {}
	local bowParts: { BasePart } = {}
	local chunkClock = 0
	local rng = Random.new()
	local rocks: { MeshPart } = {}
	local vfxAssets = ReplicatedStorage:FindFirstChild("VfxAssets")
	if vfxAssets then
		for _, child in vfxAssets:GetChildren() do
			if child:IsA("MeshPart") and string.sub(child.Name, 1, 5) == "Rock_" then
				table.insert(rocks, child)
			end
		end
	end
	local flybyDone = false
	local lastTick = math.huge
	local finished = false

	local function emerge()
		local template = starTemplate(info)
		local shellSize = class.size * FALL.heatShell
		local holder = FxUtil.part(
			Enum.PartType.Ball,
			Vector3.one * shellSize,
			CFrame.lookAlong(info.startPos, direction),
			glow,
			Enum.Material.ForceField
		)
		holder.Name = `Falling_{info.id}`
		holder.Transparency = 0.1
		shell = holder

		if template then
			local model = template:Clone()
			if model:GetAttribute("VisualV2") then
				-- T40: w locie tylko gwiazda — krater pojawia się dopiero przy uderzeniu (StarVisual.ImpactLanding).
				for _, name in { "Crater", "Hitbox" } do
					local part = model:FindFirstChild(name)
					if part then
						part:Destroy()
					end
				end
				local core = model:FindFirstChild("Core")
				if core and core:IsA("BasePart") then
					model.WorldPivot = core.CFrame -- wiruje wokół rdzenia, nie dna krateru
					-- gruz ciasno przy gwieździe; po uderzeniu rozlatuje się na orbity
					local debris = model:FindFirstChild("FloatingDebris")
					if debris then
						for _, rock in debris:GetChildren() do
							if rock:IsA("BasePart") then
								rock.Position = core.Position + (rock.Position - core.Position) * FALL.v2DebrisTighten
							end
						end
					end
				end
			end
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
					descendant.CanCollide = false
					descendant.CanQuery = false
					descendant.CanTouch = false
				end
			end
			model:PivotTo(holder.CFrame)
			model.Parent = folder
			starModel = model
		else
			holder.Material = Enum.Material.Neon
		end

		-- Smugi: szeroka ognista + wąska biała w środku.
		local half = class.size * 0.5
		local a0 = FxUtil.attachment(holder, Vector3.new(half, 0, 0))
		local a1 = FxUtil.attachment(holder, Vector3.new(-half, 0, 0))
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Texture = VfxIds.FIRE_TRAIL
		trail.TextureMode = Enum.TextureMode.Stretch
		trail.Lifetime = FxUtil.bySize(FALL.trailLifetime, info.size)
		trail.Color = FxUtil.colorSeq(FxUtil.lighten(glow, 0.6), glow, color)
		trail.Transparency = FxUtil.numberSeq(0, 0.25, 1)
		trail.WidthScale = FxUtil.numberSeq(1, 0.55, 0.1)
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.FaceCamera = true
		trail.Parent = holder
		local c0 = FxUtil.attachment(holder, Vector3.new(half * 0.35, 0, 0))
		local c1 = FxUtil.attachment(holder, Vector3.new(-half * 0.35, 0, 0))
		local core = trail:Clone()
		core.Attachment0 = c0
		core.Attachment1 = c1
		core.Lifetime = trail.Lifetime * 0.45
		core.Color = FxUtil.colorSeq(Color3.new(1, 1, 1), FxUtil.lighten(glow, 0.5))
		core.Parent = holder

		local q = FxUtil.quality()
		table.insert(
			emitters,
			FxUtil.emitter(holder, {
				Texture = VfxIds.SMOKE_SHEET,
				FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
				FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				Shape = Enum.ParticleEmitterShape.Sphere,
				Rate = FALL.fireRate * q,
				Lifetime = NumberRange.new(0.35, 0.65),
				Speed = NumberRange.new(0, class.size * 0.3),
				Size = FxUtil.numberSeq(class.size * 0.95, class.size * 0.25),
				Color = FxUtil.colorSeq(FxUtil.lighten(glow, 0.5), glow, color),
				LightEmission = 1,
				Brightness = 2.5,
				Transparency = FxUtil.numberSeq(0.1, 0.4, 1),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-90, 90),
			})
		)
		if full then
			table.insert(
				emitters,
				FxUtil.emitter(holder, {
					Texture = VfxIds.SMOKE_SHEET,
					FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
					FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
					Rate = FALL.smokeRate * q,
					Lifetime = NumberRange.new(2.5, 4),
					Speed = NumberRange.new(0, 2),
					Drag = 1,
					Size = FxUtil.numberSeq(class.size * 0.6, class.size * 2.2),
					Color = FxUtil.colorSeq(Color3.fromRGB(90, 82, 88), Color3.fromRGB(45, 40, 48)),
					LightInfluence = 1,
					Transparency = FxUtil.numberSeq(0.35, 1),
					Rotation = NumberRange.new(0, 360),
					RotSpeed = NumberRange.new(-40, 40),
				})
			)
			table.insert(
				emitters,
				FxUtil.emitter(holder, {
					Texture = VfxIds.SPARK,
					Shape = Enum.ParticleEmitterShape.Sphere,
					Rate = FALL.sparkRate * q,
					Lifetime = NumberRange.new(0.5, 1.1),
					Speed = NumberRange.new(class.size, class.size * 2.5),
					SpreadAngle = Vector2.new(180, 180),
					Acceleration = Vector3.new(0, -50, 0),
					Size = FxUtil.numberSeq(class.size * 0.14, 0),
					Color = FxUtil.colorSeq(Color3.new(1, 1, 1), glow),
					LightEmission = 1,
				})
			)
		end
		local light = Instance.new("PointLight")
		light.Color = glow
		light.Brightness = 6
		light.Range = 60
		light.Parent = holder
		local flareGui = Instance.new("BillboardGui")
		flareGui.Size = UDim2.new(class.size * 4, 50, class.size * 4, 50)
		flareGui.LightInfluence = 0
		flareGui.Adornee = holder
		local flare = Instance.new("ImageLabel")
		flare.BackgroundTransparency = 1
		flare.Image = VfxIds.FLARE
		flare.ImageColor3 = glow
		flare.ImageTransparency = 0.1
		flare.Size = UDim2.fromScale(1, 1)
		flare.Parent = flareGui
		flareGui.Parent = holder
		holder.Parent = folder

		-- T39: ogon plazmy (3 warstwy Beamów od gwiazdy do punktu za nią).
		local head = FxUtil.attachment(holder, Vector3.zero)
		local tailAttachment = Instance.new("Attachment")
		tailAttachment.Name = `FallTail_{info.id}`
		tailAttachment.WorldPosition = info.startPos
		tailAttachment.Parent = Workspace.Terrain
		tail = tailAttachment
		local size = class.size
		local layers = {
			{
				width = size * FALL.plasmaWidth * 1.7,
				color = FxUtil.colorSeq(FxUtil.darken(color, 0.3), Color3.fromRGB(60, 50, 60)),
				transparency = FxUtil.numberSeq(0.55, 1),
				brightness = 1,
				emission = 0.3,
			},
			{
				width = size * FALL.plasmaWidth,
				color = FxUtil.colorSeq(FxUtil.lighten(glow, 0.3), color),
				transparency = FxUtil.numberSeq(0.05, 1),
				brightness = 3,
				emission = 1,
			},
			{
				width = size * 0.45,
				color = FxUtil.colorSeq(Color3.new(1, 1, 1), FxUtil.lighten(glow, 0.4)),
				transparency = FxUtil.numberSeq(0, 1),
				brightness = 4,
				emission = 1,
			},
		}
		for _, layer in layers do
			table.insert(
				plasmaBeams,
				FxUtil.beam(holder, head, tailAttachment, {
					Texture = VfxIds.PLASMA,
					TextureMode = Enum.TextureMode.Wrap,
					TextureLength = size * 4,
					TextureSpeed = FALL.plasmaSpeed,
					Color = layer.color,
					Transparency = layer.transparency,
					Width0 = layer.width,
					Width1 = layer.width * 0.15,
					LightEmission = layer.emission,
					Brightness = layer.brightness,
					FaceCamera = true,
					Segments = 1,
				})
			)
		end
		-- T39: stożek żaru przed gwiazdą (ForceField + półprzezroczysty Neon).
		local cone = vfxAssets and vfxAssets:FindFirstChild("BowCone") :: MeshPart?
		if cone then
			for index, look in
				{ { Enum.Material.ForceField, glow, 0 }, { Enum.Material.Neon, FxUtil.lighten(glow, 0.3), 0.78 } }
			do
				local part = cone:Clone()
				local scale = size * FALL.bowCone / cone.Size.X * (if index == 1 then 1 else 0.85)
				part.Size = cone.Size * scale
				part.Material = look[1]
				part.Color = look[2]
				part.Transparency = look[3]
				part.Parent = folder
				table.insert(bowParts, part)
			end
		end

		SoundController.playAt("emergeRoar", info.startPos)
		fireLoop = SoundController.attach("fallLoop", holder, 0.5)
	end

	-- T39: płonący kawałek odrywający się od gwiazdy.
	local function shedChunk(position: Vector3, speed: number)
		if #rocks == 0 then
			return
		end
		local template = rocks[rng:NextInteger(1, #rocks)]
		local rock = template:Clone()
		rock.Size = template.Size * class.size * rng:NextNumber(FALL.chunkScale[1], FALL.chunkScale[2])
		rock.Material = Enum.Material.Basalt
		rock.Color = Color3.fromRGB(40, 34, 32)
		rock.Anchored = false
		rock.CanCollide = false
		rock.CFrame = CFrame.new(
			position
				+ Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
					* class.size
					* 0.5
		)
		rock.AssemblyLinearVelocity = direction * speed * rng:NextNumber(0.35, 0.6)
			+ Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 1), rng:NextNumber(-1, 1)) * class.size
		rock.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6), rng:NextNumber(-6, 6))
		local a0 = FxUtil.attachment(rock, Vector3.new(0, rock.Size.Y * 0.3, 0))
		local a1 = FxUtil.attachment(rock, Vector3.new(0, -rock.Size.Y * 0.3, 0))
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Texture = VfxIds.FIRE_TRAIL
		trail.Lifetime = 0.5
		trail.Color = FxUtil.colorSeq(FxUtil.lighten(glow, 0.5), glow)
		trail.Transparency = FxUtil.numberSeq(0, 1)
		trail.LightEmission = 1
		trail.Brightness = 3
		trail.FaceCamera = true
		trail.Parent = rock
		rock.Parent = folder
		task.delay(FALL.chunkLifetime, function()
			rock:Destroy()
		end)
	end

	local function ringBurst(position: Vector3, texture: string, loud: boolean)
		local ring = FxUtil.anchor(Vector3.new(class.size, class.size, 0.2), CFrame.lookAlong(position, direction))
		local decals = {}
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local decal = Instance.new("Decal")
			decal.Face = face
			decal.Texture = texture
			decal.Color3 = FxUtil.lighten(glow, 0.5)
			decal.Parent = ring
			table.insert(decals, decal)
		end
		ring.Parent = folder
		local grown = class.size * FALL.sonicBoomGrow
		FxUtil.tween(ring, 0.7, { Size = Vector3.new(grown, grown, 0.2) })
		for _, decal in decals do
			FxUtil.tween(decal, 0.7, { Transparency = 1 })
		end
		task.delay(0.8, function()
			ring:Destroy()
		end)
		if loud then
			SoundController.playAt("sonicBoom", position)
		end
	end

	local fall = {} :: Fall

	function fall.emerged(): boolean
		return shell ~= nil
	end

	function fall.update(now: number, dt: number)
		if finished then
			return
		end
		local total = math.max(info.impactAt - info.launchedAt, 0.01)
		local alpha = math.clamp((now - info.launchedAt) / total, 0, 1)
		local remaining = math.max(info.impactAt - now, 0)

		-- Ziemia
		local eased = alpha ^ StarConfig.FALL.accelPower
		local shadowDiameter = craterDiameter * (0.3 + 0.9 * eased)
		shadowPart.Size = Vector3.new(shadowDiameter, 0.2, shadowDiameter)
		shadowDecal.Transparency = 0.9 - 0.55 * alpha
		warnPart.CFrame = warnBase * CFrame.Angles(0, os.clock() * FALL.warnSpin * 2 * math.pi, 0)
		warnDecal.Transparency = 0.15 + 0.25 * (0.5 + 0.5 * math.sin(os.clock() * (4 + 10 * alpha)))
		groundLight.Brightness = 5 * eased
		dust.Rate = if remaining < FALL.dustSeconds
			then 30 * FxUtil.quality() * (1 - remaining / FALL.dustSeconds)
			else 0
		countdown.Text = string.format("%.1f", remaining)
		local whole = math.ceil(remaining)
		if whole < lastTick and whole <= FALL.tickSeconds and whole > 0 then
			lastTick = whole
			SoundController.playAt("countdownTick", info.impactPos)
		end

		-- Niebo
		if not shell and now - info.launchedAt >= RIFT.emergeAt then
			emerge()
		end
		local holder = shell
		if holder then
			local position = StarConfig.fallPosition(info.startPos, info.impactPos, alpha)
			spin += dt * FALL.spinSpeed
			local cf = CFrame.lookAlong(position, direction)
			holder.CFrame = cf
			if starModel then
				starModel:PivotTo(cf * CFrame.Angles(spin, spin * 0.6, 0))
			end
			if fireLoop then
				fireLoop.Volume = FALL_LOOP_VOLUME * (0.5 + 0.7 * eased)
				fireLoop.PlaybackSpeed = FALL.doppler[1] + (FALL.doppler[2] - FALL.doppler[1]) * eased
			end
			-- Pierścienie przyspieszenia; środkowy = sonic boom z dźwiękiem.
			local nextRing = FALL.ringsAt[ringsDone + 1]
			if nextRing and eased >= nextRing then
				ringsDone += 1
				local loud = ringsDone == 2
				ringBurst(position, if loud then VfxIds.SHOCK_RING else VfxIds.HEAT_RING, loud)
			end
			-- Ogon plazmy: długość rośnie z prędkością.
			local speedK = math.clamp(alpha ^ (StarConfig.FALL.accelPower - 1), 0.15, 1)
			local tailAttachment = tail
			if tailAttachment then
				tailAttachment.WorldPosition = position - direction * class.size * FALL.plasmaLength * speedK
			end
			for index, part in bowParts do
				local flicker = 1 + 0.06 * math.sin(os.clock() * 25 + index)
				part.CFrame = cf * CFrame.new(0, 0, -class.size * 0.3) * CFrame.Angles(0, 0, os.clock() * 3)
				if index == 2 then
					part.Transparency = 0.72 + 0.1 * flicker - 0.3 * speedK
				end
			end
			-- Odpadające płonące kawałki.
			chunkClock += dt
			if full and chunkClock >= FALL.chunkInterval / math.max(FxUtil.quality(), 0.3) and alpha > 0.1 then
				chunkClock = 0
				local speed = (info.impactPos - info.startPos).Magnitude * StarConfig.FALL.accelPower * speedK / total
				shedChunk(position, speed)
			end
			local camera = Workspace.CurrentCamera
			if not flybyDone and camera and (camera.CFrame.Position - position).Magnitude < FALL.flybyDistance then
				flybyDone = true
				SoundController.playAt("flyby", position)
			end
		end
	end

	-- Uderzenie: gwiazda znika (model położy serwer), smugi i dym dogasają same, ziemia sprzątnięta.
	function fall.finish()
		if finished then
			return
		end
		finished = true
		ground:Destroy()
		if starModel then
			starModel:Destroy()
		end
		SoundController.fadeOut(fireLoop, 0.25)
		for _, beam in plasmaBeams do
			beam:Destroy()
		end
		if tail then
			tail:Destroy()
		end
		for _, part in bowParts do
			part:Destroy()
		end
		local holder = shell
		if holder then
			holder.Transparency = 1
			for _, emitter in emitters do
				emitter.Enabled = false
			end
			for _, child in holder:GetChildren() do
				if child:IsA("PointLight") or child:IsA("BillboardGui") then
					child:Destroy()
				end
			end
			task.delay(4.5, function()
				holder:Destroy()
			end)
		end
	end

	-- Pierwsze ustawienie (gracz dołączył w trakcie spadku).
	fall.update(Workspace:GetServerTimeNow(), 0)
	return fall
end

return FallFx
