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
	local boomDone = false
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

		SoundController.playAt("emergeRoar", info.startPos)
		fireLoop = SoundController.attach("fallLoop", holder, 0.5)
	end

	local function sonicBoom(position: Vector3)
		boomDone = true
		local ring = FxUtil.anchor(Vector3.new(class.size, class.size, 0.2), CFrame.lookAlong(position, direction))
		local decals = {}
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local decal = Instance.new("Decal")
			decal.Face = face
			decal.Texture = VfxIds.SHOCK_RING
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
		SoundController.playAt("sonicBoom", position)
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
			end
			if not boomDone and eased >= FALL.sonicBoomAt then
				sonicBoom(position)
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
