--!strict
-- Import Toxic Star v2 (T40). WYGENEROWANE — nie edytuj; gotowy skrypt generuje art/stars/toxic/make_import.py (wstawia toxic_v2_anchors.json).
-- Wejście: ServerStorage.ToxicV2Import (FBX star_toxic_v2.fbx przez insert_asset; części Large_* i Small_*).
-- Wyjście: ServerStorage.Stars.Toxic/<Small|Medium|Large|Huge> (Model, PrimaryPart = Hitbox, atrybuty VisualV2, Upright),
-- stary Toxic (v1) → ServerStorage.StarsBackup.Toxic_v1. Hierarchia: vault/02 Systemy/Toxic Star v2 - specyfikacja produkcyjna.md.
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local DATA = HttpService:JSONDecode([==[{"zoneCounts": {"Small": 1, "Medium": 2, "Large": 4, "Huge": 8, "Supernova": 12}, "Large": {"extent": 5.9865, "anchors": {"ANCHOR_Core": [-0.0, 1.15, -0.2], "ANCHOR_Shockwave": [-0.0, 0.06, 0.0], "ANCHOR_Particles": [-0.0, 1.7, 0.0], "ANCHOR_Drip_01": [0.16, 0.42, -0.5], "ANCHOR_Drip_02": [-0.0, 0.2, -0.55], "ANCHOR_Drip_03": [-0.13, 0.37, -0.52], "ANCHOR_Cracks_01": [0.4107, 1.2602, -0.2216], "ANCHOR_Cracks_02": [0.249, 1.3679, -0.3466], "ANCHOR_Cracks_03": [0.1631, 1.2549, -0.5188]}, "zones": [[-0.2473, 1.4205, -0.1474], [0.5498, 1.1585, 0.0274], [0.1631, 1.2549, -0.5188], [-0.5803, 1.1875, 0.0657], [-0.2118, 1.1848, -0.4251], [0.4107, 1.2602, -0.2216], [-0.4033, 1.2289, -0.3021], [0.249, 1.3679, -0.3466], [-0.0538, 1.3092, -0.3754], [0.2793, 1.2351, -0.4056], [0.0277, 1.2196, -0.5258], [-0.1592, 1.3312, -0.347]]}, "Small": {"extent": 5.9, "anchors": {"ANCHOR_Core": [-0.0, 1.15, -0.2], "ANCHOR_Shockwave": [-0.0, 0.06, 0.0], "ANCHOR_Particles": [-0.0, 1.7, 0.0], "ANCHOR_Drip_01": [0.16, 0.42, -0.5], "ANCHOR_Drip_02": [-0.0, 0.2, -0.55], "ANCHOR_Drip_03": [-0.13, 0.37, -0.52], "ANCHOR_Cracks_01": [-0.4194, 1.1451, -0.3186], "ANCHOR_Cracks_02": [-0.0934, 1.2135, -0.32], "ANCHOR_Cracks_03": [-0.4074, 1.3294, -0.1128]}, "zones": [[-0.2437, 1.5143, 0.031], [0.5423, 1.1749, -0.222], [-0.1284, 1.1427, -0.3925], [0.3797, 1.2942, 0.1251], [0.257, 1.3394, -0.3145], [-0.4194, 1.1451, -0.3186], [-0.0596, 1.3092, -0.0618], [-0.4074, 1.3294, -0.1128], [-0.3474, 1.4647, -0.1461], [-0.05, 1.2439, -0.3701], [0.3163, 1.4249, -0.2506], [-0.0934, 1.2135, -0.32]]}}]==])
local SIZES = HttpService:JSONDecode([==[{"Small": 6, "Medium": 12, "Large": 24, "Huge": 45}]==]) -- { Small = 6, ... }
local COLOR = HttpService:JSONDecode([==[{"color": "#7CFF2E", "glow": "#D9FF5C"}]==]) -- color, glow
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
