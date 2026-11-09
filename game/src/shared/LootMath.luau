--!strict
--!native
-- LootMath — czysta matematyka łupu (bez usług Roblox): luck gracza, pule, szanse rzadkości i mutacji,
-- losowanie z pity, dochód przedmiotu, wolny postument. Wspólna dla serwera (LootService — jedyne miejsce,
-- które naprawdę losuje) i klienta (pokazywanie szans w UI). Losowość tylko przez przekazany Random.
--
-- Wzór szans (Rarities.json → loot.notes): od najrzadszej w dół p = luck/oneIn (luck od Rare w górę,
-- niżej 1/oneIn), suma ucięta do 1, reszta = Common. Jedna liczba u z [0,1) wybiera próg — przy luck 1
-- rozkład to dokładnie 1/oneIn. Brak rzadkości w puli → jej szansa przechodzi na następną niższą
-- (poza exclusiveTiers: Secret istnieje tylko w puli Supernowej).

local Config = script.Parent.Config
local LootConfig = require(Config.LootConfig)
local StarConfig = require(Config.StarConfig)

export type Mutation = "None" | "Shiny" | "Golden"

-- Szansa jednej opcji. Lista zawsze od najrzadszej (tak też idzie losowanie).
export type Odds = { { id: string, p: number } }

-- Pula losowania: rarity → { itemId }.
export type Pool = { [string]: { string } }

export type Drop = {
	itemId: string,
	rarity: string,
	mutation: Mutation,
	pity: string?, -- rzadkość gwarantowana przez pity (tylko gdy to pity podniosło łup)
}

export type RollContext = {
	themeId: string,
	sizeId: string,
	share: number, -- udział gracza w obrażeniach 0..1
	luck: number, -- LootMath.luck(...)
	pity: { [string]: number }, -- liczniki rozbić bez danej rzadkości (tylko odczyt)
}

export type RollResult = {
	drops: { Drop },
	pity: { [string]: number }, -- nowe liczniki
	pityHit: string?, -- rzadkość z pity, jeśli zadziałało
}

-- Dane gracza potrzebne do luck (podzbiór PlayerData).
export type LuckSource = {
	purchases: { [string]: boolean },
	boosts: { [string]: number },
	index: { [string]: boolean },
}

export type LuckBreakdown = {
	size: number,
	passes: number, -- suma bonusów gamepassów (Lucky 0.25, VIP 0.1)
	index: number, -- bonus za komplety motywów
	themesComplete: number,
	boost: number, -- mnożnik boosta (1 = brak)
	total: number,
}

local RARITY_ORDER = LootConfig.RARITY_ORDER
local TIERS = LootConfig.TIERS
local MUTATION_ORDER = LootConfig.MUTATION_ORDER
local MUTATIONS = LootConfig.MUTATIONS
local LUCK_FROM_RANK = LootConfig.rarityRank(LootConfig.LUCK_FROM)

-- Progi pity od najrzadszej (Mythic sprawdzany przed Legendary).
local PITY_TIERS: { string } = {}
for rarity in LootConfig.PITY do
	table.insert(PITY_TIERS, rarity)
end
table.sort(PITY_TIERS, function(a, b)
	return LootConfig.rarityRank(a) > LootConfig.rarityRank(b)
end)

local LootMath = {}

LootMath.PITY_TIERS = PITY_TIERS

-- Liczba motywów z kompletem w indeksie (wszystkie przedmioty poza Secret).
function LootMath.completedThemes(index: { [string]: boolean }): number
	local count = 0
	for _, set in LootConfig.THEME_SET do
		local complete = #set > 0
		for _, itemId in set do
			if not index[itemId] then
				complete = false
				break
			end
		end
		if complete then
			count += 1
		end
	end
	return count
end

-- luck = rozmiar.luck × (1 + Lucky + VIP + indeks × komplety) × boost.
function LootMath.luck(sizeId: string, source: LuckSource, now: number): (number, LuckBreakdown)
	local class = StarConfig.CLASSES[sizeId]
	local sizeLuck = if class then class.luck else 1
	local passes = 0
	for _, passId in LootConfig.LUCK_PASSES do
		local effect = LootConfig.PASSES[passId]
		if effect and source.purchases[passId] then
			passes += effect.luckBonus or 0
		end
	end
	local themesComplete = LootMath.completedThemes(source.index)
	local indexBonus = themesComplete * LootConfig.INDEX_LUCK_BONUS
	local boost = 1
	local product = LootConfig.PRODUCTS[LootConfig.LUCK_BOOST]
	local boostEnd = source.boosts[LootConfig.LUCK_BOOST]
	if product and type(boostEnd) == "number" and boostEnd > now then
		boost = product.luckMult or 1
	end
	local total = sizeLuck * (1 + passes + indexBonus) * boost
	return total,
		{
			size = sizeLuck,
			passes = passes,
			index = indexBonus,
			themesComplete = themesComplete,
			boost = boost,
			total = total,
		}
end

-- Czy gracz z takim udziałem dostaje łup (udział > 0 i ≥ minShare rozmiaru).
function LootMath.eligible(sizeId: string, share: number): boolean
	local class = StarConfig.CLASSES[sizeId]
	return class ~= nil and share == share and share > 0 and share >= class.minShare
end

-- Liczba losowań: lootRolls (+extraRoll przy dużym udziale na Huge/Supernova).
function LootMath.rollCount(sizeId: string, share: number): number
	local class = StarConfig.CLASSES[sizeId]
	if not class then
		return 0
	end
	local count = class.lootRolls
	local extra = LootConfig.EXTRA_ROLL
	if share >= extra.minShare and table.find(extra.sizes, sizeId) then
		count += extra.rolls
	end
	return count
end

-- Pula: 6 przedmiotów rodzaju gwiazdy (+ Secret z puli Supernowej).
function LootMath.pool(themeId: string, sizeId: string): Pool
	local pool: Pool = {}
	for rarity, list in LootConfig.THEME_POOLS[themeId] or {} do
		pool[rarity] = table.clone(list)
	end
	if LootConfig.hasSupernovaPool(sizeId) then
		for rarity, list in LootConfig.SUPERNOVA_EXTRA do
			local target = pool[rarity] or {}
			pool[rarity] = target
			for _, itemId in list do
				table.insert(target, itemId)
			end
		end
	end
	return pool
end

local function present(pool: Pool, rarity: string): boolean
	local list = pool[rarity]
	return list ~= nil and #list > 0
end

-- Szanse rzadkości dla puli i luck, od najrzadszej. Suma = 1 (gdy pula ma choć jedną rzadkość).
function LootMath.rarityOdds(pool: Pool, luck: number): Odds
	local odds: Odds = {}
	local remaining = 1
	local carry = 0
	for i = #RARITY_ORDER, 1, -1 do
		local rarity = RARITY_ORDER[i]
		local has = present(pool, rarity)
		if not has and LootConfig.EXCLUSIVE_TIERS[rarity] then
			continue
		end
		local mult = if i >= LUCK_FROM_RANK then luck else 1
		local p = mult / TIERS[rarity].oneIn + carry
		if not has then
			carry = p
			continue
		end
		carry = 0
		p = math.min(p, remaining)
		remaining -= p
		table.insert(odds, { id = rarity, p = p })
	end
	-- Reszta (np. gdy pula nie ma Common) trafia do najczęstszej obecnej rzadkości.
	if remaining > 0 and #odds > 0 then
		odds[#odds].p += remaining
	end
	return odds
end

-- Szanse mutacji (Golden, Shiny, None) — luck działa, gdy loot.mutationsUseLuck.
function LootMath.mutationOdds(luck: number): Odds
	local mult = if LootConfig.MUTATIONS_USE_LUCK then luck else 1
	local odds: Odds = {}
	local remaining = 1
	for i = #MUTATION_ORDER, 1, -1 do
		local id = MUTATION_ORDER[i]
		local p = math.min(mult / MUTATIONS[id].oneIn, remaining)
		remaining -= p
		table.insert(odds, { id = id, p = p })
	end
	if remaining > 0 and #odds > 0 then
		odds[#odds].p += remaining
	end
	return odds
end

-- Wybór z listy szans dla u z [0,1).
function LootMath.pick(odds: Odds, u: number): string
	local acc = 0
	for _, entry in odds do
		acc += entry.p
		if u < acc then
			return entry.id
		end
	end
	return odds[#odds].id
end

local function pickItem(pool: Pool, rarity: string, rng: Random): string
	local list = pool[rarity]
	return list[rng:NextInteger(1, #list)]
end

-- Jedno losowanie: rzadkość → przedmiot z puli → mutacja.
function LootMath.rollOnce(pool: Pool, rarityOdds: Odds, mutationOdds: Odds, rng: Random): Drop
	local rarity = LootMath.pick(rarityOdds, rng:NextNumber())
	return {
		itemId = pickItem(pool, rarity, rng),
		rarity = rarity,
		mutation = LootMath.pick(mutationOdds, rng:NextNumber()) :: Mutation,
	}
end

-- Pełny łup gracza z jednej gwiazdy: losowania, pity (gwarancja + nowe liczniki).
function LootMath.roll(context: RollContext, rng: Random): RollResult
	local pool = LootMath.pool(context.themeId, context.sizeId)
	local count = LootMath.rollCount(context.sizeId, context.share)
	local rarityOdds = LootMath.rarityOdds(pool, context.luck)
	local mutationOdds = LootMath.mutationOdds(context.luck)

	local drops: { Drop } = {}
	local best, bestIndex = 0, 0
	for i = 1, count do
		local drop = LootMath.rollOnce(pool, rarityOdds, mutationOdds, rng)
		drops[i] = drop
		local rank = LootConfig.rarityRank(drop.rarity)
		if rank > best then
			best, bestIndex = rank, i
		end
	end

	-- Pity: N-te rozbicie z rzędu bez tej rzadkości (lub lepszej) podnosi najlepszy łup do niej.
	local pityHit: string? = nil
	if bestIndex > 0 then
		for _, tier in PITY_TIERS do
			local tierRank = LootConfig.rarityRank(tier)
			if best >= tierRank or (context.pity[tier] or 0) + 1 < LootConfig.PITY[tier] then
				continue
			end
			-- Motyw bez tej rzadkości → najbliższa niższa, ale lepsza niż obecny łup.
			for rank = tierRank, best + 1, -1 do
				local rarity = RARITY_ORDER[rank]
				if present(pool, rarity) and not LootConfig.EXCLUSIVE_TIERS[rarity] then
					local drop = drops[bestIndex]
					drop.rarity = rarity
					drop.itemId = pickItem(pool, rarity, rng)
					drop.pity = tier
					best = rank
					pityHit = tier
					break
				end
			end
			if pityHit then
				break
			end
		end
	end

	local newPity: { [string]: number } = {}
	for _, tier in PITY_TIERS do
		newPity[tier] = if best >= LootConfig.rarityRank(tier) then 0 else (context.pity[tier] or 0) + 1
	end

	return { drops = drops, pity = newPity, pityHit = pityHit }
end

-- Szanse dla UI: { rarity → p } i { mutation → p } dla motywu, rozmiaru i luck.
function LootMath.odds(themeId: string, sizeId: string, luck: number): ({ [string]: number }, { [string]: number })
	local rarities, mutations = {}, {}
	for _, entry in LootMath.rarityOdds(LootMath.pool(themeId, sizeId), luck) do
		rarities[entry.id] = entry.p
	end
	for _, entry in LootMath.mutationOdds(luck) do
		mutations[entry.id] = entry.p
	end
	return rarities, mutations
end

-- Dochód przedmiotu: rzadkość.incomePerSec × motyw.incomeMult × mutacja.incomeMult.
function LootMath.incomePerSec(itemId: string, mutation: string): number
	local item = LootConfig.ITEMS[itemId]
	if not item then
		return 0
	end
	local tier = TIERS[item.rarity]
	local theme = StarConfig.THEMES[item.theme]
	local mutationDef = MUTATIONS[mutation]
	return (if tier then tier.incomePerSec else 0)
		* (if theme then theme.incomeMult else 1)
		* (if mutationDef then mutationDef.incomeMult else 1)
end

-- Liczba postumentów: kupione sloty + bonusy gamepassów (VIP +1, +5 Slots).
function LootMath.slotCapacity(slots: number, purchases: { [string]: boolean }): number
	local total = slots
	for passId, effect in LootConfig.PASSES do
		if effect.slotBonus and purchases[passId] then
			total += effect.slotBonus
		end
	end
	return total
end

-- Najniższy wolny numer postumentu (1..capacity) albo nil, gdy baza pełna.
function LootMath.freeSlot(items: { [string]: { slot: number? } }, capacity: number): number?
	local used: { [number]: boolean } = {}
	for _, owned in items do
		if owned.slot then
			used[owned.slot] = true
		end
	end
	for slot = 1, capacity do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

return table.freeze(LootMath)
