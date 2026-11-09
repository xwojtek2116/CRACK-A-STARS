--!strict
-- Szablon importu budynków lobby (T15). Plik import_lobby.luau generuje art/map/gen_import.py z lobby_meta.json.
-- Kroki: build_lobby.py → lobby.fbx → upload (Open Cloud, asset 129737341287677) → insert_asset do ServerStorage
-- jako „LobbyImport” → ten skrypt (execute_luau, Edit).
-- Dla każdej stacji Workspace.Map.Lobby.Stations.<Stacja>: stare bryły z blockoutu (Body, Roof, Stripe, Door,
-- DoorFrame, Pillar / Ring, Plinth) → Model „Building” z MeshPartów; zostają PromptAnchor, Sign (przeniesiony na
-- fasadę), VipZone/VipBorder/VipSign*, Core portalu. Front budynku stoi tam, gdzie front blockoutu (prompt bez zmian).

local HttpService = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local META = HttpService:JSONDecode([==[__META__]==])

local src = SS:FindFirstChild("LobbyImport")
assert(src, "Brak ServerStorage.LobbyImport (insert_asset 129737341287677)")
local stations = workspace.Map.Lobby.Stations

local OLD = { Body = true, Roof = true, Stripe = true, Door = true, DoorFrame = true, Pillar = true, Ring = true, Plinth = true }

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-4 then f.Unit else Vector3.new(0, 0, -1)
end

local report = {}
for name, m in META do
	local st = stations:FindFirstChild(name)
	if not st then
		table.insert(report, name .. ": brak stacji")
		continue
	end
	-- położenie: front budynku = front blockoutu
	local target: CFrame
	local body = st:FindFirstChild("Body") :: BasePart?
	local prev = st:FindFirstChild("Building") :: Model?
	if prev and prev:GetAttribute("Target") then
		target = prev:GetAttribute("Target") :: CFrame
	elseif body then
		local look = flat(body.CFrame.LookVector)
		local floorY = body.Position.Y - body.Size.Y / 2
		local front = Vector3.new(body.Position.X, floorY, body.Position.Z) + look * (body.Size.Z / 2)
		local depth = m.parts.Shell.size[3]
		local c = front - look * (depth / 2)
		target = CFrame.lookAt(c, c + look)
	else
		-- portal: środek cokołu, przodem do środka lobby
		local plinth = st:FindFirstChild("Plinth") :: BasePart?
		local core = st:FindFirstChild("Core") :: BasePart?
		local ref = plinth or core
		assert(ref, name .. ": brak Plinth/Core")
		local floorY = if plinth then plinth.Position.Y - plinth.Size.Y / 2 else 20.4
		local p = Vector3.new(ref.Position.X, floorY, ref.Position.Z)
		local look = flat(-p)
		target = CFrame.lookAt(p, p + look)
	end
	if prev then
		prev:Destroy()
	end
	for _, c in st:GetChildren() do
		if OLD[c.Name] then
			c:Destroy()
		end
	end
	local model = Instance.new("Model")
	model.Name = "Building"
	model:SetAttribute("Target", target)
	local tris = 0
	for partName, p in m.parts do
		local mp = src:FindFirstChild(name .. "_" .. partName) :: MeshPart?
		if not mp then
			table.insert(report, name .. "_" .. partName .. ": brak w imporcie")
			continue
		end
		local part = mp:Clone()
		for _, ch in part:GetChildren() do
			ch:Destroy()
		end
		part.Name = partName
		part.Size = v3(p.size)
		part.CFrame = target * CFrame.new(v3(p.center))
		part.Material = (Enum.Material :: any)[p.material]
		part.Color = Color3.fromHex(p.color)
		part.Transparency = p.transparency
		part.Anchored = true
		part.CanCollide = p.collide
		part.CanQuery = p.collide
		part.CanTouch = false
		part.CastShadow = p.material ~= "Neon" and p.material ~= "Glass"
		if p.material == "Metal" or p.material == "DiamondPlate" then
			part.Reflectance = 0.05
		end
		part.Parent = model
	end
	model.PrimaryPart = model:FindFirstChild("Shell") :: BasePart?
	model.Parent = st
	-- niewidzialna kotwica „Body” (zgodność z ToolService: witryna liczy front z Body.CFrame.LookVector i Size.Z)
	local shellSize = v3(m.parts.Shell.size)
	if m.parts.Shell and not m.core then
		local anchor = Instance.new("Part")
		anchor.Name = "Body"
		local h = 24
		anchor.Size = Vector3.new(shellSize.X, h, shellSize.Z)
		anchor.CFrame = target * CFrame.new(0, h / 2, 0)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Parent = st
	end
	-- szyld na fasadę
	local sign = st:FindFirstChild("Sign") :: BasePart?
	if sign and m.sign then
		sign.Size = v3(m.sign.size)
		sign.CFrame = target * CFrame.new(v3(m.sign.center))
		sign.Color = Color3.fromRGB(18, 18, 30)
	end
	-- rdzeń portalu w środek pierścienia
	local core = st:FindFirstChild("Core") :: BasePart?
	if core and m.core then
		local rel = core.CFrame - core.Position
		-- tafla portalu: okrągła (walec wzdłuż X = oś przód–tył), mieści się w wewnętrznej krawędzi pierścienia
		if core:IsA("Part") then
			core.Shape = Enum.PartType.Cylinder
			core.Size = Vector3.new(0.6, 20.4, 20.4)
		end
		core.CFrame = CFrame.new((target * CFrame.new(v3(m.core))).Position) * rel
	end
	st.PrimaryPart = model.PrimaryPart
	table.insert(report, ("%s: %d części"):format(name, #model:GetChildren()))
end
return table.concat(report, "\n")
