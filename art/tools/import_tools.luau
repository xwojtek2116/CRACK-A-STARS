--!strict
-- WYGENEROWANE (T11) z import_tools.template.luau przez art/tools/gen_import.py (wstawia META) — nie edytuj wygenerowanego.
-- Uruchom w Studio (execute_luau, Edit) po wstawieniu FBX art/tools/tools.fbx jako ServerStorage.ToolImport (insert_asset).
-- Wynik: ServerStorage.Tools/<toolId> (Tool z Handle, części na Weld do Handle, atrybuty ToolId/Tier/Exclusive,
-- Grip = punkt chwytu + obrót 180° wokół trzonka, smuga TrailA/TrailB, cząsteczki, PointLight na Glow).
-- Części Spin* mają tag "ToolSpin" i atrybuty SpinAxis/SpinSpeed — kręci je klient (ToolFxController przez Weld.C0).
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VfxIds = require(ReplicatedStorage.Shared.Config.VfxIds) :: any
local META = HttpService:JSONDecode([==[{"stone_pickaxe":{"name":"Stone Pickaxe","tier":1,"exclusive":false,"grip":[0,0,0],"parts":{"Handle":{"material":"Wood","color":"#8A5530","transparency":0,"center":[-0.0,0.935,0.0]},"Grip":{"material":"Leather","color":"#5A3420","transparency":0,"center":[-0.0,0.1,0.0]},"HeadCore":{"material":"Slate","color":"#5E5A6E","transparency":0,"center":[0.0005,2.42,-0.0038]},"Head":{"material":"Slate","color":"#8C8798","transparency":0,"center":[0.0008,2.3488,-0.1813]},"Wrap":{"material":"Fabric","color":"#C9A66B","transparency":0,"center":[-0.0,2.27,0.0]}}},"iron_hammer":{"name":"Iron Hammer","tier":2,"exclusive":false,"grip":[0,0,0],"parts":{"Handle":{"material":"Wood","color":"#5C3519","transparency":0,"center":[-0.0,1.075,0.0]},"Grip":{"material":"Leather","color":"#5A3420","transparency":0,"center":[-0.0,0.1,0.0]},"Accent":{"material":"Metal","color":"#4E576A","transparency":0,"center":[-0.0,1.3593,0.0]},"Head":{"material":"Metal","color":"#A7B0C0","transparency":0,"center":[-0.0,2.88,0.0]}}},"crystal_axe":{"name":"Crystal Axe","tier":3,"exclusive":false,"grip":[0,0,0],"parts":{"Handle":{"material":"Metal","color":"#3A2466","transparency":0,"center":[-0.0,1.375,0.0]},"Grip":{"material":"Metal","color":"#2C3142","transparency":0,"center":[-0.0,0.075,0.0]},"Accent":{"material":"Metal","color":"#C9D2DE","transparency":0,"center":[-0.0,2.0275,0.0]},"Crystal":{"material":"Glass","color":"#4FC8FF","transparency":0.15,"center":[-0.0,1.485,-0.35]},"Glow":{"material":"Neon","color":"#8FEAFF","transparency":0,"center":[-0.0,3.195,-0.9068]}}},"plasma_saw":{"name":"Plasma Saw","tier":4,"exclusive":false,"grip":[0,0,0],"parts":{"Handle":{"material":"Metal","color":"#2C3142","transparency":0,"center":[-0.0,0.06,0.0]},"Grip":{"material":"Leather","color":"#24202C","transparency":0,"center":[-0.0,0.075,0.0]},"Accent":{"material":"Metal","color":"#1C2030","transparency":0,"center":[-0.0138,1.8896,0.2701]},"Body":{"material":"Metal","color":"#C9D2DE","transparency":0,"center":[-0.0,1.475,0.0]},"Glow":{"material":"Neon","color":"#3DF2FF","transparency":0,"center":[-0.0,2.6364,0.0]},"SpinDisc":{"material":"Metal","color":"#C9D2DE","transparency":0,"center":[-0.0,3.33,0.0],"spin":{"axis":[1.0,0.0,0.0],"speed":420}}}},"laser_sword":{"name":"Laser Sword","tier":5,"exclusive":false,"grip":[0,0,0],"trail":{"a":[0,1.3,0],"b":[0,4.15,0],"colors":["#E8FFFF","#3DF2FF"],"lifetime":0.16,"width":1.0},"parts":{"Handle":{"material":"Metal","color":"#C9D2DE","transparency":0,"center":[-0.0,0.1,0.0]},"Grip":{"material":"Metal","color":"#2C3142","transparency":0,"center":[-0.0,0.1,0.0]},"Accent":{"material":"Metal","color":"#2C3142","transparency":0,"center":[-0.0,0.15,0.0]},"Glow":{"material":"Neon","color":"#3DF2FF","transparency":0,"center":[-0.0,0.105,0.0]},"Beam":{"material":"Neon","color":"#E8FFFF","transparency":0,"center":[-0.0,2.65,0.0]},"BeamGlow":{"material":"Neon","color":"#3DF2FF","transparency":0.6,"center":[-0.0,2.7,0.0]}}},"gravity_hammer":{"name":"Gravity Hammer","tier":6,"exclusive":false,"grip":[0,0,0],"trail":{"a":[0,3.0,0],"b":[0,4.8,0],"colors":["#E08BFF","#6A2FD0"],"lifetime":0.18,"width":1.2},"particles":[{"part":"Body","color":"#C77BFF","rate":6,"size":0.25,"speed":0.6,"tex":"spark","life":1.0}],"parts":{"Handle":{"material":"Metal","color":"#2C3142","transparency":0,"center":[-0.0,1.6,0.0]},"Grip":{"material":"Fabric","color":"#5A2EA6","transparency":0,"center":[-0.0,0.1,0.0]},"Accent":{"material":"Metal","color":"#1C2030","transparency":0,"center":[-0.0,2.1262,0.0]},"Glow":{"material":"Neon","color":"#B45CFF","transparency":0,"center":[-0.0,1.89,0.0]},"Body":{"material":"Metal","color":"#4B2A8C","transparency":0,"center":[-0.0,4.28,0.0]},"SpinA":{"material":"Neon","color":"#E08BFF","transparency":0,"center":[-0.0174,4.2783,-0.34],"spin":{"axis":[0.0,0.0,1.0],"speed":80}},"SpinB":{"material":"Neon","color":"#E08BFF","transparency":0,"center":[-0.0016,4.2664,0.34],"spin":{"axis":[0.0,0.0,1.0],"speed":-110}}}},"nova_cannon":{"name":"Nova Cannon","tier":7,"exclusive":false,"grip":[0,0,0],"trail":{"a":[0,3.6,0],"b":[0,4.97,-1.4],"colors":["#FFE27A","#FF8A1E"],"lifetime":0.2,"width":1.2},"particles":[{"part":"Glow","color":"#FFB23D","rate":8,"size":0.22,"speed":0.8,"tex":"spark","life":0.8}],"parts":{"Handle":{"material":"Metal","color":"#2C3142","transparency":0,"center":[-0.0,1.975,0.0]},"Grip":{"material":"Leather","color":"#24202C","transparency":0,"center":[-0.0,0.1,0.0]},"Accent":{"material":"Metal","color":"#FFC23D","transparency":0,"center":[-0.0,2.385,-0.16]},"Body":{"material":"Metal","color":"#1C2030","transparency":0,"center":[-0.0,4.97,-0.575]},"Glow":{"material":"Neon","color":"#FF8A1E","transparency":0,"center":[-0.0,4.97,-1.525]},"Glass":{"material":"Glass","color":"#FFD9A0","transparency":0.55,"center":[-0.0,4.97,0.5]},"Core":{"material":"Neon","color":"#FFE27A","transparency":0,"center":[-0.0,4.97,0.5]}}},"starbreaker":{"name":"Starbreaker","tier":8,"exclusive":false,"grip":[0,0,0],"trail":{"a":[0,3.6,0],"b":[0,5.9,0],"colors":["#FFD45C","#D07CFF"],"lifetime":0.22,"width":1.4},"particles":[{"part":"Core","color":"#FFE27A","rate":10,"size":0.25,"speed":1.0,"tex":"glint","life":1.0}],"parts":{"Handle":{"material":"Metal","color":"#FFC23D","transparency":0,"center":[-0.0,1.9,0.0]},"Grip":{"material":"Fabric","color":"#3B1A6E","transparency":0,"center":[-0.0,1.11,0.0]},"Accent":{"material":"Metal","color":"#FFC23D","transparency":0,"center":[-0.0,2.4999,-0.1496]},"Core":{"material":"Neon","color":"#FFE27A","transparency":0,"center":[-0.0,2.165,0.0]},"Blade":{"material":"Glass","color":"#7A35F0","transparency":0.0,"center":[-0.0,4.75,-0.1892]},"Glow":{"material":"Neon","color":"#D07CFF","transparency":0,"center":[-0.0,4.75,-0.1969]}}},"comet_blade":{"name":"Comet Blade","exclusive":true,"grip":[0,0,0],"trail":{"a":[0,1.3,0],"b":[0,4.1,0.5],"colors":["#FFFFFF","#9FF6FF"],"lifetime":0.35,"width":1.3},"particles":[{"part":"Blade","color":"#CFF8FF","rate":8,"size":0.2,"speed":0.4,"tex":"glint","life":1.2}],"parts":{"Handle":{"material":"Metal","color":"#1F2A4A","transparency":0,"center":[-0.0,0.125,0.0]},"Grip":{"material":"Fabric","color":"#6FB6FF","transparency":0,"center":[-0.0,0.11,0.0]},"Glow":{"material":"Neon","color":"#9FF6FF","transparency":0,"center":[-0.0,1.76,0.175]},"Accent":{"material":"Metal","color":"#DDE8FF","transparency":0,"center":[-0.0,0.79,0.0]},"Blade":{"material":"Glass","color":"#BDEBFF","transparency":0.25,"center":[-0.0,2.36,0.3157]}}},"galaxy_hammer":{"name":"Galaxy Hammer","exclusive":true,"grip":[0,0,0],"trail":{"a":[0,3.3,0],"b":[0,5.0,0],"colors":["#FF5CE1","#7A8CFF"],"lifetime":0.2,"width":1.2},"particles":[{"part":"Glass","color":"#FFB8F5","rate":6,"size":0.18,"speed":0.3,"tex":"glint","life":1.4}],"parts":{"Handle":{"material":"Metal","color":"#1A1530","transparency":0,"center":[-0.0,1.675,0.0]},"Grip":{"material":"Fabric","color":"#3B1A6E","transparency":0,"center":[-0.0,0.1,0.0]},"Accent":{"material":"Metal","color":"#FFC23D","transparency":0,"center":[-0.0,2.136,0.0]},"Glow":{"material":"Neon","color":"#FFFFFF","transparency":0,"center":[-0.0,1.865,0.0]},"Glass":{"material":"Glass","color":"#BFD4FF","transparency":0.6,"center":[-0.0,4.45,0.0]},"Body":{"material":"Metal","color":"#1A1530","transparency":0,"center":[-0.0,4.2412,0.0]},"SpinArms":{"material":"Neon","color":"#FF5CE1","transparency":0,"center":[-0.0,4.45,0.0],"spin":{"axis":[1.0,0.0,0.0],"speed":60}},"SpinStars":{"material":"Neon","color":"#7A8CFF","transparency":0,"center":[0.0014,4.5104,-0.0146],"spin":{"axis":[1.0,0.0,0.0],"speed":60}}}}}]==])
local TEX = { spark = VfxIds.SPARK, glint = VfxIds.GLINT }

local import = ServerStorage:FindFirstChild("ToolImport")
assert(import, "Brak ServerStorage.ToolImport — najpierw insert_asset tools.fbx")
local root = ServerStorage:FindFirstChild("Tools") or Instance.new("Folder")
root.Name = "Tools"
root.Parent = ServerStorage

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local report = {}
for toolId, m in META do
	local srcHandle = import:FindFirstChild(toolId .. "_Handle", true) :: BasePart?
	if not srcHandle then
		table.insert(report, toolId .. ": brak Handle")
		continue
	end
	local old = root:FindFirstChild(toolId)
	if old then
		old:Destroy()
	end
	local handleCenter = v3(m.parts.Handle.center)
	local base = srcHandle.CFrame -- wszystkie części mają tę samą orientację co Handle

	local tool = Instance.new("Tool")
	tool.Name = toolId
	tool.ToolTip = m.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ToolId", toolId)
	tool:SetAttribute("DisplayName", m.name)
	if m.tier then
		tool:SetAttribute("Tier", m.tier)
	end
	tool:SetAttribute("Exclusive", m.exclusive == true)
	-- Dłoń na środku owijki (część Grip; Starbreaker ma ją wyżej, nad głowicą rękojeści), oś trzonka.
	-- W układzie Handle: punkt chwytu − środek Handle. Model uderza w −Z, a w ręku R15 przód postaci to +Z
	-- Handle → obrót 180° wokół osi trzonka (sprawdzone w Play: obuch do przodu, Feel.swing: zamach za bark, cios przed siebie).
	local gripPoint = v3(m.grip)
	if m.parts.Grip then
		gripPoint = Vector3.new(gripPoint.X, m.parts.Grip.center[2], gripPoint.Z)
	end
	tool.Grip = CFrame.new(gripPoint - handleCenter) * CFrame.Angles(0, math.pi, 0)

	local handle: BasePart
	local maxErr = 0
	for partName, p in m.parts do
		local src = import:FindFirstChild(toolId .. "_" .. partName, true) :: BasePart?
		if not src then
			table.insert(report, toolId .. ": brak " .. partName)
			continue
		end
		local part = src:Clone()
		part.Name = partName
		local ok, mat = pcall(function()
			return (Enum.Material :: any)[p.material]
		end)
		part.Material = if ok and mat then mat else Enum.Material.SmoothPlastic
		part.Color = Color3.fromHex(p.color)
		part.Transparency = p.transparency or 0
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = part.Material ~= Enum.Material.Neon and part.Material ~= Enum.Material.Glass
		local rel = base:ToObjectSpace(src.CFrame)
		-- kontrola osi: środek części względem Handle musi zgadzać się z meta
		maxErr = math.max(maxErr, (rel.Position - (v3(p.center) - handleCenter)).Magnitude)
		part.CFrame = rel -- Handle w (0,0,0) bez obrotu
		if partName == "Handle" then
			handle = part
		end
		if p.spin then
			part:SetAttribute("SpinAxis", v3(p.spin.axis))
			part:SetAttribute("SpinSpeed", p.spin.speed)
			CollectionService:AddTag(part, "ToolSpin")
		end
		part.Parent = tool
	end
	assert(handle, toolId .. ": brak Handle")
	for _, part in tool:GetChildren() do
		if part:IsA("BasePart") and part ~= handle then
			-- Weld (nie WeldConstraint), żeby klient mógł kręcić części Spin* przez C0.
			local w = Instance.new("Weld")
			w.Name = "ToolWeld"
			w.Part0 = handle
			w.Part1 = part
			w.C0 = handle.CFrame:ToObjectSpace(part.CFrame)
			w.Parent = part
		end
	end

	-- Smuga przy ruchu (tier 5+ i ekskluzywy).
	if m.trail then
		local tr = m.trail
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailA"
		a0.Position = v3(tr.a) - handleCenter
		a0.Parent = handle
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailB"
		a1.Position = v3(tr.b) - handleCenter
		a1.Parent = handle
		local t = Instance.new("Trail")
		t.Name = "SwingTrail"
		t.Attachment0 = a0
		t.Attachment1 = a1
		t.Color = ColorSequence.new(Color3.fromHex(tr.colors[1]), Color3.fromHex(tr.colors[2]))
		t.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.6, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		t.WidthScale = NumberSequence.new(1, 0.3)
		t.Lifetime = tr.lifetime
		t.MinLength = 0.05
		t.LightEmission = 1
		t.LightInfluence = 0
		t.FaceCamera = false
		t.Parent = handle
	end

	-- Cząsteczki (tekstury VFX gry).
	for i, pe in m.particles or {} do
		local host = tool:FindFirstChild(pe.part) :: BasePart?
		if not host then
			continue
		end
		local e = Instance.new("ParticleEmitter")
		e.Name = "ToolSparkle" .. i
		e.Texture = TEX[pe.tex] or VfxIds.SPARK
		e.Color = ColorSequence.new(Color3.fromHex(pe.color))
		e.Rate = pe.rate
		e.Lifetime = NumberRange.new(pe.life * 0.7, pe.life)
		e.Speed = NumberRange.new(pe.speed * 0.5, pe.speed)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.25, pe.size),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Parent = host
	end

	-- Poświata w kolorze motywu (od tieru 3 — tier 1-2 nie mają części Glow).
	local glow = tool:FindFirstChild("Glow") :: BasePart?
	if glow and glow.Material == Enum.Material.Neon then
		local l = Instance.new("PointLight")
		l.Name = "ToolGlow"
		l.Color = glow.Color
		l.Brightness = 1.2
		l.Range = 6
		l.Shadows = false
		l.Parent = glow
	end

	tool.Parent = root
	table.insert(report, string.format("%s: %d części, błąd osi %.3f", toolId, #tool:GetChildren(), maxErr))
end
table.sort(report)
return table.concat(report, "\n")
