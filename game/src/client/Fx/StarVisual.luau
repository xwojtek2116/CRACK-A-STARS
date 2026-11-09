--!strict
-- StarVisual — „żyjąca” gwiazda v2 (T40) na kliencie: stany (Dormant, Active, Charging, Burst, Damaged, Depleted)
-- i animacje (ImpactLanding, DamageReaction, ToxicBurst, Collapse, CorePulse, CrystalPulse, CrystalGrowth, EnergyCharge).
-- Model z ServerStorage.Stars/<Rodzaj>/<Rozmiar> z atrybutem VisualV2 (import: art/stars/toxic/import_toxic_v2.luau).
-- Serwer trzyma model nieruchomo; tu ruszamy części lokalnie (BulkMoveTo), dokładamy gruz i emitery.
-- Wzór zachowania: prototyp art/stars/toxic/viewer/ToxicStarLab.html. Liczby: Config/StarVisualConfig.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StarConfig = require(Shared.Config.StarConfig)
local StarVisualConfig = require(Shared.Config.StarVisualConfig)
local VfxIds = require(Shared.Config.VfxIds)

local FxUtil = require(script.Parent.FxUtil)

type Pose = StarVisualConfig.Pose
export type VisualState = "Dormant" | "Active" | "Charging" | "Burst" | "Damaged" | "Depleted"
export type AnimName =
	"CorePulse"
	| "CrystalPulse"
	| "CrystalGrowth"
	| "EnergyCharge"
	| "ToxicBurst"
	| "ImpactLanding"
	| "DamageReaction"
	| "Collapse"

-- Ruchoma grupa części: transformacja wokół `center` (przestrzeń pivotu modelu), opcjonalne skalowanie od `base`.
type Mover = {
	name: string,
	parts: { BasePart },
	rel: { CFrame }, -- CFrame części względem pivotu (stan bazowy)
	sizes: { Vector3 },
	center: Vector3,
	base: Vector3, -- punkt skalowania (podstawa kryształu, dno krateru)
	dir: Vector3,
	rotAxis: Vector3,
	rank: number,
	grows: boolean,
	dist: number,
	lastScale: number,
}

type Debris = {
	part: BasePart,
	size: number,
	radius: number,
	height: number,
	angle: number,
	speed: number,
	bob: number,
	bobFreq: number,
	phase: number,
	spin: Vector3,
	rot: CFrame,
}

type Anim = { name: AnimName, t: number, thenState: VisualState? }

export type StarVisual = {
	setState: (state: VisualState) -> (),
	play: (name: AnimName, thenState: VisualState?) -> (),
	setEnergyLevel: (value: number) -> (),
	update: (dt: number) -> (),
	dying: (reason: string) -> (),
	destroy: () -> (),
}

local CFG = StarVisualConfig
local ANIM = CFG.ANIM_SECONDS
local rng = Random.new()

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
local function seg(p: number, a: number, b: number): number
	return clamp01((p - a) / (b - a))
end
local function smoothstep(a: number, b: number, x: number): number
	local t = clamp01((x - a) / (b - a))
	return t * t * (3 - 2 * t)
end
local function easeInQ(x: number): number
	return x * x
end
local function easeOutQ(x: number): number
	return 1 - (1 - x) * (1 - x)
end
local function easeOutC(x: number): number
	return 1 - (1 - x) ^ 3
end
local function easeInOut(x: number): number
	return if x < 0.5 then 4 * x * x * x else 1 - (-2 * x + 2) ^ 3 / 2
end
local function hash(n: number): number
	local s = math.sin(n * 127.1) * 43758.5453
	return s - math.floor(s)
end
local function pulseWave(x: number): number
	return math.max(0, math.sin(x * math.pi * 2)) ^ 3 * 0.7 + math.max(0, math.sin(x * math.pi * 2 * 1.7 + 1)) ^ 4 * 0.3
end

-- Nadpisania animacji (p = postęp 0..1). Zwracają dodatki do pozy; `x` = pola chwilowe.
type Extra = {
	pulse: number,
	coreScale: number,
	flash: number,
	shock: number, -- 0..1 postęp fali, -1 brak
	growSel: number,
	crystalWave: number,
	bodyY: number,
	craterScale: number,
}

local function applyAnim(name: AnimName, p: number, P: Pose, x: Extra)
	local pose = P :: any
	if name == "CorePulse" then
		local k = if p < 0.3 then easeOutQ(p / 0.3) else 1 - easeInQ((p - 0.3) / 0.7)
		x.coreScale *= 1 + 0.28 * k
		x.pulse += 0.9 * k
	elseif name == "CrystalPulse" then
		x.crystalWave = p
	elseif name == "CrystalGrowth" then
		x.growSel = FxUtil.easeOutBack(p)
	elseif name == "EnergyCharge" then
		local k = easeInQ(p)
		pose.debrisPull += 0.75 * k
		x.pulse += 1.1 * k
		x.coreScale *= 1 + 0.2 * k
		pose.shake += 0.04 * k
		pose.debrisSpeed *= 1 + 3 * k
		pose.spores += k
		pose.sparks += k
	elseif name == "ToxicBurst" then
		local pre, out, back = seg(p, 0, 0.12), seg(p, 0.12, 0.32), seg(p, 0.35, 1)
		pose.debrisPull += 0.6 * pre * (1 - out)
		x.coreScale *= 1 - 0.15 * pre * (1 - out) + 0.35 * out * (1 - back)
		pose.explode += easeOutC(out) * (1 - easeInOut(back)) * 1.1
		pose.debrisRadius *= 1 + 0.8 * out * (1 - back)
		x.pulse += 1.5 * pre + 2 * out * (1 - back)
		x.flash += math.max(0, 1 - math.abs(p - 0.15) / 0.1)
		x.shock = if p >= 0.12 then seg(p, 0.12, 0.75) else -1
		pose.smoke += 0.8 * out
		pose.sparks += 2 * out * (1 - back)
		pose.spores += 2 * out * (1 - back)
	elseif name == "ImpactLanding" then
		-- W grze lot pokazuje FallFx — tu tylko odbicie, osiadanie, rozrost krateru i fala.
		local damp = math.exp(-p * 6)
		x.bodyY = 0.35 * math.abs(math.sin(p * 9)) * damp
		pose.debrisRadius *= 0.55 + 0.45 * easeOutC(seg(p, 0.05, 0.6)) + 0.5 * damp
		x.craterScale = FxUtil.easeOutBack(seg(p, 0, 0.35))
		x.growSel = FxUtil.easeOutBack(seg(p, 0.25, 0.75))
		x.shock = seg(p, 0, 0.55)
		pose.smoke += 0.8 * damp
		x.flash += math.max(0, 1 - p * 8)
		pose.shake += 0.08 * damp
	elseif name == "DamageReaction" then
		local k = 1 - p
		pose.shake += 0.12 * k
		pose.explode += 0.12 * math.sin(math.pi * p)
		x.pulse += (hash(math.floor(p * 30)) - 0.4) * 1.2 * k
		x.coreScale *= 1 - 0.12 * math.sin(math.pi * p)
		pose.sparks += 2 * k
	elseif name == "Collapse" then
		local k = easeInQ(p)
		pose.energy *= 1 - 0.95 * easeOutQ(p)
		pose.debrisFall = math.max(pose.debrisFall, k)
		pose.desat = math.max(pose.desat, 0.85 * p)
		pose.explode += 0.05 * p
		pose.smoke += 0.5 * p
		pose.spores *= 1 - p
		pose.drops *= 1 - p
		pose.broken = math.max(pose.broken, 0.5 * p)
	end
end

local StarVisual = {}

function StarVisual.isV2(model: Model): boolean
	return model:GetAttribute("VisualV2") == true
end

function StarVisual.attach(model: Model, fresh: boolean): StarVisual?
	if not StarVisual.isV2(model) then
		return nil
	end
	local sizeId = model:GetAttribute("Size")
	local typeId = model:GetAttribute("Type")
	local core = model:FindFirstChild("Core")
	local mainBody = model:FindFirstChild("MainBody")
	local hitbox = model.PrimaryPart
	if
		typeof(sizeId) ~= "string"
		or typeof(typeId) ~= "string"
		or not core
		or not core:IsA("BasePart")
		or not mainBody
		or not hitbox
	then
		return nil
	end
	local su = (model:GetAttribute("StudsPerUnit") :: number?) or 1
	local pivot0 = model:GetPivot()
	local inv0 = pivot0:Inverse()
	local neon = StarConfig.color(typeId)
	local crystalColor = FxUtil.darken(neon, 0.2)
	local coreBaseColor = core.Color
	local quality = FxUtil.quality()

	local function relOf(p: BasePart): CFrame
		return inv0 * p.CFrame
	end
	local coreRel = relOf(core).Position
	local crater = model:FindFirstChild("Crater") :: BasePart?
	-- Dno krateru: środek bbox krateru leży 0,149 jednostki nad dnem.
	local floorY = if crater then relOf(crater).Position.Y - 0.149 * su else coreRel.Y - 1.15 * su

	local function mover(name: string, root: BasePart, grows: boolean, rank: number): Mover
		local parts: { BasePart } = { root }
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		local rel, sizes = {}, {}
		for i, p in parts do
			rel[i] = relOf(p)
			sizes[i] = p.Size
		end
		local center = rel[1].Position
		local base = Vector3.new(center.X, center.Y - root.Size.Y * 0.5, center.Z)
		local flat = Vector3.new(center.X - coreRel.X, 0, center.Z - coreRel.Z)
		local dir = (if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis) + Vector3.new(0, 0.35, 0)
		return {
			name = name,
			parts = parts,
			rel = rel,
			sizes = sizes,
			center = center,
			base = base,
			dir = dir.Unit,
			rotAxis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit,
			rank = rank,
			grows = grows,
			dist = (center - coreRel).Magnitude / su,
			lastScale = 1,
		}
	end

	local shells: { Mover } = {}
	for _, child in mainBody:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(shells, mover(child.Name, child, false, 1))
		end
	end
	local crystals: { Mover } = {}
	local crystalFolder = model:FindFirstChild("Crystals")
	if crystalFolder then
		for _, child in crystalFolder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(
					crystals,
					mover(child.Name, child, CFG.GROWING[child.Name] == true, CFG.CRYSTAL_RANK[child.Name] or 0.5)
				)
			end
		end
	end
	local coreMover = mover("Core", core, false, 1)
	coreMover.base = coreMover.center
	local slime = model:FindFirstChild("Slime") :: BasePart?
	local slimeMover = if slime then mover("Slime", slime, false, 1) else nil
	local craterMover: Mover? = nil
	if crater then
		craterMover = mover("Crater", crater, true, 1)
		craterMover.base = Vector3.new(0, floorY, 0)
	end

	-- Gruz: szablony z modelu + klony do liczby z configu (tylko klient).
	local debris: { Debris } = {}
	local debrisFolder = model:FindFirstChild("FloatingDebris")
	if debrisFolder then
		local templates = {}
		for _, child in debrisFolder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(templates, child)
			end
		end
		local want = math.max(#templates, math.floor((CFG.DEBRIS_COUNT[sizeId] or 6) * math.max(0.5, quality)))
		local orbit = CFG.DEBRIS_ORBIT
		for i = 1, want do
			local template = templates[(i - 1) % #templates + 1]
			local part = if i <= #templates then template else template:Clone()
			if part ~= template then
				local s = rng:NextNumber(0.6, 1.2)
				part.Size = template.Size * s
				part.Parent = debrisFolder
			end
			table.insert(debris, {
				part = part,
				size = part.Size.Magnitude * 0.3,
				radius = rng:NextNumber(orbit.radius[1], orbit.radius[2]),
				height = rng:NextNumber(orbit.height[1], orbit.height[2]),
				angle = rng:NextNumber(0, math.pi * 2),
				speed = rng:NextNumber(orbit.speed[1], orbit.speed[2]) * (if rng:NextNumber() < 0.3 then -1 else 1),
				bob = rng:NextNumber(0.05, 0.16),
				bobFreq = rng:NextNumber(0.6, 1.4),
				phase = rng:NextNumber(0, math.pi * 2),
				spin = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)),
				rot = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
			})
		end
	end

	-- Emitery w punktach zaczepienia (Attachmenty na Hitbox).
	local size = StarConfig.CLASSES[sizeId] and StarConfig.CLASSES[sizeId].size or 24
	local rates = CFG.EMITTERS
	local sizeMult = size / 24
	local emitters: { [string]: { ParticleEmitter } } = { spores = {}, sparks = {}, smoke = {}, drops = {} }
	local function emitterAt(kind: string, attachmentName: string, props: { [string]: any })
		local attachment = hitbox:FindFirstChild(attachmentName)
		if attachment and attachment:IsA("Attachment") then
			table.insert(emitters[kind], FxUtil.emitter(attachment, props :: any))
		end
	end
	emitterAt("spores", "ANCHOR_Particles", {
		Texture = VfxIds.GLINT,
		Rate = 0,
		Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(size * 0.02, size * 0.08),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, size * 0.05, 0),
		Size = FxUtil.numberSeq(0, size * 0.03, 0),
		Color = FxUtil.colorSeq(FxUtil.lighten(neon, 0.4), neon),
		LightEmission = 1,
		Shape = Enum.ParticleEmitterShape.Sphere,
	})
	for i = 1, 3 do
		emitterAt("sparks", string.format("ANCHOR_Cracks_%02d", i), {
			Texture = VfxIds.SPARK,
			Rate = 0,
			Lifetime = NumberRange.new(0.4, 0.9),
			Speed = NumberRange.new(size * 0.05, size * 0.15),
			SpreadAngle = Vector2.new(60, 60),
			Acceleration = Vector3.new(0, size * 0.15, 0),
			Size = FxUtil.numberSeq(size * 0.02, 0),
			Color = FxUtil.colorSeq(Color3.new(1, 1, 1), neon),
			LightEmission = 1,
		})
	end
	emitterAt("smoke", "ANCHOR_Shockwave", {
		Texture = VfxIds.SMOKE_SHEET,
		FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4,
		FlipbookMode = Enum.ParticleFlipbookMode.OneShot,
		Rate = 0,
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(size * 0.03, size * 0.08),
		SpreadAngle = Vector2.new(40, 40),
		Acceleration = Vector3.new(0, size * 0.04, 0),
		Size = FxUtil.numberSeq(size * 0.15, size * 0.5),
		Color = FxUtil.colorSeq(FxUtil.darken(neon, 0.55), Color3.fromRGB(60, 66, 58)),
		Transparency = FxUtil.numberSeq(0.5, 1),
		LightInfluence = 1,
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		EmissionDirection = Enum.NormalId.Top,
	})
	for i = 1, 3 do
		emitterAt("drops", string.format("ANCHOR_Drip_%02d", i), {
			Texture = VfxIds.GLINT,
			Rate = 0,
			Lifetime = NumberRange.new(0.5, 0.8),
			Speed = NumberRange.new(0, 0),
			Acceleration = Vector3.new(0, -size * 1.6, 0),
			Size = FxUtil.numberSeq(size * 0.012, size * 0.008),
			Color = FxUtil.colorSeq(neon),
			LightEmission = 0.8,
		})
	end

	local glowLight = core:FindFirstChild("Glow") :: PointLight?
	local glowBase = if glowLight then glowLight.Brightness else 2
	local folder = FxUtil.folder()

	-- Stan i animacja
	local stateName: VisualState = "Active"
	local base: Pose = table.clone(CFG.STATES.Active) :: any
	local target: Pose = CFG.STATES.Active
	local anim: Anim? = nil
	local energyLevel = 1
	local time = 0
	local farClock = 0
	local lastHitAt = -math.huge
	local dyingAt: number? = nil
	local destroyed = false

	local handle = {} :: StarVisual

	function handle.setState(state: VisualState)
		stateName = state
		target = CFG.STATES[state]
	end
	function handle.play(name: AnimName, thenState: VisualState?)
		anim = { name = name, t = 0, thenState = thenState }
	end
	function handle.setEnergyLevel(value: number)
		energyLevel = math.clamp(value, 0, 1.5)
	end

	local shockPart: BasePart? = nil
	local function shockwave(progress: number)
		if progress < 0 or progress >= 1 then
			if shockPart then
				shockPart.Transparency = 1
			end
			return
		end
		if not shockPart then
			local ring = FxUtil.part(Enum.PartType.Cylinder, Vector3.one, CFrame.identity, neon, Enum.Material.Neon)
			ring.Parent = folder
			shockPart = ring
		end
		local ring = shockPart :: BasePart
		local r = size * (0.2 + progress * 1.6)
		ring.Size = Vector3.new(size * 0.02, r * 2, r * 2)
		ring.CFrame = pivot0 * CFrame.new(0, floorY + size * 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Transparency = 0.15 + 0.85 * progress
	end

	local bulkParts: { BasePart } = {}
	local bulkCFrames: { CFrame } = {}
	local function place(m: Mover, offset: Vector3, rot: CFrame, scale: number)
		local scaled = math.abs(scale - m.lastScale) > 0.002
		for i, p in m.parts do
			local rel = m.rel[i]
			if scale ~= 1 then
				rel = CFrame.new(m.base + (rel.Position - m.base) * scale) * rel.Rotation
			end
			local cf = pivot0 * CFrame.new(m.center + offset) * rot * CFrame.new(-m.center) * rel
			table.insert(bulkParts, p)
			table.insert(bulkCFrames, cf)
			if scaled then
				p.Size = m.sizes[i] * math.max(scale, 0.001)
			end
		end
		if scaled then
			m.lastScale = scale
		end
	end

	local function apply(P: Pose, x: Extra, dt: number)
		local pv = pulseWave(time * P.pulseRate)
		local E = math.max(0, P.energy * (1 + P.pulseAmp * (pv - 0.3)) + x.pulse * math.max(0.3, P.energy))
		if P.flicker > 0.01 and hash(math.floor(time * 11)) > 1 - P.flicker * 0.35 then
			E *= 0.3
		end
		E *= energyLevel
		local Ec = math.min(E, 1.3)
		local bright = clamp01(0.25 + Ec * 0.6)
		local dead = CFG.DEAD_COLOR

		-- światło i kolory Neon (jasność Neon = jasność koloru)
		if glowLight then
			glowLight.Brightness = glowBase * (0.3 + Ec * 1.2) + x.flash * 6
		end
		core.Color = dead:Lerp(coreBaseColor, clamp01(0.35 + Ec * 0.55) * (1 - P.desat))
		local veinColor = dead:Lerp(neon, bright * (1 - P.desat * 0.85))
		for _, m in shells do
			for i = 2, #m.parts do
				m.parts[i].Color = veinColor
			end
		end
		if craterMover then
			for i = 2, #craterMover.parts do
				craterMover.parts[i].Color = veinColor
			end
		end
		if slime then
			slime.Color = veinColor
		end

		table.clear(bulkParts)
		table.clear(bulkCFrames)
		local sh = P.shake * su
		local bodyOffset = Vector3.new(
			(hash(time * 60) - 0.5) * sh * 2,
			x.bodyY * su + (hash(time * 60 + 7) - 0.5) * sh,
			(hash(time * 60 + 3) - 0.5) * sh * 2
		)
		for _, m in shells do
			local offset = bodyOffset + m.dir * (P.explode * CFG.EXPLODE_DISTANCE * su)
			if P.flicker > 0.01 then
				offset += Vector3.new(0, math.sin(time * 23 + m.center.X) * 0.012 * su, 0)
			end
			place(m, offset, CFrame.fromAxisAngle(m.rotAxis, P.explode * 0.35), 1)
		end
		local coreScale = x.coreScale * (1 + 0.07 * pv * P.pulseAmp)
		place(coreMover, bodyOffset, CFrame.identity, coreScale)
		if slimeMover then
			place(slimeMover, bodyOffset, CFrame.identity, 1)
		end
		for _, m in crystals do
			local brokenF = smoothstep(P.broken - 0.06, P.broken + 0.06, m.rank)
			local grow = (if m.grows then x.growSel else 1) * brokenF
			place(m, bodyOffset + m.dir * (P.explode * 2.2 * su), CFrame.identity, math.max(grow, 0.001))
			local wave = 0
			if x.crystalWave >= 0 then
				wave = math.exp(-((m.dist - x.crystalWave * 3.6) ^ 2) / 0.12) * 0.8
			end
			local shimmer = 0.12 * math.sin(time * 2.2 - m.dist * 2.5)
			local k = clamp01(bright * (1 + shimmer) + wave)
			m.parts[1].Color = dead:Lerp(crystalColor, k * (1 - P.desat * 0.8))
		end
		if craterMover then
			place(craterMover, Vector3.zero, CFrame.identity, math.max(x.craterScale, 0.001))
		end

		-- gruz
		local fall = easeInQ(clamp01(P.debrisFall))
		for _, d in debris do
			d.angle += dt * d.speed * P.debrisSpeed * (1 - fall)
			local radius = (d.radius * P.debrisRadius * (1 - P.debrisPull * 0.7) + P.explode * 1.4) * su
			local y = floorY + (d.height + P.debrisLift + math.sin(time * d.bobFreq + d.phase) * d.bob) * su
			local orbitPos = Vector3.new(math.sin(d.angle) * radius, y, math.cos(d.angle) * radius)
			local groundR = math.min(2.4, d.radius * 0.85) * su
			local groundPos =
				Vector3.new(math.sin(d.angle) * groundR, floorY + d.size * 0.5, math.cos(d.angle) * groundR)
			local pos = orbitPos:Lerp(groundPos, fall) + bodyOffset * (1 - fall)
			local spin = (1 - fall) * dt
			d.rot *= CFrame.Angles(d.spin.X * spin, d.spin.Y * spin, d.spin.Z * spin)
			table.insert(bulkParts, d.part)
			table.insert(bulkCFrames, pivot0 * CFrame.new(pos) * d.rot)
		end
		Workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)

		-- emitery
		local fx = quality * sizeMult
		for kind, list in emitters do
			local level = math.max(0, (P :: any)[kind] :: number)
			for _, e in list do
				e.Rate = rates[kind] * level * fx
			end
		end
		shockwave(x.shock)
	end

	local hpConnection = model:GetAttributeChangedSignal("Hp"):Connect(function()
		lastHitAt = time
		if not dyingAt then
			handle.play("DamageReaction")
		end
	end)

	local function chooseState()
		if dyingAt then
			return
		end
		local hp = model:GetAttribute("Hp")
		local maxHp = model:GetAttribute("MaxHp")
		local camera = Workspace.CurrentCamera
		local far = camera and (camera.CFrame.Position - pivot0.Position).Magnitude > CFG.DORMANT_DISTANCE
		local want: VisualState = "Active"
		if typeof(hp) == "number" and typeof(maxHp) == "number" and maxHp > 0 and hp / maxHp < CFG.DAMAGED_HP then
			want = "Damaged"
		elseif time - lastHitAt < CFG.CHARGING_SECONDS then
			want = "Charging"
		elseif far then
			want = "Dormant"
		end
		if want ~= stateName then
			handle.setState(want)
		end
	end

	local accum = 0
	function handle.update(dt: number)
		if destroyed or not model.Parent then
			return
		end
		time += dt
		accum += dt
		-- Daleko: rzadsze odświeżanie (stan Dormant), blisko co klatkę.
		if stateName == "Dormant" and not anim then
			farClock += dt
			if farClock < CFG.FAR_UPDATE_SECONDS then
				return
			end
		end
		local step = accum
		accum = 0
		farClock = 0
		chooseState()
		local k = math.min(1, step * CFG.BLEND_SPEED)
		local b = base :: any
		local tgt = target :: any
		for key in CFG.DEFAULT do
			b[key] += ((tgt[key] :: number) - (b[key] :: number)) * k
		end
		local P = table.clone(base) :: Pose
		local x: Extra = {
			pulse = 0,
			coreScale = 1,
			flash = 0,
			shock = -1,
			growSel = 1,
			crystalWave = -1,
			bodyY = 0,
			craterScale = 1,
		}
		local current = anim
		if current then
			current.t += step
			local duration = ANIM[current.name]
			local p = math.min(1, current.t / duration)
			applyAnim(current.name, p, P, x)
			if p >= 1 then
				if current.thenState then
					-- Płynne przejście: baza przejmuje ostatnią pozę animacji.
					for key in CFG.DEFAULT do
						b[key] = (P :: any)[key]
					end
					handle.setState(current.thenState)
				end
				anim = nil
			end
		end
		apply(P, x, step)
		if dyingAt and time - dyingAt > StarConfig.SCHEDULE.dyingSeconds - CFG.FADE_SECONDS - 0.15 then
			local fade = clamp01(
				(time - dyingAt - (StarConfig.SCHEDULE.dyingSeconds - CFG.FADE_SECONDS - 0.15)) / CFG.FADE_SECONDS
			)
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d ~= hitbox then
					d.LocalTransparencyModifier = fade
				end
			end
		end
	end

	function handle.dying(reason: string)
		if dyingAt then
			return
		end
		dyingAt = time
		lastHitAt = -math.huge
		if reason == "Cracked" then
			handle.setState("Burst")
			handle.play("ToxicBurst", "Depleted")
		else
			handle.play("Collapse", "Depleted")
		end
	end

	function handle.destroy()
		if destroyed then
			return
		end
		destroyed = true
		hpConnection:Disconnect()
		if shockPart then
			shockPart:Destroy()
		end
		for _, list in emitters do
			for _, e in list do
				e:Destroy()
			end
		end
	end

	if fresh then
		handle.play("ImpactLanding")
	end
	return handle
end

return StarVisual
