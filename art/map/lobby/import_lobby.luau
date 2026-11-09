--!strict
-- Szablon importu budynków lobby (T15). Plik import_lobby.luau generuje art/map/gen_import.py z lobby_meta.json.
-- Kroki: build_lobby.py → lobby.fbx → upload (Open Cloud, asset 129737341287677) → insert_asset do ServerStorage
-- jako „LobbyImport” → ten skrypt (execute_luau, Edit).
-- Dla każdej stacji Workspace.Map.Lobby.Stations.<Stacja>: stare bryły z blockoutu (Body, Roof, Stripe, Door,
-- DoorFrame, Pillar / Ring, Plinth) → Model „Building” z MeshPartów; zostają PromptAnchor, Sign (przeniesiony na
-- fasadę), VipZone/VipBorder/VipSign*, Core portalu. Front budynku stoi tam, gdzie front blockoutu (prompt bez zmian).

local HttpService = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local META = HttpService:JSONDecode([==[{"ToolShop":{"sign":{"center":[0,18.4,-14.55],"size":[29.64,5.5,0.8]},"footprint":[46,36],"parts":{"Base":{"material":"Concrete","color":"#45435E","transparency":0,"center":[-0.0,0.6,0.0],"size":[46.0,1.2,36.0],"collide":true},"Glow":{"material":"Neon","color":"#FFAA3C","transparency":0,"center":[-0.0,22.0122,-1.115],"size":[46.24,42.2244,38.47],"collide":false},"Shell":{"material":"Metal","color":"#C9CDE0","transparency":0,"center":[-0.0,22.152,0.0],"size":[38.0,41.904,28.0],"collide":true},"Frame":{"material":"Metal","color":"#3B3F5E","transparency":0,"center":[-0.0,14.0,-2.525],"size":[40.4,26.2,35.45],"collide":false},"Trim":{"material":"DiamondPlate","color":"#262A42","transparency":0,"center":[-0.0,25.4,0.0],"size":[35.0,2.2,25.0],"collide":false},"Glass":{"material":"Glass","color":"#86D8FF","transparency":0.45,"center":[-0.0,8.03,-3.045],"size":[38.6,13.66,22.41],"collide":false},"Accent":{"material":"Metal","color":"#8C5D21","transparency":0,"center":[-0.0,34.4,0.0],"size":[9.6685,13.0329,1.3],"collide":false}}},"Garage":{"sign":{"center":[0,20.2,-16.55],"size":[35.88,5.5,0.8]},"footprint":[54,40],"parts":{"Base":{"material":"Concrete","color":"#45435E","transparency":0,"center":[-0.0,0.6,0.0],"size":[54.0,1.2,40.0],"collide":true},"Glow":{"material":"Neon","color":"#3CC8FF","transparency":0,"center":[-0.0,15.025,-1.115],"size":[54.24,28.25,42.47],"collide":false},"Shell":{"material":"Metal","color":"#C9CDE0","transparency":0,"center":[-0.0,15.1963,0.0],"size":[46.0,27.9925,32.0],"collide":true},"Frame":{"material":"Metal","color":"#3B3F5E","transparency":0,"center":[-0.0,14.4,-2.525],"size":[48.4,27.0,39.45],"collide":false},"Trim":{"material":"DiamondPlate","color":"#262A42","transparency":0,"center":[-0.0,12.25,-0.975],"size":[43.0,21.9,30.95],"collide":false},"Glass":{"material":"Glass","color":"#86D8FF","transparency":0.45,"center":[-0.0,13.6,0.0],"size":[46.4,2.4,19.2],"collide":false},"Accent":{"material":"Metal","color":"#216E8C","transparency":0,"center":[14.0,27.3,6.0],"size":[0.3118,2.4,0.36],"collide":false}}},"SellStation":{"sign":{"center":[0,18.4,-14.55],"size":[28.08,5.5,0.8]},"footprint":[44,36],"parts":{"Base":{"material":"Concrete","color":"#45435E","transparency":0,"center":[-0.0,0.6,0.0],"size":[44.0,1.2,36.0],"collide":true},"Glow":{"material":"Neon","color":"#50E678","transparency":0,"center":[-0.0,19.1022,-1.115],"size":[57.4,36.4043,38.47],"collide":false},"Shell":{"material":"Metal","color":"#C9CDE0","transparency":0,"center":[-0.0,18.1,0.0],"size":[36.0,33.8,28.0],"collide":true},"Frame":{"material":"Metal","color":"#3B3F5E","transparency":0,"center":[-0.0,14.525,-2.525],"size":[57.3,27.25,35.45],"collide":false},"Trim":{"material":"DiamondPlate","color":"#262A42","transparency":0,"center":[-0.0,23.6,0.0],"size":[33.0,0.6,25.0],"collide":false},"Glass":{"material":"Glass","color":"#86D8FF","transparency":0.45,"center":[-0.0,7.765,-3.045],"size":[36.6,13.13,22.41],"collide":false},"Accent":{"material":"Metal","color":"#2C7E42","transparency":0,"center":[-0.0,18.9,4.0],"size":[57.0,35.4,14.0],"collide":true}}},"Upgrades":{"sign":{"center":[0,18.4,-13.55],"size":[26.52,5.5,0.8]},"footprint":[42,34],"parts":{"Base":{"material":"Concrete","color":"#45435E","transparency":0,"center":[-0.0,0.6,0.0],"size":[42.0,1.2,34.0],"collide":true},"Glow":{"material":"Neon","color":"#FFDC50","transparency":0,"center":[-0.0,21.725,-1.115],"size":[42.24,41.65,36.47],"collide":false},"Shell":{"material":"Metal","color":"#C9CDE0","transparency":0,"center":[-0.0,18.55,0.0],"size":[34.0,34.7,26.0],"collide":true},"Frame":{"material":"Metal","color":"#3B3F5E","transparency":0,"center":[-0.0,21.3,-2.525],"size":[36.4,40.8,33.45],"collide":false},"Trim":{"material":"DiamondPlate","color":"#262A42","transparency":0,"center":[-0.0,23.3,0.0],"size":[31.0,2.0,23.0],"collide":false},"Glass":{"material":"Glass","color":"#86D8FF","transparency":0.45,"center":[-0.0,7.5,-2.765],"size":[34.6,12.6,20.97],"collide":false}}},"IndexHall":{"sign":{"center":[0,18.4,-15.55],"size":[31.2,5.5,0.8]},"footprint":[48,38],"parts":{"Base":{"material":"Concrete","color":"#45435E","transparency":0,"center":[-0.0,0.6,0.0],"size":[48.0,1.2,38.0],"collide":true},"Glow":{"material":"Neon","color":"#AA78FF","transparency":0,"center":[-0.0,13.65,-1.24],"size":[48.24,25.5,40.72],"collide":false},"Shell":{"material":"Metal","color":"#C9CDE0","transparency":0,"center":[-0.0,12.2,0.0],"size":[40.0,22.0,30.0],"collide":true},"Frame":{"material":"Metal","color":"#3B3F5E","transparency":0,"center":[-0.0,17.7702,-2.6],"size":[42.4,33.7405,37.6],"collide":false},"Trim":{"material":"DiamondPlate","color":"#262A42","transparency":0,"center":[-0.0,24.6,0.0],"size":[37.0,0.6,27.0],"collide":false},"Glass":{"material":"Glass","color":"#86D8FF","transparency":0.45,"center":[-0.0,17.775,-1.125],"size":[40.6,33.15,28.25],"collide":false},"Accent":{"material":"Metal","color":"#5D428C","transparency":0,"center":[-0.0,34.975,-0.2854],"size":[4.4,9.9957,12.0094],"collide":false}}},"RobuxShop":{"sign":{"center":[0,18.4,-15.55],"size":[31.2,5.5,0.8]},"footprint":[48,38],"parts":{"Base":{"material":"Concrete","color":"#45435E","transparency":0,"center":[-0.0,0.6,0.0],"size":[48.0,1.2,38.0],"collide":true},"Glow":{"material":"Neon","color":"#FF5AC8","transparency":0,"center":[-0.0,19.2875,-1.115],"size":[48.24,36.775,40.47],"collide":false},"Shell":{"material":"Metal","color":"#C9CDE0","transparency":0,"center":[-0.0,12.7,0.0],"size":[40.0,23.0,30.0],"collide":true},"Frame":{"material":"Metal","color":"#3B3F5E","transparency":0,"center":[-0.0,14.6,-2.525],"size":[42.4,27.4,37.45],"collide":false},"Trim":{"material":"DiamondPlate","color":"#262A42","transparency":0,"center":[-0.0,25.6,0.0],"size":[37.0,0.6,27.0],"collide":false},"Glass":{"material":"Glass","color":"#86D8FF","transparency":0.45,"center":[-0.0,19.56,-3.325],"size":[40.6,36.72,23.85],"collide":false}}},"DailyCodes":{"sign":{"center":[0,18.4,-13.55],"size":[24.96,5.5,0.8]},"footprint":[40,34],"parts":{"Base":{"material":"Concrete","color":"#45435E","transparency":0,"center":[-0.0,0.6,0.0],"size":[40.0,1.2,34.0],"collide":true},"Glow":{"material":"Neon","color":"#3CF0D2","transparency":0,"center":[-0.0,17.3182,-1.115],"size":[40.24,32.8364,36.47],"collide":false},"Shell":{"material":"Metal","color":"#C9CDE0","transparency":0,"center":[-0.0,15.1642,0.0],"size":[32.0,27.9284,26.0],"collide":true},"Frame":{"material":"Metal","color":"#3B3F5E","transparency":0,"center":[-0.0,13.5,-2.525],"size":[34.4,25.2,33.45],"collide":false},"Trim":{"material":"DiamondPlate","color":"#262A42","transparency":0,"center":[-0.0,22.6,0.0],"size":[29.0,0.6,23.0],"collide":false},"Glass":{"material":"Glass","color":"#86D8FF","transparency":0.45,"center":[-0.0,7.5,-2.765],"size":[32.6,12.6,20.97],"collide":false},"Accent":{"material":"Metal","color":"#218473","transparency":0,"center":[0.1471,28.975,0.865],"size":[18.6059,5.75,6.63],"collide":false}}},"RebirthPortal":{"sign":{"center":[0,32.0,0],"size":[16,4,0.8]},"core":[0,15.5,0],"footprint":[28,14],"parts":{"Base":{"material":"Concrete","color":"#45435E","transparency":0,"center":[-0.0,1.2,0.0],"size":[28.0,2.4,14.0],"collide":true},"Glow":{"material":"Neon","color":"#FF5AC8","transparency":0,"center":[-0.0,15.26,0.0],"size":[28.24,28.62,14.24],"collide":false},"Shell":{"material":"Metal","color":"#C9CDE0","transparency":0,"center":[-0.0,15.5,0.0],"size":[27.4,27.4,3.4],"collide":true},"Frame":{"material":"Metal","color":"#3B3F5E","transparency":0,"center":[-0.0,15.5,0.0],"size":[34.2,26.4,4.4],"collide":false},"Accent":{"material":"Metal","color":"#8C316E","transparency":0,"center":[-0.0,15.0,0.0],"size":[35.0,1.2,4.8],"collide":false}}}}]==])

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
