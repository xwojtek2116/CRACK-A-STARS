--!strict
-- Actions — prośby UI bazy do serwera (BaseService/SellService) i komunikaty dla gracza.
-- Klient niczego nie liczy „na serio”: wysyła prośbę, serwer odsyła wynik, stan wraca deltą.
-- Każda akcja działa w osobnym wątku (invoke czeka na serwer) — przyciski mogą ją wołać wprost.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseMath = require(Shared.BaseMath)
local LootConfig = require(Shared.Config.LootConfig)
local LootMath = require(Shared.LootMath)
local Remotes = require(Shared.Remotes)

local UI = script.Parent.Parent
local Format = require(UI.Format)
local Sfx = require(UI.Sfx)
local Store = require(UI.Store)

export type Entry = {
	uid: string,
	itemId: string,
	name: string,
	rarity: string,
	mutation: string,
	income: number, -- $/s z mnożnikiem gracza
	price: number, -- cena sprzedaży
	slot: number?, -- postument (nil = ekwipunek)
	confirm: boolean, -- sprzedaż wymaga potwierdzenia
}

local REASONS: { [string]: string } = {
	NoCash = "Not enough cash!",
	Max = "All pedestals unlocked!",
	InventoryFull = `Inventory full ({BaseMath.INVENTORY_LIMIT})! Sell some items.`,
	TooFar = "Go to the Sell Station in the lobby!",
	Nothing = "Nothing to sell.",
	NoItem = "That item is gone.",
	Empty = "This pedestal is empty.",
	BadSlot = "That pedestal is locked.",
	NoCharacter = "Wait for your character to load.",
	RateLimited = "Slow down!",
}

local Actions = {}

-- Lista przedmiotów gracza dla okien: najlepsze $/s pierwsze. filter: "placed" | "inventory" | nil (wszystkie).
function Actions.entries(state: Store.State, filter: string?): { Entry }
	local list: { Entry } = {}
	for uid, item in state.items do
		local placed = BaseMath.isPlaced(item :: any, state.capacity)
		if (filter == "placed" and not placed) or (filter == "inventory" and placed) then
			continue
		end
		local def = LootConfig.ITEMS[item.itemId]
		table.insert(list, {
			uid = uid,
			itemId = item.itemId,
			name = if def then def.name else item.itemId,
			rarity = BaseMath.rarity(item.itemId),
			mutation = item.mutation,
			income = BaseMath.itemIncome(item :: any) * state.incomeMult,
			price = BaseMath.sellPrice(item :: any),
			slot = if placed then item.slot else nil,
			confirm = BaseMath.needsConfirm(item.itemId),
		})
	end
	table.sort(list, function(a, b)
		if a.income ~= b.income then
			return a.income > b.income
		end
		return a.uid < b.uid
	end)
	return list
end

-- Slot dla przedmiotu z ekwipunku: wolny postument, a przy pełnej bazie najsłabszy (zamiana). nil = brak sensu.
function Actions.targetSlot(state: Store.State, uid: string): number?
	local free = LootMath.freeSlot(state.items :: any, state.capacity)
	if free then
		return free
	end
	local weakest = BaseMath.weakestPlaced(state.items :: any, state.capacity)
	return if weakest and weakest ~= uid then state.items[weakest].slot else nil
end

local function report(result: any, success: string?)
	if type(result) == "table" and result.ok then
		if success then
			Store.toast(success, "success")
		end
		return true
	end
	local reason = if type(result) == "table" then result.reason else nil
	Store.toast(REASONS[reason or ""] or "Something went wrong. Try again.", "error")
	return false
end

local function run(fn: () -> ())
	task.spawn(fn)
end

function Actions.place(uid: string, slot: number)
	run(function()
		report(Remotes.invoke("PlaceItem", uid, slot))
	end)
end

function Actions.remove(slot: number)
	run(function()
		report(Remotes.invoke("RemoveItem", slot), "Moved to inventory")
	end)
end

function Actions.autoPlace()
	run(function()
		local result = Remotes.invoke("AutoPlace")
		if type(result) == "table" and result.ok then
			Store.toast(
				if result.moved > 0 then "Best items placed!" else "Your best items are already placed.",
				"success"
			)
		else
			report(result)
		end
	end)
end

function Actions.buySlot()
	run(function()
		local result = Remotes.invoke("BuySlot")
		if report(result, "New pedestal unlocked!") then
			Sfx.play("uiCoin")
		end
	end)
end

-- Sprzedaż jednego przedmiotu; confirm = gracz potwierdził w oknie (od Legendary). onDone(true) po sprzedaży.
function Actions.sell(uid: string, confirm: boolean, onDone: ((boolean) -> ())?)
	run(function()
		local result = Remotes.invoke("SellItem", uid, confirm)
		local ok = report(
			result,
			if type(result) == "table" and result.ok then `Sold for {Format.cash(result.price)}!` else nil
		)
		if ok then
			Sfx.play("uiCoin")
		end
		if onDone then
			onDone(ok)
		end
	end)
end

function Actions.sellBelow(rarity: string)
	run(function()
		local result = Remotes.invoke("SellBelow", rarity)
		if
			report(
				result,
				if type(result) == "table" and result.ok
					then `Sold {result.count} items for {Format.cash(result.price)}!`
					else nil
			)
		then
			Sfx.play("uiCoin")
		end
	end)
end

return Actions
