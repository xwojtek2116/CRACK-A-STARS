--!strict
-- CrackRound — wspólna logika rundy minigry rozbijania (serwer liczy, klient pokazuje to samo).
-- Runda = `targets` punktów narzędzia, kolejno co spawnGap; każdy kurczy się przez shrinkTime.
-- Ocena: faza = (t − spawnAt) / shrinkTime, błąd = |faza − 1|; ≤ perfect.window/2 → Perfect,
-- ≤ good.window/2 → Good, reszta albo brak trafienia → Miss. Pozycje i słaby punkt wynikają z seed.

local ToolsData = require(script.Parent.Config.Data.Tools) :: any

export type Grade = "Perfect" | "Good" | "Miss"

export type ToolDef = {
	name: string,
	tier: number,
	price: number,
	damage: number,
	cooldown: number,
	targets: number,
	targetSize: number,
	shrinkTime: number,
	crit: number,
}

export type Fx = {
	coneDeg: number,
	fovZoom: number,
	shakePerfect: number,
	shakeCrit: number,
	shakeTime: number,
	numberRise: number,
	numberTime: number,
}

export type Minigame = {
	perfect: { window: number, mult: number },
	good: { window: number, mult: number },
	miss: { mult: number },
	critMult: number,
	autoCrackGrade: string,
	weakSpotMult: number,
	spawnGap: number,
	range: number,
	latencyGrace: number,
	minTapGap: number,
	cooldownGrace: number,
	fx: Fx,
}

export type Target = {
	index: number,
	spawnAt: number, -- s od startu rundy
	closeAt: number, -- chwila zamknięcia pierścienia (idealne trafienie)
	endAt: number, -- po tym punkt znika (Miss)
	weak: boolean,
	yaw: number, -- odchylenie od kierunku gracz→gwiazda (radiany)
	pitch: number,
}

export type Round = {
	seed: number,
	toolId: string,
	targets: { Target },
	duration: number,
}

local TOOLS: { [string]: ToolDef } = ToolsData.tools
local MINIGAME: Minigame = ToolsData.minigame

local CrackRound = {
	TOOLS = TOOLS,
	MINIGAME = MINIGAME,
	MULT = {
		Perfect = MINIGAME.perfect.mult,
		Good = MINIGAME.good.mult,
		Miss = MINIGAME.miss.mult,
	} :: { [Grade]: number },
}

-- Ranking ocen (do „co najmniej Good”).
local RANK: { [Grade]: number } = { Miss = 0, Good = 1, Perfect = 2 }

function CrackRound.rank(grade: Grade): number
	return RANK[grade]
end

function CrackRound.getTool(toolId: string): ToolDef?
	return TOOLS[toolId]
end

-- Buduje rundę z seed. Ten sam seed i narzędzie = te same punkty na serwerze i kliencie.
function CrackRound.build(seed: number, toolId: string): Round?
	local tool = TOOLS[toolId]
	if not tool then
		return nil
	end
	local rng = Random.new(seed)
	local cone = math.rad(MINIGAME.fx.coneDeg)
	local life = tool.shrinkTime * (1 + MINIGAME.good.window / 2)
	local weakIndex = rng:NextInteger(1, tool.targets)
	local targets: { Target } = {}
	local lastYaw = 0
	for index = 1, tool.targets do
		-- Kolejne punkty nie lądują w tym samym miejscu: odsunięcie co najmniej ~1/3 stożka.
		local yaw = rng:NextNumber(-cone, cone)
		if index > 1 and math.abs(yaw - lastYaw) < cone / 3 then
			yaw = if yaw > 0 then yaw - cone * 0.8 else yaw + cone * 0.8
		end
		lastYaw = yaw
		local spawnAt = (index - 1) * MINIGAME.spawnGap
		table.insert(targets, {
			index = index,
			spawnAt = spawnAt,
			closeAt = spawnAt + tool.shrinkTime,
			endAt = spawnAt + life,
			weak = index == weakIndex,
			yaw = yaw,
			pitch = rng:NextNumber(-0.1, 0.75) * cone,
		})
	end
	return {
		seed = seed,
		toolId = toolId,
		targets = targets,
		duration = (tool.targets - 1) * MINIGAME.spawnGap + life,
	}
end

-- Ocena trafienia w chwili t (s od startu rundy). nil/poza oknem = Miss.
function CrackRound.grade(round: Round, target: Target, t: number?): Grade
	if t == nil or t < target.spawnAt or t > target.endAt then
		return "Miss"
	end
	local tool = TOOLS[round.toolId]
	local err = math.abs((t - target.spawnAt) / tool.shrinkTime - 1)
	if err <= MINIGAME.perfect.window / 2 then
		return "Perfect"
	elseif err <= MINIGAME.good.window / 2 then
		return "Good"
	end
	return "Miss"
end

-- Mnożnik rundy: średnia mnożników ocen × słaby punkt (jeśli trafiony co najmniej na Good).
function CrackRound.multiplier(round: Round, grades: { Grade }): (number, boolean)
	local sum = 0
	local weakHit = false
	for index, target in round.targets do
		local grade = grades[index] or "Miss"
		sum += CrackRound.MULT[grade]
		if target.weak and RANK[grade] >= RANK.Good then
			weakHit = true
		end
	end
	local mult = sum / math.max(#round.targets, 1)
	if weakHit then
		mult *= MINIGAME.weakSpotMult
	end
	return mult, weakHit
end

-- Ocena całej rundy do wyświetlenia (z mnożnika bez słabego punktu i krytyka).
function CrackRound.overall(mult: number): Grade
	if mult >= CrackRound.MULT.Perfect * 0.9 then
		return "Perfect"
	elseif mult >= CrackRound.MULT.Good then
		return "Good"
	end
	return "Miss"
end

return CrackRound
