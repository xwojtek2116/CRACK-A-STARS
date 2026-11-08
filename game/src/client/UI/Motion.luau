--!strict
-- Motion — animacje UI (TweenService) jako hooki React: pop z overshootem, licznik kasy, pulsy
-- oraz lekkie pętle „życia” w tle (unoszenie, oddychanie obrysu, kołysanie, błysk). Tylko klient, tylko wygląd.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Theme = require(script.Parent.Theme)

local Motion = {}

type Ref<T> = { current: T? }

function Motion.tween(instance: Instance?, info: TweenInfo, goals: { [string]: any }): Tween?
	if not instance then
		return nil
	end
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

-- Liczba płynnie dochodząca do `target` (kasa w HUD). Pierwszy render bez animacji.
function Motion.useCountUp(target: number, info: TweenInfo?): number
	local shown, setShown = React.useState(target)
	local valueRef = React.useRef(nil :: NumberValue?)

	React.useEffect(function()
		local value = Instance.new("NumberValue")
		value.Value = target
		valueRef.current = value
		local connection = value.Changed:Connect(function(newValue: number)
			setShown(math.round(newValue))
		end)
		return function()
			connection:Disconnect()
			value:Destroy()
		end
	end, {})

	React.useEffect(function()
		local value = valueRef.current
		if not value then
			return nil
		end
		local tween = TweenService:Create(value, info or Theme.MOTION.count, { Value = target })
		tween:Play()
		return function()
			tween:Cancel()
		end
	end, { target })

	return shown
end

-- Krótkie „pyknięcie” UIScale przy zmianie `trigger` (pomija pierwszy render). Zwraca ref pod UIScale.
function Motion.usePulse(trigger: any, peak: number?): Ref<UIScale>
	local scaleRef = React.useRef(nil :: UIScale?)
	local first = React.useRef(true)
	React.useEffect(function()
		if first.current then
			first.current = false
			return
		end
		local scale = scaleRef.current
		if not scale then
			return
		end
		scale.Scale = peak or 1.15
		Motion.tween(scale, Theme.MOTION.release, { Scale = 1 })
	end, { trigger })
	return scaleRef :: any
end

-- Wejście przy montowaniu: UIScale od `from` do 1 z overshootem.
function Motion.useEnter(from: number?, info: TweenInfo?): Ref<UIScale>
	local scaleRef = React.useRef(nil :: UIScale?)
	React.useEffect(function()
		local scale = scaleRef.current
		if scale then
			scale.Scale = from or 0.6
			Motion.tween(scale, info or Theme.MOTION.pop, { Scale = 1 })
		end
	end, {})
	return scaleRef :: any
end

-- Zapętlony tween instancji z refa. `reverses` = tam i z powrotem, `delay` = przesunięcie startu (fala).
function Motion.useLoop(
	ref: Ref<Instance>,
	duration: number,
	goals: { [string]: any },
	options: {
		reverses: boolean?,
		delay: number?,
		style: Enum.EasingStyle?,
		pause: number?,
		enabled: boolean?,
	}?
)
	local opts = options or {}
	local enabled = opts.enabled ~= false
	React.useEffect(function()
		local instance = ref.current
		if not instance or not enabled then
			return nil
		end
		local info = TweenInfo.new(
			duration,
			opts.style or Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			opts.reverses ~= false,
			opts.pause or 0
		)
		local tween: Tween? = nil
		local thread = task.delay(opts.delay or 0, function()
			tween = TweenService:Create(instance, info, goals);
			(tween :: Tween):Play()
		end)
		return function()
			task.cancel(thread)
			if tween then
				tween:Cancel()
			end
		end
	end, { enabled })
end

-- Unoszenie (±px w pionie). `ref` = wewnętrzna ramka-opakowanie o Position (0,0) i Size (1,1),
-- więc animacja nie psuje układu rodzica (UIListLayout itp.).
function Motion.useBob(ref: Ref<GuiObject>, pixels: number?, duration: number?, delay: number?)
	local px = pixels or Theme.IDLE.bobPixels
	React.useEffect(function()
		local object = ref.current
		if object then
			object.Position = UDim2.fromOffset(0, px)
		end
		return nil
	end, {})
	Motion.useLoop(
		ref :: any,
		duration or Theme.IDLE.bobTime,
		{ Position = UDim2.fromOffset(0, -px) },
		{ delay = delay }
	)
end

-- Przelatujący co jakiś czas błysk: UIGradient z Theme.SHINE_BAND, Offset -1 → 1.
function Motion.useShine(gradientRef: Ref<UIGradient>, delay: number?)
	React.useEffect(function()
		local gradient = gradientRef.current
		if gradient then
			gradient.Offset = Vector2.new(-1, 0)
		end
		return nil
	end, {})
	Motion.useLoop(gradientRef :: any, Theme.IDLE.shineTime, { Offset = Vector2.new(1, 0) }, {
		reverses = false,
		style = Enum.EasingStyle.Quad,
		pause = Theme.IDLE.shinePause,
		delay = delay,
	})
end

return Motion
