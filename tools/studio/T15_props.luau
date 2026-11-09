--!strict
-- T15_props.luau — rozmieszczenie propsów mapy (T15). Uruchom w Studio (execute_luau, Edit) po import_props
-- (ServerStorage.MapProps). Deterministyczne (SEED), ponowne uruchomienie przebudowuje Workspace.Map.Props.
--
-- Zasady (decyzje 9.11, notatka [[Mapa]]):
--  • biomy = ćwiartki wg kąta atan2(z, x): Lava 0°, Frost 90°, Crystal 180°, Nebula 270° (jak T36_map_gen);
--    pas ±TRANSITION_DEG przy granicy miesza propsy obu biomów (płynne przejście);
--  • skupiska (3–6 propsów) z otwartymi polami między nimi — gwiazdy mają gdzie lądować; ~500–650 instancji;
--  • omijamy: lobby i działki (r < R_MIN), drogi (pas ROAD_CLEAR od osi), rampy, stoki > MAX_SLOPE dla dużych;
--  • punkty orientacyjne: łuk/iglica/monolit każdego biomu, wieże-latarnie na granicach biomów, 2 wraki,
--    16 pylonów pola siłowego na r = 1995;
--  • duże propsy kolidują (CanQuery = true → StarService nie wyląduje na nich: punkt musi trafić w Terrain);
--  • streaming: Model.ModelStreamingMode = Atomic, duże i punkty orientacyjne LevelOfDetail = StreamingMesh.

local SS = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local SEED = 1515
local R_MIN, R_MAX = 470, 1880
local ROAD_CLEAR = 30 -- połowa pasa wolnego od propsów wokół osi drogi (droga ma 28)
local ROAD_END = 1820
local RAMP_R = { 650, 1050, 1450 }
local TRANSITION_DEG = 12
local CLUSTERS_PER_BIOME = 34
local CLUSTER_MIN_GAP = 95
local MAX_SLOPE_LARGE = 0.82 -- cos ~35°
local BIOMES = {
	{ id = "LavaFields", angle = 0, special = { name = "Lava_Vent", count = 8 } },
	{ id = "FrostCrater", angle = 90 },
	{ id = "CrystalCanyon", angle = 180 },
	{ id = "NebulaPlateau", angle = 270 },
}
local LANDMARK = { LavaFields = "Lava_Arch", FrostCrater = "Frost_Arch", CrystalCanyon = "Crystal_Spire", NebulaPlateau = "Nebula_Monolith" }

local templates = SS:FindFirstChild("MapProps")
assert(templates, "Brak ServerStorage.MapProps (najpierw import_props)")
local rng = Random.new(SEED)
local map = Workspace:FindFirstChild("Map") :: Folder

-- stare propsy z części (T36) — zastępujemy modelami z Blendera
for _, biome in (map:FindFirstChild("Biomes") :: Instance):GetChildren() do
	local old = biome:FindFirstChild("Props")
	if old then
		old:Destroy()
	end
end
local prev = map:FindFirstChild("Props")
if prev then
	prev:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Props"
root.Parent = map

-- szablony wg biomu i kategorii
local byBiome: { [string]: { [string]: { Model } } } = {}
for _, m in templates:GetChildren() do
	local b = (m:GetAttribute("Biome") :: string?) or "Common"
	local c = m:GetAttribute("Category") :: string
	byBiome[b] = byBiome[b] or {}
	byBiome[b][c] = byBiome[b][c] or {}
	table.insert(byBiome[b][c], m :: Model)
end

local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.FilterDescendantsInstances = { Workspace.Terrain }
terrainParams.IgnoreWater = false

local function angleOf(x: number, z: number): number
	return math.deg(math.atan2(z, x)) % 360
end

local function angDiff(a: number, b: number): number
	return math.abs((a - b + 180) % 360 - 180)
end

local function nearRoad(x: number, z: number): boolean
	local r = math.sqrt(x * x + z * z)
	if r > ROAD_END + 40 then
		return false
	end
	if math.abs(z) < ROAD_CLEAR or math.abs(x) < ROAD_CLEAR then
		return true
	end
	for _, rr in RAMP_R do
		for _, a in { 0, 90, 180, 270 } do
			local rx, rz = math.cos(math.rad(a)) * rr, math.sin(math.rad(a)) * rr
			if (x - rx) ^ 2 + (z - rz) ^ 2 < 60 ^ 2 then
				return true
			end
		end
	end
	return false
end

local function ground(x: number, z: number): RaycastResult?
	local hit = Workspace:Raycast(Vector3.new(x, 700, z), Vector3.new(0, -900, 0), terrainParams)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit
	end
	return nil
end

local placedLarge: { Vector3 } = {}
local count = 0
local holders: { [string]: Folder } = {}
local function holder(name: string): Folder
	local h = holders[name]
	if not h then
		h = Instance.new("Folder")
		h.Name = name
		h.Parent = root
		holders[name] = h
	end
	return h
end

local function biomeAt(a: number): (string, string?)
	-- biom główny + (w pasie przejścia) sąsiedni
	local best, bestD = BIOMES[1].id, 999
	for _, b in BIOMES do
		local d = angDiff(a, b.angle)
		if d < bestD then
			best, bestD = b.id, d
		end
	end
	if 45 - bestD < TRANSITION_DEG then
		for _, b in BIOMES do
			if b.id ~= best and angDiff(a, b.angle) < 45 + TRANSITION_DEG then
				return best, b.id
			end
		end
	end
	return best, nil
end

local function place(template: Model, hit: RaycastResult, opts: { scale: number?, upright: boolean?, yaw: number?, folder: string }): Model
	local m = template:Clone()
	local s = opts.scale or 1
	if s ~= 1 then
		m:ScaleTo(s)
	end
	local up = Vector3.yAxis
	if not opts.upright then
		up = (Vector3.yAxis + hit.Normal):Unit() -- pół drogi do normalnej terenu
	end
	local yaw = opts.yaw or rng:NextNumber(0, 2 * math.pi)
	local fwd = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	local right = fwd:Cross(up).Unit
	fwd = up:Cross(right).Unit
	local pos = hit.Position - hit.Normal * 0.4
	m:PivotTo(CFrame.fromMatrix(pos, right, up, -fwd))
	local cat = m:GetAttribute("Category")
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	if cat == "large" or cat == "landmark" then
		m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
	end
	m.Parent = holder(opts.folder)
	count += 1
	return m
end

local function pick(list: { Model }?): Model?
	if not list or #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

-- 1) punkty orientacyjne
local function landmarkAt(name: string, a: number, r: number, folder: string, upright: boolean?)
	local t = templates:FindFirstChild(name) :: Model
	for _ = 1, 12 do
		local x, z = math.cos(math.rad(a)) * r, math.sin(math.rad(a)) * r
		local hit = ground(x, z)
		if hit and not nearRoad(x, z) then
			local yaw = math.atan2(-z, -x) + math.pi / 2 -- przodem (oś łuku) w poprzek promienia
			place(t, hit, { scale = if name == "Beacon_Tower" or name == "Wreck" then 1.0 else 1.35, upright = true, yaw = yaw, folder = folder })
			table.insert(placedLarge, hit.Position)
			return
		end
		a += 3
		r += 15
	end
end

for _, b in BIOMES do
	landmarkAt(LANDMARK[b.id], b.angle + 22, 1180, b.id)
end
for _, a in { 45, 135, 225, 315 } do
	landmarkAt("Beacon_Tower", a, 980, "Landmarks")
	landmarkAt("Beacon_Tower", a + 4, 1640, "Landmarks")
end
landmarkAt("Wreck", 112, 1380, "Landmarks")
landmarkAt("Wreck", 292, 760, "Landmarks")
for i = 0, 15 do
	local a = i * 22.5 + 11.25
	local x, z = math.cos(math.rad(a)) * 1995, math.sin(math.rad(a)) * 1995
	local hit = ground(x, z)
	if hit then
		place(templates.Shield_Pylon :: Model, hit, { upright = true, folder = "Boundary" })
	end
end
task.wait()

-- 2) specjalne (kominy lawy)
for _, b in BIOMES do
	if b.special then
		local placedN = 0
		for _ = 1, 200 do
			if placedN >= b.special.count then
				break
			end
			local a = b.angle + rng:NextNumber(-38, 38)
			local r = rng:NextNumber(R_MIN + 80, R_MAX - 60)
			local x, z = math.cos(math.rad(a)) * r, math.sin(math.rad(a)) * r
			local hit = ground(x, z)
			if hit and hit.Normal.Y > 0.9 and not nearRoad(x, z) then
				place(templates:FindFirstChild(b.special.name) :: Model, hit, { scale = rng:NextNumber(1.4, 2.0), folder = b.id })
				table.insert(placedLarge, hit.Position)
				placedN += 1
			end
		end
	end
end
task.wait()

-- 3) skupiska w każdym biomie (+ wymieszane w pasach przejścia)
local clusterCenters: { Vector3 } = {}
local function farFromClusters(p: Vector3): boolean
	for _, c in clusterCenters do
		if (Vector3.new(c.X, 0, c.Z) - Vector3.new(p.X, 0, p.Z)).Magnitude < CLUSTER_MIN_GAP then
			return false
		end
	end
	for _, c in placedLarge do
		if (Vector3.new(c.X, 0, c.Z) - Vector3.new(p.X, 0, p.Z)).Magnitude < 45 then
			return false
		end
	end
	return true
end

for _, b in BIOMES do
	local made = 0
	for _ = 1, CLUSTERS_PER_BIOME * 8 do
		if made >= CLUSTERS_PER_BIOME then
			break
		end
		local a = b.angle + rng:NextNumber(-45, 45)
		local r = math.sqrt(rng:NextNumber(R_MIN ^ 2, R_MAX ^ 2))
		local x, z = math.cos(math.rad(a)) * r, math.sin(math.rad(a)) * r
		if nearRoad(x, z) then
			continue
		end
		local center = ground(x, z)
		if not center or not farFromClusters(center.Position) then
			continue
		end
		table.insert(clusterCenters, center.Position)
		made += 1
		-- skład skupiska: 1 duży (60%), 1–2 średnie, 1–3 małe; w przejściu 40% z sąsiedniego biomu, 20% wspólne
		local n = rng:NextInteger(3, 6)
		for i = 1, n do
			local ox, oz = x, z
			if i > 1 then
				local ang, d = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(16, 52)
				ox, oz = x + math.cos(ang) * d, z + math.sin(ang) * d
			end
			if nearRoad(ox, oz) then
				continue
			end
			local hit = ground(ox, oz)
			if not hit then
				continue
			end
			local main, other = biomeAt(angleOf(ox, oz))
			local src = main
			local roll = rng:NextNumber()
			if other and roll < 0.4 then
				src = other
			elseif roll > 0.85 then
				src = "Common"
			end
			local cat
			if i == 1 then
				cat = if rng:NextNumber() < 0.6 then "large" else "medium"
			elseif i <= 3 then
				cat = "medium"
			else
				cat = "small"
			end
			local t = pick(byBiome[src] and byBiome[src][cat]) or pick(byBiome[main][cat]) or pick(byBiome[main].medium)
			if not t then
				continue
			end
			if cat ~= "small" and hit.Normal.Y < MAX_SLOPE_LARGE then
				cat = "small"
				t = pick(byBiome[main].small) or t
			end
			local scale = if cat == "large" then rng:NextNumber(1.5, 2.3) elseif cat == "medium" then rng:NextNumber(1.1, 1.7) else rng:NextNumber(0.9, 1.4)
			place(t, hit, { scale = scale, upright = cat == "large", folder = main })
		end
		if made % 8 == 0 then
			task.wait()
		end
	end
end

-- 4) rozrzucone pojedyncze małe propsy (detal między skupiskami)
for _ = 1, 140 do
	local a = rng:NextNumber(0, 360)
	local r = math.sqrt(rng:NextNumber(R_MIN ^ 2, R_MAX ^ 2))
	local x, z = math.cos(math.rad(a)) * r, math.sin(math.rad(a)) * r
	if nearRoad(x, z) then
		continue
	end
	local hit = ground(x, z)
	if hit then
		local main = biomeAt(a)
		local t = pick(byBiome[main].small)
		if t then
			place(t, hit, { scale = rng:NextNumber(1.0, 1.6), folder = main })
		end
	end
end

local summary = {}
for name, h in holders do
	table.insert(summary, ("%s=%d"):format(name, #h:GetChildren()))
end
table.sort(summary)
return ("Propsy: %d (%s)"):format(count, table.concat(summary, ", "))
