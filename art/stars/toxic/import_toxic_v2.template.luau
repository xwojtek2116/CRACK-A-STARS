--!strict
-- Import Toxic Star v2 (T40). Szablon: art/stars/toxic/import_toxic_v2.template.luau,
-- gotowy skrypt generuje art/stars/toxic/make_import.py (wstawia toxic_v2_anchors.json).
-- Wejście: ServerStorage.ToxicV2Import (FBX star_toxic_v2.fbx przez insert_asset; części Large_* i Small_*).
-- Wyjście: ServerStorage.Stars.Toxic/<Small|Medium|Large|Huge> (Model, PrimaryPart = Hitbox, atrybuty VisualV2, Upright),
-- stary Toxic (v1) → ServerStorage.StarsBackup.Toxic_v1. Hierarchia: vault/02 Systemy/Toxic Star v2 - specyfikacja produkcyjna.md.
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local DATA = HttpService:JSONDecode([==[__ANCHORS__]==])
local SIZES = HttpService:JSONDecode([==[__SIZES__]==]) -- { Small = 6, ... }
local COLOR = HttpService:JSONDecode([==[__COLORS__]==]) -- color, glow
local ROCK = Color3.fromHex("#3B3842")
local GROUND = Color3.fromHex("#46434C")
local NEON = Color3.fromHex(COLOR.color)
local GLOW = Color3.fromHex("#A6FF3D") -- rdzeń: zielony, theme glow (#D9FF5C) przepala się na żółto
local CRYSTAL = Color3.fromHex("#3FCF1A")
-- Wysokość pivotu nad dnem krateru (× wymiar skorupy): StarService stawia pivot 0,15 × size nad punktem uderzenia,
-- Large+ mają misę w terenie (dno ~0,24 × size niżej); dno modelu 0,1 × size pod gruntem, żeby gwiazda wystawała.
local PIVOT_HEIGHT = { Small = 0.16, Medium = 0.16, Large = 0.25, Huge = 0.25 }

local src = ServerStorage:FindFirstChild("ToxicV2Import") :: Model
assert(src, "Brak ServerStorage.ToxicV2Import")

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- Rama importu: FBX wstawia się z dowolnym obrotem wokół Y. Lokalne = Roblox (−x, z, y) z Blendera.
-- Rdzeń: lokalnie (0, 1.15, −0.2); kierunek rdzeń → środek CrystalC (bbox) lokalnie (−0.025, 1.644, 0.735).
local function frameFor(prefix: string): CFrame
	local core = src:FindFirstChild(prefix .. "_Core", true) :: BasePart
	local cry = src:FindFirstChild(prefix .. "_CrystalC", true) :: BasePart
	local coreLocal = Vector3.new(0, 1.15, -0.2)
	local localDir = Vector3.new(-0.025, 0, 0.735)
	local w = cry.Position - core.Position
	local theta = math.atan2(localDir.Z, localDir.X) - math.atan2(w.Z, w.X)
	return CFrame.new(core.Position) * CFrame.Angles(0, theta, 0) * CFrame.new(-coreLocal)
end

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
		c.CFrame = inv * p.CFrame -- układ lokalny gwiazdy, origin = środek dna krateru
		return c
	end

	local main = Instance.new("Model")
	main.Name = "MainBody"
	main.Parent = model
	for i = 1, 6 do
		local n = string.format("%02d", i)
		local shell = take("Shell" .. n)
		if shell then
			style(shell, Enum.Material.Basalt, ROCK, true)
			shell.Parent = main
			local veins = take("CrackVeins" .. n)
			if veins then
				style(veins, Enum.Material.Neon, NEON, false)
				veins.Parent = shell
			end
		end
	end

	local core = take("Core") :: MeshPart
	style(core, Enum.Material.Neon, GLOW, false)
	core.Parent = model
	local coreShell = take("CoreShell")
	if coreShell then
		style(coreShell, Enum.Material.ForceField, NEON, false)
		coreShell.Parent = core
	end
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = GLOW
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
			style(c, Enum.Material.Neon, CRYSTAL, false)
			c.Transparency = 0.08
			c.Parent = crystals
		end
	end

	local slime = take("Slime")
	if slime then
		style(slime, Enum.Material.Neon, NEON, false)
		slime.Parent = model
	end

	local crater = take("Crater") :: MeshPart
	style(crater, Enum.Material.Basalt, GROUND, false)
	crater.Parent = model
	for _, name in { "CraterVeins", "GroundCracks" } do
		local c = take(name)
		if c then
			style(c, Enum.Material.Neon, NEON, false)
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
				style(c, Enum.Material.Neon, CRYSTAL, false)
				c.Transparency = 0.08
			else
				style(c, Enum.Material.Basalt, ROCK, false)
			end
			c.Parent = debris
		end
	end

	-- Hitbox: prosta bryła do raycastów minigry; PrimaryPart z Attachmentami (strefy i punkty efektów).
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

	local data = DATA[prefix]
	for name, pos in data.anchors do
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = hitbox.CFrame:PointToObjectSpace(v3(pos))
		a.Parent = hitbox
	end
	local zoneCount = DATA.zoneCounts[sizeId] or 1
	for i = 1, math.min(zoneCount, #data.zones) do
		local a = Instance.new("Attachment")
		a.Name = "Zone_" .. i
		a.Position = hitbox.CFrame:PointToObjectSpace(v3(data.zones[i]))
		a.Parent = hitbox
	end

	-- Skala: szerokość skorupy = size gwiazdy; pivot nad dnem krateru.
	local width = math.max(bodySize.X, bodySize.Z)
	model.WorldPivot = CFrame.new(0, width * PIVOT_HEIGHT[sizeId], 0)
	local scale = SIZES[sizeId] / width
	model:ScaleTo(scale)
	light.Range = SIZES[sizeId] * 0.9
	model:SetAttribute("VisualV2", true)
	model:SetAttribute("Upright", true)
	model:SetAttribute("StudsPerUnit", scale)
	model:SetAttribute("BodyWidth", SIZES[sizeId])
	return model
end

local stars = ServerStorage:FindFirstChild("Stars") :: Folder
local old = stars:FindFirstChild("Toxic")
if old and not old:GetAttribute("VisualV2") then
	local backup = ServerStorage:FindFirstChild("StarsBackup") or Instance.new("Folder")
	backup.Name = "StarsBackup"
	backup.Parent = ServerStorage
	old.Name = "Toxic_v1"
	old.Parent = backup
elseif old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Toxic"
folder:SetAttribute("VisualV2", true)
local report = {}
for _, sizeId in { "Small", "Medium", "Large", "Huge" } do
	local m = build(sizeId, if sizeId == "Small" then "Small" else "Large")
	-- szablony stoją obok siebie w (0, 0, 0) — serwer i tak je klonuje i przestawia
	m:PivotTo(CFrame.new(0, 0, 0))
	m.Parent = folder
	local _, ext = m:GetBoundingBox()
	table.insert(report, `{sizeId}: ext {math.floor(ext.X)}×{math.floor(ext.Y)}×{math.floor(ext.Z)}, zones {#m.Hitbox:GetChildren()}`)
end
folder.Parent = stars
src:Destroy()
return table.concat(report, "\n")
