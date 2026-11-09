--!strict
-- EconomyService — kasa gracza i dochód bazy (T08):
--   • add/trySpend — jedyne wejście do zmian kasy z innych serwisów (przez DataService.update),
--   • dochód/s = BaseMath.incomePerSec (postumenty × rebirth × 2× Cash), przeliczany po zmianie przedmiotów,
--     slotów i rebirthów; wynik w atrybucie gracza IncomePerSec (HUD),
--   • tik co Economy.base.incomeTickSeconds: kasa += dochód × upływ czasu (ułamki przenoszone, kasa całkowita),
--     lastOnline = teraz (świeży przy każdym tiku, więc wyjście/padnięcie serwera nie zawyża offline),
--   • offline przy wejściu: min(teraz − lastOnline, 8 h) × dochód × 0,5 → od razu do kasy, a klient
--     pobiera podsumowanie do okna „Welcome back” przez WelcomeInfo (raz).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseMath = require(Shared.BaseMath)
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)

type PlayerData = Types.PlayerData

export type Welcome = { seconds: number, amount: number, income: number }

local ATTR_INCOME = "IncomePerSec"

local log = Logger.new("EconomyService")

local incomes: { [Player]: number } = {}
local carry: { [Player]: number } = {}
local welcome: { [Player]: Welcome } = {}

local EconomyService = {}

-- Dochód/s gracza (z mnożnikami), 0 gdy dane niewczytane.
function EconomyService.getIncome(player: Player): number
	return incomes[player] or 0
end

-- Przelicza dochód gracza. Wołaj po zmianach, których DataService nie zgłasza (np. gamepass, T16).
function EconomyService.refresh(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local income = BaseMath.incomePerSec(data)
	incomes[player] = income
	player:SetAttribute(ATTR_INCOME, income)
end

-- Dodaje kasę (amount ≥ 0). Zwraca false, gdy danych nie ma.
function EconomyService.add(player: Player, amount: number, reason: string?): boolean
	if amount ~= amount or amount < 0 or amount == math.huge then
		log:warn(`add {player.Name}: zła kwota {amount} ({reason or "?"})`)
		return false
	end
	return DataService.update(player, function(data: PlayerData)
		data.cash += amount
	end)
end

-- Pobiera kasę, jeśli wystarcza. Zwraca true po pobraniu.
function EconomyService.trySpend(player: Player, amount: number, reason: string?): boolean
	if amount ~= amount or amount < 0 or amount == math.huge then
		log:warn(`trySpend {player.Name}: zła kwota {amount} ({reason or "?"})`)
		return false
	end
	local spent = false
	DataService.update(player, function(data: PlayerData)
		if data.cash >= amount then
			data.cash -= amount
			spent = true
		end
	end)
	return spent
end

local function onLoaded(player: Player, data: PlayerData)
	local now = os.time()
	local income = BaseMath.incomePerSec(data)
	incomes[player] = income
	carry[player] = 0
	player:SetAttribute(ATTR_INCOME, income)

	local away = if data.lastOnline > 0 then math.max(now - data.lastOnline, 0) else 0
	local amount, counted = BaseMath.offlineEarnings(away, income)
	DataService.update(player, function(d: PlayerData)
		d.lastOnline = now
		if amount > 0 then
			d.cash += amount
			d.stats.offlineEarned = (d.stats.offlineEarned or 0) + amount
		end
	end)
	if amount > 0 then
		welcome[player] = { seconds = away, amount = amount, income = income }
		log:info(`{player.Name}: offline {away} s (liczone {counted} s) × {income}/s → +{amount}`)
	end
end

local function tick(dt: number)
	local now = os.time()
	for _, player in Players:GetPlayers() do
		if not DataService.isLoaded(player) then
			continue
		end
		local income = incomes[player] or 0
		local pending = (carry[player] or 0) + income * dt
		local whole = math.floor(pending)
		carry[player] = pending - whole
		DataService.update(player, function(data: PlayerData)
			data.lastOnline = now
			if whole > 0 then
				data.cash += whole
			end
		end)
	end
end

function EconomyService.Init() end

function EconomyService.Start()
	DataService.onLoaded(onLoaded)
	for _, key in { "items", "slots", "rebirths" } do
		DataService.onChanged(key, function(player)
			EconomyService.refresh(player)
		end)
	end

	Remotes.onInvoke("WelcomeInfo", function(player: Player)
		local info = welcome[player]
		welcome[player] = nil
		return info
	end)

	Players.PlayerRemoving:Connect(function(player)
		incomes[player] = nil
		carry[player] = nil
		welcome[player] = nil
	end)

	-- Tylko Studio (dane bez DataStore, więc bez prawdziwego ponownego wejścia): ta sama ścieżka co przy
	-- wejściu gracza. ServerStorage.DebugHooks.EconomyService:Invoke("rejoin", userId, secondsAway) → Welcome?
	if RunService:IsStudio() then
		local hooks = ServerStorage:FindFirstChild("DebugHooks") or Instance.new("Folder")
		hooks.Name = "DebugHooks"
		local hook = Instance.new("BindableFunction")
		hook.Name = "EconomyService"
		hook.OnInvoke = function(command: string, userId: number, seconds: number?)
			local player = Players:GetPlayerByUserId(userId)
			local data = player and DataService.get(player)
			if command ~= "rejoin" or not player or not data or type(seconds) ~= "number" then
				return nil
			end
			DataService.update(player, function(d: PlayerData)
				d.lastOnline = os.time() - seconds
			end)
			onLoaded(player, data)
			return welcome[player]
		end
		hook.Parent = hooks
		hooks.Parent = ServerStorage
	end

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(BaseMath.TICK_SECONDS)
			local now = os.clock()
			-- Po zawieszeniu serwera nie dopisujemy więcej niż 5 tików naraz.
			local dt = math.min(now - last, BaseMath.TICK_SECONDS * 5)
			last = now
			local ok, err = pcall(tick, dt)
			if not ok then
				log:error(`tick: {err}`)
			end
		end
	end)
end

return EconomyService
