--!strict
-- NetConfig — limity zapytań (token bucket) dla Remotes.
-- capacity = ile zapytań naraz (seria), refillPerSecond = ile żetonów wraca na sekundę.

export type Bucket = {
	capacity: number,
	refillPerSecond: number,
}

local DEFAULT_BUCKET: Bucket = {
	capacity = 10,
	refillPerSecond = 5,
}

-- Limity per remote (nazwa z Shared/Remotes). Nowy remote od klienta = dopisz tu limit.
local BUCKETS: { [string]: Bucket } = {
	RequestState = { capacity = 3, refillPerSecond = 0.5 },
	SetSetting = { capacity = 5, refillPerSecond = 1 },
	RequestStars = { capacity = 3, refillPerSecond = 0.5 },
	-- Minigra: legalnie ~1 runda na 2 s (runda + cooldown narzędzia).
	CrackStart = { capacity = 3, refillPerSecond = 1 },
	CrackFinish = { capacity = 3, refillPerSecond = 1 },
	-- Baza i sprzedaż: klikanie po postumentach / liście, ale bez spamu.
	PlaceItem = { capacity = 6, refillPerSecond = 3 },
	RemoveItem = { capacity = 6, refillPerSecond = 3 },
	AutoPlace = { capacity = 2, refillPerSecond = 0.5 },
	BuySlot = { capacity = 3, refillPerSecond = 1 },
	SellItem = { capacity = 8, refillPerSecond = 4 },
	SellBelow = { capacity = 2, refillPerSecond = 0.5 },
	WelcomeInfo = { capacity = 2, refillPerSecond = 0.2 },
}

return {
	DEFAULT_BUCKET = DEFAULT_BUCKET,
	BUCKETS = BUCKETS,
	REJECT_LOG_EVERY = 25,
	INVALID_LOG_EVERY = 10,
	MAX_ARGS = 8,
}
