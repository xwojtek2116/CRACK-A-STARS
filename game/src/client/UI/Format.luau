--!strict
-- Format — teksty liczb i czasu w UI (po angielsku, rynek USA). Kasa w skrócie: $1.25M, $3.4B, $12.5Qa.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234 → "1.23K", 999 → "999", 1250000 → "1.25M". Trzy cyfry znaczące, bez zbędnych zer.
function Format.short(value: number): string
	local sign = if value < 0 then "-" else ""
	local n = math.abs(value)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local decimals = if scaled >= 100 then 0 elseif scaled >= 10 then 1 else 2
	local factor = 10 ^ decimals
	scaled = math.floor(scaled * factor) / factor -- obcinamy, nie zaokrąglamy (999.99K ≠ 1000K)
	local text = string.format(`%.{decimals}f`, scaled)
	if decimals > 0 then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return sign .. text .. SUFFIXES[tier + 1]
end

function Format.cash(value: number): string
	local text = Format.short(value)
	if string.sub(text, 1, 1) == "-" then
		return "-$" .. string.sub(text, 2)
	end
	return "$" .. text
end

-- Pełna liczba z przecinkami: 1250000 → "1,250,000" (popupy „+$1,200”).
function Format.number(value: number): string
	local text = tostring(math.floor(math.abs(value)))
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	formatted = string.gsub(formatted, "^,", "")
	return if value < 0 then "-" .. formatted else formatted
end

-- 75 → "1:15", 3700 → "1:01:40".
function Format.duration(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%02d:%02d", minutes, secs)
end

return Format
