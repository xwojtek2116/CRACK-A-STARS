--!strict
-- import_pedestal.luau — składa ServerStorage.BaseAssets z modelu FBX postumentu (T08).
-- Kroki: 1) build_pedestal.py → pedestal.fbx, 2) upload FBX jako Model (Open Cloud, asset 74109633398415 —
-- wersja z 9.11.2026), 3) insert_asset do ServerStorage jako „PedestalImport”, 4) ten skrypt (execute_luau, Edit).
-- Wynik: BaseAssets/Pedestal (Shell = PrimaryPart z Attachment ItemPoint, Ring = Neon w kolorze rzadkości,
-- Accent), BaseAssets/Hologram (ForceField, cyjan), BaseAssets/Placeholder (Crystal z atrybutem Tint).
-- Pivot modeli = środek podstawy (y = 0). Kolory/materiały zgodne z BaseConfig i BaseService.

local SS = game:GetService("ServerStorage")
local src = SS:FindFirstChild("PedestalImport") :: Model
assert(src, "Brak ServerStorage.PedestalImport (insert_asset 74109633398415)")

local old = SS:FindFirstChild("BaseAssets")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "BaseAssets"

local shellSrc = src:FindFirstChild("Pedestal_Shell") :: MeshPart
local bottom = shellSrc.Position - Vector3.new(0, shellSrc.Size.Y / 2, 0)
local shift = CFrame.new(-bottom)

local function prep(part: BasePart, name: string, material: Enum.Material, color: Color3): BasePart
	local p = part:Clone()
	p.Name = name
	p.CFrame = shift * part.CFrame
	p.Material = material
	p.Color = color
	p.Anchored = true
	p.CanTouch = false
	for _, child in p:GetChildren() do
		child:Destroy()
	end
	return p
end

local pedestal = Instance.new("Model")
pedestal.Name = "Pedestal"
local shell = prep(shellSrc, "Shell", Enum.Material.Slate, Color3.fromHex("#2A2440"))
shell.Parent = pedestal
local ring =
	prep(src:FindFirstChild("Pedestal_Ring") :: BasePart, "Ring", Enum.Material.Neon, Color3.fromHex("#3A2E5C"))
ring.CanCollide = false
ring.CanQuery = false
ring.CastShadow = false
ring.Parent = pedestal
local accent =
	prep(src:FindFirstChild("Pedestal_Accent") :: BasePart, "Accent", Enum.Material.Metal, Color3.fromHex("#6A6390"))
accent.Reflectance = 0.15
accent.CanCollide = false
accent.Parent = pedestal
local point = Instance.new("Attachment")
point.Name = "ItemPoint"
point.Position = Vector3.new(0, 4.1 - shell.Size.Y / 2, 0) -- wierzch płyty = 4,1 studs nad ziemią
point.Parent = shell
pedestal.PrimaryPart = shell
pedestal.WorldPivot = CFrame.new(0, 0, 0)
pedestal.Parent = folder

local hologram = pedestal:Clone()
hologram.Name = "Hologram"
for _, p in hologram:GetDescendants() do
	if p:IsA("BasePart") then
		p.Material = Enum.Material.ForceField
		p.Color = Color3.fromHex("#3DF2FF")
		p.CastShadow = false
		p.CanCollide = false
	end
end
hologram.Parent = folder

local placeholder = Instance.new("Model")
placeholder.Name = "Placeholder"
local crystal = (src:FindFirstChild("Placeholder_Crystal") :: BasePart):Clone()
crystal.Name = "Crystal"
crystal.Material = Enum.Material.Neon
crystal.Color = Color3.new(1, 1, 1)
crystal.CFrame = crystal.CFrame.Rotation
crystal:SetAttribute("Tint", true)
for _, child in crystal:GetChildren() do
	child:Destroy()
end
crystal.Parent = placeholder
placeholder.PrimaryPart = crystal
placeholder.Parent = folder

folder.Parent = SS
src:Destroy()
return "BaseAssets gotowe"
