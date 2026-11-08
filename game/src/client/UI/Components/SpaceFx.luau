--!strict
-- SpaceFx — kosmiczne efekty UI wielokrotnego użytku:
--   Nebula     — dryfująca, bezszwowa mgławica (tekstura VFX z T38) w kolorze okna,
--   Particles  — iskierki/gwiazdki unoszące się w górę i migoczące,
--   NeonBorder — obrys z gradientem, który powoli się obraca (tęczowy neon),
--   Flare      — miękka poświata za obiektem, pulsuje i kręci się.
-- Wszystko to pętle TweenService (bez Heartbeat), zatrzymywane przy odmontowaniu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Motion = require(script.Parent.Parent.Motion)
local Theme = require(script.Parent.Parent.Theme)

local e = React.createElement

local SpaceFx = {}

local NEBULA_TILE = 420

-- Mgławica: obraz kafelkowany większy od rodzica, przesuwany o jeden kafel w pętli (płynny dryf bez szwu).
function SpaceFx.Nebula(props: { color: Color3, transparency: number?, speed: number?, zIndex: number? })
	local ref = React.useRef(nil :: ImageLabel?)
	Motion.useLoop(ref :: any, props.speed or 40, { Position = UDim2.fromOffset(-NEBULA_TILE, -NEBULA_TILE) }, {
		reverses = false,
		style = Enum.EasingStyle.Linear,
	})
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = props.zIndex or 1,
	}, {
		Image = e("ImageLabel", {
			ref = ref,
			Image = Theme.FX.nebula,
			ImageColor3 = props.color,
			ImageTransparency = props.transparency or 0.55,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(NEBULA_TILE, NEBULA_TILE),
			Size = UDim2.new(1, NEBULA_TILE, 1, NEBULA_TILE),
			BackgroundTransparency = 1,
		}),
	})
end

-- Jedna iskierka: start na dole w danym X, odlot w górę z lekkim zniesieniem, migotanie.
local function Particle(
	props: { x: number, size: number, duration: number, delay: number, image: string, color: Color3 }
)
	local ref = React.useRef(nil :: ImageLabel?)
	Motion.useLoop(ref :: any, props.duration, {
		Position = UDim2.fromScale(props.x + 0.04, -0.1),
		ImageTransparency = 0.9,
		Rotation = 180,
	}, { reverses = false, style = Enum.EasingStyle.Linear, delay = props.delay })
	return e("ImageLabel", {
		ref = ref,
		Image = props.image,
		ImageColor3 = props.color,
		ImageTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(props.x, 1.1),
		Size = UDim2.fromOffset(props.size, props.size),
		BackgroundTransparency = 1,
	})
end

-- Stały „losowy” układ (seed), żeby iskierki nie skakały przy przerysowaniu.
function SpaceFx.Particles(props: { count: number?, color: Color3?, seed: number?, zIndex: number? })
	local items = React.useMemo(function()
		local rng = Random.new(props.seed or 7)
		local list = {}
		for i = 1, props.count or 14 do
			list[i] = {
				x = rng:NextNumber(0.03, 0.97),
				size = rng:NextInteger(8, 20),
				duration = rng:NextNumber(5, 10),
				delay = rng:NextNumber(0, 8),
				image = if rng:NextNumber() < 0.6 then Theme.FX.glint else Theme.FX.spark,
			}
		end
		return list
	end, {})
	local children = {}
	for i, item in items do
		children[`P{i}`] = e(Particle, {
			x = item.x,
			size = item.size,
			duration = item.duration,
			delay = item.delay,
			image = item.image,
			color = props.color or Color3.new(1, 1, 1),
		})
	end
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = props.zIndex or 2,
	}, children)
end

-- Neonowy obrys z obracającym się gradientem (wstawiany jako dziecko ramki z UICorner).
function SpaceFx.NeonBorder(props: { thickness: number?, colors: ColorSequence?, speed: number? })
	local ref = React.useRef(nil :: UIGradient?)
	Motion.useLoop(ref :: any, props.speed or 4, { Rotation = 360 }, {
		reverses = false,
		style = Enum.EasingStyle.Linear,
	})
	return e("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Thickness = props.thickness or 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, {
		Gradient = e("UIGradient", {
			ref = ref,
			Color = props.colors or ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.COLORS.neonCyan),
				ColorSequenceKeypoint.new(0.5, Theme.COLORS.neonMagenta),
				ColorSequenceKeypoint.new(1, Theme.COLORS.neonCyan),
			}),
		}),
	})
end

-- Miękka poświata (flara) za obiektem: kręci się i pulsuje.
function SpaceFx.Flare(props: {
	color: Color3,
	size: number,
	position: UDim2?,
	transparency: number?,
	zIndex: number?,
	pulse: boolean?,
})
	local ref = React.useRef(nil :: ImageLabel?)
	local scaleRef = React.useRef(nil :: UIScale?)
	Motion.useLoop(ref :: any, 9, { Rotation = 360 }, { reverses = false, style = Enum.EasingStyle.Linear })
	Motion.useLoop(scaleRef :: any, 1.3, { Scale = 1.15 }, { enabled = props.pulse ~= false })
	return e("ImageLabel", {
		ref = ref,
		Image = Theme.FX.flare,
		ImageColor3 = props.color,
		ImageTransparency = props.transparency or 0.25,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(props.size, props.size),
		BackgroundTransparency = 1,
		ZIndex = props.zIndex or 1,
	}, { Scale = e("UIScale", { ref = scaleRef }) })
end

return SpaceFx
