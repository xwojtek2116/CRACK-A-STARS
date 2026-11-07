--!strict
-- StateController — kopia stanu gracza po stronie klienta (tylko do odczytu).
-- Pełny stan z PlayerState (albo RequestState przy późnym podłączeniu), potem delty StateDelta.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

type PlayerState = Types.PlayerData
type ChangedCallback = (newValue: any, oldValue: any) -> ()

local log = Logger.new("StateController")

local state: { [string]: any }? = nil
local loadedCallbacks: { (state: PlayerState) -> () } = {}
local changedCallbacks: { [string]: { ChangedCallback } } = {}

local function setFullState(newState: { [string]: any })
	local previous = state
	state = newState
	if previous == nil then
		log:debug(`Stan wczytany (cash {newState.cash})`)
		for _, callback in loadedCallbacks do
			task.spawn(callback, newState :: any)
		end
	end
	for key, value in newState do
		local callbacks = changedCallbacks[key]
		if callbacks then
			for _, callback in callbacks do
				task.spawn(callback, value, if previous then previous[key] else nil)
			end
		end
	end
end

local StateController = {}

-- Bieżący stan albo nil, jeśli serwer jeszcze go nie przysłał.
function StateController.get(): PlayerState?
	return state :: any
end

function StateController.onLoaded(callback: (state: PlayerState) -> ())
	table.insert(loadedCallbacks, callback)
	if state then
		task.spawn(callback, state :: any)
	end
end

-- callback(newValue, oldValue) po zmianie klucza najwyższego poziomu (np. "cash").
function StateController.onChanged(key: string, callback: ChangedCallback): () -> ()
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

function StateController.Init() end

function StateController.Start()
	Remotes.connect("PlayerState", setFullState)
	Remotes.connect("StateDelta", function(delta: { [string]: any })
		local current = state
		if not current then
			return -- pełny stan i tak przyjdzie
		end
		for key, value in delta do
			local oldValue = current[key]
			current[key] = value
			local callbacks = changedCallbacks[key]
			if callbacks then
				for _, callback in callbacks do
					task.spawn(callback, value, oldValue)
				end
			end
		end
	end)

	if state == nil then
		local fetched = Remotes.invoke("RequestState")
		if fetched and state == nil then
			setFullState(fetched)
		end
	end
end

return StateController
