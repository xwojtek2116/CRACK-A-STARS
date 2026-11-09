--!strict
-- Loot/Fx — wspólne klocki karty łupu i ogłoszeń: tekst z konturem, gradienty rzadkości, pętle tweenów,
-- iskry rozlatujące się z punktu, błysk ekranu. Wszystko na instancjach (jak Minigame/Banner), bez React,
-- bo to krótkie, samosprzątające się efekty.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)

local Fx = {}

function Fx.tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- Pętla tam i z powrotem (Sine) albo w kółko (Linear, reverse = false).
function Fx.loop(instance: Instance, seconds: number, goal: { [string]: any }, reverse: boolean?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(
			seconds,
			if reverse == false then Enum.EasingStyle.Linear else Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			reverse ~= false
		),
		goal
	)
	tween:Play()
	return tween
end

function Fx.corner(parent: Instance, radius: UDim?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.CORNER
	corner.Parent = parent
end

function Fx.stroke(parent: Instance, color: Color3, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or Theme.FRAME_STROKE
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Fx.gradient(parent: Instance, color: ColorSequence, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = color
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

export type TextProps = {
	text: string,
	size: UDim2,
	position: UDim2,
	color: Color3?,
	maxSize: number,
	font: Font?,
	anchor: Vector2?,
	rich: boolean?,
	align: Enum.TextXAlignment?,
	stroke: number?,
}

function Fx.text(parent: Instance, props: TextProps): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)
	label.Size = props.size
	label.Position = props.position
	label.BackgroundTransparency = 1
	label.FontFace = props.font or Theme.FONTS.display
	label.TextScaled = true
	label.RichText = props.rich == true
	label.Text = props.text
	label.TextColor3 = props.color or Theme.COLORS.text
	label.TextXAlignment = props.align or Enum.TextXAlignment.Center
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = props.stroke or Theme.STROKE
	stroke.Color = Theme.COLORS.ink
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = props.maxSize
	limit.Parent = label
	label.Parent = parent
	return label
end

function Fx.rarityColor(rarity: string): Color3
	return Theme.RARITY_COLORS[rarity] or Theme.COLORS.text
end

-- Gradient wypełnienia w kolorze rzadkości (Secret = tęcza).
function Fx.rarityFill(rarity: string): ColorSequence
	if rarity == "Secret" then
		return Theme.SECRET_GRADIENT
	end
	return Theme.duo(Fx.rarityColor(rarity))
end

Fx.GOLD = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 252, 210)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 205, 60)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 130, 40)),
})

Fx.SHINY = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("#E8FDFF")),
	ColorSequenceKeypoint.new(0.5, Color3.fromHex("#8FF7FF")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("#C9A6FF")),
})

-- Przesuwający się błysk po elemencie (pasmo SHINE_BAND).
function Fx.shine(parent: GuiObject, seconds: number, pause: number): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
	gradient.Transparency = Theme.SHINE_BAND
	gradient.Rotation = 20
	gradient.Offset = Vector2.new(-1, 0)
	local band = Instance.new("Frame")
	band.Name = "Shine"
	band.Size = UDim2.fromScale(1, 1)
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BackgroundTransparency = 0.25
	band.ZIndex = parent.ZIndex + 5
	local corner = parent:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = band
	end
	gradient.Parent = band
	band.Parent = parent
	task.spawn(function()
		while band.Parent do
			gradient.Offset = Vector2.new(-1, 0)
			Fx.tween(
				gradient,
				seconds,
				{ Offset = Vector2.new(1, 0) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.InOut
			)
			task.wait(seconds + pause)
		end
	end)
	return gradient
end

-- Iskry z punktu (pozycja w skali rodzica): obracające się gwiazdki rozlatują się i gasną.
function Fx.burst(parent: GuiObject, count: number, color: Color3, center: UDim2, reach: number)
	local rng = Random.new()
	for i = 1, count do
		local spark = Instance.new("ImageLabel")
		spark.Image = if i % 3 == 0 then Theme.FX.glint else Theme.FX.spark
		spark.ImageColor3 = color:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, 0.6))
		spark.BackgroundTransparency = 1
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		local size = rng:NextInteger(10, 26)
		spark.Size = UDim2.fromOffset(size, size)
		spark.Position = center
		spark.Rotation = rng:NextNumber(0, 360)
		spark.ZIndex = 20
		spark.Parent = parent
		local angle = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local distance = reach * rng:NextNumber(0.55, 1.1)
		local seconds = rng:NextNumber(0.5, 0.9)
		Fx.tween(spark, seconds, {
			Position = center + UDim2.fromOffset(math.cos(angle) * distance, math.sin(angle) * distance),
			ImageTransparency = 1,
			Rotation = spark.Rotation + rng:NextNumber(-180, 180),
			Size = UDim2.fromOffset(size * 0.3, size * 0.3),
		}, Enum.EasingStyle.Quart)
		task.delay(seconds + 0.05, function()
			spark:Destroy()
		end)
	end
end

-- Błysk całego ekranu w kolorze (Mythic/Secret).
function Fx.flash(screen: ScreenGui, color: Color3, alpha: number, seconds: number)
	local frame = Instance.new("Frame")
	frame.Name = "Flash"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1 - alpha
	frame.BorderSizePixel = 0
	frame.ZIndex = 50
	frame.Active = false
	frame.Parent = screen
	Fx.tween(frame, seconds, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
	task.delay(seconds + 0.05, function()
		frame:Destroy()
	end)
end

-- Skala UI jak w App (ekran bazowy Theme.BASE_SIZE).
function Fx.screenScale(screen: ScreenGui): number
	local size = screen.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return 1
	end
	return math.clamp(
		math.min(size.X / Theme.BASE_SIZE.X, size.Y / Theme.BASE_SIZE.Y),
		Theme.MIN_SCALE,
		Theme.MAX_SCALE
	)
end

-- Tekst bezpieczny dla RichText (nazwa gracza).
function Fx.escape(value: string): string
	return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

return Fx
