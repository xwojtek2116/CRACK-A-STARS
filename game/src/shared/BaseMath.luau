--!strict
-- BaseMath — czysta matematyka bazy (bez usług Roblox): dochód postumentów i mnożniki, offline, cena slotu,
-- cena sprzedaży, układ „Auto-place best”, nowy łup przy pełnej bazie, limit ekwipunku.
-- Wspólna dla serwera (jedyne miejsce, które zmienia dane — wewnątrz DataService.update) i klienta (UI).
-- Funkcje z „mutuje” w opisie zmieniają przekazaną tabelę items w miejscu.
--
-- Wzory (vault/02 Systemy/Baza i dochód):
--   dochód/s  = Σ $/s przedmiotów na postumentach × (1 + cashMultPerRebirth × rebirths) × 2× Cash
--   offline   = min(nieobecność, offlineCapHours) × dochód/s × offlineRate (od offlineMinSeconds)
--   slot      = slotPriceBase × slotPriceGrowth^(kupione sloty − startSlots)
--   sprzedaż  = $/s przedmiotu (z mutacją) × sell.incomeSeconds

local Config = script.Parent.Config
local Economy = require(Config.Data.Economy) :: any
local LootConfig = require(Config.LootConfig)
local LootMath = require(script.Parent.LootMath)

local BASE = Economy.base
local SELL = Economy.sell
local REBIRTH = Economy.rebirth

export type Item = {
	itemId: string,
	mutation: string,
	obtainedAt: number,
	slot: number?,
}
export type Items = { [string]: Item }

export type SoldItem = { uid: string, itemId: string, mutation: string, price: number }

local CONFIRM_RANK = LootConfig.rarityRank(SELL.confirmFromRarity)
local AUTO_SELL_RANK = LootConfig.rarityRank(BASE.autoSellMaxRarity)

local BaseMath = {}

BaseMath.START_SLOTS = BASE.startSlots :: number
BaseMath.MAX_SLOTS = BASE.maxSlots :: number
BaseMath.INVENTORY_LIMIT = BASE.inventoryLimit :: number
BaseMath.TICK_SECONDS = BASE.incomeTickSeconds :: number
BaseMath.OFFLINE_MIN_SECONDS = BASE.offlineMinSeconds :: number
BaseMath.OFFLINE_CAP_SECONDS = (BASE.offlineCapHours :: number) * 3600
BaseMath.OFFLINE_RATE = BASE.offlineRate :: number
BaseMath.SELL_SECONDS = SELL.incomeSeconds :: number
BaseMath.STATION_DISTANCE = SELL.stationDistance :: number
BaseMath.PEDESTAL_DISTANCE = SELL.pedestalDistance :: number

function BaseMath.rarity(itemId: string): string
	local item = LootConfig.ITEMS[itemId]
	return if item then item.rarity else "Common"
end

function BaseMath.itemIncome(item: Item): number
	return LootMath.incomePerSec(item.itemId, item.mutation)
end

-- Przedmiot stoi na postumencie (slot w zakresie pojemności; po utracie gamepassa wyższe sloty = ekwipunek).
function BaseMath.isPlaced(item: Item, capacity: number): boolean
	return item.slot ~= nil and item.slot <= capacity
end

-- Mnożnik dochodu bazy: rebirthy i gamepassy z cashMult (2× Cash).
function BaseMath.incomeMultiplier(rebirths: number, purchases: { [string]: boolean }): number
	local mult = 1 + (REBIRTH.cashMultPerRebirth :: number) * rebirths
	for passId, effect in LootConfig.PASSES do
		if effect.cashMult and purchases[passId] then
			mult *= effect.cashMult
		end
	end
	return mult
end

-- Suma $/s przedmiotów na postumentach (bez mnożników).
function BaseMath.rawIncome(items: Items, capacity: number): number
	local total = 0
	for _, item in items do
		if BaseMath.isPlaced(item, capacity) then
			total += BaseMath.itemIncome(item)
		end
	end
	return total
end

-- Dochód gracza na sekundę (PlayerData lub jego podzbiór).
function BaseMath.incomePerSec(data: {
	items: Items,
	slots: number,
	rebirths: number,
	purchases: { [string]: boolean },
}): number
	local capacity = LootMath.slotCapacity(data.slots, data.purchases)
	return BaseMath.rawIncome(data.items, capacity) * BaseMath.incomeMultiplier(data.rebirths, data.purchases)
end

-- Zarobek offline za `seconds` nieobecności przy dochodzie `incomePerSec`. 0 poniżej progu.
function BaseMath.offlineEarnings(seconds: number, incomePerSec: number): (number, number)
	if seconds < BaseMath.OFFLINE_MIN_SECONDS or incomePerSec <= 0 then
		return 0, 0
	end
	local counted = math.min(seconds, BaseMath.OFFLINE_CAP_SECONDS)
	return math.floor(counted * incomePerSec * BaseMath.OFFLINE_RATE), counted
end

-- Cena następnego slotu przy `slots` kupionych; nil = maksimum.
function BaseMath.slotPrice(slots: number): number?
	if slots >= BaseMath.MAX_SLOTS then
		return nil
	end
	local n = math.max(slots - BaseMath.START_SLOTS, 0)
	return math.floor((BASE.slotPriceBase :: number) * (BASE.slotPriceGrowth :: number) ^ n)
end

function BaseMath.sellPrice(item: Item): number
	return math.floor(BaseMath.itemIncome(item) * BaseMath.SELL_SECONDS)
end

-- Sprzedaż tej rzadkości wymaga potwierdzenia (od Legendary).
function BaseMath.needsConfirm(itemId: string): boolean
	return LootConfig.rarityRank(BaseMath.rarity(itemId)) >= CONFIRM_RANK
end

-- Kolejność „lepszy pierwszy”: $/s malejąco, potem starszy, potem uid (deterministycznie).
local function better(items: Items, a: string, b: string): boolean
	local ia, ib = BaseMath.itemIncome(items[a]), BaseMath.itemIncome(items[b])
	if ia ~= ib then
		return ia > ib
	end
	local ta, tb = items[a].obtainedAt, items[b].obtainedAt
	if ta ~= tb then
		return ta < tb
	end
	return a < b
end

function BaseMath.inventoryCount(items: Items, capacity: number): number
	local count = 0
	for _, item in items do
		if not BaseMath.isPlaced(item, capacity) then
			count += 1
		end
	end
	return count
end

-- Auto-place best (mutuje): na postumentach zostaje `capacity` najlepszych przedmiotów. Te, które już stały
-- i dalej są w czołówce, nie zmieniają miejsca. Zwraca liczbę przedmiotów, którym zmienił się slot.
function BaseMath.autoPlace(items: Items, capacity: number): number
	local order = {}
	for uid in items do
		table.insert(order, uid)
	end
	table.sort(order, function(a, b)
		return better(items, a, b)
	end)

	local keep: { [string]: boolean } = {}
	for i = 1, math.min(capacity, #order) do
		keep[order[i]] = true
	end

	local before: { [string]: number? } = {}
	local used: { [number]: boolean } = {}
	for uid, item in items do
		before[uid] = item.slot
		if keep[uid] and BaseMath.isPlaced(item, capacity) then
			used[item.slot :: number] = true
		else
			item.slot = nil
		end
	end

	local nextSlot = 1
	for i = 1, math.min(capacity, #order) do
		local item = items[order[i]]
		if item.slot == nil then
			while used[nextSlot] do
				nextSlot += 1
			end
			item.slot = nextSlot
			used[nextSlot] = true
		end
	end

	local moved = 0
	for uid, item in items do
		if before[uid] ~= item.slot then
			moved += 1
		end
	end
	return moved
end

-- Najsłabszy przedmiot na postumentach (uid) albo nil.
function BaseMath.weakestPlaced(items: Items, capacity: number): string?
	local weakest: string? = nil
	for uid, item in items do
		if BaseMath.isPlaced(item, capacity) and (weakest == nil or better(items, weakest, uid)) then
			weakest = uid
		end
	end
	return weakest
end

-- Nowy przedmiot `uid` (już w items, bez slotu) na bazę (mutuje): wolny postument, a przy pełnej bazie
-- zamiana z najsłabszym, jeśli nowy jest lepszy. Zwraca (slot?, uid zdjętego przedmiotu?).
function BaseMath.placeNew(items: Items, uid: string, capacity: number): (number?, string?)
	local item = items[uid]
	local free = LootMath.freeSlot(items, capacity)
	if free then
		item.slot = free
		return free, nil
	end
	local weakest = BaseMath.weakestPlaced(items, capacity)
	if weakest and weakest ~= uid and better(items, uid, weakest) then
		local slot = items[weakest].slot
		items[weakest].slot = nil
		item.slot = slot
		return slot, weakest
	end
	item.slot = nil
	return nil, nil
end

-- Limit ekwipunku (mutuje): dopóki poza postumentami jest więcej niż limit, sprzedaje najsłabszy
-- Common/Uncommon bez mutacji, a gdy takiego brak — najsłabszy poniżej rzadkości z potwierdzeniem.
-- Nigdy nie sprzedaje Legendary+ ani przedmiotów z `protect`. Zwraca sprzedane (z ceną).
function BaseMath.trimInventory(
	items: Items,
	capacity: number,
	limit: number?,
	protect: { [string]: boolean }?
): { SoldItem }
	local max = limit or BaseMath.INVENTORY_LIMIT
	local sold: { SoldItem } = {}
	local count = BaseMath.inventoryCount(items, capacity)
	while count > max do
		local strict: string? = nil
		local loose: string? = nil
		for uid, item in items do
			if BaseMath.isPlaced(item, capacity) or (protect and protect[uid]) then
				continue
			end
			local rank = LootConfig.rarityRank(BaseMath.rarity(item.itemId))
			if rank >= CONFIRM_RANK then
				continue
			end
			if rank <= AUTO_SELL_RANK and item.mutation == "None" then
				if strict == nil or better(items, strict, uid) then
					strict = uid
				end
			elseif loose == nil or better(items, loose, uid) then
				loose = uid
			end
		end
		local pick = strict or loose
		if not pick then
			break
		end
		local item = items[pick]
		table.insert(
			sold,
			{ uid = pick, itemId = item.itemId, mutation = item.mutation, price = BaseMath.sellPrice(item) }
		)
		items[pick] = nil
		count -= 1
	end
	return sold
end

-- Grid: pozycja slotu w układzie BuildOrigin (x w prawo, z w stronę lobby) dla siatki columns × rows.
function BaseMath.gridOffset(
	slot: number,
	columns: number,
	spacingX: number,
	spacingZ: number,
	front: number
): (number, number)
	local index = slot - 1
	local row = index // columns
	local col = index % columns
	local x = (col - (columns - 1) / 2) * spacingX
	local z = front - row * spacingZ
	return x, z
end

return table.freeze(BaseMath)
