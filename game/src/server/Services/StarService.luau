--!strict
-- StarService — spadanie gwiazd: harmonogram wg Stars.json (osobny zegar na rozmiar), losowy punkt lądowania
-- na całej planecie, wybór rodzaju (waga + biom), lot (klient animuje), uderzenie (model wbity w grunt, krater,
-- przypalony teren i pas przelotu, dym), HP i udział w obrażeniach, gaśnięcie po lifetime, ślady 180 s (max 14).
-- Obrażenia zadaje tylko CrackService przez StarService.damage (walidacja odległości/cooldownu jest tam).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Data.Economy) :: any
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)
local StarConfig = require(Shared.Config.StarConfig)
local Types = require(Shared.Types)

type StarInfo = Types.StarInfo

type VoxelChange = {
	x: number,
	y: number,
	z: number,
	oldMaterial: Enum.Material,
	oldOccupancy: number,
	newMaterial: Enum.Material,
}

type TerrainPatch = {
	region: Region3,
	changes: { VoxelChange },
}

type Scar = {
	id: string,
	folder: Folder,
	impactPos: Vector3,
	trailEnd: Vector3,
	clearance: number,
	patches: { TerrainPatch },
	smoke: { ParticleEmitter },
	fadeAt: number?, -- czas serwera (GetServerTimeNow); nil = gwiazda jeszcze leży
	fadeSeconds: number,
}

type Star = {
	info: StarInfo,
	model: Model?,
	scar: Scar?,
	damageBy: { [number]: number },
	biome: string?,
	expireThread: thread?,
}

type CrackedCallback = (info: StarInfo, damageBy: { [number]: number }) -> ()

local LANDING = StarConfig.LANDING
local SCHEDULE = StarConfig.SCHEDULE
local FALL = StarConfig.FALL
local IMPACT = StarConfig.IMPACT
local CLASSES = StarConfig.CLASSES
local THEMES = StarConfig.THEMES

local CEILING: number = Economy.map.ceiling
local VOXEL = 4
local TICK_SECONDS = 0.5
-- Materiały przypalenia terenu: wyściółka krateru i pasa, żar w środku.
local SCORCH_MATERIAL = Enum.Material.Basalt
local EMBER_MATERIAL = Enum.Material.CrackedLava
local RIM_COLOR = Color3.fromRGB(46, 40, 38)
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local log = Logger.new("StarService")
local rng = Random.new()

local templates: Folder? = nil
local starsFolder: Folder
local scarsFolder: Folder
local rayParams = RaycastParams.new()
local rimParams = RaycastParams.new()

local stars: { [string]: Star } = {}
local scars: { Scar } = {} -- od najstarszego
local nextDropAt: { [string]: number } = {}
local crackedCallbacks: { CrackedCallback } = {}
local rejectMaterials: { [string]: boolean } = {}
local idCounter = 0
local devPaused = false -- tryb dev: pauza harmonogramu (testy wydajności i wycieków)

local StarService = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function newId(): string
	idCounter += 1
	return `S{idCounter}`
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Odległość punktu od odcinka a–b w płaszczyźnie XZ.
local function distanceToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local pa, ba = flat(p - a), flat(b - a)
	local lengthSq = ba:Dot(ba)
	local t = if lengthSq > 0 then math.clamp(pa:Dot(ba) / lengthSq, 0, 1) else 0
	return (pa - ba * t).Magnitude
end

-- Szablon modelu: ServerStorage.Stars/<Rodzaj>/<Rozmiar>. Rodzaje bez modelu nie spadają.
local function getTemplate(typeId: string, sizeId: string): Model?
	if not templates then
		return nil
	end
	local folder = templates:FindFirstChild(typeId)
	local model = folder and folder:FindFirstChild(sizeId)
	return if model and model:IsA("Model") then model else nil
end

local function isEventSize(sizeId: string): boolean
	local class = CLASSES[sizeId]
	return class == nil or class.event
end

local function activeCount(): number
	local count = 0
	for _, star in stars do
		if not isEventSize(star.info.size) then
			count += 1
		end
	end
	return count
end

-- Biom (Theme strefy) pod punktem: części z tagiem StarLandingZone z atrybutami AngleMin/Max, RadiusMin/Max.
-- Kąt = atan2(z, x) w stopniach, jak w generatorze mapy T36.
local function findBiome(pos: Vector3): string?
	local angle = math.deg(math.atan2(pos.Z, pos.X))
	local radius = flat(pos).Magnitude
	for _, zone in CollectionService:GetTagged("StarLandingZone") do
		local theme = zone:GetAttribute("Theme")
		local angleMin = zone:GetAttribute("AngleMin")
		local angleMax = zone:GetAttribute("AngleMax")
		local radiusMin = zone:GetAttribute("RadiusMin")
		local radiusMax = zone:GetAttribute("RadiusMax")
		if
			typeof(theme) ~= "string"
			or typeof(angleMin) ~= "number"
			or typeof(angleMax) ~= "number"
			or typeof(radiusMin) ~= "number"
			or typeof(radiusMax) ~= "number"
		then
			continue
		end
		local offset = (angle - angleMin) % 360
		if offset <= angleMax - angleMin and radius >= radiusMin and radius <= radiusMax then
			return theme
		end
	end
	return nil
end

local function nearPlot(pos: Vector3): boolean
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return false
	end
	for _, plot in plots:GetChildren() do
		if plot:IsA("PVInstance") and flat(plot:GetPivot().Position - pos).Magnitude < LANDING.plotClearance then
			return true
		end
	end
	return false
end

-- Za blisko innej gwiazdy (spadającej lub leżącej) albo śladu (krater + pas, żeby łaty terenu się nie nakładały).
local function tooClose(pos: Vector3, sizeId: string): boolean
	for _, star in stars do
		if flat(star.info.impactPos - pos).Magnitude < LANDING.starSpacing then
			return true
		end
	end
	local reach = StarConfig.craterRadius(sizeId) + VOXEL * 3
	for _, scar in scars do
		if distanceToSegment(pos, scar.impactPos, scar.trailEnd) < scar.clearance + reach then
			return true
		end
	end
	return false
end

-- Losowy punkt na pierścieniu minRadius–maxRadius (równomiernie po powierzchni), raycast w dół na teren.
local function findLandingPoint(sizeId: string): RaycastResult?
	local maxSlopeCos = math.cos(math.rad(LANDING.maxSlopeDeg))
	local minSq, maxSq = LANDING.minRadius ^ 2, LANDING.maxRadius ^ 2
	for _ = 1, LANDING.maxTries do
		local theta = rng:NextNumber(0, 2 * math.pi)
		local radius = math.sqrt(rng:NextNumber(minSq, maxSq))
		local origin = Vector3.new(math.cos(theta) * radius, CEILING - 5, math.sin(theta) * radius)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -(CEILING + 400), 0), rayParams)
		if
			hit
			and hit.Instance == Workspace.Terrain
			and not rejectMaterials[hit.Material.Name]
			and hit.Normal.Y >= maxSlopeCos
			and not nearPlot(hit.Position)
			and not tooClose(hit.Position, sizeId)
		then
			return hit
		end
	end
	return nil
end

-- Rodzaj gwiazdy: waga z Themes.json (przesunięta rareTypeBoost), ×biomeTypeBoost dla pasującego biomu.
local function pickType(sizeId: string, biome: string?): string?
	local total = 0
	local options: { { id: string, weight: number } } = {}
	for _, typeId in StarConfig.THEME_ORDER do
		local theme = THEMES[typeId]
		if theme.eventOnly or not getTemplate(typeId, sizeId) then
			continue
		end
		local weight = StarConfig.typeWeight(typeId, sizeId)
		if biome and theme.zone == biome then
			weight *= LANDING.biomeTypeBoost
		end
		if weight > 0 then
			total += weight
			table.insert(options, { id = typeId, weight = weight })
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber(0, total)
	for _, option in options do
		roll -= option.weight
		if roll <= 0 then
			return option.id
		end
	end
	return options[#options].id
end

local function voxelCenter(region: Region3, x: number, y: number, z: number): Vector3
	local corner = region.CFrame.Position - region.Size / 2
	return corner + Vector3.new(x - 0.5, y - 0.5, z - 0.5) * VOXEL
end

-- Zapisuje zmianę voxela (oryginał do odtworzenia) i ustawia nowy materiał/wypełnienie w tablicach.
local function setVoxel(
	changes: { VoxelChange },
	materials: any,
	occupancies: any,
	x: number,
	y: number,
	z: number,
	material: Enum.Material,
	occupancy: number
)
	local oldMaterial: Enum.Material = materials[x][y][z]
	local oldOccupancy: number = occupancies[x][y][z]
	if oldMaterial == material and oldOccupancy == occupancy then
		return
	end
	table.insert(changes, {
		x = x,
		y = y,
		z = z,
		oldMaterial = oldMaterial,
		oldOccupancy = oldOccupancy,
		newMaterial = material,
	})
	materials[x][y][z] = material
	occupancies[x][y][z] = occupancy
end

-- Krater w terenie: dla dużych (digTerrainFromSize+) wykopana misa wyłożona bazaltem z żarem w środku,
-- dla małych tylko przypalona powierzchnia. Zwraca łatę do odtworzenia.
local function scorchCrater(impactPos: Vector3, radius: number, dig: boolean): TerrainPatch?
	local terrain = Workspace.Terrain
	-- Misa: kula o promieniu krateru, głębokość dna = radius × digBowlDepth pod gruntem.
	local ballCenter = impactPos + Vector3.yAxis * (radius * (1 - IMPACT.digBowlDepth))
	local reach = radius + VOXEL * 2
	local region = Region3.new(ballCenter - Vector3.one * reach, ballCenter + Vector3.one * reach):ExpandToGrid(VOXEL)
	local materials, occupancies = terrain:ReadVoxels(region, VOXEL)
	local size = materials.Size :: Vector3
	local changes: { VoxelChange } = {}
	for x = 1, size.X do
		for z = 1, size.Z do
			-- Idziemy od góry kolumny: pierwszy pełny voxel = powierzchnia.
			local surfaceFound = false
			for y = size.Y, 1, -1 do
				local occupancy: number = occupancies[x][y][z]
				if occupancy <= 0 then
					continue
				end
				local pos = voxelCenter(region, x, y, z)
				local fromBall = (pos - ballCenter).Magnitude
				local fromImpact = flat(pos - impactPos).Magnitude
				if dig and fromBall < radius then
					setVoxel(changes, materials, occupancies, x, y, z, Enum.Material.Air, 0)
					continue
				end
				if not surfaceFound then
					surfaceFound = true
					local edge = if dig then radius + VOXEL * 1.5 else radius + VOXEL
					if fromImpact < edge then
						local material = if fromImpact < radius * 0.35 then EMBER_MATERIAL else SCORCH_MATERIAL
						setVoxel(changes, materials, occupancies, x, y, z, material, occupancy)
					end
				end
			end
		end
	end
	if #changes == 0 then
		return nil
	end
	terrain:WriteVoxels(region, VOXEL, materials, occupancies)
	return { region = region, changes = changes }
end

-- Kolumny, których pas przelotu nie rusza: blisko lobby/działek i w kraterach innych śladów
-- (łaty terenu nie mogą się nakładać na wykopane misy, inaczej odtworzenie zostawi dziurę).
local function skipColumn(pos: Vector3): boolean
	if flat(pos).Magnitude < LANDING.minRadius - LANDING.plotClearance then
		return true
	end
	for _, scar in scars do
		if flat(pos - scar.impactPos).Magnitude < scar.clearance then
			return true
		end
	end
	return false
end

-- Pas przelotu: przypalona powierzchnia wzdłuż toru lotu (od krateru w stronę, z której przyleciała gwiazda).
local function scorchTrail(fromPos: Vector3, toPos: Vector3, startWidth: number, endWidth: number): TerrainPatch?
	local terrain = Workspace.Terrain
	local low = fromPos:Min(toPos) - Vector3.new(startWidth, 40, startWidth)
	local high = fromPos:Max(toPos) + Vector3.new(startWidth, 40, startWidth)
	local region = Region3.new(low, high):ExpandToGrid(VOXEL)
	local materials, occupancies = terrain:ReadVoxels(region, VOXEL)
	local size = materials.Size :: Vector3
	local along = flat(toPos - fromPos)
	local length = along.Magnitude
	if length <= 0 then
		return nil
	end
	local dir = along / length
	local changes: { VoxelChange } = {}
	for x = 1, size.X do
		for z = 1, size.Z do
			local column = voxelCenter(region, x, 1, z)
			local rel = flat(column - fromPos)
			local t = rel:Dot(dir) / length
			if t < 0 or t > 1 then
				continue
			end
			local halfWidth = (startWidth + (endWidth - startWidth) * t) / 2
			if (rel - dir * rel:Dot(dir)).Magnitude > halfWidth or skipColumn(column) then
				continue
			end
			for y = size.Y, 1, -1 do
				local occupancy: number = occupancies[x][y][z]
				if occupancy > 0 then
					local material: Enum.Material = materials[x][y][z]
					if material ~= Enum.Material.Water then
						setVoxel(changes, materials, occupancies, x, y, z, SCORCH_MATERIAL, occupancy)
					end
					break
				end
			end
		end
	end
	if #changes == 0 then
		return nil
	end
	terrain:WriteVoxels(region, VOXEL, materials, occupancies)
	return { region = region, changes = changes }
end

-- Odtwarza teren łaty. Voxel wraca do oryginału tylko, jeśli nikt go od tego czasu nie zmienił.
local function restorePatch(patch: TerrainPatch)
	local terrain = Workspace.Terrain
	local materials, occupancies = terrain:ReadVoxels(patch.region, VOXEL)
	for _, change in patch.changes do
		if materials[change.x][change.y][change.z] == change.newMaterial then
			materials[change.x][change.y][change.z] = change.oldMaterial
			occupancies[change.x][change.y][change.z] = change.oldOccupancy
		end
	end
	terrain:WriteVoxels(patch.region, VOXEL, materials, occupancies)
end

local function groundAt(pos: Vector3): RaycastResult?
	return Workspace:Raycast(pos + Vector3.yAxis * 60, Vector3.yAxis * -160, rimParams)
end

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanTouch = false
	part.CanQuery = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Odłamek wału: mesh skały z ReplicatedStorage.VfxAssets (T38), a gdy go brak — klocek.
local function rimChunk(chunkSize: number, cframe: CFrame): BasePart
	local assets = ReplicatedStorage:FindFirstChild("VfxAssets")
	local rocks = {}
	if assets then
		for _, child in assets:GetChildren() do
			if child:IsA("MeshPart") and string.sub(child.Name, 1, 5) == "Rock_" then
				table.insert(rocks, child)
			end
		end
	end
	if #rocks == 0 then
		return makePart(
			"Rim",
			Vector3.new(chunkSize * 1.1, chunkSize * 0.7, chunkSize),
			cframe,
			RIM_COLOR,
			Enum.Material.Basalt
		)
	end
	local template = rocks[rng:NextInteger(1, #rocks)]
	local rock = template:Clone()
	rock.Name = "Rim"
	rock.Size = template.Size * (chunkSize / math.max(template.Size.X, template.Size.Y, template.Size.Z)) * 1.3
	rock.CFrame = cframe
	rock.Color = RIM_COLOR
	rock.Material = Enum.Material.Basalt
	rock.Anchored = true
	rock.CanTouch = false
	rock.CanQuery = false
	rock.CastShadow = true
	return rock
end

-- Wał z odłamków wokół krateru, żarzące się okruchy i dym. Części są statyczne; animacje robi klient (T12).
local function buildDebris(scar: Scar, info: StarInfo, radius: number)
	local class = CLASSES[info.size]
	local glow = StarConfig.glow(info.type)
	local chunks = IMPACT.rimChunks[info.size] or 8
	for index = 1, chunks do
		local angle = (index / chunks) * 2 * math.pi + rng:NextNumber(-0.2, 0.2)
		local ring = radius * rng:NextNumber(0.9, 1.15)
		local around = info.impactPos + Vector3.new(math.cos(angle) * ring, 0, math.sin(angle) * ring)
		local ground = groundAt(around)
		if not ground then
			continue
		end
		local chunkSize = class.size * rng:NextNumber(0.14, 0.26)
		local outward = flat(around - info.impactPos).Unit
		local cframe = CFrame.lookAlong(ground.Position, outward)
			* CFrame.Angles(math.rad(rng:NextNumber(-40, -20)), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.4, 0.4))
		local chunk = rimChunk(chunkSize, cframe)
		chunk.CanCollide = chunkSize > 2.5
		chunk.Parent = scar.folder
		-- co drugi odłamek ma żarzący się okruch
		if index % 2 == 0 then
			local ember = makePart(
				"Ember",
				Vector3.one * math.max(0.4, chunkSize * 0.25),
				cframe
					* CFrame.new(0, chunkSize * 0.35, 0)
					* CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0),
				glow,
				Enum.Material.Neon
			)
			ember.CanCollide = false
			ember.CastShadow = false
			ember.Parent = scar.folder
		end
	end

	-- Dym: niewidoczna część w środku krateru z emiterem; wyłączany po smokeSeconds.
	local holder = makePart("Smoke", Vector3.one, CFrame.new(info.impactPos), RIM_COLOR, Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CastShadow = false
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Smoke"
	emitter.Texture = SMOKE_TEXTURE
	emitter.Color = ColorSequence.new(Color3.fromRGB(70, 64, 62), Color3.fromRGB(150, 146, 144))
	emitter.Rate = math.min(4 + class.size * 0.25, 18)
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Speed = NumberRange.new(class.size * 0.15, class.size * 0.3)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Acceleration = Vector3.new(0, class.size * 0.05, 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, class.size * 0.25),
		NumberSequenceKeypoint.new(1, class.size * 0.9),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.RotSpeed = NumberRange.new(-30, 30)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.LightInfluence = 1
	emitter.Parent = holder
	holder.Parent = scar.folder
	table.insert(scar.smoke, emitter)
	task.delay(IMPACT.smokeSeconds, function()
		emitter.Enabled = false
	end)
end

local function removeScar(scar: Scar)
	local index = table.find(scars, scar)
	if index then
		table.remove(scars, index)
	end
	for _, patch in scar.patches do
		local ok, err = pcall(restorePatch, patch)
		if not ok then
			log:warn(`Odtworzenie terenu {scar.id}: {err}`)
		end
	end
	scar.folder:Destroy()
end

-- Limit śladów: usuwamy najstarsze, których gwiazda już zniknęła (ślad pod leżącą gwiazdą zostaje).
local function trimScars()
	while #scars >= IMPACT.maxScars do
		local oldest: Scar? = nil
		for _, scar in scars do
			if scar.fadeAt then
				oldest = scar
				break
			end
		end
		if not oldest then
			return
		end
		removeScar(oldest)
	end
end

local function createScar(info: StarInfo): Scar
	trimScars()
	local class = CLASSES[info.size]
	local radius = StarConfig.craterRadius(info.size)
	local folder = Instance.new("Folder")
	folder.Name = info.id
	local back = flat(info.startPos - info.impactPos).Unit
	local trailEnd = info.impactPos + back * (class.size * IMPACT.trailLengthMult)
	local scar: Scar = {
		id = info.id,
		folder = folder,
		impactPos = info.impactPos,
		trailEnd = trailEnd,
		clearance = radius + VOXEL * 2,
		patches = {},
		smoke = {},
		fadeAt = nil,
		fadeSeconds = IMPACT.scarFadeSeconds,
	}

	local ok, cratePatch = pcall(scorchCrater, info.impactPos, radius, StarConfig.digsTerrain(info.size))
	if ok then
		if cratePatch then
			table.insert(scar.patches, cratePatch)
		end
	else
		log:warn(`Krater {info.id}: {cratePatch}`)
	end
	local trailOk, trailPatch = pcall(scorchTrail, info.impactPos, trailEnd, radius * 1.4, radius * 0.4)
	if trailOk then
		if trailPatch then
			table.insert(scar.patches, trailPatch)
		end
	else
		log:warn(`Pas przelotu {info.id}: {trailPatch}`)
	end

	buildDebris(scar, info, radius)
	folder.Parent = scarsFolder
	table.insert(scars, scar)
	return scar
end

local function startScarFade(scar: Scar)
	if scar.fadeAt then
		return
	end
	local fadeAt = now() + IMPACT.scarSeconds * StarConfig.TIME_SCALE
	scar.fadeAt = fadeAt
	scar.fadeSeconds = IMPACT.scarFadeSeconds * StarConfig.TIME_SCALE
	-- Klient blednie części od FadeAt przez FadeSeconds; serwer usuwa ślad i odtwarza teren po tym czasie.
	scar.folder:SetAttribute("FadeAt", fadeAt)
	scar.folder:SetAttribute("FadeSeconds", scar.fadeSeconds)
end

local function publicInfo(star: Star): StarInfo
	return table.clone(star.info)
end

local function finish(star: Star, reason: "Cracked" | "Expired")
	local info = star.info
	if info.state == "Dying" or stars[info.id] ~= star then
		return
	end
	info.state = "Dying"
	if star.expireThread and coroutine.status(star.expireThread) == "suspended" then
		task.cancel(star.expireThread)
	end
	local model = star.model
	if model then
		-- EndReason przed State: klient czyta powód w reakcji na zmianę State.
		model:SetAttribute("EndReason", reason)
		model:SetAttribute("State", "Dying")
	end
	log:info(`{StarConfig.displayName(info.size, info.type)} {info.id}: {reason}`)
	Remotes.fireAllClients("StarEvent", "Gone", { id = info.id, reason = reason })
	if reason == "Cracked" then
		local share = table.clone(star.damageBy)
		for _, callback in crackedCallbacks do
			task.spawn(callback, publicInfo(star), share)
		end
	end
	task.delay(SCHEDULE.dyingSeconds, function()
		if model then
			model:Destroy()
		end
		stars[info.id] = nil
		if star.scar then
			startScarFade(star.scar)
		end
	end)
end

-- Uderzenie: model wbity na embedDepth wysokości, przechylony wzdłuż toru lotu; krater i ślad.
local function land(star: Star)
	local info = star.info
	if stars[info.id] ~= star or info.state ~= "Falling" then
		return
	end
	local template = getTemplate(info.type, info.size)
	if not template then
		log:warn(`Brak modelu {info.type}/{info.size} przy lądowaniu`)
		stars[info.id] = nil
		Remotes.fireAllClients("StarEvent", "Gone", { id = info.id, reason = "Expired" })
		return
	end
	local class = CLASSES[info.size]

	star.scar = createScar(info)

	local flightDir = (info.impactPos - info.startPos).Unit
	local up = (info.normal - flightDir).Unit -- pochylona w stronę, z której przyleciała
	-- Wbicie liczone od pierwotnego gruntu; dno misy (digBowlDepth) jest płycej niż spód gwiazdy.
	local center = info.impactPos + up * (class.size * (0.5 - IMPACT.embedDepth))
	local side = up:Cross(Vector3.new(rng:NextNumber(-1, 1), 0.01, rng:NextNumber(-1, 1)))
	if side.Magnitude < 1e-3 then
		side = up:Cross(Vector3.xAxis)
	end
	local right = side.Unit
	local cframe = CFrame.fromMatrix(center, right, up)

	local model = template:Clone()
	model.Name = info.id
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:PivotTo(cframe)
	model:SetAttribute("StarId", info.id)
	model:SetAttribute("Size", info.size)
	model:SetAttribute("Type", info.type)
	model:SetAttribute("Hp", info.hp)
	model:SetAttribute("MaxHp", info.maxHp)
	model:SetAttribute("State", "Landed")
	local expiresAt = now() + class.lifetime
	model:SetAttribute("ExpiresAt", expiresAt)
	model.Parent = starsFolder

	star.model = model
	info.state = "Landed"
	info.expiresAt = expiresAt
	Remotes.fireAllClients("StarEvent", "Landed", publicInfo(star))
	star.expireThread = task.delay(class.lifetime, function()
		star.expireThread = nil
		finish(star, "Expired")
	end)
end

-- Zrzuca gwiazdę danego rozmiaru. typeId/pos opcjonalnie (event, tryb dev). Zwraca id albo nil.
function StarService.drop(sizeId: string, typeId: string?, pos: Vector3?): string?
	local class = CLASSES[sizeId]
	if not class then
		log:warn(`Nieznany rozmiar gwiazdy {sizeId}`)
		return nil
	end
	local impactPos: Vector3
	local normal = Vector3.yAxis
	if pos then
		local hit = groundAt(pos)
		impactPos = if hit then hit.Position else pos
		normal = if hit then hit.Normal else normal
	else
		local hit = findLandingPoint(sizeId)
		if not hit then
			log:debug(`Brak miejsca do lądowania ({sizeId})`)
			return nil
		end
		impactPos, normal = hit.Position, hit.Normal
	end
	local biome = findBiome(impactPos)
	local chosen = if typeId and getTemplate(typeId, sizeId) then typeId else pickType(sizeId, biome)
	if not chosen then
		log:debug(`Brak modelu dla rozmiaru {sizeId}`)
		return nil
	end

	local yaw = rng:NextNumber(0, 2 * math.pi)
	local tilt = math.rad(rng:NextNumber(FALL.angleMinDeg, FALL.angleMaxDeg))
	local horizontal = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
	local startPos = impactPos + horizontal * (FALL.startHeight * math.tan(tilt)) + Vector3.yAxis * FALL.startHeight
	local launchedAt = now()

	local info: StarInfo = {
		id = newId(),
		size = sizeId,
		type = chosen,
		state = "Falling",
		startPos = startPos,
		impactPos = impactPos,
		normal = normal,
		launchedAt = launchedAt,
		impactAt = launchedAt + class.warning,
		expiresAt = nil,
		hp = class.hp,
		maxHp = class.hp,
	}
	local star: Star = { info = info, model = nil, scar = nil, damageBy = {}, biome = biome }
	stars[info.id] = star
	log:info(
		`Spada {StarConfig.displayName(sizeId, chosen)} {info.id} w {math.round(impactPos.X)}, {math.round(impactPos.Z)} (biom {biome or "-"}, za {class.warning} s)`
	)
	Remotes.fireAllClients("StarEvent", "Incoming", publicInfo(star))
	task.delay(class.warning, land, star)
	return info.id
end

-- Obrażenia od CrackService (już zwalidowane: odległość, cooldown, narzędzie). Zwraca zadane HP.
function StarService.damage(userId: number, starId: string, amount: number): number
	local star = stars[starId]
	if not star or star.info.state ~= "Landed" or amount ~= amount or amount <= 0 or amount == math.huge then
		return 0
	end
	local info = star.info
	local applied = math.min(amount, info.hp)
	info.hp -= applied
	star.damageBy[userId] = (star.damageBy[userId] or 0) + applied
	if star.model then
		star.model:SetAttribute("Hp", info.hp)
	end
	if info.hp <= 0 then
		finish(star, "Cracked")
	end
	return applied
end

-- Dane gwiazdy dla innych serwisów (CrackService: strefy = Attachmenty Zone_N na model.PrimaryPart).
function StarService.getStar(starId: string): (StarInfo?, Model?)
	local star = stars[starId]
	if not star then
		return nil, nil
	end
	return publicInfo(star), star.model
end

-- LootService: wołane po rozbiciu z kopią damageBy[userId] = obrażenia.
function StarService.onCracked(callback: CrackedCallback)
	table.insert(crackedCallbacks, callback)
end

function StarService.expire(starId: string)
	local star = stars[starId]
	if star and star.info.state == "Landed" then
		finish(star, "Expired")
	end
end

local function listActive(): { StarInfo }
	local list = {}
	for _, star in stars do
		if star.info.state ~= "Dying" then
			table.insert(list, publicInfo(star))
		end
	end
	return list
end

local function interval(class: StarConfig.SizeClass): number
	return rng:NextNumber(class.intervalMin, class.intervalMax) * StarConfig.TIME_SCALE
end

local function tick()
	local clock = os.clock()
	for sizeId, dueAt in nextDropAt do
		if devPaused or clock < dueAt then
			continue
		end
		local class = CLASSES[sizeId]
		if activeCount() >= SCHEDULE.maxActive then
			nextDropAt[sizeId] = clock + SCHEDULE.retryDelay
			continue
		end
		local ok, result = pcall(StarService.drop, sizeId)
		if not ok then
			log:error(`Spadek {sizeId}: {result}`)
		end
		nextDropAt[sizeId] = clock + if ok and result then interval(class) else SCHEDULE.retryDelay
	end

	local serverNow = now()
	for index = #scars, 1, -1 do
		local scar = scars[index]
		if scar.fadeAt and serverNow >= scar.fadeAt + scar.fadeSeconds then
			removeScar(scar)
		end
	end
end

-- Tryb dev (tylko Studio): ServerStorage.DevStar:Invoke(akcja, ...) — "drop"(rozmiar, rodzaj?, Vector3?),
-- "damage"(id, ile), "expire"(id), "list"(), "scars"(), "pause"(bool).
local function setupDev()
	local bindable = Instance.new("BindableFunction")
	bindable.Name = "DevStar"
	bindable.OnInvoke = function(action: string, a: any, b: any, c: any): any
		if action == "drop" then
			return StarService.drop(a, b, c)
		elseif action == "damage" then
			return StarService.damage(0, a, b)
		elseif action == "expire" then
			StarService.expire(a)
			return true
		elseif action == "list" then
			return listActive()
		elseif action == "scars" then
			return #scars
		elseif action == "pause" then
			devPaused = a == true
			return devPaused
		end
		return nil
	end
	bindable.Parent = ServerStorage
	log:info(`Tryb dev: czasy ×{StarConfig.TIME_SCALE}, ServerStorage.DevStar`)
end

function StarService.Init()
	for _, name in LANDING.rejectMaterials do
		rejectMaterials[name] = true
	end

	local found = ServerStorage:FindFirstChild("Stars")
	if found and found:IsA("Folder") then
		templates = found
		-- Kopia dla klientów: w locie (T38) klient pokazuje prawdziwy model gwiazdy.
		local visuals = found:Clone()
		visuals.Name = "StarVisuals"
		visuals.Parent = ReplicatedStorage
	else
		log:error("Brak ServerStorage.Stars — gwiazdy nie będą spadać")
	end

	starsFolder = Instance.new("Folder")
	starsFolder.Name = "ActiveStars"
	starsFolder.Parent = Workspace
	scarsFolder = Instance.new("Folder")
	scarsFolder.Name = "StarScars"
	scarsFolder.Parent = Workspace

	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = false
	rayParams.FilterDescendantsInstances = { starsFolder, scarsFolder }
	rimParams.FilterType = Enum.RaycastFilterType.Exclude
	rimParams.IgnoreWater = true
	rimParams.FilterDescendantsInstances = { starsFolder, scarsFolder }

	Remotes.onInvoke("RequestStars", function()
		return listActive()
	end)

	if StarConfig.IS_DEV then
		setupDev()
	end
end

function StarService.Start()
	local clock = os.clock()
	for _, sizeId in StarConfig.SIZE_ORDER do
		local class = CLASSES[sizeId]
		if not class.event then
			nextDropAt[sizeId] = clock + interval(class)
		end
	end
	if nextDropAt[SCHEDULE.firstDropSize] then
		nextDropAt[SCHEDULE.firstDropSize] = clock + SCHEDULE.firstDropDelay
	end
	task.spawn(function()
		while true do
			task.wait(TICK_SECONDS)
			local ok, err = pcall(tick)
			if not ok then
				log:error(`tick: {err}`)
			end
		end
	end)
end

return StarService
