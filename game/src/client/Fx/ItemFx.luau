--!strict
-- ItemFx — „życie” modeli łupu na postumencie (T21). Model z ServerStorage.Items (import art/items/import_items.luau)
-- ma części z atrybutami:
--   FxType = "Spin"  — obrót wokół osi FxAxis przez środek przedmiotu (klatki, pierścienie, aureole), FxSpeed °/s,
--   FxType = "Orbit" — odłamki krążące wokół pionu przedmiotu, FxSpeed °/s, FxBob = unoszenie (studs przy skali 1),
--   FxType = "Pulse" — serce Mythic: skala części 1 + FxAmount w rytmie FxRate uderzeń/s (podwójne „bum-bum”).
-- Oś i spoczynkowe położenie są w układzie pivotu przedmiotu, więc działa po ScaleTo i obrocie z serwera.
-- Części są zakotwiczone (BaseService) — klient tylko nadpisuje CFrame/Size lokalnie po PivotTo całego modelu.

export type Part = {
	part: BasePart,
	kind: string,
	rest: CFrame, -- względem pivotu przedmiotu
	axis: Vector3,
	speed: number, -- rad/s
	bob: number,
	amount: number,
	rate: number,
	size: Vector3,
	phase: number,
}

local ItemFx = {}

-- Zbiera animowane części przedmiotu (wywołać, gdy model jest jeszcze w pozycji z serwera).
function ItemFx.collect(item: Model): { Part }
	local out: { Part } = {}
	local pivot = item:GetPivot()
	local scale = item:GetScale()
	for _, inst in item:GetDescendants() do
		if not inst:IsA("BasePart") then
			continue
		end
		local kind = inst:GetAttribute("FxType")
		if type(kind) ~= "string" then
			continue
		end
		local axis = inst:GetAttribute("FxAxis")
		local speed = inst:GetAttribute("FxSpeed")
		local bob = inst:GetAttribute("FxBob")
		local amount = inst:GetAttribute("FxAmount")
		local rate = inst:GetAttribute("FxRate")
		table.insert(out, {
			part = inst,
			kind = kind,
			rest = pivot:ToObjectSpace(inst.CFrame),
			axis = if typeof(axis) == "Vector3" and axis.Magnitude > 0 then axis.Unit else Vector3.yAxis,
			speed = math.rad(if type(speed) == "number" then speed else 0),
			bob = (if type(bob) == "number" then bob else 0) * scale,
			amount = if type(amount) == "number" then amount else 0,
			rate = if type(rate) == "number" then rate else 1,
			size = inst.Size,
			phase = #out * 0.9,
		})
	end
	return out
end

-- Rytm serca: dwa krótkie uderzenia na cykl (0..1), potem przerwa.
local function heartbeat(t: number, rate: number): number
	local x = (t * rate) % 1
	local a = math.max(0, 1 - math.abs(x - 0.08) / 0.08)
	local b = math.max(0, 1 - math.abs(x - 0.3) / 0.09) * 0.6
	return math.max(a, b)
end

-- Ustawia części dla pivotu przedmiotu `pivot` w czasie `t`. Zwraca siłę pulsu (0..1) do jasności światła.
function ItemFx.apply(parts: { Part }, pivot: CFrame, t: number): number
	local beat = 0
	for _, p in parts do
		local part = p.part
		if p.kind == "Spin" then
			part.CFrame = pivot * CFrame.fromAxisAngle(p.axis, p.speed * t) * p.rest
		elseif p.kind == "Orbit" then
			local lift = math.sin(t * 1.7 + p.phase) * p.bob
			part.CFrame = pivot * CFrame.new(0, lift, 0) * CFrame.fromAxisAngle(Vector3.yAxis, p.speed * t) * p.rest
		elseif p.kind == "Pulse" then
			local k = heartbeat(t, p.rate)
			beat = math.max(beat, k)
			part.Size = p.size * (1 + p.amount * k)
			part.CFrame = pivot * p.rest
		end
	end
	return beat
end

return ItemFx
