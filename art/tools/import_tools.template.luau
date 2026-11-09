--!strict
-- Szablon importu narzędzi (T11). Plik import_tools.luau generuje art/tools/gen_import.py (wstawia META) — nie edytuj wygenerowanego.
-- Uruchom w Studio (execute_luau, Edit) po wstawieniu FBX art/tools/tools.fbx jako ServerStorage.ToolImport (insert_asset).
-- Wynik: ServerStorage.Tools/<toolId> (Tool z Handle, części na Weld do Handle, atrybuty ToolId/Tier/Exclusive,
-- Grip = punkt chwytu + obrót 180° wokół trzonka, smuga TrailA/TrailB, cząsteczki, PointLight na Glow).
-- Części Spin* mają tag "ToolSpin" i atrybuty SpinAxis/SpinSpeed — kręci je klient (ToolFxController przez Weld.C0).
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VfxIds = require(ReplicatedStorage.Shared.Config.VfxIds) :: any
local META = HttpService:JSONDecode([==[__META__]==])
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
