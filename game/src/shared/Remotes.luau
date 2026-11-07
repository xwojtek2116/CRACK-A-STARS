--!strict
-- Remotes — jedyne miejsce definicji RemoteEvent/RemoteFunction.
-- Serwer tworzy je w ReplicatedStorage.Remotes i podpina handlery przez onEvent/onInvoke
-- (limit zapytań + schemat argumentów + pcall). Klient pobiera je przez fire/invoke/connect.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DataConfig = require(script.Parent.Config.DataConfig)
local Logger = require(script.Parent.Logger)
local NetConfig = require(script.Parent.Config.NetConfig)
local RateLimiter = require(script.Parent.Net.RateLimiter)
local Validate = require(script.Parent.Net.Validate)

type Checker = Validate.Checker

type Definition = {
	kind: "Event" | "Function",
	-- ToServer: klient → serwer (wymaga args). ToClient: serwer → klient.
	direction: "ToServer" | "ToClient",
	args: { Checker }?,
}

-- Nazwy remotów. Dodając remote, dopisz go tu, w DEFINITIONS i limit w Config/NetConfig.
export type RemoteName = "PlayerState" | "StateDelta" | "RequestState" | "SetSetting" | "Announcement"

local DEFINITIONS: { [RemoteName]: Definition } = {
	-- Stan gracza: pełny stan po wczytaniu, potem delty { [klucz] = nowa wartość }.
	PlayerState = { kind = "Event", direction = "ToClient" },
	StateDelta = { kind = "Event", direction = "ToClient" },
	-- Klient prosi o pełny stan, jeśli podłączył się po PlayerState. Zwraca stan albo nil.
	RequestState = { kind = "Function", direction = "ToServer", args = {} },
	-- Ustawienia gracza. SetSetting(klucz, wartość) → { ok, reason? }.
	SetSetting = {
		kind = "Function",
		direction = "ToServer",
		args = { Validate.oneOf(DataConfig.SETTING_KEYS), Validate.boolean },
	},
	-- Ogłoszenia dla wszystkich (rzadki łup, spadająca gwiazda): { kind, text, color? }.
	Announcement = { kind = "Event", direction = "ToClient" },
}

local FOLDER_NAME = "Remotes"
local IS_SERVER = RunService:IsServer()

local log = Logger.new("Remotes")
local folder: Folder? = nil
local invalidCounts: { [Player]: number } = {}

local function getFolder(): Folder
	if folder then
		return folder
	end
	if IS_SERVER then
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		for name, definition in DEFINITIONS do
			local remote = Instance.new(if definition.kind == "Event" then "RemoteEvent" else "RemoteFunction")
			remote.Name = name
			remote.Parent = created
		end
		created.Parent = ReplicatedStorage
		folder = created
	else
		folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	end
	return folder :: Folder
end

local function getDefinition(name: RemoteName, kind: "Event" | "Function"): Definition
	local definition = DEFINITIONS[name]
	assert(definition, `Unknown remote "{name}"`)
	assert(definition.kind == kind, `Remote "{name}" is a {definition.kind}, not a {kind}`)
	return definition
end

local function getEvent(name: RemoteName): RemoteEvent
	getDefinition(name, "Event")
	return getFolder():WaitForChild(name) :: RemoteEvent
end

local function getFunction(name: RemoteName): RemoteFunction
	getDefinition(name, "Function")
	return getFolder():WaitForChild(name) :: RemoteFunction
end

-- Wspólna bramka dla zapytań klienta: liczba argumentów, limit, schemat. Zwraca powód odrzucenia albo nil.
local function gate(
	player: Player,
	name: RemoteName,
	definition: Definition,
	args: { n: number, [number]: unknown }
): string?
	local allowed, rejectedTotal = RateLimiter.consume(player, name)
	if not allowed then
		if rejectedTotal == 1 or rejectedTotal % NetConfig.REJECT_LOG_EVERY == 0 then
			log:warn(`Rate limit: {player.Name} → {name} (odrzucono łącznie {rejectedTotal})`)
		end
		return "RateLimited"
	end

	local schema = definition.args or {}
	local ok, badIndex = false, nil
	if args.n <= NetConfig.MAX_ARGS then
		ok, badIndex = Validate.args(schema, args)
	end
	if not ok then
		local count = (invalidCounts[player] or 0) + 1
		invalidCounts[player] = count
		if count == 1 or count % NetConfig.INVALID_LOG_EVERY == 0 then
			local got = if badIndex then typeof(args[badIndex]) else `{args.n} args`
			log:warn(`Złe argumenty: {player.Name} → {name}, arg #{badIndex or "?"} ({got}), łącznie {count}`)
		end
		return "InvalidArgs"
	end
	return nil
end

local Remotes = {}

-- Serwer: tworzy folder z remotami. Wołane przez bootstrap przed Init serwisów.
function Remotes.setup()
	assert(IS_SERVER, "Remotes.setup is server-only")
	getFolder()
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		invalidCounts[player] = nil
	end)
end

-- Serwer: handler RemoteEvent klient → serwer. Argumenty są już sprawdzone schematem z DEFINITIONS.
function Remotes.onEvent(name: RemoteName, handler: (player: Player, ...any) -> ())
	assert(IS_SERVER, "Remotes.onEvent is server-only")
	local definition = getDefinition(name, "Event")
	assert(definition.direction == "ToServer", `Remote "{name}" is not ToServer`)
	getEvent(name).OnServerEvent:Connect(function(player, ...)
		if gate(player, name, definition, table.pack(...)) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			log:error(`Handler {name} ({player.Name}): {err}`)
		end
	end)
end

-- Serwer: handler RemoteFunction. Przy odrzuceniu klient dostaje (nil, "RateLimited" | "InvalidArgs" | "Error").
function Remotes.onInvoke(name: RemoteName, handler: (player: Player, ...any) -> ...any)
	assert(IS_SERVER, "Remotes.onInvoke is server-only")
	local definition = getDefinition(name, "Function")
	assert(definition.direction == "ToServer", `Remote "{name}" is not ToServer`)
	getFunction(name).OnServerInvoke = function(player, ...)
		local reason = gate(player, name, definition, table.pack(...))
		if reason then
			return nil, reason
		end
		local result = table.pack(pcall(handler, player, ...))
		if not result[1] then
			log:error(`Handler {name} ({player.Name}): {result[2]}`)
			return nil, "Error"
		end
		return table.unpack(result, 2, result.n)
	end
end

-- Serwer → klient.
function Remotes.fireClient(name: RemoteName, player: Player, ...: any)
	getEvent(name):FireClient(player, ...)
end

function Remotes.fireAllClients(name: RemoteName, ...: any)
	getEvent(name):FireAllClients(...)
end

-- Klient → serwer.
function Remotes.fire(name: RemoteName, ...: any)
	getEvent(name):FireServer(...)
end

function Remotes.invoke(name: RemoteName, ...: any): ...any
	return getFunction(name):InvokeServer(...)
end

-- Klient: nasłuch zdarzeń serwer → klient.
function Remotes.connect(name: RemoteName, handler: (...any) -> ()): RBXScriptConnection
	assert(not IS_SERVER, "Remotes.connect is client-only")
	return getEvent(name).OnClientEvent:Connect(handler)
end

return Remotes
