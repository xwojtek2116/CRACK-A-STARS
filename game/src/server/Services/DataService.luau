--!strict
-- DataService — dane gracza na ProfileStore: sesja przy wejściu, zapis przy wyjściu, migracje schematu,
-- replikacja stanu do klienta (PlayerState + delty StateDelta) i leaderstats (Cash, Rebirths).
-- Jedyne miejsce, które zmienia dane gracza: DataService.update(player, fn).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataConfig = require(Shared.Config.DataConfig)
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local ProfileStore = require(ServerScriptService:WaitForChild("ServerPackages"):WaitForChild("ProfileStore")) :: any
local PlayerSchema = require(script.Parent.Parent.Data.PlayerSchema)

type PlayerData = Types.PlayerData
type LoadedCallback = (player: Player, data: PlayerData) -> ()
type ChangedCallback = (player: Player, newValue: any, oldValue: any) -> ()

-- Klucze, których klient nie dostaje.
local HIDDEN_KEYS: { [string]: boolean } = {
	purchases = true,
	pity = true, -- liczniki pity (klient widzi tylko pasek postępu z osobnego remote, jeśli będzie)
	lastOnline = true, -- zmienia się co tik dochodu (EconomyService), klientowi niepotrzebny
}

local log = Logger.new("DataService")

local store: any = nil
local profiles: { [Player]: any } = {}
-- Ostatni stan wysłany do klienta (głęboka kopia) — z niego liczymy delty i stare wartości dla onChanged.
local replicated: { [Player]: { [string]: any } } = {}
local leaderstatsValues: { [Player]: { Cash: NumberValue, Rebirths: IntValue } } = {}

local loadedCallbacks: { LoadedCallback } = {}
local changedCallbacks: { [string]: { ChangedCallback } } = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function visibleState(data: PlayerData): { [string]: any }
	local state = {}
	for key, value in data :: any do
		if not HIDDEN_KEYS[key] then
			state[key] = deepCopy(value)
		end
	end
	return state
end

local function fireChanged(player: Player, key: string, newValue: any, oldValue: any)
	local callbacks = changedCallbacks[key]
	if not callbacks then
		return
	end
	for _, callback in callbacks do
		task.spawn(callback, player, newValue, oldValue)
	end
end

local function setupLeaderstats(player: Player, data: PlayerData)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Value = data.cash
	cash.Parent = folder

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = data.rebirths
	rebirths.Parent = folder

	folder.Parent = player
	leaderstatsValues[player] = { Cash = cash, Rebirths = rebirths }
end

local function cleanup(player: Player)
	profiles[player] = nil
	replicated[player] = nil
	leaderstatsValues[player] = nil
end

local function loadPlayer(player: Player)
	if profiles[player] then
		return
	end

	local profile = store:StartSessionAsync(`{DataConfig.KEY_PREFIX}{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		if player.Parent == Players then
			log:error(`Nie udało się wczytać danych {player.Name}`)
			player:Kick(DataConfig.LOAD_FAILED_KICK)
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR
	local migrated, fromVersion = PlayerSchema.migrate(profile.Data)
	if not migrated then
		log:warn(`{player.Name}: dane w nowszej wersji schematu ({fromVersion}) — bez migracji`)
	elseif fromVersion ~= DataConfig.SCHEMA_VERSION then
		log:info(`{player.Name}: migracja schematu {fromVersion} → {DataConfig.SCHEMA_VERSION}`)
	end
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		cleanup(player)
		if player.Parent == Players then
			player:Kick(DataConfig.SESSION_LOST_KICK)
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	local data = profile.Data :: PlayerData
	profiles[player] = profile
	replicated[player] = visibleState(data)
	setupLeaderstats(player, data)
	Remotes.fireClient("PlayerState", player, replicated[player])
	log:debug(`Wczytano dane {player.Name} (cash {data.cash})`)

	for _, callback in loadedCallbacks do
		task.spawn(callback, player, data)
	end
end

local DataService = {}

-- Dane gracza albo nil (jeszcze nie wczytane / wyszedł). Traktuj jako tylko do odczytu — zmiany przez update().
function DataService.get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile then profile.Data :: PlayerData else nil
end

function DataService.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Zmienia dane gracza w fn (w miejscu), potem wysyła klientowi delty zmienionych kluczy
-- i woła słuchaczy onChanged. Zwraca false, gdy danych nie ma albo fn rzuciła błąd.
function DataService.update(player: Player, fn: (data: PlayerData) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local data = profile.Data :: PlayerData

	local ok, err = pcall(fn, data)
	if not ok then
		log:error(`update {player.Name}: {err}`)
	end

	local previous = replicated[player]
	local delta = {}
	local changed = false
	for key, value in data :: any do
		if HIDDEN_KEYS[key] or deepEqual(value, previous[key]) then
			continue
		end
		local oldValue = previous[key]
		local newValue = deepCopy(value)
		previous[key] = newValue
		delta[key] = newValue
		changed = true
		fireChanged(player, key, newValue, oldValue)
	end

	if changed then
		local stats = leaderstatsValues[player]
		if stats then
			stats.Cash.Value = data.cash
			stats.Rebirths.Value = data.rebirths
		end
		Remotes.fireClient("StateDelta", player, delta)
	end
	return ok
end

-- Woła callback po wczytaniu danych gracza (także dla już wczytanych w chwili rejestracji).
function DataService.onLoaded(callback: LoadedCallback): () -> ()
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
	return function()
		local index = table.find(loadedCallbacks, callback)
		if index then
			table.remove(loadedCallbacks, index)
		end
	end
end

-- Woła callback(player, newValue, oldValue) po zmianie klucza najwyższego poziomu (np. "cash", "items").
function DataService.onChanged(key: string, callback: ChangedCallback): () -> ()
	local list = changedCallbacks[key]
	if not list then
		list = {}
		changedCallbacks[key] = list
	end
	table.insert(list, callback)
	return function()
		local index = table.find(list, callback)
		if index then
			table.remove(list, index)
		end
	end
end

function DataService.Init()
	store = ProfileStore.New(DataConfig.STORE_NAME, PlayerSchema.template())
end

function DataService.Start()
	-- Klient, który podłączył się po PlayerState, prosi o pełny stan sam.
	Remotes.onInvoke("RequestState", function(player)
		return replicated[player]
	end)

	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
		cleanup(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	game:BindToClose(function()
		for _, profile in profiles do
			profile:EndSession()
		end
	end)

	-- Tylko Studio: hak dla testów przez MCP (execute_luau działa w osobnej VM i nie widzi tego modułu).
	-- ServerStorage.DebugHooks.DataService:Invoke("get", userId) / ("addCash", userId, amount)
	if RunService:IsStudio() then
		local hooks = Instance.new("Folder")
		hooks.Name = "DebugHooks"
		local hook = Instance.new("BindableFunction")
		hook.Name = "DataService"
		hook.OnInvoke = function(command: string, userId: number, amount: number?)
			local player = Players:GetPlayerByUserId(userId)
			if not player then
				return nil
			end
			if command == "addCash" and type(amount) == "number" then
				DataService.update(player, function(data)
					data.cash += amount
				end)
			end
			return DataService.get(player)
		end
		hook.Parent = hooks
		hooks.Parent = game:GetService("ServerStorage")
	end

	-- Tryb testowy: bez API Services ProfileStore trzyma dane w pamięci (nic się nie zapisze).
	task.spawn(function()
		while ProfileStore.DataStoreState == "NotReady" do
			task.wait()
		end
		if ProfileStore.DataStoreState ~= "Access" then
			log:warn(
				`TRYB TESTOWY: brak dostępu do DataStore ({ProfileStore.DataStoreState}) — dane tylko w pamięci, bez zapisu`
			)
		else
			log:info("DataStore dostępny — zapis włączony")
		end
	end)
end

return DataService
