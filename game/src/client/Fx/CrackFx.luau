--!strict
-- CrackFx — efekty 3D minigry rozbijania (T06 v2), wszystko lokalnie u klienta:
--   surface()  — punkt i normalna na prawdziwej powierzchni modelu gwiazdy (raycast do środka),
--   leak()     — snop światła wyciekający z punktu, rośnie, gdy pierścień się zamyka,
--   burst()    — trafienie: iskry, odłamki, błysk światła (Miss = szary pył),
--   cracks()   — świecące pęknięcia na gwieździe odsłaniane z utratą HP (ten sam układ u wszystkich: seed z id).
-- Liczby: AnimConfig.CRACK.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VfxIds = require(Shared.Config.VfxIds)

local FxUtil = require(script.Parent.FxUtil)

local CRACK = FxUtil.CONFIG.CRACK

local rng = Random.new()
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local CrackFx = {}

-- Punkt na powierzchni modelu w kierunku `dir` od środka. Zwraca pozycję i normalną (fallback: sfera).
function CrackFx.surface(model: Model, center: Vector3, dir: Vector3, radius: number): (Vector3, Vector3)
	local unit = if dir.Magnitude > 1e-4 then dir.Unit else Vector3.yAxis
	rayParams.FilterDescendantsInstances = { model }
	local origin = center + unit * radius * 2.5
	local hit = Workspace:Raycast(origin, center - origin, rayParams)
	if hit then
		return hit.Position, hit.Normal
	end
	return center + unit * radius * 0.92, unit
end

export type Leak = {
	set: (self: Leak, phase: number) -> (),
	destroy: (self: Leak) -> (),
}

-- Snop światła z punktu na powierzchni (Beam od wnętrza na zewnątrz + PointLight).
function CrackFx.leak(position: Vector3, normal: Vector3, radius: number, glow: Color3): Leak
	local anchor = FxUtil.anchor(Vector3.one * 0.2, CFrame.new(position))
	local length = math.max(4, radius * CRACK.leakLength)
	local width = math.max(1.5, radius * CRACK.leakWidth)
	local a0 = FxUtil.attachment(anchor, -normal * 0.5)
	local a1 = FxUtil.attachment(anchor, normal * length)
	local beam = FxUtil.beam(anchor, a0, a1, {
		Texture = VfxIds.LIGHT_SHAFT,
		TextureMode = Enum.TextureMode.Stretch,
		Color = FxUtil.colorSeq(Color3.new(1, 1, 1), glow),
		LightEmission = 1,
		Brightness = 0.6,
		Width0 = width * 0.2,
		Width1 = width * 0.4,
		FaceCamera = true,
		Segments = 1,
		Transparency = FxUtil.numberSeq(0.8, 1),
	})
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = CRACK.leakLight
	light.Brightness = 0.5
	light.Shadows = false
	light.Parent = anchor
	anchor.Parent = FxUtil.folder()

	local leak = {} :: Leak
	function leak.set(_self: Leak, phase: number)
		local p = math.clamp(phase, 0, 1.2)
		beam.Width0 = width * (0.15 + 0.3 * p)
		beam.Width1 = width * (0.3 + 0.6 * p)
		beam.Transparency = FxUtil.numberSeq(0.85 - 0.3 * math.min(p, 1), 1)
		light.Brightness = 0.3 + 1.2 * p
	end
	function leak.destroy(_self: Leak)
		FxUtil.tween(beam, 0.15, { Width0 = 0, Width1 = 0 })
		FxUtil.tween(light, 0.15, { Brightness = 0 })
		task.delay(0.2, function()
			anchor:Destroy()
		end)
	end
	return leak
end

local shardPool: { MeshPart }? = nil
local function shards(): { MeshPart }
	if shardPool then
		return shardPool
	end
	local pool: { MeshPart } = {}
	local assets = ReplicatedStorage:FindFirstChild("VfxAssets")
	if assets then
		for _, child in assets:GetChildren() do
			if child:IsA("MeshPart") and string.sub(child.Name, 1, 6) == "Shard_" then
				table.insert(pool, child)
			end
		end
	end
	shardPool = pool
	return pool
end

-- Odłamki: zakotwiczone, lot po paraboli liczony lokalnie (bez fizyki i kolizji — tanio na telefonie).
local function flyShards(position: Vector3, normal: Vector3, glow: Color3, count: number, scale: number)
	local pool = shards()
	if #pool == 0 or count <= 0 then
		return
	end
	type Flying = { part: BasePart, velocity: Vector3, spin: CFrame }
	local flying: { Flying } = {}
	for _ = 1, count do
		local template = pool[rng:NextInteger(1, #pool)]
		local shard = template:Clone()
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.CastShadow = false
		shard.Material = Enum.Material.Neon
		shard.Color = FxUtil.lighten(glow, rng:NextNumber(0, 0.5))
		shard.Size = template.Size * scale * rng:NextNumber(0.6, 1.2)
		shard.CFrame = CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		local spread = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 1), rng:NextNumber(-1, 1))
		local velocity = (normal * 1.4 + spread).Unit * CRACK.shardSpeed * rng:NextNumber(0.6, 1.3)
		shard.Parent = FxUtil.folder()
		table.insert(flying, {
			part = shard,
			velocity = velocity,
			spin = CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3)),
		})
	end
	local age = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		age += dt
		local fade = math.clamp((age - CRACK.shardSeconds * 0.6) / (CRACK.shardSeconds * 0.4), 0, 1)
		for _, item in flying do
			item.velocity -= Vector3.yAxis * CRACK.shardGravity * dt
			item.part.CFrame = (item.part.CFrame + item.velocity * dt) * item.spin
			item.part.Transparency = fade
		end
		if age >= CRACK.shardSeconds then
			connection:Disconnect()
			for _, item in flying do
				item.part:Destroy()
			end
		end
	end)
end

-- Wybuch przy trafieniu. `kind` = ocena albo "Other" (trafienie innego gracza, skromniej).
function CrackFx.burst(position: Vector3, normal: Vector3, glow: Color3, kind: string, radius: number)
	local anchor = FxUtil.anchor(Vector3.one * 0.2, CFrame.lookAlong(position, normal))
	anchor.Parent = FxUtil.folder()
	local miss = kind == "Miss"
	local scale = math.clamp(radius * 0.06, 0.4, 3)
	if miss then
		local dust = FxUtil.emitter(anchor, {
			Texture = VfxIds.DUST,
			Enabled = false,
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(2, 6),
			SpreadAngle = Vector2.new(50, 50),
			EmissionDirection = Enum.NormalId.Front,
			Size = FxUtil.numberSeq(scale * 1.2, scale * 3),
			Color = FxUtil.colorSeq(Color3.fromRGB(150, 150, 165)),
			Transparency = FxUtil.numberSeq(0.5, 1),
			LightInfluence = 1,
		})
		dust:Emit(FxUtil.count(6))
	else
		local sparks = FxUtil.emitter(anchor, {
			Texture = VfxIds.SPARK,
			Enabled = false,
			Lifetime = NumberRange.new(0.25, 0.6),
			Speed = NumberRange.new(14, 34),
			SpreadAngle = Vector2.new(70, 70),
			EmissionDirection = Enum.NormalId.Front,
			Acceleration = Vector3.new(0, -30, 0),
			Drag = 3,
			Size = FxUtil.numberSeq(scale * 0.9, 0),
			Color = FxUtil.colorSeq(Color3.new(1, 1, 1), glow),
			LightEmission = 1,
		})
		sparks:Emit(FxUtil.count(CRACK.burstSparks[kind] or 10))
		local embers = FxUtil.emitter(anchor, {
			Texture = VfxIds.EMBER,
			Enabled = false,
			Lifetime = NumberRange.new(0.5, 1),
			Speed = NumberRange.new(4, 10),
			SpreadAngle = Vector2.new(180, 180),
			Size = FxUtil.numberSeq(scale * 0.5, 0),
			Color = FxUtil.colorSeq(FxUtil.lighten(glow, 0.4)),
			LightEmission = 1,
		})
		embers:Emit(FxUtil.count(math.ceil((CRACK.burstSparks[kind] or 10) / 2)))
		-- Błysk: rozbłysk-gwiazdka (Billboard) + światło.
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(scale * 6, scale * 6)
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		local glint = Instance.new("ImageLabel")
		glint.BackgroundTransparency = 1
		glint.Image = if kind == "Perfect" then VfxIds.FLARE else VfxIds.GLINT
		glint.ImageColor3 = FxUtil.lighten(glow, 0.5)
		glint.AnchorPoint = Vector2.new(0.5, 0.5)
		glint.Position = UDim2.fromScale(0.5, 0.5)
		glint.Size = UDim2.fromScale(0.3, 0.3)
		glint.Rotation = rng:NextNumber(0, 90)
		glint.Parent = gui
		gui.Adornee = anchor
		gui.Parent = anchor
		FxUtil.tween(glint, CRACK.flashSeconds, {
			Size = UDim2.fromScale(1, 1),
			ImageTransparency = 1,
			Rotation = glint.Rotation + 45,
		})
		local light = Instance.new("PointLight")
		light.Color = glow
		light.Range = CRACK.flashRange * (if kind == "Perfect" then 1.3 else 1)
		light.Brightness = if kind == "Perfect" then 2.5 else 1.2
		light.Parent = anchor
		FxUtil.tween(light, CRACK.flashSeconds, { Brightness = 0 })
		flyShards(position, normal, glow, FxUtil.count(CRACK.burstShards[kind] or 0), scale * 0.8)
	end
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

export type Cracks = {
	setDamage: (self: Cracks, fraction: number) -> (),
	flash: (self: Cracks) -> (),
	destroy: (self: Cracks) -> (),
}

local function hashSeed(text: string): number
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % 2147483647
	end
	return h
end

-- Sieć pęknięć na gwieździe. Ścieżka k odsłania się przy obrażeniach ≥ k/(n+1); odcinki rosną kolejno.
function CrackFx.cracks(model: Model, sizeId: string, radius: number, glow: Color3): Cracks
	local center = model:GetPivot().Position
	local random = Random.new(hashSeed(model.Name))
	local folder = Instance.new("Folder")
	folder.Name = `Cracks_{model.Name}`
	local width = math.max(CRACK.crackMinWidth, radius * CRACK.crackWidth)
	local color = FxUtil.lighten(glow, 0.35)

	type Segment = { part: Part, length: number, cframe: CFrame }
	type Path = { segments: { Segment }, shown: boolean }
	local paths: { Path } = {}
	for _ = 1, FxUtil.bySize(CRACK.crackPaths, sizeId) do
		local dir = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-0.2, 1), random:NextNumber(-1, 1))
		local point, normal = CrackFx.surface(model, center, dir, radius)
		-- Kierunek wzdłuż powierzchni (styczna).
		local heading = normal:Cross(Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), 0.3)).Unit
		local path: Path = { segments = {}, shown = false }
		for _ = 1, random:NextInteger(CRACK.crackSteps[1], CRACK.crackSteps[2]) do
			heading = CFrame.fromAxisAngle(normal, random:NextNumber(-CRACK.crackJitter, CRACK.crackJitter))
				:VectorToWorldSpace(heading)
			local guess = point + heading * radius * CRACK.crackStep
			local nextPoint, nextNormal = CrackFx.surface(model, center, guess - center, radius)
			local span = nextPoint - point
			if span.Magnitude < 0.05 then
				break
			end
			local mid = (point + nextPoint) / 2 + (normal + nextNormal).Unit * width * 0.3
			local cframe = CFrame.lookAt(mid, nextPoint, normal)
			local part = FxUtil.part(
				Enum.PartType.Block,
				Vector3.new(width, width * 0.5, 0.01),
				cframe,
				color,
				Enum.Material.Neon
			)
			part.Transparency = 1
			part.Parent = folder
			table.insert(path.segments, { part = part, length = span.Magnitude, cframe = cframe })
			point, normal = nextPoint, nextNormal
			heading = span.Unit
		end
		table.insert(paths, path)
	end
	local inner = Instance.new("PointLight")
	inner.Color = glow
	inner.Range = radius * 2.5 + 10
	inner.Brightness = CRACK.innerLight[1]
	inner.Shadows = false
	local holder = FxUtil.anchor(Vector3.one * 0.2, CFrame.new(center))
	inner.Parent = holder
	holder.Parent = folder
	folder.Parent = FxUtil.folder()

	local damage = 0
	local cracks = {} :: Cracks
	function cracks.setDamage(_self: Cracks, fraction: number)
		damage = math.clamp(fraction, 0, 1)
		for index, path in paths do
			if path.shown or damage < index / (#paths + 1) then
				continue
			end
			path.shown = true
			for order, segment in path.segments do
				local delay = (order - 1) * CRACK.crackGrowSeconds / #path.segments
				task.delay(delay, function()
					if not segment.part.Parent then
						return
					end
					segment.part.Transparency = 0
					FxUtil.tween(segment.part, CRACK.crackGrowSeconds / #path.segments, {
						Size = Vector3.new(width, width * 0.5, segment.length),
					})
				end)
			end
		end
		inner.Brightness = CRACK.innerLight[1] + (CRACK.innerLight[2] - CRACK.innerLight[1]) * damage
	end
	function cracks.flash(_self: Cracks)
		local base = CRACK.innerLight[1] + (CRACK.innerLight[2] - CRACK.innerLight[1]) * damage
		inner.Brightness = base * 2.5
		FxUtil.tween(inner, CRACK.crackFlash, { Brightness = base })
		for _, path in paths do
			if path.shown then
				for _, segment in path.segments do
					segment.part.Color = Color3.new(1, 1, 1)
					FxUtil.tween(segment.part, CRACK.crackFlash, { Color = color })
				end
			end
		end
	end
	function cracks.destroy(_self: Cracks)
		folder:Destroy()
	end
	return cracks
end

return CrackFx
