--!strict
-- Szablon importu modeli łupu (T21). Plik import_items.luau generuje art/items/gen_import.py (wstawia META) — nie edytuj wygenerowanego.
-- Uruchom w Studio (execute_luau, Edit) po wstawieniu FBX art/items/<theme>/items_<theme>.fbx do ServerStorage.ItemImport (insert_asset).
-- Wynik: ServerStorage.Items/<itemId> — Model z częściami `<Część>` (kolory i materiały zapieczone), pivot = środek przedmiotu
-- bez obrotu, PrimaryPart = Body (albo największa nieanimowana część), atrybuty ItemId/Rarity.
-- Części animowane przez klienta (BaseController → ItemFx) mają atrybuty: FxType = Spin | Orbit | Pulse,
-- FxAxis (Vector3, układ modelu), FxSpeed (°/s), FxBob (studs przy skali 1), FxAmount, FxRate.
-- Cząsteczki (ParticleEmitter "ItemSparkle<n>") z tekstur VfxIds. Brak Tint — kolory są w modelu (decyzja T21).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local VfxIds = require(ReplicatedStorage.Shared.Config.VfxIds) :: any
local META = HttpService:JSONDecode([==[__META__]==])
local TEX = { spark = VfxIds.SPARK, glint = VfxIds.GLINT }

local import = ServerStorage:FindFirstChild("ItemImport")
assert(import, "Brak ServerStorage.ItemImport — najpierw insert_asset items_<theme>.fbx")
local root = ServerStorage:FindFirstChild("Items") or Instance.new("Folder")
root.Name = "Items"
root.Parent = ServerStorage

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local report = {}
for itemId, m in META do
	local first: BasePart? = nil
	local firstName = ""
	for partName in m.parts do
		local src = import:FindFirstChild(itemId .. "_" .. partName, true) :: BasePart?
		if src then
			first, firstName = src, partName
			break
		end
	end
	if not first then
		continue -- przedmiot z innego pliku FBX
	end
	local old = root:FindFirstChild(itemId)
	if old then
		old:Destroy()
	end
	-- insert_asset obraca i przesuwa model — liczymy części względem pierwszej (jej środek z meta), wynik bez obrotu.
	local base = first.CFrame
	local firstCenter = v3(m.parts[firstName].center)

	local model = Instance.new("Model")
	model.Name = itemId
	model:SetAttribute("ItemId", itemId)
	model:SetAttribute("Rarity", m.rarity)
	model:SetAttribute("DisplayName", m.name)
	local maxErr = 0
	local count = 0
	local primary: BasePart? = nil
	local primaryVolume = 0
	for partName, p in m.parts do
		local src = import:FindFirstChild(itemId .. "_" .. partName, true) :: BasePart?
		if not src then
			table.insert(report, itemId .. ": brak " .. partName)
			continue
		end
		local part = src:Clone()
		part.Name = partName
		local ok, mat = pcall(function()
			return (Enum.Material :: any)[p.material]
		end)
		part.Material = if ok and mat then mat else Enum.Material.SmoothPlastic
		part.Color = Color3.fromHex(p.color)
		part.Transparency = 0
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = part.Material ~= Enum.Material.Neon
		part.CFrame = CFrame.new(firstCenter) * base:ToObjectSpace(src.CFrame)
		maxErr = math.max(maxErr, (part.Position - v3(p.center)).Magnitude)
		local a = p.anim
		if a then
			local fxType = if a.type == "spin" then "Spin" elseif a.type == "orbit" then "Orbit" else "Pulse"
			part:SetAttribute("FxType", fxType)
			if a.axis then
				part:SetAttribute("FxAxis", v3(a.axis))
			end
			part:SetAttribute("FxSpeed", a.speed or 0)
			part:SetAttribute("FxBob", a.bob or 0)
			part:SetAttribute("FxAmount", a.amount or 0)
			part:SetAttribute("FxRate", a.rate or 0)
		else
			local volume = part.Size.X * part.Size.Y * part.Size.Z
			if partName == "Body" then
				volume = math.huge
			end
			if volume > primaryVolume then
				primary, primaryVolume = part, volume
			end
		end
		part.Parent = model
		count += 1
	end
	if not primary then
		primary = model:FindFirstChildWhichIsA("BasePart")
	end
	model.PrimaryPart = primary
	model.WorldPivot = CFrame.new(0, 0, 0)

	for i, pe in m.particles or {} do
		local host = model:FindFirstChild(pe.part) :: BasePart?
		if not host then
			continue
		end
		local e = Instance.new("ParticleEmitter")
		e.Name = "ItemSparkle" .. i
		e.Texture = TEX[pe.tex] or VfxIds.SPARK
		e.Color = ColorSequence.new(Color3.fromHex(pe.color))
		e.Rate = pe.rate
		e.Lifetime = NumberRange.new(pe.life * 0.7, pe.life)
		e.Speed = NumberRange.new(pe.speed * 0.5, pe.speed)
		e.SpreadAngle = Vector2.new(180, 180)
		if pe.up then
			e.Acceleration = Vector3.new(0, 2.5, 0)
		end
		local size = if pe.aura then pe.size * 1.6 else pe.size
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.25, size),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Transparency = NumberSequence.new(if pe.aura then 0.15 else 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.LightEmission = 1
		e.LightInfluence = 0
		if pe.aura then
			e.Shape = Enum.ParticleEmitterShape.Sphere
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		end
		e.Parent = host
	end

	model.Parent = root
	table.insert(report, string.format("%s: %d części, błąd osi %.3f", itemId, count, maxErr))
end
table.sort(report)
return table.concat(report, "\n")
