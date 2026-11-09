--!strict
-- LootMath.spec — test LootMath bez frameworka (brak Jest w projekcie). Uruchom w Studio (edycja, kod z Rojo):
--   require(game.ServerScriptService.Server.Tests["LootMath.spec"]).run()
-- Zwraca { passed, failed, lines }. Losowania z ustalonym ziarnem → wynik powtarzalny.
-- Kryterium karty T07: rozkład losowań zgodny z 1/oneIn ±5% (1M losowań, luck 1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LootConfig = require(Shared.Config.LootConfig)
local LootMath = require(Shared.LootMath)

local SEED = 20261111
local ROLLS = 1_000_000
local SECRET_ROLLS = 5_000_000
local TOLERANCE = 0.05 -- względna odchyłka od 1/oneIn
local Z_LIMIT = 4 -- dodatkowo: odchyłka w odchyleniach standardowych

type Report = { passed: number, failed: number, lines: { string } }

local function newReport(): Report
	return { passed = 0, failed = 0, lines = {} }
end

local function check(report: Report, ok: boolean, label: string)
	if ok then
		report.passed += 1
	else
		report.failed += 1
	end
	table.insert(report.lines, `{if ok then "OK  " else "FAIL"} {label}`)
end

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-9)
end

local function oddsMap(odds: LootMath.Odds): { [string]: number }
	local map = {}
	for _, entry in odds do
		map[entry.id] = entry.p
	end
	return map
end

local function sum(odds: LootMath.Odds): number
	local total = 0
	for _, entry in odds do
		total += entry.p
	end
	return total
end

-- Rozkład n losowań vs oczekiwane p: względna odchyłka ≤ TOLERANCE i |z| ≤ Z_LIMIT.
local function distribution(
	report: Report,
	label: string,
	counts: { [string]: number },
	expected: { [string]: number },
	n: number
)
	for id, p in expected do
		local got = (counts[id] or 0) / n
		local rel = if p > 0 then math.abs(got - p) / p else got
		local sigma = math.sqrt(p * (1 - p) / n)
		local z = if sigma > 0 then math.abs(got - p) / sigma else 0
		check(
			report,
			rel <= TOLERANCE and z <= Z_LIMIT,
			string.format(
				"%s %-9s oczek. 1/%.1f  wynik 1/%.1f  odchyłka %.2f%%  z=%.2f",
				label,
				id,
				1 / p,
				if got > 0 then 1 / got else math.huge,
				rel * 100,
				z
			)
		)
	end
end

local function testDistribution(report: Report)
	local rng = Random.new(SEED)
	local pool = LootMath.pool("Iron", "Small")
	local rarityOdds = LootMath.rarityOdds(pool, 1)
	local mutationOdds = LootMath.mutationOdds(1)
	local rarityCounts: { [string]: number } = {}
	local mutationCounts: { [string]: number } = {}
	local started = os.clock()
	for _ = 1, ROLLS do
		local drop = LootMath.rollOnce(pool, rarityOdds, mutationOdds, rng)
		rarityCounts[drop.rarity] = (rarityCounts[drop.rarity] or 0) + 1
		mutationCounts[drop.mutation] = (mutationCounts[drop.mutation] or 0) + 1
	end
	table.insert(report.lines, string.format("— 1M losowań Iron/Small w %.2f s", os.clock() - started))

	-- Oczekiwane: 1/oneIn dla każdej rzadkości poza Common (Common = reszta), Secret nie istnieje w puli.
	local expected: { [string]: number } = {}
	local rest = 1
	for _, rarity in LootConfig.RARITY_ORDER do
		if rarity ~= "Common" and rarity ~= "Secret" then
			expected[rarity] = 1 / LootConfig.TIERS[rarity].oneIn
			rest -= expected[rarity]
		end
	end
	expected.Common = rest
	distribution(report, "rzadkość", rarityCounts, expected, ROLLS)
	check(report, rarityCounts.Secret == nil, "Secret nie wypada poza Supernową")

	local mutationExpected = {
		Shiny = 1 / LootConfig.MUTATIONS.Shiny.oneIn,
		Golden = 1 / LootConfig.MUTATIONS.Golden.oneIn,
	}
	distribution(report, "mutacja ", mutationCounts, mutationExpected, ROLLS)
end

local function testSecret(report: Report)
	local rng = Random.new(SEED + 1)
	local pool = LootMath.pool("Void", "Supernova")
	check(report, #(pool.Secret or {}) == 3, "pula Supernowej: 6 przedmiotów rodzaju + 3 Secret")
	check(report, LootMath.pool("Void", "Huge").Secret == nil, "pula Huge: bez Secret")
	local rarityOdds = LootMath.rarityOdds(pool, 1)
	local mutationOdds = LootMath.mutationOdds(1)
	local secrets = 0
	for _ = 1, SECRET_ROLLS do
		if LootMath.rollOnce(pool, rarityOdds, mutationOdds, rng).rarity == "Secret" then
			secrets += 1
		end
	end
	distribution(
		report,
		"Supernova",
		{ Secret = secrets },
		{ Secret = 1 / LootConfig.TIERS.Secret.oneIn },
		SECRET_ROLLS
	)
end

local function testOdds(report: Report)
	-- Luck działa od Rare w górę, Uncommon stałe 1/3.
	local pool = LootMath.pool("Lava", "Large")
	local luck = 2.8
	local odds = oddsMap(LootMath.rarityOdds(pool, luck))
	check(report, near(odds.Uncommon, 1 / 3), "luck nie zmienia Uncommon")
	check(report, near(odds.Rare, luck / 10), "Rare = luck/10")
	check(report, near(odds.Mythic, luck / 500), "Mythic = luck/500")
	check(report, near(sum(LootMath.rarityOdds(pool, luck)), 1), "suma szans = 1")

	-- Ogromny luck: suma dalej 1, nic ujemnego, najrzadsze mają pierwszeństwo.
	local capped = LootMath.rarityOdds(LootMath.pool("Void", "Supernova"), 400)
	local negative = false
	for _, entry in capped do
		negative = negative or entry.p < 0
	end
	local cappedMap = oddsMap(capped)
	check(
		report,
		near(sum(capped), 1) and not negative and (cappedMap.Common or 0) == 0,
		"luck 400: suma 1, brak ujemnych, Common 0"
	)

	-- Brak rzadkości w puli → szansa przechodzi na następną niższą (Epic → Rare).
	local gap = LootMath.rarityOdds({ Common = { "a" }, Rare = { "b" }, Legendary = { "c" } }, 1)
	local gapMap = oddsMap(gap)
	check(report, near(gapMap.Legendary, 1 / 100 + 1 / 500), "brak Mythic → +1/500 do Legendary")
	check(report, near(gapMap.Rare, 1 / 10 + 1 / 30), "brak Epic → +1/30 do Rare")
	check(report, gapMap.Secret == nil, "brak Secret w puli → Secret pominięty (exclusive)")
	check(report, near(sum(gap), 1), "pula z lukami: suma 1")

	-- Mutacje z luck (decyzja 2026-11-09).
	local mutations = oddsMap(LootMath.mutationOdds(2))
	check(report, near(mutations.Golden, 2 / 200) and near(mutations.Shiny, 2 / 25), "mutacje × luck")
end

local function testRolls(report: Report)
	check(report, LootMath.rollCount("Small", 1) == 1, "Small: 1 losowanie")
	check(report, LootMath.rollCount("Huge", 0.2) == 3, "Huge udział 20%: 3 losowania")
	check(report, LootMath.rollCount("Huge", 0.25) == 4, "Huge udział 25%: +1 losowanie")
	check(report, LootMath.rollCount("Large", 0.9) == 2, "Large: bez dodatkowego losowania")
	check(report, LootMath.rollCount("Supernova", 0.5) == 6, "Supernova udział 50%: 6 losowań")
	check(report, not LootMath.eligible("Medium", 0.04), "Medium udział 4% < minShare 5%")
	check(report, LootMath.eligible("Small", 0.001), "Small: każdy udział > 0")
	check(report, not LootMath.eligible("Small", 0), "udział 0 → brak łupu")
	check(report, not LootMath.eligible("Small", 0 / 0), "udział NaN → brak łupu")
end

local function testPity(report: Report)
	local rng = Random.new(SEED + 2)
	-- 250. rozbicie bez Legendary+ → gwarantowany Legendary, licznik Legendary = 0.
	local hits, legendary = 0, 0
	for _ = 1, 200 do
		local result = LootMath.roll({
			themeId = "Iron",
			sizeId = "Small",
			share = 1,
			luck = 1,
			pity = { Legendary = LootConfig.PITY.Legendary - 1, Mythic = 10 },
		}, rng)
		local best = 0
		for _, drop in result.drops do
			best = math.max(best, LootConfig.rarityRank(drop.rarity))
		end
		if best >= LootConfig.rarityRank("Legendary") then
			legendary += 1
		end
		if result.pityHit == "Legendary" then
			hits += 1
		end
		if result.pity.Legendary ~= 0 then
			legendary = -math.huge
		end
	end
	check(report, legendary == 200, "pity Legendary: zawsze Legendary+ i licznik 0")
	check(report, hits > 190, `pity Legendary zadziałało {hits}/200 (reszta wylosowała Legendary+ sama)`)

	-- 1200. rozbicie bez Mythic → Mythic, oba liczniki 0.
	local mythic = LootMath.roll({
		themeId = "Frost",
		sizeId = "Medium",
		share = 1,
		luck = 1,
		pity = { Legendary = 3, Mythic = LootConfig.PITY.Mythic - 1 },
	}, rng)
	check(
		report,
		mythic.drops[1].rarity == "Mythic" and mythic.pity.Mythic == 0 and mythic.pity.Legendary == 0,
		"pity Mythic: Mythic, liczniki zerowane"
	)

	-- Zwykłe rozbicie: licznik rośnie o 1 (na rozbicie, nie na losowanie — Huge ma 3 losowania).
	local normal = LootMath.roll({
		themeId = "Iron",
		sizeId = "Huge",
		share = 0.1,
		luck = 0.0001,
		pity = { Legendary = 5, Mythic = 7 },
	}, rng)
	check(report, #normal.drops == 3, "Huge: 3 przedmioty")
	check(report, normal.pity.Legendary == 6 and normal.pity.Mythic == 8, "pity +1 na rozbicie")
	check(report, normal.pityHit == nil, "bez pity przed progiem")
end

local function testLuckAndSlots(report: Report)
	local now = 1_000_000
	local base = { purchases = {}, boosts = {}, index = {} }
	local luck = LootMath.luck("Huge", base, now)
	check(report, near(luck, 4.5), "luck Huge bez bonusów = 4.5")

	local paid = { purchases = { lucky = true, vip = true }, boosts = { luck_boost = now + 60 }, index = {} }
	local paidLuck, breakdown = LootMath.luck("Small", paid, now)
	check(report, near(paidLuck, 1 * (1 + 0.25 + 0.1) * 2), `Lucky+VIP+boost = {paidLuck}`)
	check(report, near(breakdown.boost, 2), "boost aktywny ×2")
	local expired = LootMath.luck("Small", { purchases = {}, boosts = { luck_boost = now - 1 }, index = {} }, now)
	check(report, near(expired, 1), "boost po czasie nie działa")

	local index = {}
	for _, itemId in LootConfig.THEME_SET.Iron do
		index[itemId] = true
	end
	check(report, LootMath.completedThemes(index) == 1, "komplet Iron = 1 motyw")
	check(report, near(LootMath.luck("Small", { purchases = {}, boosts = {}, index = index }, now), 1.05), "indeks +5%")

	check(report, LootMath.slotCapacity(6, { vip = true, extra_slots = true }) == 12, "sloty 6 + VIP 1 + 5")
	local items = { a = { slot = 1 }, b = { slot = 3 }, c = {} }
	check(report, LootMath.freeSlot(items, 6) == 2, "wolny slot = najniższy wolny")
	check(report, LootMath.freeSlot({ a = { slot = 1 } }, 1) == nil, "pełna baza → nil (ekwipunek)")

	check(report, LootMath.incomePerSec("iron_pebble", "None") == 1, "dochód Common Iron = 1")
	check(report, LootMath.incomePerSec("iron_pebble", "Golden") == 5, "Golden ×5")
end

local Spec = {}

function Spec.run(): Report
	local report = newReport()
	testOdds(report)
	testRolls(report)
	testPity(report)
	testLuckAndSlots(report)
	testDistribution(report)
	testSecret(report)
	table.insert(report.lines, `== {report.passed} OK, {report.failed} FAIL`)
	return report
end

return Spec
