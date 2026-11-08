--!strict
-- FxUtil — wspólne klocki efektów klienta: części FX, emitery, beamy, tweeny, poziom jakości, kolory.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimConfig = require(Shared.Config.AnimConfig)
local StarConfig = require(Shared.Config.StarConfig)

local FxUtil = {}

local qualityMult = 1
local folder: Folder? = nil

-- Folder lokalnych efektów w Workspace (tworzony przy pierwszym użyciu).
function FxUtil.folder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "StarFx"
	created.Parent = Workspace
	folder = created
	return created
end

-- Mnożnik liczby cząsteczek (AnimConfig.QUALITY), ustawiany przez StarFxController.
function FxUtil.setQuality(mult: number)
	qualityMult = mult
end

function FxUtil.quality(): number
	return qualityMult
end

-- Liczba elementów po uwzględnieniu jakości (min. 1, gdy base > 0).
function FxUtil.count(base: number): number
	if base <= 0 then
		return 0
	end
	return math.max(1, math.round(base * qualityMult))
end

function FxUtil.part(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Niewidoczna kotwica (dla emiterów, świateł, dźwięków, Decali).
function FxUtil.anchor(size: Vector3, cframe: CFrame): Part
	local part = FxUtil.part(Enum.PartType.Block, size, cframe, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	part.Transparency = 1
	return part
end

-- Płaska część leżąca na terenie (oś Y = normalna) z Decalem na górnej ścianie.
function FxUtil.groundDecal(
	position: Vector3,
	normal: Vector3,
	diameter: number,
	texture: string,
	color: Color3
): (Part, Decal)
	local other = if math.abs(normal:Dot(Vector3.zAxis)) > 0.9 then Vector3.xAxis else Vector3.zAxis
	local right = normal:Cross(other).Unit
	local cframe = CFrame.fromMatrix(position, right, normal)
	local part = FxUtil.anchor(Vector3.new(diameter, 0.2, diameter), cframe)
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = texture
	decal.Color3 = color
	decal.Parent = part
	return part, decal
end

export type EmitterProps = { [string]: any }

-- ParticleEmitter z właściwościami (Enabled=false domyślnie, gdy podano `burst`).
function FxUtil.emitter(parent: Instance, props: EmitterProps): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.LightInfluence = 0
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = parent
	return emitter
end

function FxUtil.beam(parent: Instance, a0: Attachment, a1: Attachment, props: { [string]: any }): Beam
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.LightInfluence = 0
	for key, value in props do
		(beam :: any)[key] = value
	end
	beam.Parent = parent
	return beam
end

function FxUtil.attachment(parent: Instance, position: Vector3, axis: Vector3?, secondary: Vector3?): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Position = position
	if axis and secondary then
		attachment.Axis = axis
		attachment.SecondaryAxis = secondary
	end
	attachment.Parent = parent
	return attachment
end

function FxUtil.tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

function FxUtil.numberSeq(...: number): NumberSequence
	local values = { ... }
	local points = {}
	for index, value in values do
		table.insert(points, NumberSequenceKeypoint.new((index - 1) / math.max(#values - 1, 1), value))
	end
	return NumberSequence.new(points)
end

function FxUtil.colorSeq(...: Color3): ColorSequence
	local values = { ... }
	if #values == 1 then
		return ColorSequence.new(values[1])
	end
	local points = {}
	for index, value in values do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / (#values - 1), value))
	end
	return ColorSequence.new(points)
end

function FxUtil.lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function FxUtil.darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- Krzywa ease-out-back (rozdarcie „wyskakuje” z lekkim przestrzeleniem).
function FxUtil.easeOutBack(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	local x = math.clamp(t, 0, 1) - 1
	return 1 + c3 * x * x * x + c1 * x * x
end

-- Czy rozmiar osiąga próg z AnimConfig (np. SKY.fromSize); kolejność z Stars.json → order.
function FxUtil.atLeast(sizeId: string, threshold: string): boolean
	return StarConfig.sizeRank(sizeId) >= StarConfig.sizeRank(threshold)
end

function FxUtil.bySize(map: { [string]: number }, sizeId: string): number
	return map[sizeId] or map.Small or 0
end

FxUtil.CONFIG = AnimConfig

return FxUtil
