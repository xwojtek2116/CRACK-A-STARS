--!strict
-- T36: generator dużej mapy Crack a Stars — teren r=2000 (Terrain), lobby w centrum, działki r=320,
-- 4 biomy jako ćwiartki, drogi, rampy, granice. Uruchamiany w Studio przez MCP (execute_luau, Edit)
-- jako ModuleScript (ServerStorage.T36MapGen, usuwany po budowie). Deterministyczny: ten sam SEED = ten sam teren.
-- Liczby mapy: Economy.json → map (radius 2000, lobbyRadius 180, plotRadius 320, ceiling 600),
-- Stars.json → landing (minRadius 450, maxRadius 1900).
-- Kąt biomu = atan2(z, x): Lava 0° (+X), Frost 90° (+Z), Crystal 180° (−X), Nebula 270° (−Z).
--
-- Odtworzenie terenu (np. po utracie miejsca): wstaw ten plik jako ModuleScript `ServerStorage.T36MapGen`
-- (execute_luau: Instance.new("ModuleScript"), Source = treść), potem w kontekście Edit:
--   local M = require(game.ServerStorage.T36MapGen)
--   workspace.Terrain:Clear(); M.setMaterialColors()
--   M.buildTerrain(0, 15); M.buildTerrain(16, 31)   -- ~15 s
--   M.buildBoulders(500)
-- Części (Lobby, Biomes, Ramps, Bounds, Plots) są w game/assets/map/blockout.rbxm — wstaw je zamiast
-- ponownego budowania (M.clearOld/buildLobby/movePlots/buildBounds/buildBiomes/buildRamps/buildProps).
-- Na koniec usuń ModuleScript z ServerStorage.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local M = {}

local SEED = 3636
local S = SEED * 0.01371

M.R = 2000
M.CEILING = 600
M.LOBBY_R = 180
M.LOBBY_H = 20
M.FLOOR_Y = 20.4
M.PLOT_R = 320
M.LAND_MIN = 450
M.LAND_MAX = 1900

local FLAT_R = 420
local WILD_R = 640
local BERM_R = 250
local ROAD_HALF = 14
local ROAD_BLEND = 32
local ROAD_END = 1800
local BAND = 120
local TERRAIN_R = 2060
local TERRAIN_SURFACE_OFFSET = 2

M.BIOMES = {
	{ id = "LavaFields", name = "Lava Fields", angle = 0, color = Color3.fromRGB(255, 120, 50) },
	{ id = "FrostCrater", name = "Frost Crater", angle = 90, color = Color3.fromRGB(140, 210, 255) },
	{ id = "CrystalCanyon", name = "Crystal Canyon", angle = 180, color = Color3.fromRGB(90, 255, 220) },
	{ id = "NebulaPlateau", name = "Nebula Plateau", angle = 270, color = Color3.fromRGB(200, 120, 255) },
}

local MAT = Enum.Material
local noise = math.noise
local sqrt, abs, floor, atan2, rad, deg, cos, sin, exp =
	math.sqrt, math.abs, math.floor, math.atan2, math.rad, math.deg, math.cos, math.sin, math.exp

local function clamp01(t: number): number
	return if t < 0 then 0 elseif t > 1 then 1 else t
end
local function smooth(a: number, b: number, x: number): number
	local t = clamp01((x - a) / (b - a))
	return t * t * (3 - 2 * t)
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function fbm(x: number, z: number, scale: number, oct: number, k: number): number
	local sum, amp, f, norm = 0, 1, 1 / scale, 0
	for o = 1, oct do
		sum += noise(x * f + 0.31, z * f + 0.77, S + k * 7.13 + o * 1.71) * amp
		norm += amp
		amp *= 0.5
		f *= 2.03
	end
	return sum / norm
end

local function angleDeg(x: number, z: number): number
	local a = deg(atan2(z, x))
	return if a < 0 then a + 360 else a
end
local function biomeAt(a: number): number
	return floor(((a + 45) % 360) / 90) + 1
end
M.biomeAt = biomeAt
M.angleDeg = angleDeg

-- Wysokość biomów (studs) przed wygaszeniem przy lobby. "Średni" teren: wzgórza 30–80.
local function hLava(x: number, z: number): number
	return 8 + fbm(x, z, 420, 4, 1) * 150
end
local function hFrost(x: number, z: number): number
	return fbm(x, z, 340, 4, 2) * 100
end
local function hCrystal(x: number, z: number): number
	local n = 1 - abs(noise(x / 300 + 0.13, z / 300 + 0.57, S + 31.7))
	n = n * n * n
	return -12 + n * 95 + fbm(x, z, 140, 3, 3) * 30
end
local function hNebula(x: number, z: number): number
	local f = 10 + fbm(x, z, 460, 4, 4) * 170
	local step = 16
	local k = f / step
	local b = floor(k)
	return (b + smooth(0.3, 0.7, k - b)) * step
end
local HF = { hLava, hFrost, hCrystal, hNebula }

-- Drogi wzdłuż osi: 1 +X (Lava), 2 +Z (Frost), 3 −X (Crystal), 4 −Z (Nebula).
local ROAD_DIR = { Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1) }
local function roadLateral(x: number, z: number): (number, number, number)
	local best, along, idx = math.huge, 0, 0
	if x > 0 and abs(z) < best then
		best, along, idx = abs(z), x, 1
	end
	if z > 0 and abs(x) < best then
		best, along, idx = abs(x), z, 2
	end
	if x < 0 and abs(z) < best then
		best, along, idx = abs(z), -x, 3
	end
	if z < 0 and abs(x) < best then
		best, along, idx = abs(x), -z, 4
	end
	return best, along, idx
end

-- Kratery i wulkany (losowane raz, deterministycznie).
type Feature = { kind: string, x: number, z: number, R: number, D: number, biome: number }
local FEATURES: { Feature } = {}
local rng = Random.new(SEED)

local function randomIn(b: number, rMin: number, rMax: number, margin: number): (number?, number?)
	for _ = 1, 60 do
		local a = rad(M.BIOMES[b].angle + rng:NextNumber(-38, 38))
		local r = sqrt(rng:NextNumber(rMin * rMin, rMax * rMax))
		local x, z = r * cos(a), r * sin(a)
		local dl, along = roadLateral(x, z)
		if dl > margin + ROAD_HALF + ROAD_BLEND or along > ROAD_END + 60 then
			return x, z
		end
	end
	return nil, nil
end

do
	-- Wielki Lodowy Krater (punkt orientacyjny biomu Frost), obok drogi.
	local a = rad(90 + 18)
	table.insert(FEATURES, { kind = "crater", x = 1250 * cos(a), z = 1250 * sin(a), R = 220, D = 45, biome = 2 })
	for b = 1, 4 do
		local count = if b == 2 then 24 else 12
		for _ = 1, count do
			local R = if b == 2 then rng:NextNumber(45, 120) else rng:NextNumber(30, 80)
			local D = if b == 2 then rng:NextNumber(14, 32) else rng:NextNumber(8, 20)
			local x, z = randomIn(b, 540, 1840, R * 1.45)
			if x and z then
				table.insert(FEATURES, { kind = "crater", x = x, z = z, R = R, D = D, biome = b })
			end
		end
	end
	for _ = 1, 4 do
		local R = rng:NextNumber(100, 150)
		local x, z = randomIn(1, 700, 1750, R * 1.6)
		if x and z then
			table.insert(FEATURES, { kind = "volcano", x = x, z = z, R = R, D = rng:NextNumber(55, 85), biome = 1 })
		end
	end
end
M.FEATURES = FEATURES

local NO_FEATURES: { Feature } = {}

local function features(x: number, z: number, list: { Feature }): (number, boolean)
	local dh, fl = 0, false
	for _, c in list do
		local dx, dz = x - c.x, z - c.z
		local d2 = dx * dx + dz * dz
		if c.kind == "crater" then
			local lim = c.R * 1.45
			if d2 < lim * lim then
				local d = sqrt(d2) / c.R
				if d < 1 then
					dh -= c.D * (1 - d * d)
					if d < 0.8 then
						fl = true
					end
				end
				local e = (d - 1) / 0.18
				dh += c.D * 0.45 * exp(-e * e)
			end
		else
			local lim = c.R * 1.6
			if d2 < lim * lim then
				local d = sqrt(d2) / c.R
				dh += c.D * (1 - smooth(0.3, 1.6, d))
				if d < 0.3 then
					local q = d / 0.3
					dh -= c.D * 0.5 * (1 - q * q)
					fl = true
				end
			end
		end
	end
	return dh, fl
end

local function rawHeight(x: number, z: number, list: { Feature }): (number, boolean, number)
	local r = sqrt(x * x + z * z)
	if r <= M.LOBBY_R + 4 then
		return M.LOBBY_H, false, r
	end
	local h = M.LOBBY_H * (1 - smooth(M.LOBBY_R + 4, BERM_R, r))
	local w = smooth(FLAT_R, WILD_R, r)
	local fl = false
	if w > 0 then
		local a = angleDeg(x, z)
		local bi = biomeAt(a)
		local diff = ((a - M.BIOMES[bi].angle + 540) % 360) - 180
		local s = rad(45 - abs(diff)) * r
		local hb = HF[bi](x, z)
		if s < BAND / 2 then
			local nb = if diff >= 0 then bi % 4 + 1 else (bi + 2) % 4 + 1
			local wa = 0.5 + 0.5 * smooth(0, BAND / 2, s)
			hb = hb * wa + HF[nb](x, z) * (1 - wa)
		end
		local dh
		dh, fl = features(x, z, list)
		h += w * (hb + dh)
	end
	h += smooth(1880, 2010, r) * (130 + fbm(x, z, 160, 3, 8) * 80)
	return h, fl, r
end

-- Wysokość z drogami: oś drogi wygładzona (średnia z 5 próbek co 30 studs), pobocze przechodzi w teren.
function M.height(x: number, z: number, list: { Feature }?): (number, boolean, boolean, number)
	local feat = list or FEATURES
	local h, fl, r = rawHeight(x, z, feat)
	local isRoad = false
	if r > M.LOBBY_R then
		local dl, along, idx = roadLateral(x, z)
		if dl < ROAD_HALF + ROAD_BLEND and along < ROAD_END + 60 then
			local d = ROAD_DIR[idx]
			local sum = 0
			for i = -2, 2 do
				local t = along + i * 30
				sum += (rawHeight(d.X * t, d.Z * t, NO_FEATURES))
			end
			local hr = sum / 5
			local k = math.max(smooth(ROAD_HALF, ROAD_HALF + ROAD_BLEND, dl), smooth(ROAD_END, ROAD_END + 60, along))
			h = lerp(hr, h, k)
			isRoad = dl < ROAD_HALF - 1 and along < ROAD_END
		end
	end
	return h, fl, isRoad, r
end

local BIOME_MATS = {
	{ base = MAT.Basalt, alt = MAT.CrackedLava, floor = MAT.CrackedLava, low = -12, boulder = MAT.Basalt },
	{ base = MAT.Snow, alt = MAT.Glacier, floor = MAT.Ice, low = -999, boulder = MAT.Glacier },
	{ base = MAT.Rock, alt = MAT.Limestone, floor = MAT.Limestone, low = 4, boulder = MAT.Rock },
	{ base = MAT.Sandstone, alt = MAT.Salt, floor = MAT.Salt, low = -999, boulder = MAT.Salt },
}

local function materialAt(x: number, z: number, h: number, fl: boolean, isRoad: boolean, r: number): Enum.Material
	if isRoad then
		return MAT.Asphalt
	end
	if r < M.LOBBY_R + 6 then
		return MAT.Slate
	end
	local n = fbm(x, z, 70, 2, 11)
	if r < FLAT_R + 40 + n * 120 then
		return MAT.Slate
	end
	if r > 1920 + n * 60 then
		return MAT.Ground
	end
	-- Płynne przejście biomów: duże plamy (fbm) + drobne wtrącenia (~5 studs) w pasie ~±BAND.
	local j = fbm(x, z, 90, 3, 9) * 2.6 + noise(x * 0.19, z * 0.19, S + 77.7) * 0.5
	local a = angleDeg(x, z) + deg(j * BAND / r)
	local bm = BIOME_MATS[biomeAt(a % 360)]
	if fl then
		return bm.floor
	end
	if h < bm.low or n > 0.18 then
		return bm.alt
	end
	return bm.base
end

function M.setMaterialColors()
	local t = Workspace.Terrain
	t:SetMaterialColor(MAT.Slate, Color3.fromRGB(92, 88, 116))
	t:SetMaterialColor(MAT.Asphalt, Color3.fromRGB(48, 46, 62))
	t:SetMaterialColor(MAT.Basalt, Color3.fromRGB(52, 42, 44))
	t:SetMaterialColor(MAT.CrackedLava, Color3.fromRGB(214, 96, 48))
	t:SetMaterialColor(MAT.Snow, Color3.fromRGB(222, 232, 255))
	t:SetMaterialColor(MAT.Glacier, Color3.fromRGB(150, 200, 240))
	t:SetMaterialColor(MAT.Ice, Color3.fromRGB(165, 212, 255))
	t:SetMaterialColor(MAT.Rock, Color3.fromRGB(66, 78, 112))
	t:SetMaterialColor(MAT.Limestone, Color3.fromRGB(80, 140, 156))
	t:SetMaterialColor(MAT.Sandstone, Color3.fromRGB(140, 96, 186))
	t:SetMaterialColor(MAT.Salt, Color3.fromRGB(206, 172, 236))
	t:SetMaterialColor(MAT.Ground, Color3.fromRGB(78, 68, 98))
end

local function chunkFeatures(x0: number, z0: number, size: number): { Feature }
	local list = {}
	for _, f in FEATURES do
		local m = f.R * 1.6
		if f.x + m > x0 and f.x - m < x0 + size and f.z + m > z0 and f.z - m < z0 + size then
			table.insert(list, f)
		end
	end
	return list
end

function M.writeChunk(x0: number, z0: number, size: number): number
	local n = size // 4
	local feat = chunkFeatures(x0, z0, size)
	local hs: { number } = table.create(n * n, 0)
	local ms: { Enum.Material } = table.create(n * n, MAT.Air)
	local minH, maxH, any = math.huge, -math.huge, false
	for i = 1, n do
		for k = 1, n do
			local x, z = x0 + (i - 0.5) * 4, z0 + (k - 0.5) * 4
			local idx = (i - 1) * n + k
			local r = sqrt(x * x + z * z)
			if r > TERRAIN_R then
				hs[idx] = -1e9
			else
				local h, fl, road = M.height(x, z, feat)
				hs[idx] = h
				ms[idx] = materialAt(x, z, h, fl, road, r)
				any = true
				minH = math.min(minH, h)
				maxH = math.max(maxH, h)
			end
		end
	end
	if not any then
		return 0
	end
	local yMin = floor((minH - 28) / 4) * 4
	local yMax = math.ceil((maxH + 4) / 4) * 4
	local ny = (yMax - yMin) // 4
	local mats, occ = table.create(n), table.create(n)
	for i = 1, n do
		local mi, oi = table.create(ny), table.create(ny)
		for j = 1, ny do
			local mj, oj = table.create(n), table.create(n)
			local vb = yMin + (j - 1) * 4
			for k = 1, n do
				local idx = (i - 1) * n + k
				-- −2: gładki teren rysuje powierzchnię ~2 studs nad granicą pełnego voxela (zmierzone).
				local o = clamp01((hs[idx] - TERRAIN_SURFACE_OFFSET - vb) / 4)
				mj[k] = if o > 0 then ms[idx] else MAT.Air
				oj[k] = o
			end
			mi[j] = mj
			oi[j] = oj
		end
		mats[i] = mi
		occ[i] = oi
	end
	local region = Region3.new(Vector3.new(x0, yMin, z0), Vector3.new(x0 + size, yMax, z0 + size))
	Workspace.Terrain:WriteVoxels(region, 4, mats, occ)
	return n * n * ny
end

-- Teren w rzędach chunków 128×128 (0..31 od −2048).
function M.buildTerrain(rowFrom: number, rowTo: number): number
	local total = 0
	for row = rowFrom, rowTo do
		for col = 0, 31 do
			local x0, z0 = -2048 + col * 128, -2048 + row * 128
			local nx, nz = math.clamp(0, x0, x0 + 128), math.clamp(0, z0, z0 + 128)
			if nx * nx + nz * nz < TERRAIN_R * TERRAIN_R then
				total += M.writeChunk(x0, z0, 128)
				task.wait()
			end
		end
	end
	return total
end

function M.buildBoulders(count: number): number
	local r2 = Random.new(SEED + 1)
	local placed = 0
	for _ = 1, count do
		local a = r2:NextNumber(0, 360)
		local r = sqrt(r2:NextNumber(480 * 480, 1880 * 1880))
		local x, z = r * cos(rad(a)), r * sin(rad(a))
		local dl, along = roadLateral(x, z)
		if dl > ROAD_HALF + 10 or along > ROAD_END then
			local h = M.height(x, z)
			local mat = BIOME_MATS[biomeAt(a)].boulder
			local size = r2:NextNumber(3, 10)
			Workspace.Terrain:FillBall(Vector3.new(x, h + size * 0.2, z), size, mat)
			for _ = 1, r2:NextInteger(0, 2) do
				local s2 = size * r2:NextNumber(0.4, 0.7)
				local off = Vector3.new(r2:NextNumber(-1, 1), 0, r2:NextNumber(-1, 1)).Unit * size * 0.9
				Workspace.Terrain:FillBall(Vector3.new(x, h, z) + off, s2, mat)
			end
			placed += 1
		end
		if placed % 50 == 0 then
			task.wait()
		end
	end
	return placed
end

-- Pomocniki do części ------------------------------------------------------------------------------
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, extra: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then
		for k, v in extra do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function label(p: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local g = Instance.new("SurfaceGui")
	g.Name = "Label"
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.LightInfluence = 0
	g.MaxDistance = 700
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.Text = text
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.5
	t.Parent = g
	g.Parent = p
end

local WALL = Color3.fromRGB(222, 226, 240)
local ROOF = Color3.fromRGB(70, 72, 96)
local DARK = Color3.fromRGB(24, 24, 38)
local FLOOR = Color3.fromRGB(96, 98, 122)

local function tagStation(m: Model, id: string)
	m:SetAttribute("Station", id)
	CollectionService:AddTag(m, "LobbyStation")
end

local function frontCF(angle: number, r: number): CFrame
	local a = rad(angle)
	local pos = Vector3.new(r * cos(a), M.FLOOR_Y, r * sin(a))
	return CFrame.lookAt(pos, Vector3.new(0, M.FLOOR_Y, 0))
end

-- Budynek: cf = środek frontu (LookVector do centrum lobby), bryła za frontem.
local function building(parent: Instance, id: string, title: string, angle: number, r: number, w: number, d: number, h: number, accent: Color3): Model
	local cf = frontCF(angle, r)
	local m = Instance.new("Model")
	m.Name = id
	local body = part(m, "Body", Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, d / 2), WALL, MAT.SmoothPlastic)
	part(m, "Roof", Vector3.new(w + 4, 1.6, d + 4), cf * CFrame.new(0, h + 0.8, d / 2), ROOF, MAT.Metal)
	part(m, "Stripe", Vector3.new(w + 0.4, 1.2, d + 0.4), cf * CFrame.new(0, h - 2.5, d / 2), accent, MAT.Neon, { CanCollide = false, CastShadow = false })
	part(m, "Door", Vector3.new(w * 0.42, h * 0.55, 0.6), cf * CFrame.new(0, h * 0.275, -0.2), DARK, MAT.Glass, { Transparency = 0.15 })
	part(m, "DoorFrame", Vector3.new(w * 0.42 + 1.6, 1, 0.8), cf * CFrame.new(0, h * 0.55 + 0.5, -0.3), accent, MAT.Neon, { CanCollide = false, CastShadow = false })
	for _, sx in { -1, 1 } do
		part(m, "Pillar", Vector3.new(2, h, 2), cf * CFrame.new(sx * (w / 2 - 1), h / 2, -0.6), ROOF, MAT.Metal)
	end
	local sign = part(m, "Sign", Vector3.new(w * 0.85, 5.5, 0.8), cf * CFrame.new(0, h + 4.6, 1), DARK, MAT.SmoothPlastic)
	label(sign, Enum.NormalId.Front, title, accent)
	local pad = part(m, "PromptAnchor", Vector3.new(6, 0.3, 6), cf * CFrame.new(0, 0.15, -6), accent, MAT.Neon, { CanCollide = false, CastShadow = false, Transparency = 0.35 })
	local att = Instance.new("Attachment")
	att.Name = "Prompt"
	att.Position = Vector3.new(0, 3, 0)
	att.Parent = pad
	m.PrimaryPart = body
	tagStation(m, id)
	m:SetAttribute("DisplayName", title)
	m.Parent = parent
	return m
end

function M.buildLobby(map: Instance): Model
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = map
	local floorY = M.FLOOR_Y
	local vertical = CFrame.Angles(0, 0, math.pi / 2)
	part(lobby, "Floor", Vector3.new(2, (M.LOBBY_R + 2) * 2, (M.LOBBY_R + 2) * 2), CFrame.new(0, floorY - 1, 0) * vertical, FLOOR, MAT.Concrete)
	part(lobby, "Plaza", Vector3.new(0.4, 120, 120), CFrame.new(0, floorY + 0.2, 0) * vertical, Color3.fromRGB(150, 154, 182), MAT.Marble)
	part(lobby, "PlazaRing", Vector3.new(0.3, 124, 124), CFrame.new(0, floorY + 0.1, 0) * vertical, Color3.fromRGB(150, 110, 255), MAT.Neon, { CanCollide = false, CastShadow = false })

	-- Drogi przez lobby (krzyż) i bramy do biomów.
	for i, b in M.BIOMES do
		local d = ROAD_DIR[i]
		local cfRoad = CFrame.lookAt(d * 121 + Vector3.new(0, floorY + 0.1, 0), d * 300 + Vector3.new(0, floorY + 0.1, 0))
		part(lobby, "Road", Vector3.new(ROAD_HALF * 2, 0.4, 122), cfRoad, Color3.fromRGB(48, 46, 62), MAT.Asphalt)
		part(lobby, "RoadLine", Vector3.new(1, 0.45, 118), cfRoad, b.color, MAT.Neon, { CanCollide = false, CastShadow = false })
		local gate = Instance.new("Model")
		gate.Name = "Gate_" .. b.id
		local gcf = CFrame.lookAt(d * 172 + Vector3.new(0, floorY, 0), Vector3.new(0, floorY, 0))
		for _, sx in { -1, 1 } do
			part(gate, "Post", Vector3.new(3, 20, 3), gcf * CFrame.new(sx * (ROAD_HALF + 3), 10, 0), ROOF, MAT.Metal)
			part(gate, "PostGlow", Vector3.new(3.2, 16, 0.6), gcf * CFrame.new(sx * (ROAD_HALF + 3), 10, -1.4), b.color, MAT.Neon, { CanCollide = false, CastShadow = false })
		end
		local beam = part(gate, "Beam", Vector3.new(ROAD_HALF * 2 + 10, 5, 2), gcf * CFrame.new(0, 21, 0), DARK, MAT.SmoothPlastic)
		label(beam, Enum.NormalId.Front, string.upper(b.name) .. "  >>", b.color)
		label(beam, Enum.NormalId.Back, "LOBBY", Color3.fromRGB(230, 230, 255))
		gate.Parent = lobby
	end

	-- Barierka na krawędzi płaskowyżu (przerwy na drogi).
	local rail = Instance.new("Model")
	rail.Name = "Railing"
	for a = 5, 355, 10 do
		local near = false
		for _, c in { 0, 90, 180, 270, 360 } do
			if abs(a - c) < 9 then
				near = true
			end
		end
		if not near then
			local cf = frontCF(a, M.LOBBY_R - 1)
			part(rail, "Rail", Vector3.new(31, 3, 0.6), cf * CFrame.new(0, 1.5, 0), Color3.fromRGB(180, 190, 255), MAT.Glass, { Transparency = 0.55, CastShadow = false })
			part(rail, "RailTop", Vector3.new(31, 0.4, 0.8), cf * CFrame.new(0, 3.1, 0), Color3.fromRGB(150, 110, 255), MAT.Neon, { CanCollide = false, CastShadow = false })
		end
	end
	rail.Parent = lobby

	-- Spawn + tablica eventów nad nim.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(20, 1, 20)
	spawn.CFrame = CFrame.new(0, floorY + 0.5, 0)
	spawn.Color = Color3.fromRGB(150, 110, 255)
	spawn.Material = MAT.Neon
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby
	local ev = Instance.new("Model")
	ev.Name = "EventBoard"
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(ev, "Leg", Vector3.new(2, 30, 2), CFrame.new(sx * 16, floorY + 15, sz * 16), ROOF, MAT.Metal)
		end
	end
	local screen = part(ev, "Screen", Vector3.new(34, 12, 34), CFrame.new(0, floorY + 36, 0), DARK, MAT.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		label(screen, face, "STAR SHOWER\nsoon", Color3.fromRGB(255, 225, 120))
	end
	part(ev, "ScreenGlow", Vector3.new(34.4, 1, 34.4), CFrame.new(0, floorY + 29.6, 0), Color3.fromRGB(255, 225, 120), MAT.Neon, { CanCollide = false, CastShadow = false })
	ev.PrimaryPart = screen
	tagStation(ev, "EventBoard")
	ev:SetAttribute("DisplayName", "Events")
	ev.Parent = lobby

	-- Ćwiartki: 45° sprzęt, 135° baza i kasa, 225° kolekcja i rebirth, 315° Robux i daily.
	local st = Instance.new("Folder")
	st.Name = "Stations"
	st.Parent = lobby
	building(st, "ToolShop", "TOOL SHOP", 25, 112, 40, 28, 18, Color3.fromRGB(255, 170, 60))
	building(st, "Garage", "GARAGE", 65, 112, 44, 32, 20, Color3.fromRGB(60, 200, 255))
	building(st, "SellStation", "SELL", 115, 112, 36, 26, 16, Color3.fromRGB(80, 230, 120))
	building(st, "Upgrades", "UPGRADES", 155, 112, 36, 26, 16, Color3.fromRGB(255, 220, 80))
	building(st, "IndexHall", "INDEX HALL", 205, 112, 44, 32, 22, Color3.fromRGB(170, 120, 255))
	local robux = building(st, "RobuxShop", "ROBUX SHOP", 295, 112, 40, 28, 18, Color3.fromRGB(255, 90, 200))
	building(st, "DailyCodes", "DAILY & CODES", 335, 112, 36, 26, 16, Color3.fromRGB(60, 240, 210))

	-- Strefa VIP (część Robux Shop) między budynkami ćwiartki 315°.
	local vcf = frontCF(315, 150)
	local gold = Color3.fromRGB(255, 200, 60)
	local vip = part(robux, "VipZone", Vector3.new(26, 0.6, 26), vcf * CFrame.new(0, 0.3, 0), Color3.fromRGB(60, 50, 30), MAT.Metal)
	vip:SetAttribute("VipZone", true)
	part(robux, "VipBorder", Vector3.new(27, 0.4, 27), vcf * CFrame.new(0, 0.2, 0), gold, MAT.Neon, { CanCollide = false, CastShadow = false })
	local vsign = part(robux, "VipSign", Vector3.new(14, 5, 0.8), vcf * CFrame.new(0, 9, 12), DARK, MAT.SmoothPlastic)
	label(vsign, Enum.NormalId.Front, "VIP", gold)
	part(robux, "VipSignPost", Vector3.new(1.5, 7, 1.5), vcf * CFrame.new(0, 3.5, 12.6), ROOF, MAT.Metal)

	-- Portal Rebirth: pionowy pierścień z bloków + tafla.
	local pcf = frontCF(245, 128)
	local portal = Instance.new("Model")
	portal.Name = "RebirthPortal"
	local pink = Color3.fromRGB(255, 80, 140)
	part(portal, "Plinth", Vector3.new(30, 2, 12), pcf * CFrame.new(0, 1, 0), ROOF, MAT.Metal)
	local ringR = 12
	for k = 0, 15 do
		local t = k / 16 * math.pi * 2
		local p = pcf * CFrame.new(ringR * cos(t), 2 + ringR + ringR * sin(t), 0) * CFrame.Angles(0, 0, t)
		part(portal, "Ring", Vector3.new(2.5, 5.2, 3), p, if k % 2 == 0 then pink else Color3.fromRGB(255, 160, 200), MAT.Neon, { CastShadow = false })
	end
	local core = part(portal, "Core", Vector3.new(0.6, ringR * 2 - 2, ringR * 2 - 2), pcf * CFrame.new(0, 2 + ringR, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0), Color3.fromRGB(255, 120, 190), MAT.Neon, { Transparency = 0.45, CanCollide = false, CastShadow = false, Shape = Enum.PartType.Cylinder })
	local psign = part(portal, "Sign", Vector3.new(20, 5, 0.8), pcf * CFrame.new(0, 2 + ringR * 2 + 4, 0), DARK, MAT.SmoothPlastic)
	label(psign, Enum.NormalId.Front, "REBIRTH", pink)
	local pad = part(portal, "PromptAnchor", Vector3.new(6, 0.3, 6), pcf * CFrame.new(0, 0.15, -9), pink, MAT.Neon, { CanCollide = false, CastShadow = false, Transparency = 0.35 })
	local att = Instance.new("Attachment")
	att.Name = "Prompt"
	att.Position = Vector3.new(0, 3, 0)
	att.Parent = pad
	portal.PrimaryPart = core
	tagStation(portal, "RebirthPortal")
	portal:SetAttribute("DisplayName", "Rebirth")
	portal.Parent = st

	return lobby
end

-- Działki: przesunięcie radialne na PLOT_R (konwencja PlotService bez zmian).
function M.movePlots(): { string }
	local out = {}
	for _, plot in (Workspace:FindFirstChild("Plots") :: Instance):GetChildren() do
		if plot:IsA("Model") then
			local base = plot:FindFirstChild("Base") :: BasePart
			local p = base.Position
			local flat = Vector3.new(p.X, 0, p.Z)
			local offset = flat.Unit * (M.PLOT_R - flat.Magnitude)
			plot:PivotTo(plot:GetPivot() + offset)
			local bo = plot:FindFirstChild("BuildOrigin") :: CFrameValue?
			if bo then
				bo.Value = bo.Value + offset
			end
			local np = base.Position
			table.insert(out, string.format("%s r=%.1f a=%.1f", plot.Name, Vector3.new(np.X, 0, np.Z).Magnitude, angleDeg(np.X, np.Z)))
		end
	end
	return out
end

function M.buildBounds(map: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = "Bounds"
	local n = 64
	local width = 2 * M.R * math.tan(math.pi / n) + 2
	local yBot, yTop = -100, M.CEILING
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * 360
		local ar = rad(a)
		local pos = Vector3.new(M.R * cos(ar), (yBot + yTop) / 2, M.R * sin(ar))
		part(f, "Wall", Vector3.new(width, yTop - yBot, 4), CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)), Color3.fromRGB(150, 110, 255), MAT.ForceField, { Transparency = 0.4, CastShadow = false, CanQuery = false, CanTouch = false })
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			part(f, "Ceiling", Vector3.new(2048, 4, 2048), CFrame.new(sx * 1024, M.CEILING + 2, sz * 1024), Color3.new(1, 1, 1), MAT.SmoothPlastic, { Transparency = 1, CastShadow = false, CanQuery = false, CanTouch = false })
		end
	end
	f.Parent = map
	return f
end

-- Biomy: znacznik StarLandingZone + Theme na środku ćwiartki, granice w atrybutach (mapa biomów dla StarService).
function M.buildBiomes(map: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = "Biomes"
	f.Parent = map
	for i, b in M.BIOMES do
		local m = Instance.new("Model")
		m.Name = b.id
		local rc = (M.LAND_MIN + M.LAND_MAX) / 2
		local d = ROAD_DIR[i]
		local hz = M.height(d.X * rc, d.Z * rc)
		local zone = part(m, "LandingZone", Vector3.new(8, 1, 8), CFrame.new(d.X * rc, hz + 0.5, d.Z * rc), b.color, MAT.SmoothPlastic, { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false })
		zone:SetAttribute("Theme", b.id)
		zone:SetAttribute("DisplayName", b.name)
		zone:SetAttribute("AngleMin", b.angle - 45)
		zone:SetAttribute("AngleMax", b.angle + 45)
		zone:SetAttribute("RadiusMin", M.LAND_MIN)
		zone:SetAttribute("RadiusMax", M.LAND_MAX)
		CollectionService:AddTag(zone, "StarLandingZone")
		-- Tablica przy wejściu do biomu (r≈470, prawe pobocze).
		local side = Vector3.new(-d.Z, 0, d.X)
		local sp = d * 470 + side * (ROAD_HALF + 6)
		local sh = M.height(sp.X, sp.Z)
		local scf = CFrame.lookAt(Vector3.new(sp.X, sh, sp.Z), Vector3.new(0, sh, 0))
		part(m, "SignPost", Vector3.new(1.5, 12, 1.5), scf * CFrame.new(0, 5, 0), ROOF, MAT.Metal)
		local board = part(m, "Sign", Vector3.new(18, 6, 0.8), scf * CFrame.new(0, 12, 0), DARK, MAT.SmoothPlastic)
		label(board, Enum.NormalId.Front, string.upper(b.name), b.color)
		m.Parent = f
	end
	return f
end

-- Rampy do skoków na drogach (jeden pas), dopasowane do spadku drogi.
function M.buildRamps(map: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = "Ramps"
	for i, b in M.BIOMES do
		local d = ROAD_DIR[i]
		local side = Vector3.new(-d.Z, 0, d.X)
		for _, along in { 650, 1050, 1450 } do
			local p0 = d * (along - 13) + side * 7
			local p1 = d * (along + 13) + side * 7
			local a0 = Vector3.new(p0.X, M.height(p0.X, p0.Z), p0.Z)
			local a1 = Vector3.new(p1.X, M.height(p1.X, p1.Z), p1.Z)
			local mid = (a0 + a1) / 2
			local look = CFrame.lookAt(mid, mid - (a1 - a0).Unit)
			local w = Instance.new("WedgePart")
			w.Name = "Ramp"
			w.Anchored = true
			w.Size = Vector3.new(11, 7, 26)
			w.CFrame = look * CFrame.new(0, 3, 0)
			w.Color = b.color
			w.Material = MAT.DiamondPlate
			w.Parent = f
		end
	end
	f.Parent = map
	return f
end

-- Propsy biomów z części: kryształy (Crystal Canyon), kolce lodu (Frost Crater).
function M.buildProps(map: Instance): number
	local r3 = Random.new(SEED + 2)
	local count = 0
	local biomes = map:FindFirstChild("Biomes") :: Instance
	local function cluster(b: number, n: number, colors: { Color3 }, mat: Enum.Material, lenMin: number, lenMax: number)
		local holder = Instance.new("Folder")
		holder.Name = "Props"
		holder.Parent = biomes:FindFirstChild(M.BIOMES[b].id)
		for _ = 1, n do
			local x, z = randomIn(b, 520, 1850, 20)
			if x and z then
				local h = M.height(x, z)
				local m = Instance.new("Model")
				m.Name = "Cluster"
				for _ = 1, r3:NextInteger(3, 5) do
					local len = r3:NextNumber(lenMin, lenMax)
					local wdt = len * r3:NextNumber(0.18, 0.3)
					local off = Vector3.new(r3:NextNumber(-6, 6), 0, r3:NextNumber(-6, 6))
					local tilt = CFrame.Angles(rad(r3:NextNumber(-25, 25)), rad(r3:NextNumber(0, 360)), rad(r3:NextNumber(-25, 25)))
					local cf = CFrame.new(Vector3.new(x, h - 2, z) + off) * tilt * CFrame.new(0, len / 2, 0)
					part(m, "Shard", Vector3.new(wdt, len, wdt), cf, colors[r3:NextInteger(1, #colors)], mat, { CastShadow = false, CanCollide = len > 18 })
					count += 1
				end
				m.Parent = holder
			end
		end
	end
	-- `randomIn` używa głównego rng; tu wystarczy (propsy losowane po kraterach).
	cluster(3, 34, { Color3.fromRGB(90, 255, 220), Color3.fromRGB(120, 180, 255), Color3.fromRGB(255, 120, 230) }, MAT.Neon, 10, 34)
	cluster(2, 20, { Color3.fromRGB(170, 220, 255), Color3.fromRGB(210, 240, 255) }, MAT.Ice, 8, 22)
	return count
end

function M.clearOld(map: Instance)
	for _, name in { "Hub", "Paths", "Zones", "Ground", "Bounds", "Lobby", "Biomes", "Ramps" } do
		local c = map:FindFirstChild(name)
		if c then
			c:Destroy()
		end
	end
end

return M
