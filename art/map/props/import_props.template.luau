--!strict
-- Szablon importu propsów mapy (T15). Plik import_props.luau generuje art/map/gen_import.py z props_meta.json.
-- Kroki: build_props.py → props.fbx → upload (Open Cloud, asset 81577794889258) → insert_asset do ServerStorage
-- jako „PropsImport” → ten skrypt (execute_luau, Edit) → tools/studio/T15_props.luau (rozmieszczenie).
-- Wynik: ServerStorage.MapProps.<Nazwa> — Model z MeshPartów, pivot = środek podstawy (y = 0), atrybuty Category
-- (small/medium/large/landmark) i Biome; latarnie dostają PointLight, komin lawy dym, wrak iskry.

local HttpService = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local META = HttpService:JSONDecode([==[__META__]==])

local src = SS:FindFirstChild("PropsImport")
assert(src, "Brak ServerStorage.PropsImport (insert_asset 81577794889258)")

local old = SS:FindFirstChild("MapProps")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "MapProps"

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function emitter(parent: Instance, kind: string)
	local e = Instance.new("ParticleEmitter")
	e.Name = kind
	e.LightEmission = if kind == "Smoke" then 0.2 else 1
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	if kind == "Smoke" then
		e.Color = ColorSequence.new(Color3.fromRGB(90, 70, 80), Color3.fromRGB(40, 34, 44))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(4, 6)
		e.Rate = 3
		e.Speed = NumberRange.new(4, 7)
		e.SpreadAngle = Vector2.new(12, 12)
		e.Acceleration = Vector3.new(1.5, 1, 0)
	else
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(120, 240, 255))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.4, 0.9)
		e.Rate = 6
		e.Speed = NumberRange.new(6, 12)
		e.SpreadAngle = Vector2.new(40, 40)
		e.Acceleration = Vector3.new(0, -30, 0)
	end
	e.Parent = parent
end

local count = 0
for name, m in META do
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Category", m.category)
	if m.biome then
		model:SetAttribute("Biome", m.biome)
	end
	local primary: BasePart? = nil
	for partName, p in m.parts do
		local mp = src:FindFirstChild(name .. "_" .. partName) :: MeshPart?
		if not mp then
			warn("Brak " .. name .. "_" .. partName)
			continue
		end
		local part = mp:Clone()
		for _, ch in part:GetChildren() do
			ch:Destroy()
		end
		part.Name = partName
		part.Size = v3(p.size)
		part.CFrame = CFrame.new(v3(p.center))
		part.Material = (Enum.Material :: any)[p.material]
		part.Color = Color3.fromHex(p.color)
		part.Transparency = p.transparency
		part.Anchored = true
		part.CanCollide = p.collide
		part.CanQuery = p.collide
		part.CanTouch = false
		part.CastShadow = p.material ~= "Neon" and m.category ~= "small"
		if p.material == "Glass" or p.material == "Ice" then
			part.Reflectance = 0.1
		end
		part.Parent = model
		if partName == "Rock" or (primary == nil and p.collide) then
			primary = part
		end
	end
	model.PrimaryPart = primary or model:FindFirstChildWhichIsA("BasePart")
	model.WorldPivot = CFrame.new(0, 0, 0)
	if m.light then
		local a = Instance.new("Attachment")
		a.Name = "LightPoint"
		local glow = model:FindFirstChild("Glow") :: BasePart
		a.Parent = glow
		a.WorldPosition = v3(m.light)
		local l = Instance.new("PointLight")
		l.Range = 40
		l.Brightness = 2
		l.Color = glow.Color
		l.Shadows = false
		l.Parent = a
	end
	if m.fx then
		local host = model.PrimaryPart :: BasePart
		for kind, pos in m.fx do
			local a = Instance.new("Attachment")
			a.Name = "Fx_" .. kind
			a.Parent = host
			a.WorldPosition = v3(pos)
			emitter(a, if kind == "smoke" then "Smoke" else "Spark")
		end
	end
	model.Parent = folder
	count += 1
end
folder.Parent = SS
return ("MapProps: %d modeli"):format(count)
