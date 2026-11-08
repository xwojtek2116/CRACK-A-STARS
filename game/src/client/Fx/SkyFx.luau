--!strict
-- SkyFx — reakcja całego świata na duże spadki (od SKY.fromSize): niebo ciemnieje i barwi się kolorem gwiazdy,
-- wyładowania wyrwy rozświetlają teren (OutdoorAmbient), uderzenie daje biały flash. Wszystko lokalnie
-- (ColorCorrection klienta), stan bazowy Lighting zawsze wraca, gdy nie ma aktywnych źródeł.

local Lighting = game:GetService("Lighting")

local FxUtil = require(script.Parent.FxUtil)

local SKY = FxUtil.CONFIG.SKY

type Tint = { color: Color3, strength: number, darken: number }

local tints: { [string]: Tint } = {}
local correction: ColorCorrectionEffect? = nil
local baseAmbient: Color3 = Lighting.OutdoorAmbient
local current = { r = 1, g = 1, b = 1, darken = 0 }
local flash = 0
local flashDecay = 2
local lightning = 0
local lightningColor = Color3.new(1, 1, 1)

local SkyFx = {}

local function effect(): ColorCorrectionEffect
	if correction and correction.Parent then
		return correction
	end
	local created = Instance.new("ColorCorrectionEffect")
	created.Name = "StarSkyFx"
	created.Parent = Lighting
	correction = created
	baseAmbient = Lighting.OutdoorAmbient
	return created
end

-- Aktywuje barwienie nieba dla gwiazdy `id` (wiele naraz = uśrednione, silniejsze wygrywa jasność).
function SkyFx.tint(id: string, color: Color3, strength: number, darken: number)
	if strength <= 0 then
		return
	end
	effect()
	tints[id] = { color = color, strength = strength, darken = darken }
end

function SkyFx.release(id: string)
	tints[id] = nil
end

-- Biały flash (0..1) zanikający w `seconds`.
function SkyFx.flash(amount: number, seconds: number)
	if amount <= 0 then
		return
	end
	effect()
	if amount > flash then
		flash = amount
		flashDecay = amount / math.max(seconds, 0.05)
	end
end

-- Błysk wyładowania rozświetlający teren kolorem wyrwy.
function SkyFx.lightning(color: Color3, amount: number)
	effect()
	if amount > lightning then
		lightning = amount
		lightningColor = color
	end
end

function SkyFx.update(dt: number)
	if not correction then
		return
	end
	-- Cel: średni kolor aktywnych źródeł ważony siłą.
	local targetR, targetG, targetB, targetDarken = 1, 1, 1, 0
	local total = 0
	for _, tint in tints do
		total += tint.strength
	end
	if total > 0 then
		local r, g, b, dark = 0, 0, 0, 0
		for _, tint in tints do
			local w = tint.strength / total
			r += tint.color.R * w
			g += tint.color.G * w
			b += tint.color.B * w
			dark = math.min(dark, tint.darken)
		end
		local strength = math.min(total, 1)
		local mixed = Color3.new(1, 1, 1):Lerp(Color3.new(r, g, b), strength)
		targetR, targetG, targetB, targetDarken = mixed.R, mixed.G, mixed.B, dark
	end
	local k = 1 - math.exp(-SKY.approach * dt)
	current.r += (targetR - current.r) * k
	current.g += (targetG - current.g) * k
	current.b += (targetB - current.b) * k
	current.darken += (targetDarken - current.darken) * k

	flash = math.max(0, flash - flashDecay * dt)
	lightning = math.max(0, lightning - dt * 6)

	local cc = effect()
	cc.TintColor = Color3.new(current.r, current.g, current.b):Lerp(Color3.new(1, 1, 1), flash)
	cc.Brightness = current.darken + flash * 0.6
	cc.Contrast = flash * 0.3
	cc.Saturation = -flash * 0.4
	Lighting.OutdoorAmbient = baseAmbient:Lerp(lightningColor, math.clamp(lightning, 0, 1) * SKY.lightningAmbient)

	-- Nic nie świeci i wszystko wróciło do bazy: zdejmujemy efekt (zero kosztu na co dzień).
	if
		total == 0
		and flash == 0
		and lightning == 0
		and math.abs(current.r - 1)
				+ math.abs(current.g - 1)
				+ math.abs(current.b - 1)
				+ math.abs(current.darken)
			< 0.01
	then
		Lighting.OutdoorAmbient = baseAmbient
		cc:Destroy()
		correction = nil
		current = { r = 1, g = 1, b = 1, darken = 0 }
	end
end

return SkyFx
