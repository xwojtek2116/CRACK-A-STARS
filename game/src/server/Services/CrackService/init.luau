--!strict
-- CrackService — minigra rozbijania po stronie serwera (jedyne źródło prawdy o obrażeniach).
-- CrackStart(starId): sprawdza gwiazdę, odległość, narzędzie w ręku, cooldown → { roundId, seed, toolId, autoCrack }.
-- CrackFinish(roundId, times): odtwarza rundę z seed (Shared/CrackRound), odrzuca niemożliwe czasy,
-- liczy mnożnik (średnia ocen × słaby punkt), krytyk losuje serwer → StarService.damage → CrackResult do wszystkich.
-- Auto Crack (gamepass albo atrybut DevAutoCrack w Studio): każdy punkt co najmniej Good.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrackRound = require(Shared.CrackRound)
local Logger = require(Shared.Logger)
local Monetization = require(Shared.Config.Data.Monetization) :: any
local Remotes = require(Shared.Remotes)
local StarConfig = require(Shared.Config.StarConfig)

local Services = script.Parent
local DataService = require(Services.DataService)
local StarService = require(Services.StarService)

type Round = CrackRound.Round
type Grade = CrackRound.Grade

type Active = {
	id: number,
	starId: string,
	round: Round,
	startedAt: number, -- os.clock serwera
	autoCrack: boolean,
}

type PlayerState = {
	active: Active?,
	nextStartAt: number, -- os.clock; wcześniej CrackStart odrzucany (cooldown narzędzia)
	rejected: number,
}

type BoostProvider = (player: Player) -> number

local MINIGAME = CrackRound.MINIGAME
local IS_STUDIO = RunService:IsStudio()
local REJECT_LOG_EVERY = 10

local log = Logger.new("CrackService")
local rng = Random.new()
local seedRng = Random.new()
local states: { [Player]: PlayerState } = {}
local autoCrackCache: { [Player]: boolean } = {}
local roundCounter = 0
-- Mnożnik boostów (eventy, produkty) — podpinają go inne serwisy; domyślnie 1.
local boostProvider: BoostProvider = function(_player: Player)
	return 1
end

local function findGamepassId(id: string): number?
	for _, pass in Monetization.gamepasses do
		if pass.id == id and type(pass.assetId) == "number" and pass.assetId > 0 then
			return pass.assetId
		end
	end
	return nil
end

local AUTO_CRACK_PASS = findGamepassId("auto_crack")

local CrackService = {}

local function getState(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = { active = nil, nextStartAt = 0, rejected = 0 }
		states[player] = state
	end
	return state
end

local function reject(player: Player, reason: string): (nil, string)
	local state = getState(player)
	state.rejected += 1
	if state.rejected == 1 or state.rejected % REJECT_LOG_EVERY == 0 then
		log:warn(`Odrzucono {player.Name}: {reason} (łącznie {state.rejected})`)
	end
	return nil, reason
end

local function hasAutoCrack(player: Player): boolean
	if IS_STUDIO and player:GetAttribute("DevAutoCrack") == true then
		return true
	end
	return autoCrackCache[player] == true
end

local function refreshAutoCrack(player: Player)
	if not AUTO_CRACK_PASS then
		return
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, AUTO_CRACK_PASS)
	if ok then
		autoCrackCache[player] = owns == true
	else
		log:warn(`UserOwnsGamePassAsync {player.Name}: {owns}`)
	end
end

-- Narzędzie w ręku: Tool z atrybutem ToolId = equippedTool z danych gracza.
local function heldTool(player: Player): string?
	local character = player.Character
	local data = DataService.get(player)
	if not character or not data then
		return nil
	end
	local tool = character:FindFirstChildWhichIsA("Tool")
	if not tool or tool:GetAttribute("ToolId") ~= data.equippedTool then
		return nil
	end
	return if CrackRound.getTool(data.equippedTool) then data.equippedTool else nil
end

-- Czy gracz stoi przy gwieździe: odległość korzenia postaci od środka ≤ promień + range.
local function inRange(player: Player, starId: string): (boolean, Vector3?)
	local info, model = StarService.getStar(starId)
	if not info or not model or info.state ~= "Landed" then
		return false, nil
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false, nil
	end
	local class = StarConfig.CLASSES[info.size]
	local center = model:GetPivot().Position
	local reach = class.size / 2 + MINIGAME.range
	return (root.Position - center).Magnitude <= reach, center
end

local function onStart(player: Player, starId: string): any
	local state = getState(player)
	local clock = os.clock()
	local active = state.active
	if active then
		-- Runda bez CrackFinish po czasie trwania + zapas wygasa (bez obrażeń).
		if clock - active.startedAt <= active.round.duration + MINIGAME.latencyGrace * 2 then
			return reject(player, "RoundActive")
		end
		state.active = nil
	end
	if clock < state.nextStartAt then
		return reject(player, "Cooldown")
	end
	local toolId = heldTool(player)
	if not toolId then
		return reject(player, "NoTool")
	end
	local ok = inRange(player, starId)
	if not ok then
		return nil, "OutOfRange" -- częste przy normalnej grze, bez logu
	end

	roundCounter += 1
	local seed = seedRng:NextInteger(1, 2 ^ 30)
	local round = CrackRound.build(seed, toolId) :: Round
	local autoCrack = hasAutoCrack(player)
	state.active = {
		id = roundCounter,
		starId = starId,
		round = round,
		startedAt = clock,
		autoCrack = autoCrack,
	}
	return { roundId = roundCounter, seed = seed, toolId = toolId, autoCrack = autoCrack }
end

-- Sprawdza, czy zgłoszone czasy są możliwe. Zwraca oceny albo nil (runda odrzucona).
local function gradeTimes(active: Active, times: { number }, elapsed: number): { Grade }?
	local round = active.round
	if #times ~= #round.targets then
		return nil
	end
	local hits: { number } = {}
	local grades: { Grade } = {}
	for index, target in round.targets do
		local t = times[index]
		if t >= 0 then
			-- Nie da się zgłosić trafienia później, niż CrackFinish dotarł do serwera.
			if t > elapsed + MINIGAME.latencyGrace then
				return nil
			end
			table.insert(hits, t)
			grades[index] = CrackRound.grade(round, target, t)
		else
			grades[index] = "Miss"
		end
		if active.autoCrack and CrackRound.rank(grades[index]) < CrackRound.rank("Good") then
			grades[index] = "Good"
		end
	end
	-- Dwa trafienia w tej samej chwili = nie z palca/myszki.
	table.sort(hits)
	for i = 2, #hits do
		if hits[i] - hits[i - 1] < MINIGAME.minTapGap then
			return nil
		end
	end
	return grades
end

local function onFinish(player: Player, roundId: number, times: { number })
	local state = getState(player)
	local active = state.active
	if not active or active.id ~= roundId then
		reject(player, "UnknownRound")
		return
	end
	state.active = nil
	local tool = CrackRound.getTool(active.round.toolId)
	if not tool then
		return
	end
	local clock = os.clock()
	local elapsed = clock - active.startedAt
	-- Cooldown liczony od końca rundy (z małym zapasem na opóźnienie sieci).
	state.nextStartAt = clock + tool.cooldown * (1 - MINIGAME.cooldownGrace)

	if elapsed > active.round.duration + MINIGAME.latencyGrace * 2 then
		reject(player, "RoundExpired")
		return
	end
	local grades = gradeTimes(active, times, elapsed)
	if not grades then
		reject(player, "ImpossibleTimes")
		return
	end
	local ok, center = inRange(player, active.starId)
	if not ok or not center then
		reject(player, "OutOfRange")
		return
	end

	local mult, weakHit = CrackRound.multiplier(active.round, grades)
	local crit = rng:NextNumber() < tool.crit
	local boost = boostProvider(player)
	local amount = math.max(1, math.round(tool.damage * mult * boost * (if crit then MINIGAME.critMult else 1)))
	local applied = StarService.damage(player.UserId, active.starId, amount)
	if applied <= 0 then
		return
	end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local toward = if root then (root.Position - center) else Vector3.zero
	local info = StarService.getStar(active.starId)
	local radius = if info then StarConfig.CLASSES[info.size].size / 2 else 0
	local pos = center + (if toward.Magnitude > 0.01 then toward.Unit * radius * 0.8 else Vector3.zero)
	Remotes.fireAllClients("CrackResult", {
		starId = active.starId,
		userId = player.UserId,
		damage = applied,
		grade = CrackRound.overall(if weakHit then mult / MINIGAME.weakSpotMult else mult),
		grades = grades,
		crit = crit,
		weak = weakHit,
		pos = pos,
	})
end

-- Czy gracz jest w trakcie rundy minigry (LobbyService blokuje wtedy Return to Lobby).
function CrackService.isInRound(player: Player): boolean
	local state = states[player]
	local active = state and state.active
	if not active then
		return false
	end
	return os.clock() - active.startedAt <= active.round.duration + MINIGAME.latencyGrace * 2
end

-- Inne serwisy (boosty, eventy) podają mnożnik obrażeń gracza.
function CrackService.setBoostProvider(provider: BoostProvider)
	boostProvider = provider
end

function CrackService.Init()
	Remotes.onInvoke("CrackStart", onStart)
	Remotes.onEvent("CrackFinish", onFinish)
end

function CrackService.Start()
	DataService.onLoaded(function(player: Player)
		task.spawn(refreshAutoCrack, player)
	end)
	if AUTO_CRACK_PASS then
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
			if purchased and passId == AUTO_CRACK_PASS then
				autoCrackCache[player] = true
			end
		end)
	else
		log:info(
			"Brak assetId gamepassa auto_crack w Monetization.json — Auto Crack tylko przez DevAutoCrack (Studio)"
		)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		autoCrackCache[player] = nil
	end)
end

return CrackService
