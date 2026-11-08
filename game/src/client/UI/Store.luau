--!strict
-- Store — stan UI klienta: dane z serwera potrzebne HUD (kasa, $/s, paliwo, czas do gwiazdy) i stan okien/toastów.
-- Każda zmiana tworzy nową tabelę stanu, więc komponenty React porównują referencje (Store.use).
-- Tylko do odczytu — zmiany danych gry idą przez Remotes, serwer odsyła delty (StateController → UIController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Theme = require(script.Parent.Theme)

export type ToastKind = "info" | "success" | "error"
export type Toast = { id: number, text: string, kind: ToastKind }
export type WindowId = "Shop" | "Base" | "Index" | "Rides" | "Premium"
export type State = {
	loaded: boolean,
	cash: number,
	cashGain: { id: number, amount: number }?, -- ostatni przyrost kasy (latające monety)
	incomePerSec: number, -- atrybut gracza IncomePerSec (ustawia baza, T08)
	fuel: number?, -- atrybut Fuel (ustawia jetpack, T10); nil = pasek ukryty
	fuelMax: number,
	nextStarAt: number?, -- atrybut Workspace.NextStarAt (StarService), czas serwera
	window: WindowId?,
	toasts: { Toast },
	hudHidden: boolean,
}

local state: State = {
	loaded = false,
	cash = 0,
	cashGain = nil,
	incomePerSec = 0,
	fuel = nil,
	fuelMax = 1,
	nextStarAt = nil,
	window = nil,
	toasts = {},
	hudHidden = false,
}
local listeners: { (State) -> () } = {}
local nextId = 0

local Store = {}

-- Wartość w patchu Store.set, która usuwa pole (nil w tabeli patcha nie istnieje).
Store.none = table.freeze({})

function Store.get(): State
	return state
end

function Store.subscribe(listener: (State) -> ()): () -> ()
	table.insert(listeners, listener)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function Store.set(patch: { [string]: any })
	local newState = table.clone(state) :: any
	for key, value in patch do
		newState[key] = if value == Store.none then nil else value
	end
	state = newState
	for _, listener in table.clone(listeners) do
		task.spawn(listener, state)
	end
end

function Store.nextId(): number
	nextId += 1
	return nextId
end

-- Nowa kwota kasy; przyrost (po wczytaniu) uruchamia latające monety w HUD.
function Store.setCash(cash: number)
	local previous = state.cash
	if state.loaded and cash > previous then
		Store.set({ cash = cash, cashGain = { id = Store.nextId(), amount = cash - previous } })
	else
		Store.set({ cash = cash, loaded = true })
	end
end

function Store.toast(text: string, kind: ToastKind?)
	local id = Store.nextId()
	local list = table.clone(state.toasts)
	table.insert(list, { id = id, text = text, kind = kind or "info" })
	while #list > Theme.MAX_TOASTS do
		table.remove(list, 1)
	end
	Store.set({ toasts = list })
	task.delay(Theme.TOAST_SECONDS, function()
		local remaining = {}
		for _, toast in state.toasts do
			if toast.id ~= id then
				table.insert(remaining, toast)
			end
		end
		if #remaining ~= #state.toasts then
			Store.set({ toasts = remaining })
		end
	end)
end

function Store.openWindow(id: WindowId)
	Store.set({ window = if state.window == id then Store.none else id })
end

function Store.closeWindow()
	Store.set({ window = Store.none })
end

-- Hook React: wartość wybrana z Store; przerysowanie, gdy selektor zwróci inną wartość.
function Store.use<T>(selector: (State) -> T): T
	local value, setValue = React.useState(selector(state))
	React.useEffect(function()
		setValue(selector(state))
		return Store.subscribe(function(newState)
			setValue(selector(newState))
		end)
	end, {})
	return value
end

return Store
