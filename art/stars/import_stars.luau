--!strict
-- WYGENEROWANE przez art/stars/build_star.py — nie edytuj ręcznie.
-- Uruchom w Studio (execute_luau, Edit) po wstawieniu modeli FBX (insert_asset) jako
-- ServerStorage.StarImport.<Rodzaj> (Model z MeshPartami `<Rozmiar>_<Część>`).
-- Wynik: ServerStorage.Stars/<Rodzaj>/<Rozmiar> (Model, PrimaryPart = Shell, Attachmenty Zone_N na Shell).
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

-- Dane wbudowane przy generowaniu (Stars.json → size, Themes.json → kolory), bo Config w Studio może być nieświeży.
local ZONES = HttpService:JSONDecode([==[{"Iron": {"Small": [[0.118, 0.2901, 0.2318]], "Medium": [[0.2826, 0.2879, -0.0811], [-0.2687, 0.0494, -0.3312]], "Large": [[0.1473, 0.3007, 0.0556], [-0.2746, 0.2325, -0.1982], [-0.0286, 0.1167, 0.398], [0.2091, -0.0042, -0.3411]], "Huge": [[0.1283, 0.3337, -0.0193], [-0.1936, 0.2906, -0.1494], [0.0399, 0.2177, 0.2619], [0.1502, 0.1794, -0.2944], [-0.406, 0.1632, 0.2471], [0.3448, 0.0809, 0.2735], [-0.2441, 0.0124, -0.3842], [-0.0819, -0.0472, 0.3726]]}, "Lava": {"Small": [[0.1391, 0.3489, 0.2767]], "Medium": [[0.3219, 0.3446, 0.0814], [-0.3742, 0.0375, -0.2895]], "Large": [[0.2535, 0.425, -0.0178], [-0.2021, 0.2496, -0.309], [0.2116, 0.1359, 0.4331], [0.1442, -0.0145, -0.4733]], "Huge": [[0.2006, 0.4893, -0.0353], [-0.2407, 0.3588, -0.1696], [0.0734, 0.3169, 0.3831], [0.187, 0.1982, -0.323], [-0.4764, 0.1677, -0.1017], [0.3682, 0.0771, 0.2251], [0.0338, 0.0116, -0.4639], [-0.0727, -0.0645, 0.5009]]}, "Frost": {"Small": [[0.1456, 0.3714, 0.3051]], "Medium": [[0.3356, 0.355, 0.0834], [-0.4543, 0.0516, -0.2503]], "Large": [[0.2828, 0.4424, -0.0237], [-0.3587, 0.2784, -0.2102], [-0.0471, 0.1273, 0.5129], [0.452, -0.0291, -0.2478]], "Huge": [[0.1983, 0.4698, -0.0136], [-0.2101, 0.3971, -0.2482], [0.096, 0.312, 0.3856], [0.3666, 0.2356, -0.2586], [-0.4467, 0.162, 0.1837], [0.4675, 0.088, 0.2442], [-0.259, 0.0081, -0.4558], [-0.3249, -0.0693, 0.3898]]}, "Geode": {"Small": [[0.0906, 0.269, 0.2109]], "Medium": [[0.2789, 0.2958, -0.0692], [-0.3191, 0.0553, -0.194]], "Large": [[0.2225, 0.3835, -0.0058], [-0.1842, 0.221, -0.2787], [0.0782, 0.0708, 0.2591], [0.2299, -0.018, -0.3001]], "Huge": [[0.1674, 0.4276, -0.0604], [-0.2033, 0.324, -0.1588], [-0.0333, 0.1841, 0.2349], [0.1771, 0.1794, -0.2806], [-0.3665, 0.1261, 0.013], [0.2392, 0.048, 0.1551], [-0.1149, 0.0076, -0.3303], [-0.0503, -0.0374, 0.2874]]}}]==])
local STAR_SIZE = HttpService:JSONDecode([==[{"Small": 6, "Medium": 12, "Large": 24, "Huge": 45}]==])
local THEMES = HttpService:JSONDecode([==[{"Iron": {"shell": "#3A3A40", "glow": "#FF9A3C", "color": "#9A9AA6"}, "Lava": {"shell": "#1C1412", "glow": "#FFB347", "color": "#FF5A1F"}, "Frost": {"shell": "#B9D4E6", "glow": "#E6FBFF", "color": "#7FD8FF"}, "Geode": {"shell": "#5B4A3E", "glow": "#E3C4FF", "color": "#B06BFF"}}]==])
local SIZES = { "Small", "Medium", "Large", "Huge" }

local MATERIAL = {
	Iron = Enum.Material.CorrodedMetal,
	Lava = Enum.Material.Basalt,
	Frost = Enum.Material.Snow,
	Geode = Enum.Material.Rock,
}
local ACCENT_MATERIAL = {
	Iron = Enum.Material.DiamondPlate,
	Lava = Enum.Material.Neon,
	Frost = Enum.Material.Glass,
	Geode = Enum.Material.Neon,
}

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
				p.CastShadow = role ~= "Core"
				if role == "Shell" then
					p.Material = MATERIAL[typeId]
					p.Color = Color3.fromHex(theme.shell)
				elseif role == "Core" then
					p.Material = Enum.Material.Neon
					p.Color = Color3.fromHex(theme.glow)
				elseif role == "Accent" then
					p.Material = ACCENT_MATERIAL[typeId]
					p.Color = Color3.fromHex(theme.color)
				else
					p.Material = ACCENT_MATERIAL[typeId]
					p.Color = Color3.fromHex(theme.color)
				end
				p.Parent = model
			end
		end
		local shell = model:FindFirstChild("Shell") :: MeshPart?
		if not shell then
			table.insert(report, typeId .. "/" .. size .. ": brak Shell")
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
		model:SetAttribute("Type", typeId)
		model:SetAttribute("Size", size)
		model.Parent = folder
		table.insert(report, string.format("%s/%s: %d czesci, %d stref", typeId, size, #model:GetChildren(), #zonesBySize[size]))
	end
end
return report
