--!strict
-- WYGENEROWANE przez art/stars/build_star.py — nie edytuj ręcznie.
-- Uruchom w Studio (execute_luau, Edit) po wstawieniu modeli FBX (insert_asset) jako
-- ServerStorage.StarImport.<Rodzaj> (Model z MeshPartami `<Rozmiar>_<Część>`).
-- Wynik: ServerStorage.Stars/<Rodzaj>/<Rozmiar> (Model, PrimaryPart = Shell, Attachmenty Zone_N na Shell,
-- na Core: PointLight `Glow` + ParticleEmitter `Aura` — T12 nimi pulsuje).
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

-- Dane wbudowane przy generowaniu (Stars.json → size, Themes.json → kolory), bo Config w Studio może być nieświeży.
local ZONES = HttpService:JSONDecode([==[{"Iron": {"Small": [[0.1026, 0.2887, 0.2285]], "Medium": [[0.2977, 0.3052, -0.0244], [-0.3312, 0.0561, -0.3034]], "Large": [[0.159, 0.3034, 0.0582], [-0.2965, 0.2424, -0.184], [0.0768, 0.1148, 0.3802], [0.2231, -0.005, -0.3423]], "Huge": [[0.1283, 0.3515, 0.0292], [-0.2061, 0.2843, -0.1298], [0.0941, 0.2266, 0.2565], [0.3257, 0.2123, -0.204], [-0.412, 0.1608, 0.2324], [0.4804, 0.0899, 0.0895], [-0.0792, 0.0111, -0.4092], [-0.2572, -0.0509, 0.3252]]}, "Lava": {"Small": [[0.1413, 0.3547, 0.2807]], "Medium": [[0.323, 0.3446, 0.0821], [-0.3395, 0.0381, -0.3343]], "Large": [[0.2567, 0.4308, -0.0392], [-0.3385, 0.2619, -0.1889], [0.0716, 0.1272, 0.4482], [0.2106, -0.0157, -0.4501]], "Huge": [[0.2013, 0.4921, 0.027], [-0.1536, 0.3688, -0.2631], [0.0578, 0.3152, 0.3835], [0.32, 0.2383, -0.3114], [-0.3871, 0.1402, 0.1146], [0.4133, 0.0782, 0.1467], [-0.1352, 0.0129, -0.4919], [-0.0579, -0.0639, 0.4999]]}, "Frost": {"Small": [[0.1458, 0.3793, 0.2996]], "Medium": [[0.3533, 0.3533, 0.0258], [-0.2517, 0.0493, -0.4787]], "Large": [[0.2809, 0.4328, -0.0216], [-0.349, 0.2778, -0.223], [-0.043, 0.1248, 0.5138], [0.1579, -0.0311, -0.4768]], "Huge": [[0.1924, 0.4664, 0.0323], [-0.2991, 0.4102, -0.1349], [0.106, 0.3228, 0.3998], [0.2275, 0.2464, -0.3866], [-0.4758, 0.1645, 0.0305], [0.4424, 0.0911, 0.2713], [-0.2579, 0.013, -0.4375], [-0.2527, -0.0617, 0.429]]}, "Geode": {"Small": [[0.0902, 0.2715, 0.2067]], "Medium": [[0.2051, 0.2317, 0.0797], [-0.2061, 0.0553, -0.2838]], "Large": [[0.211, 0.3853, -0.0607], [-0.2904, 0.2123, -0.148], [0.0721, 0.0719, 0.2633], [0.1416, -0.0168, -0.3511]], "Huge": [[0.1716, 0.4166, 0.046], [-0.1892, 0.3239, -0.1702], [0.0091, 0.187, 0.2449], [0.0903, 0.1712, -0.2955], [-0.356, 0.1241, -0.0354], [0.2152, 0.0489, 0.1922], [-0.0238, 0.009, -0.3732], [-0.1503, -0.0495, 0.3667]]}}]==])
local STAR_SIZE = HttpService:JSONDecode([==[{"Small": 6, "Medium": 12, "Large": 24, "Huge": 45}]==])
local THEMES = HttpService:JSONDecode([==[{"Iron": {"shell": "#3A3A40", "glow": "#FF9A3C", "color": "#9A9AA6"}, "Lava": {"shell": "#1C1412", "glow": "#FFB347", "color": "#FF5A1F"}, "Frost": {"shell": "#B9D4E6", "glow": "#E6FBFF", "color": "#7FD8FF"}, "Geode": {"shell": "#5B4A3E", "glow": "#E3C4FF", "color": "#B06BFF"}}]==])
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
		Shell = { material = Enum.Material.Ice, color = "shell" },
		Accent = { material = Enum.Material.Glass, color = "color", transparency = 0.35 },
		Orbit = { material = Enum.Material.Glass, color = "color", transparency = 0.2 },
	},
	Geode = {
		Shell = { material = Enum.Material.Rock, color = "shell" },
		Accent = { material = Enum.Material.Neon, color = "color" },
		Orbit = { material = Enum.Material.Neon, color = "color" },
	},
}

-- Poświata i cząsteczki (tekstury wbudowane w Roblox — bez uploadu). Ilość rośnie z rozmiarem, nisko dla telefonów.
type Fx = { texture: string, color: string, rate: number, life: NumberRange, speed: NumberRange, size: number, accel: number, transparency: number, emission: number }
local FX: { [string]: Fx } = {
	Iron = { texture = "rbxasset://textures/particles/smoke_main.dds", color = "shell", rate = 3, life = NumberRange.new(2, 3.5), speed = NumberRange.new(0.5, 1.5), size = 0.35, accel = 1.5, transparency = 0.55, emission = 0 },
	Lava = { texture = "rbxasset://textures/particles/fire_sparks_main.dds", color = "color", rate = 8, life = NumberRange.new(1, 2), speed = NumberRange.new(1, 3), size = 0.12, accel = 3, transparency = 0, emission = 1 },
	Frost = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = "glow", rate = 6, life = NumberRange.new(1.5, 3), speed = NumberRange.new(0.2, 0.8), size = 0.1, accel = -0.3, transparency = 0.1, emission = 1 },
	Geode = { texture = "rbxasset://textures/particles/sparkles_main.dds", color = "color", rate = 6, life = NumberRange.new(1.5, 3), speed = NumberRange.new(0.3, 1), size = 0.1, accel = 0.4, transparency = 0, emission = 1 },
}
local SIZE_RATE = { Small = 1, Medium = 1.5, Large = 2.5, Huge = 4 }

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
		local ext = shell.Size
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
		model:SetAttribute("Type", typeId)
		model:SetAttribute("Size", size)
		model.Parent = folder
		table.insert(report, string.format("%s/%s: %d czesci, %d stref", typeId, size, #model:GetChildren(), #zonesBySize[size]))
	end
end
return report
