--!strict
-- RiftFx — rozdarcie nieba, z którego wylatuje gwiazda (T38, styl „rozdarcie nieba”).
-- Fazy: jasna rysa → rozdarcie rośnie (ease-out-back) → pulsuje: wirująca mgławica, łuki błyskawic po krawędziach,
-- cząstki wsysane do środka, burzowe chmury, odłamki nieba odpadają → po uderzeniu zapada się w kreskę i znika.
-- Meshe: ReplicatedStorage.VfxAssets (Rift_Edge, Rift_Core, Shard_N) z art/vfx/build_vfx.py; front = LookVector.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarConfig = require(Shared.Config.StarConfig)
local Types = require(Shared.Types)
local VfxIds = require(Shared.Config.VfxIds)

local SoundController = require(script.Parent.Parent.Controllers.SoundController)
local FxUtil = require(script.Parent.FxUtil)
local SkyFx = require(script.Parent.SkyFx)

type StarInfo = Types.StarInfo

local RIFT = FxUtil.CONFIG.RIFT
local SKY = FxUtil.CONFIG.SKY
local OUTLINE_POINTS = 28
-- Proporcje obrysu „oka” jak w build_vfx.py (połowa wysokości / połowa szerokości, zaostrzenie końców).
local OUTLINE_HALF_HEIGHT = 0.3

export type Rift = {
	update: (now: number, dt: number) -> (),
	close: () -> (),
	destroy: () -> (),
	position: Vector3,
	closed: () -> boolean,
}

type Shard = { part: BasePart, velocity: Vector3, spin: CFrame, born: number }
type Bolt = { beam: Beam, nextAt: number }

local rng = Random.new()
local assets: Folder? = nil

local RiftFx = {}

local function vfxAssets(): Folder
	if assets then
		return assets
	end
	assets = ReplicatedStorage:WaitForChild("VfxAssets") :: Folder
	return assets :: Folder
end

local function outlinePoint(t: number, halfWidth: number): Vector3
	local x = math.cos(t)
	local y = OUTLINE_HALF_HEIGHT * math.sin(t) * (1 - math.abs(x) ^ 3) ^ 0.6
	return Vector3.new(x * halfWidth, y * halfWidth, 0)
end

function RiftFx.create(info: StarInfo, full: boolean): Rift
	local class = StarConfig.CLASSES[info.size]
	local glow = StarConfig.glow(info.type)
	local color = StarConfig.color(info.type)
	local width = class.size * FxUtil.bySize(RIFT.widthMult, info.size)
	local folder = FxUtil.folder()
	local cframe = CFrame.lookAt(info.startPos, info.impactPos)

	local templates = vfxAssets()
	local edgeTemplate = templates:FindFirstChild("Rift_Edge") :: MeshPart?
	local coreTemplate = templates:FindFirstChild("Rift_Core") :: MeshPart?
	local scale = if edgeTemplate then width / edgeTemplate.Size.X else 1
	local height = if edgeTemplate then edgeTemplate.Size.Y * scale else width * 0.56

	local holder = FxUtil.anchor(Vector3.new(width, height, 1), cframe)
	holder.Name = `Rift_{info.id}`

	-- Meshe: krawędź (Neon), miękka poświata krawędzi (większa, półprzezroczysta), wnętrze (ciemna pustka).
	local parts: { { part: MeshPart, base: Vector3 } } = {}
	local function addMesh(
		template: MeshPart?,
		mult: number,
		material: Enum.Material,
		partColor: Color3,
		transparency: number
	)
		if not template then
			return
		end
		local part = template:Clone()
		part.Material = material
		part.Color = partColor
		part.Transparency = transparency
		part.CFrame = cframe
		part.Parent = holder
		table.insert(parts, { part = part, base = template.Size * scale * mult })
	end
	addMesh(coreTemplate, 1, Enum.Material.Neon, FxUtil.darken(color, 0.82), 0)
	addMesh(edgeTemplate, 1, Enum.Material.Neon, FxUtil.lighten(glow, 0.25), 0)
	addMesh(edgeTemplate, 1.08, Enum.Material.Neon, color, 0.55)
	local edgePart = if #parts >= 2 then parts[2].part else nil

	-- Wir w głębi: dwa dyski z Decalem, obracające się w przeciwne strony.
	local swirls: { { part: Part, speed: number, size: number, depth: number } } = {}
	local function addSwirl(
		sizeMult: number,
		depthMult: number,
		speed: number,
		swirlColor: Color3,
		transparency: number
	)
		local size = height * sizeMult
		local part = FxUtil.anchor(Vector3.new(size, size, 0.2), cframe * CFrame.new(0, 0, height * depthMult))
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Front
		decal.Texture = VfxIds.SWIRL
		decal.Color3 = swirlColor
		decal.Transparency = transparency
		decal.Parent = part
		part.Parent = holder
		table.insert(swirls, { part = part, speed = speed, size = size, depth = height * depthMult })
	end
	addSwirl(1.25, 0.55, RIFT.swirlSpeed, color, 0.35)
	addSwirl(0.8, 0.35, -RIFT.swirlSpeed * 1.6, FxUtil.lighten(glow, 0.3), 0.1)

	-- Mgławica: dwa Beamy od środka do czubków (romb wypełniający oko), tekstura płynie.
	local center = FxUtil.attachment(holder, Vector3.new(0, 0, height * 0.15))
	local nebulas: { Beam } = {}
	for _, side in { -1, 1 } do
		local tip = FxUtil.attachment(holder, Vector3.new(side * width * 0.47, 0, 0))
		local beam = FxUtil.beam(holder, center, tip, {
			Texture = VfxIds.NEBULA,
			TextureMode = Enum.TextureMode.Wrap,
			TextureLength = width * 0.5,
			TextureSpeed = RIFT.nebulaSpeed * side,
			Color = FxUtil.colorSeq(FxUtil.lighten(glow, 0.2), color),
			LightEmission = 0.6,
			Transparency = FxUtil.numberSeq(0.2, 0.55),
			Width0 = height * 0.85,
			Width1 = height * 0.06,
			FaceCamera = true,
			Segments = 1,
		})
		table.insert(nebulas, beam)
	end

	-- Punkty na obrysie (dla błyskawic) i ich Attachmenty.
	local outline: { Attachment } = {}
	for i = 1, OUTLINE_POINTS do
		local t = (i - 1) / OUTLINE_POINTS * 2 * math.pi
		table.insert(outline, FxUtil.attachment(holder, outlinePoint(t, width * 0.5)))
	end

	local bolts: { Bolt } = {}
	local emitters: { ParticleEmitter } = {}
	if full then
		for _ = 1, FxUtil.count(FxUtil.bySize(RIFT.lightningCount, info.size)) do
			local beam = FxUtil.beam(holder, outline[1], outline[2], {
				Texture = VfxIds.LIGHTNING[1],
				TextureMode = Enum.TextureMode.Stretch,
				Color = FxUtil.colorSeq(Color3.new(1, 1, 1), FxUtil.lighten(glow, 0.3)),
				LightEmission = 1,
				Width0 = width * RIFT.lightningWidth,
				Width1 = width * RIFT.lightningWidth,
				FaceCamera = true,
				Segments = 12,
				Transparency = NumberSequence.new(1),
			})
			table.insert(bolts, { beam = beam, nextAt = 0 })
		end
		-- Cząstki wsysane do środka (spłaszczona elipsoida = obrys wyrwy).
		local wispAnchor = FxUtil.anchor(Vector3.new(width * 1.5, height * 1.8, 2), cframe)
		wispAnchor.Parent = holder
		table.insert(
			emitters,
			FxUtil.emitter(wispAnchor, {
				Texture = VfxIds.SPARK,
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				Rate = RIFT.wispRate * FxUtil.quality(),
				Lifetime = NumberRange.new(0.9, 1.4),
				Speed = NumberRange.new(width * 0.35, width * 0.55),
				Size = FxUtil.numberSeq(width * 0.012, width * 0.025, 0),
				Color = FxUtil.colorSeq(Color3.new(1, 1, 1), glow),
				LightEmission = 1,
				Transparency = FxUtil.numberSeq(0.2, 0, 1),
			})
		)
		-- Burzowe chmury wokół rozdarcia.
		table.insert(
			emitters,
			FxUtil.emitter(holder, {
				Texture = VfxIds.SMOKE_SHEET,
				FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
				FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				Rate = RIFT.stormRate * FxUtil.quality(),
				Lifetime = NumberRange.new(4, 6),
				Speed = NumberRange.new(width * 0.01, width * 0.04),
				Size = FxUtil.numberSeq(width * 0.2, width * 0.42),
				Color = FxUtil.colorSeq(FxUtil.darken(color, 0.55), FxUtil.darken(color, 0.8)),
				LightEmission = 0.25,
				Transparency = FxUtil.numberSeq(1, 0.45, 1),
				RotSpeed = NumberRange.new(-25, 25),
				Rotation = NumberRange.new(0, 360),
			})
		)
	end

	-- Poświata widoczna z daleka i światło w kolorze gwiazdy.
	local flareGui = Instance.new("BillboardGui")
	flareGui.Size = UDim2.new(width * RIFT.flareSize, RIFT.flarePixels, width * RIFT.flareSize, RIFT.flarePixels)
	flareGui.LightInfluence = 0
	flareGui.Adornee = holder
	local flare = Instance.new("ImageLabel")
	flare.BackgroundTransparency = 1
	flare.Image = VfxIds.FLARE
	flare.ImageColor3 = glow
	flare.Size = UDim2.fromScale(1, 1)
	flare.Parent = flareGui
	flareGui.Parent = holder
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 60
	light.Brightness = 4
	light.Parent = holder

	holder.Parent = folder

	-- Dźwięk i niebo.
	SoundController.playAt("riftOpen", info.startPos)
	local loop = SoundController.attach("riftLoop", holder)
	local skyActive = FxUtil.atLeast(info.size, SKY.fromSize)
	if skyActive then
		SoundController.play2D("thunderFar")
		SkyFx.tint(
			info.id,
			FxUtil.lighten(color, 0.35),
			FxUtil.bySize(SKY.tintStrength, info.size),
			FxUtil.bySize(SKY.darken, info.size)
		)
	end

	local shards: { Shard } = {}
	local shardsSpawned = false
	local closing = false
	local closeStart = 0
	local closedFlag = false
	local destroyed = false
	local spinAngle = 0
	local born = info.launchedAt

	local function spawnShards(now: number)
		shardsSpawned = true
		if not full then
			return
		end
		local pool = {}
		for _, child in templates:GetChildren() do
			if child:IsA("MeshPart") and string.sub(child.Name, 1, 6) == "Shard_" then
				table.insert(pool, child)
			end
		end
		if #pool == 0 then
			return
		end
		for _ = 1, FxUtil.count(FxUtil.bySize(RIFT.shardCount, info.size)) do
			local template = pool[rng:NextInteger(1, #pool)]
			local part = template:Clone()
			local s = width * rng:NextNumber(0.05, 0.11)
			part.Size = template.Size * s
			part.Material = Enum.Material.Neon
			part.Color = FxUtil.darken(color, rng:NextNumber(0.35, 0.6))
			local local_ = outlinePoint(rng:NextNumber(0, 2 * math.pi), width * 0.52)
			local world = cframe * CFrame.new(local_)
			part.CFrame = world * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
			part.Parent = folder
			local outward = (world.Position - cframe.Position).Unit
			table.insert(shards, {
				part = part,
				velocity = outward * width * rng:NextNumber(0.15, 0.35)
					+ Vector3.yAxis * width * rng:NextNumber(0, 0.1),
				spin = CFrame.Angles(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2)),
				born = now,
			})
		end
	end

	local function setOpen(sx: number, sy: number)
		for _, entry in parts do
			entry.part.Size = Vector3.new(entry.base.X * sx, math.max(entry.base.Y * sy, 0.05), entry.base.Z)
		end
		for _, beam in nebulas do
			beam.Width0 = height * 0.85 * sy
		end
		for _, swirl in swirls do
			local size = math.max(swirl.size * sy, 0.05)
			swirl.part.Size = Vector3.new(size, size, 0.2)
		end
		for _, emitter in emitters do
			emitter.Enabled = sy > 0.3
		end
	end

	local rift = {} :: Rift
	rift.position = info.startPos

	function rift.closed(): boolean
		return closedFlag
	end

	function rift.destroy()
		if destroyed then
			return
		end
		destroyed = true
		closedFlag = true
		SkyFx.release(info.id)
		SoundController.fadeOut(loop, 0.3)
		holder:Destroy()
		for _, shard in shards do
			shard.part:Destroy()
		end
		table.clear(shards)
	end

	function rift.close()
		if closing or destroyed then
			return
		end
		closing = true
		closeStart = os.clock()
		SoundController.playAt("riftClose", info.startPos)
		SoundController.fadeOut(loop, RIFT.closeSeconds)
		loop = nil
		SkyFx.release(info.id)
	end

	function rift.update(now: number, dt: number)
		if destroyed then
			return
		end
		local age = now - born
		-- Otwieranie: rysa → oko z przestrzeleniem.
		local sx, sy
		if age < RIFT.lineSeconds then
			sx = math.max(age / RIFT.lineSeconds, 0.05)
			sy = 0.03
		else
			sx = 1
			sy = math.max(FxUtil.easeOutBack((age - RIFT.lineSeconds) / RIFT.openSeconds), 0.03)
			if not shardsSpawned then
				spawnShards(now)
			end
		end
		if closing then
			local k = math.clamp((os.clock() - closeStart) / RIFT.closeSeconds, 0, 1)
			sy *= (1 - k) ^ 2
			sx *= 1 - k * k * 0.7
			if k >= 1 then
				rift.destroy()
				return
			end
		end
		setOpen(sx, sy)

		-- Puls: krawędź i światło.
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * RIFT.pulseSpeed * 2 * math.pi)
		if edgePart then
			edgePart.Color = FxUtil.lighten(glow, 0.15 + 0.35 * pulse)
		end
		light.Brightness = 3 + 3 * pulse
		flare.ImageTransparency = 0.25 + 0.25 * (1 - pulse) + (if closing then 0.5 else 0)

		spinAngle += dt
		for _, swirl in swirls do
			swirl.part.CFrame = cframe
				* CFrame.new(0, 0, swirl.depth)
				* CFrame.Angles(0, 0, spinAngle * swirl.speed * 2 * math.pi)
		end

		-- Błyskawice: co chwilę nowy łuk po krawędzi (czasem do środka), losowa tekstura i wygięcie.
		local clock = os.clock()
		for _, bolt in bolts do
			if clock >= bolt.nextAt then
				bolt.nextAt = clock + rng:NextNumber(RIFT.lightningInterval[1], RIFT.lightningInterval[2])
				if sy < 0.3 or rng:NextNumber() < 0.35 then
					bolt.beam.Transparency = NumberSequence.new(1)
				else
					local i = rng:NextInteger(1, OUTLINE_POINTS)
					local j = (
						(i - 1 + rng:NextInteger(2, 7) * (if rng:NextNumber() < 0.5 then -1 else 1)) % OUTLINE_POINTS
					) + 1
					bolt.beam.Attachment0 = outline[i]
					bolt.beam.Attachment1 = if rng:NextNumber() < 0.2 then center else outline[j]
					bolt.beam.Texture = VfxIds.LIGHTNING[rng:NextInteger(1, #VfxIds.LIGHTNING)]
					bolt.beam.CurveSize0 = rng:NextNumber(-width, width) * 0.15
					bolt.beam.CurveSize1 = rng:NextNumber(-width, width) * 0.15
					bolt.beam.Transparency = FxUtil.numberSeq(rng:NextNumber(0, 0.2), rng:NextNumber(0, 0.3))
					if skyActive and rng:NextNumber() < SKY.lightningChance then
						SkyFx.lightning(glow, 1)
					end
				end
			end
		end

		-- Odłamki nieba: spadają, obracają się i bledną.
		for index = #shards, 1, -1 do
			local shard = shards[index]
			local life = (now - shard.born) / RIFT.shardFallSeconds
			if life >= 1 then
				shard.part:Destroy()
				table.remove(shards, index)
				continue
			end
			shard.velocity -= Vector3.yAxis * RIFT.shardGravity * dt
			local cf = shard.part.CFrame
			shard.part.CFrame = (cf + shard.velocity * dt) * shard.spin:Lerp(CFrame.identity, 1 - dt)
			shard.part.Transparency = life ^ 2
		end
	end

	return rift
end

return RiftFx
