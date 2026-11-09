--!strict
-- Store — stan UI klienta: dane z serwera potrzebne HUD (kasa, $/s, paliwo, czas do gwiazdy) i stan okien/toastów.
-- Każda zmiana tworzy nową tabelę stanu, więc komponenty React porównują referencje (Store.use).
-- Tylko do odczytu — zmiany danych gry idą przez Remotes, serwer odsyła delty (StateController → UIController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Theme = require(script.Parent.Theme)

export type ToastKind = "info" | "success" | "error"
export type Toast = { id: number, text: string, kind: ToastKind }
-- Spadająca gwiazda dla paska w HUD (wypełnia Fx/StarHud z ogłoszeń StarService). Czasy = czas serwera.
export type Incoming = {
	id: string,
	name: string,
	color: Color3,
	glow: Color3,
	launchedAt: number,
	impactAt: number,
}
export type WindowId = "Shop" | "Base" | "Index" | "Rides" | "Premium" | "Sell" | "Pedestal" | "Welcome" | "Settings"
-- Przedmiot gracza (kopia z PlayerState.items, BaseController).
export type OwnedItem = { itemId: string, mutation: string, obtainedAt: number, slot: number? }
-- Podsumowanie offline do okna „Welcome back” (EconomyService → WelcomeInfo).
export type Welcome = { seconds: number, amount: number, income: number }
export type State = {
	loaded: boolean,
	cash: number,
	cashGain: { id: number, amount: number }?, -- ostatni przyrost kasy (latające monety)
	incomePerSec: number, -- atrybut gracza IncomePerSec (ustawia baza, T08)
	fuel: number?, -- atrybut Fuel (ustawia jetpack, T10); nil = pasek ukryty
	fuelMax: number,
	nextStarAt: number?, -- atrybut Workspace.NextStarAt (StarService), czas serwera
	incoming: { Incoming }, -- spadające gwiazdy, najbliższe uderzenie pierwsze
	window: WindowId?,
	tab: string?, -- zakładka otwartego okna (np. sklep: "tools" | "exclusives")
	toasts: { Toast },
	hudHidden: boolean,
	-- Baza (T08, BaseController): przedmioty, kupione sloty, pojemność (z gamepassami), cena slotu, mnożnik.
	items: { [string]: OwnedItem },
	slots: number,
	capacity: number,
	nextSlotPrice: number?, -- nil = maksimum
	incomeMult: number,
	pedestal: number?, -- slot otwarty w oknie Pedestal
	welcome: Welcome?,
	-- Dane gracza dla ekranów T14 (UIController ← StateController): narzędzia, pojazdy, indeks, rebirth, ustawienia.
	tools: { [string]: boolean },
	equippedTool: string,
	vehicles: { [string]: boolean },
	jetpackLevel: number,
	rebirths: number,
	index: { [string]: boolean },
	settings: { [string]: boolean }, -- brak klucza = DataConfig.SETTING_DEFAULTS
	lobbyReadyAt: number?, -- czas serwera, od kiedy Return to Lobby znowu działa
}

local state: State = {
	loaded = false,
	cash = 0,
	cashGain = nil,
	incomePerSec = 0,
	fuel = nil,
	fuelMax = 1,
	nextStarAt = nil,
	incoming = {},
	window = nil,
	toasts = {},
	hudHidden = false,
	items = {},
	slots = 0,
	capacity = 0,
	nextSlotPrice = nil,
	incomeMult = 1,
	pedestal = nil,
	welcome = nil,
	tools = {},
	equippedTool = "",
	vehicles = {},
	jetpackLevel = 1,
	rebirths = 0,
	index = {},
	settings = {},
	lobbyReadyAt = nil,
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

function Store.addIncoming(entry: Incoming)
	local list = table.clone(state.incoming)
	table.insert(list, entry)
	table.sort(list, function(a, b)
		return a.impactAt < b.impactAt
	end)
	Store.set({ incoming = list })
end

function Store.removeIncoming(id: string)
	local list = {}
	for _, entry in state.incoming do
		if entry.id ~= id then
			table.insert(list, entry)
		end
	end
	if #list ~= #state.incoming then
		Store.set({ incoming = list })
	end
end

-- Otwiera okno (pierwsza zakładka); to samo okno drugi raz = zamyka.
function Store.openWindow(id: WindowId, tab: string?)
	Store.set({ window = if state.window == id then Store.none else id, tab = tab or Store.none })
end

function Store.closeWindow()
	Store.set({ window = Store.none, tab = Store.none })
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
