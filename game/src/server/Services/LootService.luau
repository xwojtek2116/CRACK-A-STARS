--!strict
-- LootService — łup po rozbiciu gwiazdy (T07). Słucha StarService.onCracked i dla każdego gracza z udziałem
-- ≥ minShare: liczy luck (rozmiar × gamepassy × indeks × boost), losuje przez LootMath (Random.new(), tylko
-- serwer), stosuje pity, zapisuje przedmioty (items[uid] z wolnym postumentem albo ekwipunek) i indeks,
-- wysyła graczowi kartę łupu (LootDrop), a rzadki łup ogłasza całemu serwerowi (Announcement).
-- Klient niczego tu nie wysyła — brak remotów klient → serwer.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LootConfig = require(Shared.Config.LootConfig)
local LootMath = require(Shared.LootMath)
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)
local StarConfig = require(Shared.Config.StarConfig)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local StarService = require(script.Parent.StarService)

type StarInfo = Types.StarInfo
type PlayerData = Types.PlayerData

-- Przedmiot w karcie łupu (LootDrop → klient).
export type GrantedDrop = {
	uid: string,
	itemId: string,
	name: string,
	rarity: string,
	mutation: string,
	income: number, -- $/s
	slot: number?, -- postument; nil = ekwipunek (baza pełna)
	isNew: boolean, -- pierwszy raz w indeksie
	pity: string?,
}

export type LootDropPayload = {
	starId: string,
	star: string, -- nazwa gwiazdy, np. "Huge Lava Star"
	size: string,
	type: string,
	share: number,
	luck: number,
	drops: { GrantedDrop },
	pity: { [string]: { count: number, max: number } }, -- postęp do gwarancji
	themesCompleted: { string }?, -- motywy, które właśnie zrobiły komplet w indeksie (+luck)
}

local log = Logger.new("LootService")
local rng = Random.new()

local CHAT_RANK = LootConfig.rarityRank(LootConfig.ANNOUNCE.chatFrom)

local function completedSet(index: { [string]: boolean }): { [string]: boolean }
	local done = {}
	for themeId, set in LootConfig.THEME_SET do
		local complete = #set > 0
		for _, itemId in set do
			if not index[itemId] then
				complete = false
				break
			end
		end
		done[themeId] = complete
	end
	return done
end

local function pityProgress(pity: { [string]: number }): { [string]: { count: number, max: number } }
	local progress = {}
	for _, tier in LootMath.PITY_TIERS do
		progress[tier] = { count = pity[tier] or 0, max = LootConfig.PITY[tier] }
	end
	return progress
end

local function bump(stats: { [string]: number }, key: string, amount: number)
	stats[key] = (stats[key] or 0) + amount
end

-- Losuje i zapisuje łup gracza z jednej gwiazdy. Zwraca payload karty albo nil (brak danych / udziału).
local function award(player: Player, info: StarInfo, share: number): LootDropPayload?
	if not LootMath.eligible(info.size, share) then
		return nil
	end
	local current = DataService.get(player)
	if not current then
		return nil
	end
	local now = os.time()
	local luck = LootMath.luck(info.size, current, now)
	local result = LootMath.roll({
		themeId = info.type,
		sizeId = info.size,
		share = share,
		luck = luck,
		pity = current.pity,
	}, rng)

	local granted: { GrantedDrop } = {}
	local newlyComplete: { string } = {}
	local ok = DataService.update(player, function(data: PlayerData)
		local before = completedSet(data.index)
		local capacity = LootMath.slotCapacity(data.slots, data.purchases)
		for _, drop in result.drops do
			local uid = HttpService:GenerateGUID(false)
			local slot = LootMath.freeSlot(data.items, capacity)
			local isNew = not data.index[drop.itemId]
			data.items[uid] = {
				itemId = drop.itemId,
				mutation = drop.mutation,
				obtainedAt = now,
				slot = slot,
			}
			data.index[drop.itemId] = true
			table.insert(granted, {
				uid = uid,
				itemId = drop.itemId,
				name = LootConfig.ITEMS[drop.itemId].name,
				rarity = drop.rarity,
				mutation = drop.mutation,
				income = LootMath.incomePerSec(drop.itemId, drop.mutation),
				slot = slot,
				isNew = isNew,
				pity = drop.pity,
			})
			bump(data.stats, `found{drop.rarity}`, 1)
			if drop.mutation ~= "None" then
				bump(data.stats, `found{drop.mutation}`, 1)
			end
		end
		data.pity = table.clone(result.pity)
		bump(data.stats, "starsCracked", 1)
		bump(data.stats, "itemsLooted", #result.drops)
		for themeId, complete in completedSet(data.index) do
			if complete and not before[themeId] then
				table.insert(newlyComplete, themeId)
			end
		end
	end)
	if not ok or #granted == 0 then
		return nil
	end

	local parts = {}
	for _, drop in granted do
		local mutation = if drop.mutation ~= "None" then `{drop.mutation} ` else ""
		table.insert(parts, `{mutation}{drop.rarity} {drop.itemId}{if drop.pity then " (pity)" else ""}`)
	end
	log:info(
		`{player.Name}: {StarConfig.displayName(info.size, info.type)} udział {math.round(share * 100)}% luck {string.format(
			"%.2f",
			luck
		)} → {table.concat(parts, ", ")}`
	)

	return {
		starId = info.id,
		star = StarConfig.displayName(info.size, info.type),
		size = info.size,
		type = info.type,
		share = share,
		luck = luck,
		drops = granted,
		pity = pityProgress(result.pity),
		themesCompleted = if #newlyComplete > 0 then newlyComplete else nil,
	}
end

-- Ogłoszenie dla serwera: przedmioty od Epic (czat), klient sam wybiera baner/efekt wg ANNOUNCE.
local function announce(player: Player, payload: LootDropPayload)
	local drops = {}
	for _, drop in payload.drops do
		if LootConfig.rarityRank(drop.rarity) >= CHAT_RANK then
			table.insert(drops, { itemId = drop.itemId, rarity = drop.rarity, mutation = drop.mutation })
		end
	end
	if #drops == 0 then
		return
	end
	Remotes.fireAllClients("Announcement", {
		kind = "Loot",
		userId = player.UserId,
		name = player.DisplayName,
		star = payload.star,
		drops = drops,
	})
end

local function onCracked(info: StarInfo, damageBy: { [number]: number })
	local maxHp = math.max(info.maxHp, 1)
	for userId, damage in damageBy do
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			continue
		end
		local share = math.clamp(damage / maxHp, 0, 1)
		local ok, payload = pcall(award, player, info, share)
		if not ok then
			log:error(`award {player.Name}: {payload}`)
			continue
		end
		if payload then
			Remotes.fireClient("LootDrop", player, payload)
			announce(player, payload)
		end
	end
end

local LootService = {}

-- Szanse dla gracza na danej gwieździe (do UI szans, T13/T35): { rarity → p }, { mutation → p }, luck.
function LootService.oddsFor(
	player: Player,
	sizeId: string,
	typeId: string
): ({ [string]: number }?, { [string]: number }?, number?)
	local data = DataService.get(player)
	if not data then
		return nil, nil, nil
	end
	local luck = LootMath.luck(sizeId, data, os.time())
	local rarities, mutations = LootMath.odds(typeId, sizeId, luck)
	return rarities, mutations, luck
end

-- Tylko Studio: hak dla testów przez MCP (execute_luau nie widzi modułów serwera).
-- ServerStorage.DebugHooks.LootService:Invoke("crack", userId, rozmiar, rodzaj, udział) → payload karty
-- ("pity", userId, tier, n) → ustawia licznik; ("summary", userId) → { items, index, pity, stats }.
local function setupDebug()
	local hooks = ServerStorage:FindFirstChild("DebugHooks")
	if not hooks then
		hooks = Instance.new("Folder")
		hooks.Name = "DebugHooks"
		hooks.Parent = ServerStorage
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "LootService"
	hook.OnInvoke = function(command: string, userId: number, a: any, b: any, c: any): any
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return nil
		end
		if command == "crack" then
			local class = StarConfig.CLASSES[a]
			if not class or not StarConfig.THEMES[b] then
				return nil
			end
			local info = {
				id = `DEBUG{rng:NextInteger(1, 1e6)}`,
				size = a,
				type = b,
				hp = 0,
				maxHp = class.hp,
			} :: any
			onCracked(info, { [userId] = class.hp * (if type(c) == "number" then c else 1) })
			return true
		elseif command == "pity" and type(a) == "string" and type(b) == "number" then
			DataService.update(player, function(data)
				data.pity[a] = b
			end)
			return true
		elseif command == "summary" then
			local data = DataService.get(player)
			if not data then
				return nil
			end
			local items, onPedestal = 0, 0
			for _, item in data.items do
				items += 1
				if item.slot then
					onPedestal += 1
				end
			end
			local indexCount = 0
			for _ in data.index do
				indexCount += 1
			end
			return {
				items = items,
				onPedestal = onPedestal,
				index = indexCount,
				pity = table.clone(data.pity),
				stats = table.clone(data.stats),
			}
		end
		return nil
	end
	hook.Parent = hooks
end

function LootService.Init() end

function LootService.Start()
	StarService.onCracked(onCracked)
	if RunService:IsStudio() then
		setupDebug()
	end
end

return LootService
