--!strict
-- WYGENEROWANE przez art/stars/build_star.py — nie edytuj ręcznie.
-- Uruchom w Studio (execute_luau, Edit) po wstawieniu modeli FBX (insert_asset) jako
-- ServerStorage.StarImport.<Rodzaj> (Model z MeshPartami `<Rozmiar>_<Część>`).
-- Wynik: ServerStorage.Stars/<Rodzaj>/<Rozmiar> (Model, PrimaryPart = Shell, Attachmenty Zone_N na Shell,
-- na Core: PointLight `Glow` + ParticleEmitter `Aura` — T12 nimi pulsuje).
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

-- Dane wbudowane przy generowaniu (Stars.json → size, Themes.json → kolory), bo Config w Studio może być nieświeży.
local ZONES = HttpService:JSONDecode([==[{"Iron": {"Small": [[-0.1026, 0.2887, -0.2285]], "Medium": [[-0.2977, 0.3052, 0.0244], [0.3312, 0.0561, 0.3034]], "Large": [[-0.159, 0.3034, -0.0582], [0.2965, 0.2424, 0.184], [-0.0768, 0.1148, -0.3802], [-0.2231, -0.005, 0.3423]], "Huge": [[-0.1283, 0.3515, -0.0292], [0.2061, 0.2843, 0.1298], [-0.0941, 0.2266, -0.2565], [-0.3257, 0.2123, 0.204], [0.412, 0.1608, -0.2324], [-0.4804, 0.0899, -0.0895], [0.0792, 0.0111, 0.4092], [0.2572, -0.0509, -0.3252]]}, "Lava": {"Small": [[-0.1413, 0.3547, -0.2807]], "Medium": [[-0.323, 0.3446, -0.0821], [0.3395, 0.0381, 0.3343]], "Large": [[-0.2567, 0.4308, 0.0392], [0.3385, 0.2619, 0.1889], [-0.0716, 0.1272, -0.4482], [-0.2106, -0.0157, 0.4501]], "Huge": [[-0.2013, 0.4921, -0.027], [0.1536, 0.3688, 0.2631], [-0.0578, 0.3152, -0.3835], [-0.32, 0.2383, 0.3114], [0.3871, 0.1402, -0.1146], [-0.4133, 0.0782, -0.1467], [0.1352, 0.0129, 0.4919], [0.0579, -0.0639, -0.4999]]}, "Frost": {"Small": [[-0.1246, 0.3826, -0.2838]], "Medium": [[-0.2955, 0.3035, -0.1322], [0.388, 0.0459, 0.2]], "Large": [[-0.246, 0.3989, 0.0533], [0.2687, 0.247, 0.2867], [-0.1983, 0.126, -0.44], [-0.2108, -0.0258, 0.4212]], "Huge": [[-0.17, 0.4649, 0.0113], [0.1675, 0.3796, 0.2517], [0.1169, 0.3241, -0.4066], [-0.2515, 0.2518, 0.3583], [0.4787, 0.1632, 0.0652], [-0.4473, 0.088, -0.1426], [0.1754, 0.0149, 0.4607], [0.1731, -0.0571, -0.4624]]}, "Geode": {"Small": [[-0.0902, 0.2715, -0.2067]], "Medium": [[-0.2051, 0.2317, -0.0797], [0.2061, 0.0553, 0.2838]], "Large": [[-0.211, 0.3853, 0.0607], [0.2904, 0.2123, 0.148], [-0.0721, 0.0719, -0.2633], [-0.1416, -0.0168, 0.3511]], "Huge": [[-0.1716, 0.4166, -0.046], [0.1892, 0.3239, 0.1702], [-0.0091, 0.187, -0.2449], [-0.0903, 0.1712, 0.2955], [0.356, 0.1241, 0.0354], [-0.2152, 0.0489, -0.1922], [0.0238, 0.009, 0.3732], [0.1503, -0.0495, -0.3667]]}, "Comet": {"Small": [[-0.1533, 0.3364, -0.2413]], "Medium": [[-0.3159, 0.3156, -0.0756], [0.3277, 0.0408, 0.315]], "Large": [[-0.2189, 0.36, -0.0584], [0.181, 0.2321, 0.2999], [-0.1105, 0.0974, -0.3884], [-0.3507, -0.0273, 0.2861]], "Huge": [[-0.154, 0.3741, 0.0146], [0.2584, 0.3323, 0.1244], [-0.1083, 0.2615, -0.3068], [-0.1986, 0.1838, 0.3073], [0.4186, 0.1448, -0.1569], [-0.4441, 0.0766, -0.1691], [-0.0315, 0.0004, 0.398], [0.242, -0.0596, -0.3089]]}, "Toxic": {"Small": [[-0.0459, 0.2993, -0.2421]], "Medium": [[-0.3108, 0.2595, -0.1792], [0.2174, -0.0206, 0.3029]], "Large": [[-0.2147, 0.2966, 0.1108], [0.1305, 0.1569, 0.3338], [-0.0278, 0.0418, -0.3479], [-0.1123, -0.0783, 0.4309]], "Huge": [[-0.0925, 0.2718, 0.0635], [0.2137, 0.2413, 0.1798], [0.0698, 0.1814, -0.2458], [-0.2125, 0.1328, 0.2484], [0.372, 0.0735, -0.008], [-0.2991, 0.0186, -0.0771], [0.0075, -0.0345, 0.3996], [0.2226, -0.0846, -0.2309]]}, "Electric": {"Small": [[-0.0948, 0.2371, -0.1897]], "Medium": [[-0.2212, 0.2265, -0.0669], [0.1363, 0.0319, 0.2861]], "Large": [[-0.1681, 0.2756, -0.0305], [0.207, 0.171, 0.1567], [-0.0244, 0.0787, -0.304], [-0.1665, -0.0159, 0.2713]], "Huge": [[-0.0907, 0.2362, 0.0344], [0.1063, 0.1922, 0.1151], [0.0169, 0.1593, -0.1983], [-0.1432, 0.2185, 0.3786], [0.2355, 0.081, -0.0072], [-0.3578, 0.0705, -0.1719], [0.1258, 0.0064, 0.2244], [0.0309, -0.0311, -0.245]]}, "Nebula": {"Small": [[-0.1568, 0.3505, -0.2418]], "Medium": [[-0.3298, 0.3422, -0.0349], [0.3689, 0.0683, 0.2638]], "Large": [[-0.2364, 0.411, -0.0734], [0.3757, 0.2657, 0.1717], [0.0374, 0.1306, -0.4898], [-0.3773, -0.0255, 0.3407]], "Huge": [[-0.2057, 0.483, 0.0686], [0.1246, 0.3965, 0.2987], [-0.0637, 0.3187, -0.3827], [-0.3735, 0.2259, 0.2216], [0.4491, 0.1703, -0.1388], [-0.3242, 0.0909, -0.384], [-0.0684, 0.0145, 0.5042], [0.2858, -0.0635, -0.4139]]}}]==])
local STAR_SIZE = HttpService:JSONDecode([==[{"Small": 6, "Medium": 12, "Large": 24, "Huge": 45}]==])
local THEMES = HttpService:JSONDecode([==[{"Iron": {"shell": "#3A3A40", "glow": "#FF9A3C", "color": "#9A9AA6"}, "Lava": {"shell": "#1C1412", "glow": "#FFB347", "color": "#FF5A1F"}, "Frost": {"shell": "#B9D4E6", "glow": "#E6FBFF", "color": "#7FD8FF"}, "Geode": {"shell": "#5B4A3E", "glow": "#E3C4FF", "color": "#B06BFF"}, "Comet": {"shell": "#4E6A80", "glow": "#FFFFFF", "color": "#9EE7FF"}, "Toxic": {"shell": "#1B2A14", "glow": "#D9FF5C", "color": "#7CFF2E"}, "Electric": {"shell": "#2A2E3A", "glow": "#9FE8FF", "color": "#FFE14D"}, "Nebula": {"shell": "#1E1A33", "glow": "#FF7AE6", "color": "#8A5CFF"}}]==])
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
local EXTRA = HttpService:JSONDecode([==[{"Comet": {"Small": {"beams": [], "tail": [[-0.265, 0.0805, 0.1366], [-0.8754, 0.2801, 0.3939]]}, "Medium": {"beams": [], "tail": [[-0.2389, 0.0724, 0.1068], [-0.8754, 0.2801, 0.3939]]}, "Large": {"beams": [], "tail": [[-0.2331, 0.0709, 0.0947], [-0.8754, 0.2801, 0.3939]]}, "Huge": {"beams": [], "tail": [[-0.2349, 0.067, 0.1195], [-0.8754, 0.2801, 0.3939]]}}, "Electric": {"Small": {"beams": [[[-0.3173, -0.0474, 0.0232], [-0.4495, -0.1344, 0.0328]], [[0.3196, -0.0186, -0.0307], [0.4483, -0.0521, -0.043]]], "tail": null}, "Medium": {"beams": [[[-0.3156, -0.0001, 0.0348], [-0.4419, -0.0003, 0.0488]], [[-0.2023, -0.0242, 0.2435], [-0.2842, -0.0681, 0.342]], [[0.3136, 0.0277, -0.0412], [0.4409, 0.078, -0.0579]]], "tail": null}, "Large": {"beams": [[[-0.2246, 0.0409, 0.2167], [-0.3173, 0.1156, 0.3061]], [[-0.0685, -0.0224, 0.3064], [-0.0962, -0.063, 0.4301]], [[0.3129, -0.005, -0.0334], [0.4382, -0.014, -0.0468]], [[0.2321, 0.0043, -0.2125], [0.325, 0.012, -0.2976]]], "tail": null}, "Huge": {"beams": [[[-0.2417, 0.0466, 0.0366], [-0.3448, 0.1328, 0.0521]], [[-0.1995, 0.0079, 0.1486], [-0.2795, 0.0222, 0.2082]], [[0.2455, -0.0359, -0.0195], [0.3475, -0.1015, -0.0276]], [[0.098, 0.0101, -0.2285], [0.1373, 0.0282, -0.3203]], [[-0.0271, -0.0012, -0.2474], [-0.0379, -0.0033, -0.3464]], [[-0.1485, 0.0072, -0.1996], [-0.208, 0.0202, -0.2796]]], "tail": null}}}]==])

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
