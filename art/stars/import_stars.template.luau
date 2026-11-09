--!strict
-- WYGENEROWANE przez art/stars/build_star.py — nie edytuj ręcznie.
-- Uruchom w Studio (execute_luau, Edit) po wstawieniu modeli FBX (insert_asset) jako
-- ServerStorage.StarImport.<Rodzaj> (Model z MeshPartami `<Rozmiar>_<Część>`).
-- Wynik: ServerStorage.Stars/<Rodzaj>/<Rozmiar> (Model, PrimaryPart = Shell, Attachmenty Zone_N na Shell,
-- na Core: PointLight `Glow` + ParticleEmitter `Aura` — T12 nimi pulsuje).
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

-- Dane wbudowane przy generowaniu (Stars.json → size, Themes.json → kolory), bo Config w Studio może być nieświeży.
local ZONES = HttpService:JSONDecode([==[__ZONES__]==])
local STAR_SIZE = HttpService:JSONDecode([==[__SIZES__]==])
local THEMES = HttpService:JSONDecode([==[__THEMES__]==])
local SIZES = { "Small", "Medium", "Large", "Huge" }

type Look = { material: Enum.Material, color: string, transparency: number?, reflectance: number? }
-- Wygląd części wg rodzaju: Core zawsze Neon `glow` (wszystko, co świeci w modelu).
local LOOK: { [string]: { [string]: Look } } = {
	Iron = {
		Shell = { material = Enum.Material.CorrodedMetal, color = "shell" },
		Accent = { material = Enum.Material.Metal, color = "color", reflectance = 0.3 },
		Orbit = { material = Enum.Material.Metal, color = "color", reflectance = 0.3 },
	},
	Lava = {
		Shell = { material = Enum.Material.Basalt, color = "shell" },
		Accent = { material = Enum.Material.Neon, color = "color" },
		Orbit = { material = Enum.Material.Basalt, color = "shell" },
	},
	Frost = {
		Shell = { material = Enum.Material.Glass, color = "shell", transparency = 0.45 },
		Accent = { material = Enum.Material.Glass, color = "color", transparency = 0.25 },
		Orbit = { material = Enum.Material.Glass, color = "color", transparency = 0.2 },
	},
	Geode = {
		Shell = { material = Enum.Material.Rock, color = "shell" },
		Accent = { material = Enum.Material.Neon, color = "color" },
		Orbit = { material = Enum.Material.Neon, color = "color" },
	},
	Comet = {
		Shell = { material = Enum.Material.Ice, color = "shell" },
		Accent = { material = Enum.Material.Neon, color = "color" },
		Orbit = { material = Enum.Material.Glass, color = "color", transparency = 0.3 },
	},
	Toxic = {
		Shell = { material = Enum.Material.Slate, color = "shell" },
		Accent = { material = Enum.Material.Neon, color = "color" },
		Orbit = { material = Enum.Material.Neon, color = "color" },
	},
	Electric = {
		Shell = { material = Enum.Material.Metal, color = "shell", reflectance = 0.15 },
		Accent = { material = Enum.Material.Neon, color = "color" },
		Orbit = { material = Enum.Material.Metal, color = "shell", reflectance = 0.15 },
	},
	Nebula = {
		Shell = { material = Enum.Material.Glass, color = "color", transparency = 0.55 },
		Accent = { material = Enum.Material.Neon, color = "color" },
		Orbit = { material = Enum.Material.Neon, color = "glow" },
	},
}
-- Dodatkowe efekty z Blendera (art/stars/fx.json): Comet `tail` = [początek, kierunek], Electric `beams` = pary punktów.
local EXTRA = HttpService:JSONDecode([==[__FX__]==])

-- Poświata i cząsteczki (tekstury wbudowane w Roblox — bez uploadu). Ilość rośnie z rozmiarem, nisko dla telefonów.
type Fx = { texture: string, color: string, rate: number, life: NumberRange, speed: NumberRange, size: number, accel: number, transparency: number, emission: number }
local FX: { [string]: Fx } = {
	Iron = { texture = "rbxasset://textures/particles/smoke_main.dds", color = "shell", rate = 3, life = NumberRange.new(2, 3.5), speed = NumberRange.new(0.5, 1.5), size = 0.35, accel = 1.5, transparency = 0.55, emission = 0 },
	Lava = { texture = "rbxasset://textures/particles/fire_sparks_main.dds", color = "color", rate = 8, life = NumberRange.new(1, 2), speed = NumberRange.new(1, 3), size = 0.12, accel = 3, transparency = 0, emission = 1 },
	Frost = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = "glow", rate = 6, life = NumberRange.new(1.5, 3), speed = NumberRange.new(0.2, 0.8), size = 0.1, accel = -0.3, transparency = 0.1, emission = 1 },
	Geode = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = "color", rate = 6, life = NumberRange.new(1.5, 3), speed = NumberRange.new(0.3, 1), size = 0.1, accel = 0.4, transparency = 0, emission = 1 },
	Comet = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = "glow", rate = 4, life = NumberRange.new(1, 2), speed = NumberRange.new(0.2, 0.6), size = 0.08, accel = 0, transparency = 0, emission = 1 },
	Toxic = { texture = "rbxasset://textures/particles/smoke_main.dds", color = "color", rate = 4, life = NumberRange.new(2, 3.5), speed = NumberRange.new(0.3, 0.9), size = 0.3, accel = 1, transparency = 0.6, emission = 0.6 },
	Electric = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = "color", rate = 8, life = NumberRange.new(0.3, 0.8), speed = NumberRange.new(2, 4), size = 0.08, accel = 0, transparency = 0, emission = 1 },
	Nebula = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = "glow", rate = 5, life = NumberRange.new(2, 3.5), speed = NumberRange.new(0.1, 0.4), size = 0.08, accel = 0, transparency = 0, emission = 1 },
}
local SIZE_RATE = { Small = 1, Medium = 1.5, Large = 2.5, Huge = 4 }
-- Rodzaje skalowane po całym ciele (bez orbity), a nie po samym Shell.
local FIT_BODY: { [string]: boolean } = { Frost = true }

local function addFx(core: BasePart, typeId: string, size: string, starSize: number, theme: { [string]: string })
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = Color3.fromHex(theme.glow)
	light.Brightness = 2.5
	light.Range = math.min(60, starSize * 1.3 + 6)
	light.Shadows = false
	light.Parent = core
	local fx = FX[typeId]
	local e = Instance.new("ParticleEmitter")
	e.Name = "Aura"
	e.Texture = fx.texture
	e.Color = ColorSequence.new(Color3.fromHex(theme[fx.color]))
	e.LightEmission = fx.emission
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.Rate = fx.rate * SIZE_RATE[size]
	e.Lifetime = fx.life
	e.Speed = NumberRange.new(fx.speed.Min * starSize / 10, fx.speed.Max * starSize / 10)
	e.Acceleration = Vector3.new(0, fx.accel * starSize / 10, 0)
	local s = fx.size * starSize
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.6), NumberSequenceKeypoint.new(0.3, s), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(fx.transparency, 1)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rotation = NumberRange.new(0, 360)
	e.LightInfluence = 0
	e.Parent = core
end

-- Efekty specjalne rodzajów 5-8 (T33). Ruch/miganie dokłada T12.
local function addExtra(model: Model, typeId: string, size: string, starSize: number, theme: { [string]: string }, m: number)
	local shell = model.PrimaryPart :: BasePart
	local core = model:FindFirstChild("Core") :: BasePart
	local data = EXTRA[typeId] and EXTRA[typeId][size]
	local function at(v: { number }): Vector3
		return shell.Position + Vector3.new(v[1], v[2], v[3]) * m
	end
	if typeId == "Comet" and data and data.tail then
		-- Iskry lecące wzdłuż ogona.
		local a = Instance.new("Attachment")
		a.Name = "Tail"
		a.Parent = shell
		local o = at(data.tail[1])
		local dir = Vector3.new(data.tail[2][1], data.tail[2][2], data.tail[2][3])
		a.WorldCFrame = CFrame.lookAt(o, o + dir)
		local e = Instance.new("ParticleEmitter")
		e.Name = "TailSparks"
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromHex(theme.glow), Color3.fromHex(theme.color))
		e.EmissionDirection = Enum.NormalId.Front
		e.SpreadAngle = Vector2.new(10, 10)
		e.Rate = 6 * SIZE_RATE[size]
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Speed = NumberRange.new(starSize * 0.6, starSize * 1.0)
		e.Drag = 1
		local s = 0.07 * starSize
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s), NumberSequenceKeypoint.new(1, 0) })
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Parent = a
	elseif typeId == "Electric" and data then
		-- Błyskawice między kulą a prętami (Beam bez tekstury = jednolity świecący pasek).
		for i, pair in data.beams do
			local a0 = Instance.new("Attachment")
			a0.Name = "Arc" .. i .. "_A"
			a0.Parent = shell
			a0.WorldPosition = at(pair[1])
			local a1 = Instance.new("Attachment")
			a1.Name = "Arc" .. i .. "_B"
			a1.Parent = shell
			a1.WorldPosition = at(pair[2])
			local b = Instance.new("Beam")
			b.Name = "Arc" .. i
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.Color = ColorSequence.new(Color3.fromHex(theme.color), Color3.fromHex(theme.glow))
			b.LightEmission = 1
			b.LightInfluence = 0
			b.FaceCamera = true
			b.Segments = 12
			b.Width0 = starSize * 0.03
			b.Width1 = starSize * 0.015
			b.CurveSize0 = starSize * 0.08
			b.CurveSize1 = -starSize * 0.08
			b.Transparency = NumberSequence.new(0)
			b.Parent = shell
		end
	elseif typeId == "Nebula" then
		-- Wirująca mgiełka w szklanej kuli.
		local e = Instance.new("ParticleEmitter")
		e.Name = "Mist"
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromHex(theme.glow), Color3.fromHex(theme.color))
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Rate = 3 * SIZE_RATE[size]
		e.Lifetime = NumberRange.new(3, 5)
		e.Speed = NumberRange.new(0, starSize * 0.03)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.Rotation = NumberRange.new(0, 360)
		local s = 0.3 * starSize
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.5), NumberSequenceKeypoint.new(0.5, s), NumberSequenceKeypoint.new(1, s * 0.6) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.75), NumberSequenceKeypoint.new(1, 1) })
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Parent = core
	end
end

local import = ServerStorage:FindFirstChild("StarImport")
assert(import, "Brak ServerStorage.StarImport — najpierw insert_asset modeli FBX")
local root = ServerStorage:FindFirstChild("Stars") or Instance.new("Folder")
root.Name = "Stars"
root.Parent = ServerStorage

local report = {}
for typeId, zonesBySize in ZONES do
	local src = import:FindFirstChild(typeId)
	if not src then
		table.insert(report, typeId .. ": brak modelu")
		continue
	end
	local theme = THEMES[typeId]
	local folder = root:FindFirstChild(typeId) or Instance.new("Folder")
	folder.Name = typeId
	folder.Parent = root
	for _, size in SIZES do
		local old = folder:FindFirstChild(size)
		if old then
			old:Destroy()
		end
		local model = Instance.new("Model")
		model.Name = size
		for _, part in src:GetDescendants() do
			if part:IsA("MeshPart") and string.sub(part.Name, 1, #size + 1) == size .. "_" then
				local role = string.sub(part.Name, #size + 2)
				local p = part:Clone()
				p.Name = role
				p.Anchored = true
				p.CanCollide = role == "Shell"
				p.CanQuery = role == "Shell" or role == "Core"
				p.CanTouch = false
				p.CastShadow = role == "Shell"
				if role == "Core" then
					p.Material = Enum.Material.Neon
					p.Color = Color3.fromHex(theme.glow)
				else
					local look = LOOK[typeId][role]
					p.Material = look.material
					p.Color = Color3.fromHex(theme[look.color])
					p.Transparency = look.transparency or 0
					p.Reflectance = look.reflectance or 0
				end
				p.Parent = model
			end
		end
		local shell = model:FindFirstChild("Shell") :: MeshPart?
		local core = model:FindFirstChild("Core") :: MeshPart?
		if not shell or not core then
			table.insert(report, typeId .. "/" .. size .. ": brak Shell/Core")
			model:Destroy()
			continue
		end
		model.PrimaryPart = shell
		-- `size` z Stars.json = średnica bryły (Shell). Frost: bryła to mały klejnot, sylwetkę robią ramiona
		-- płatka — skaluj po całym ciele bez orbity (Shell+Core+Accent).
		local ext = shell.Size
		if FIT_BODY[typeId] then
			-- części z FBX są bez obrotu → prostopadłościany osiowe
			local lo, hi = shell.Position, shell.Position
			for _, p in model:GetChildren() do
				if p:IsA("BasePart") and p.Name ~= "Orbit" then
					lo = lo:Min(p.Position - p.Size / 2)
					hi = hi:Max(p.Position + p.Size / 2)
				end
			end
			ext = hi - lo
		end
		local target = STAR_SIZE[size]
		model:ScaleTo(model:GetScale() * target / math.max(ext.X, ext.Y, ext.Z))
		model:PivotTo(CFrame.new(shell.Position))
		local m = math.max(shell.Size.X, shell.Size.Y, shell.Size.Z)
		for i, v in zonesBySize[size] do
			local a = Instance.new("Attachment")
			a.Name = "Zone_" .. i
			a.Parent = shell
			a.WorldPosition = shell.Position + Vector3.new(v[1], v[2], v[3]) * m
		end
		addFx(core, typeId, size, target, theme)
		addExtra(model, typeId, size, target, theme, m)
		model:SetAttribute("Type", typeId)
		model:SetAttribute("Size", size)
		model.Parent = folder
		table.insert(report, string.format("%s/%s: %d czesci, %d stref", typeId, size, #model:GetChildren(), #zonesBySize[size]))
	end
end
return report
