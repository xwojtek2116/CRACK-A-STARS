--!strict
-- Import gwiazd v2 (T40) — ModuleScript w ServerStorage.StarImportV2 (wstawiany przez execute_luau, nie przez Rojo).
-- Wołanie: require(ServerStorage.StarImportV2)(typeId, look) po wstawieniu FBX art/stars/<rodzaj>/star_<rodzaj>_v2.fbx
-- jako ServerStorage.StarV2Import (insert_asset). Buduje ServerStorage.Stars.<Rodzaj>/<Small|Medium|Large|Huge|Supernova>
-- w tej samej hierarchii co Toxic v2 (import_toxic_v2.luau). Kotwice i strefy liczy z geometrii (raycasty w Studio),
-- więc nie potrzebuje JSON-a z Blendera. Stary model rodzaju → ServerStorage.StarsBackup.<Rodzaj>_v1.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local StarConfig = require(ReplicatedStorage.Shared.Config.StarConfig)

export type Look = {
	shellMat: string, -- Enum.Material
	rock: string,
	ground: string,
	coreColor: string?,
	glass: boolean?,
}

local SIZES_ORDER = { "Small", "Medium", "Large", "Huge", "Supernova" }
local PIVOT_HEIGHT = { Small = 0.16, Medium = 0.16, Large = 0.25, Huge = 0.25, Supernova = 0.25 }
local CRATER_FLOOR = 0.149 -- środek bbox krateru nad dnem (jednostki modelu)

local function style(p: BasePart, material: Enum.Material, color: Color3, collide: boolean)
	p.Anchored = true
	p.Material = material
	p.Color = color
	p.CanCollide = collide
	p.CanTouch = false
	p.CanQuery = collide
	p.CastShadow = material ~= Enum.Material.Neon and material ~= Enum.Material.ForceField
	if p:IsA("MeshPart") then
		p.RenderFidelity = Enum.RenderFidelity.Automatic
		pcall(function()
			p.CollisionFidelity = if collide then Enum.CollisionFidelity.Hull else Enum.CollisionFidelity.Box
		end)
	end
end

local function farthest(points: { Vector3 }, k: number): { Vector3 }
	if #points == 0 then
		return {}
	end
	local best = points[1]
	for _, p in points do
		if p.Y > best.Y then
			best = p
		end
	end
	local chosen = { best }
	while #chosen < math.min(k, #points) do
		local far, farD = points[1], -1
		for _, p in points do
			local d = math.huge
			for _, c in chosen do
				d = math.min(d, (p - c).Magnitude)
			end
			if d > farD then
				far, farD = p, d
			end
		end
		table.insert(chosen, far)
	end
	return chosen
end

return function(typeId: string, look: Look): string
	local src = ServerStorage:FindFirstChild("StarV2Import") :: Model
	assert(src, "Brak ServerStorage.StarV2Import")
	local neon = StarConfig.color(typeId)
	local glow = if look.coreColor then Color3.fromHex(look.coreColor) else StarConfig.glow(typeId)
	local crystalColor = neon:Lerp(Color3.new(0, 0, 0), 0.18)
	local rock = Color3.fromHex(look.rock)
	local ground = Color3.fromHex(look.ground)
	local shellMat = (Enum.Material :: any)[look.shellMat] :: Enum.Material
	local rng = Random.new(#typeId * 97)

	-- Rama: środek krateru = origin, przód = od środka krateru do środka kęp CrystalA/B.
	local function frameFor(prefix: string): CFrame
		local crater = src:FindFirstChild(prefix .. "_Crater", true) :: BasePart
		local a = src:FindFirstChild(prefix .. "_CrystalA", true) :: BasePart
		local b = src:FindFirstChild(prefix .. "_CrystalB", true) :: BasePart
		local origin = crater.Position - Vector3.new(0, CRATER_FLOOR, 0)
		local mid = (a.Position + b.Position) / 2 - origin
		local front = Vector3.new(mid.X, 0, mid.Z).Unit
		-- przód gwiazdy = −Z lokalnie (LookVector)
		return CFrame.lookAt(origin, origin + front)
	end

	local function build(sizeId: string, prefix: string): Model
		local frame = frameFor(prefix)
		local inv = frame:Inverse()
		local model = Instance.new("Model")
		model.Name = sizeId
		local function take(name: string): MeshPart?
			local p = src:FindFirstChild(prefix .. "_" .. name, true) :: MeshPart?
			if not p then
				return nil
			end
			local c = p:Clone()
			c.Name = name
			c.CFrame = inv * p.CFrame
			return c
		end

		local main = Instance.new("Model")
		main.Name = "MainBody"
		main.Parent = model
		for i = 1, 6 do
			local n = string.format("%02d", i)
			local shell = take("Shell" .. n)
			if shell then
				style(shell, shellMat, rock, true)
				if look.glass then
					shell.Transparency = 0.25
				end
				shell.Parent = main
				local veins = take("CrackVeins" .. n)
				if veins then
					style(veins, Enum.Material.Neon, neon, false)
					veins.Parent = shell
				end
			end
		end
		local core = take("Core") :: MeshPart
		style(core, Enum.Material.Neon, glow, false)
		core.Parent = model
		local coreShell = take("CoreShell")
		if coreShell then
			style(coreShell, Enum.Material.ForceField, neon, false)
			coreShell.Parent = core
		end
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = if look.coreColor then neon else glow
		light.Brightness = 2
		light.Range = 3
		light.Shadows = false
		light.Parent = core

		local crystals = Instance.new("Model")
		crystals.Name = "Crystals"
		crystals.Parent = model
		for _, name in { "CrystalA", "CrystalB", "CrystalC", "CrystalG01", "CrystalG02", "CrystalG03", "CrystalG04" } do
			local c = take(name)
			if c then
				style(c, Enum.Material.Neon, crystalColor, false)
				c.Transparency = 0.08
				c.Parent = crystals
			end
		end
		local slime = take("Slime")
		if slime then
			style(slime, Enum.Material.Neon, neon, false)
			slime.Parent = model
		end
		local crater = take("Crater") :: MeshPart
		style(crater, shellMat == Enum.Material.Glass and Enum.Material.Rock or shellMat, ground, false)
		if shellMat == Enum.Material.Ice or shellMat == Enum.Material.Glacier then
			crater.Material = Enum.Material.Snow
		end
		crater.Parent = model
		for _, name in { "CraterVeins", "GroundCracks" } do
			local c = take(name)
			if c then
				style(c, Enum.Material.Neon, neon, false)
				c.Parent = crater
			end
		end
		local debris = Instance.new("Model")
		debris.Name = "FloatingDebris"
		debris.Parent = model
		for _, name in { "FloatingRock01", "FloatingRock02", "FloatingRock03", "FloatingCrystal01", "FloatingCrystal02" } do
			local c = take(name)
			if c then
				if name:find("Crystal") then
					style(c, Enum.Material.Neon, crystalColor, false)
				else
					style(c, shellMat, rock, false)
				end
				c.Parent = debris
			end
		end

		local bodyCf, bodySize = main:GetBoundingBox()
		local hitbox = Instance.new("Part")
		hitbox.Name = "Hitbox"
		hitbox.Size = bodySize * 0.85
		hitbox.CFrame = bodyCf
		hitbox.Transparency = 1
		hitbox.Anchored = true
		hitbox.CanCollide = false
		hitbox.CanTouch = false
		hitbox.CanQuery = true
		hitbox.CastShadow = false
		hitbox.Parent = model
		model.PrimaryPart = hitbox

		-- Kotwice i strefy z geometrii: promienie z zewnątrz do rdzenia (przód i góra), trafienia w skorupę.
		model.Parent = workspace -- raycast wymaga części w świecie
		core.CanQuery = true -- strefy mogą leżeć na rdzeniu
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { main, core } -- duży rdzeń (Nebula, Ringed, Void) też jest celem
		local corePos = core.Position
		local hits = {}
		for _ = 1, 300 do
			if #hits >= 14 then
				break
			end
			local az = rng:NextNumber(0, math.pi * 2)
			local el = rng:NextNumber(-0.1, 0.9)
			local d = Vector3.new(math.cos(az) * math.cos(el), math.sin(el), math.sin(az) * math.cos(el))
			if d.Z > 0.6 then
				continue -- tył
			end
			local result = workspace:Raycast(corePos + d * 6, -d * 6, params)
			if result then
				table.insert(hits, result.Position + result.Normal * 0.02)
			end
		end
		model.Parent = nil
		core.CanQuery = false
		if #hits == 0 then
			table.insert(hits, corePos)
		end
		local coreR = core.Size.X * 0.5
		local anchors: { [string]: Vector3 } = {
			ANCHOR_Core = corePos,
			ANCHOR_Shockwave = Vector3.new(0, 0.06, 0),
			ANCHOR_Particles = corePos + Vector3.new(0, coreR + 0.4, 0),
			ANCHOR_Drip_01 = corePos + Vector3.new(-0.16, -coreR - 0.3, -0.3),
			ANCHOR_Drip_02 = corePos + Vector3.new(0, -coreR - 0.5, -0.35),
			ANCHOR_Drip_03 = corePos + Vector3.new(0.13, -coreR - 0.35, -0.32),
		}
		for i = 1, math.min(3, #hits) do
			anchors[string.format("ANCHOR_Cracks_%02d", i)] = hits[i]
		end
		for name, pos in anchors do
			local a = Instance.new("Attachment")
			a.Name = name
			a.Position = hitbox.CFrame:PointToObjectSpace(pos)
			a.Parent = hitbox
		end
		local zones = farthest(hits, 12)
		local count = StarConfig.CLASSES[sizeId] and (StarConfig.CLASSES[sizeId] :: any).zones or 1
		for i = 1, math.min(count, #zones) do
			local a = Instance.new("Attachment")
			a.Name = "Zone_" .. i
			a.Position = hitbox.CFrame:PointToObjectSpace(zones[i])
			a.Parent = hitbox
		end

		local width = math.max(bodySize.X, bodySize.Z)
		local size = StarConfig.CLASSES[sizeId].size
		model.WorldPivot = CFrame.new(0, width * PIVOT_HEIGHT[sizeId], 0)
		local scale = size / width
		model:ScaleTo(scale)
		light.Range = size * 0.9
		model:SetAttribute("VisualV2", true)
		model:SetAttribute("Upright", true)
		model:SetAttribute("StudsPerUnit", scale)
		model:SetAttribute("BodyWidth", size)
		return model
	end

	local stars = ServerStorage:FindFirstChild("Stars") :: Folder
	local old = stars:FindFirstChild(typeId)
	if old and not old:GetAttribute("VisualV2") then
		local backup = ServerStorage:FindFirstChild("StarsBackup") or Instance.new("Folder")
		backup.Name = "StarsBackup"
		backup.Parent = ServerStorage
		old.Name = typeId .. "_v1"
		old.Parent = backup
	elseif old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = typeId
	folder:SetAttribute("VisualV2", true)
	local report = {}
	for _, sizeId in SIZES_ORDER do
		if StarConfig.CLASSES[sizeId] then
			local m = build(sizeId, if sizeId == "Small" then "Small" else "Large")
			m:PivotTo(CFrame.new(0, 0, 0))
			m.Parent = folder
			table.insert(report, `{sizeId} z{#m.Hitbox:GetChildren() - 9}`)
		end
	end
	folder.Parent = stars
	src:Destroy()
	return typeId .. ": " .. table.concat(report, ", ")
end
