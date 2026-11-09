--!strict
-- LootConfig — typowany dostęp do łupu: Rarities.json (rzadkości, mutacje, pity, sekcja loot), Items.json
-- (przedmioty i pule motywów), efekty gamepassów z Monetization.json i bonus indeksu z Economy.json.
-- Liczby są tylko w JSON-ach; tu same typy, indeksy i czasy karty łupu (REVEAL, klient).

local Data = script.Parent.Data
local Economy = require(Data.Economy) :: any
local Items = require(Data.Items) :: any
local Monetization = require(Data.Monetization) :: any
local Rarities = require(Data.Rarities) :: any

export type Tier = {
	oneIn: number,
	incomePerSec: number,
	color: string,
	fx: number,
}

export type MutationDef = {
	oneIn: number,
	incomeMult: number,
}

export type Item = {
	id: string,
	name: string,
	theme: string,
	rarity: string,
	supernovaOnly: boolean?,
}

export type ExtraRoll = {
	minShare: number,
	sizes: { string },
	rolls: number,
}

export type Announce = {
	chatFrom: string,
	bannerFrom: string,
	effectFrom: string,
}

-- Efekt gamepassa/produktu na łup i bazę (pola opcjonalne z Monetization.json).
export type PassEffect = {
	id: string,
	luckBonus: number?,
	slotBonus: number?,
	luckMult: number?,
	durationSeconds: number?,
}

local RARITY_ORDER: { string } = Rarities.order -- od najczęstszej
local TIERS: { [string]: Tier } = Rarities.tiers
local MUTATION_ORDER: { string } = Rarities.mutations.order -- None pierwszy, najrzadsza ostatnia
local MUTATIONS: { [string]: MutationDef } = {}
for _, id in MUTATION_ORDER do
	MUTATIONS[id] = Rarities.mutations[id]
end
local PITY: { [string]: number } = Rarities.pity
local LOOT = Rarities.loot

local rarityRank: { [string]: number } = {}
for index, id in RARITY_ORDER do
	rarityRank[id] = index
end

local ITEMS: { [string]: Item } = {}
local ITEM_LIST: { Item } = Items.items
-- Pula motywu: themeId → rarity → { itemId } (bez supernovaOnly). SUPERNOVA_EXTRA: rarity → { itemId }.
local THEME_POOLS: { [string]: { [string]: { string } } } = {}
local SUPERNOVA_EXTRA: { [string]: { string } } = {}
-- Przedmioty potrzebne do kompletu motywu w indeksie (wszystkie poza exclusiveTiers).
local THEME_SET: { [string]: { string } } = {}

local exclusive: { [string]: boolean } = {}
for _, id in LOOT.exclusiveTiers :: { string } do
	exclusive[id] = true
end

for _, item in ITEM_LIST do
	ITEMS[item.id] = item
	if item.supernovaOnly then
		local list = SUPERNOVA_EXTRA[item.rarity] or {}
		SUPERNOVA_EXTRA[item.rarity] = list
		table.insert(list, item.id)
	else
		local pool = THEME_POOLS[item.theme] or {}
		THEME_POOLS[item.theme] = pool
		local list = pool[item.rarity] or {}
		pool[item.rarity] = list
		table.insert(list, item.id)
	end
	if not exclusive[item.rarity] then
		local set = THEME_SET[item.theme] or {}
		THEME_SET[item.theme] = set
		table.insert(set, item.id)
	end
end

local PASSES: { [string]: PassEffect } = {}
for _, entry in Monetization.gamepasses :: { PassEffect } do
	PASSES[entry.id] = entry
end
local PRODUCTS: { [string]: PassEffect } = {}
for _, entry in Monetization.products :: { PassEffect } do
	PRODUCTS[entry.id] = entry
end

local supernovaSizes: { [string]: boolean } = {}
for _, sizeId in LOOT.supernovaPoolSizes :: { string } do
	supernovaSizes[sizeId] = true
end

local LootConfig = {
	RARITY_ORDER = RARITY_ORDER,
	TIERS = TIERS,
	MUTATION_ORDER = MUTATION_ORDER,
	MUTATIONS = MUTATIONS,
	PITY = PITY,
	ITEMS = ITEMS,
	THEME_POOLS = THEME_POOLS,
	SUPERNOVA_EXTRA = SUPERNOVA_EXTRA,
	THEME_SET = THEME_SET,
	EXCLUSIVE_TIERS = exclusive,
	LUCK_FROM = LOOT.luckFromRarity :: string,
	MUTATIONS_USE_LUCK = LOOT.mutationsUseLuck :: boolean,
	EXTRA_ROLL = LOOT.extraRoll :: ExtraRoll,
	ANNOUNCE = LOOT.announce :: Announce,
	INDEX_LUCK_BONUS = Economy.index.themeCompleteReward.luckBonus :: number,
	PASSES = PASSES,
	PRODUCTS = PRODUCTS,
	-- Gamepassy i produkt, które zmieniają luck (id z Monetization.json).
	LUCK_PASSES = { "lucky", "vip" },
	LUCK_BOOST = "luck_boost",

	-- Karta łupu i ogłoszenia (klient). Czasy w sekundach.
	REVEAL = table.freeze({
		delay = 0.55, -- po rozbiciu gwiazdy (najpierw efekt pęknięcia)
		stagger = 0.22, -- odstęp między kartami kilku losowań
		holdSeconds = 4.2, -- karta na ekranie (dotknięcie zamyka wcześniej)
		extraHoldPerCard = 0.6,
		-- Napięcie przed odkryciem (zakryta karta pulsuje kolorem rzadkości), max 1,5 s (GDD).
		suspense = table.freeze({ Epic = 0.45, Legendary = 0.8, Mythic = 1.1, Secret = 1.45 }),
		maxCards = 6,
		bannerSeconds = 4.5,
		flashAlpha = 0.55, -- siła błysku ekranu przy Mythic/Secret u wszystkich
		sparks = table.freeze({ Rare = 6, Epic = 10, Legendary = 16, Mythic = 22, Secret = 30 }),
	}),
}

-- Indeks rzadkości w `order` (Common = 1). 0 dla nieznanej.
function LootConfig.rarityRank(rarity: string): number
	return rarityRank[rarity] or 0
end

-- Czy rozmiar gwiazdy dokłada pulę Supernowej (Secret).
function LootConfig.hasSupernovaPool(sizeId: string): boolean
	return supernovaSizes[sizeId] == true
end

function LootConfig.rarityColor(rarity: string): Color3
	local tier = TIERS[rarity]
	return if tier then Color3.fromHex(tier.color) else Color3.new(1, 1, 1)
end

return table.freeze(LootConfig)
