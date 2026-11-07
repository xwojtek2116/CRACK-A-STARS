--!strict
-- RateLimiter — token bucket per gracz per remote. Używa go tylko serwer (Shared/Remotes).

local Players = game:GetService("Players")

local NetConfig = require(script.Parent.Parent.Config.NetConfig)

type BucketState = {
	tokens: number,
	updatedAt: number,
	rejected: number,
}

local buckets: { [Player]: { [string]: BucketState } } = {}

local RateLimiter = {}

local function getConfig(remoteName: string): NetConfig.Bucket
	return NetConfig.BUCKETS[remoteName] or NetConfig.DEFAULT_BUCKET
end

-- Zwraca (czy przepuścić, łączna liczba odrzuceń tego gracza na tym remote).
function RateLimiter.consume(player: Player, remoteName: string): (boolean, number)
	local config = getConfig(remoteName)
	local now = os.clock()

	local perPlayer = buckets[player]
	if not perPlayer then
		perPlayer = {}
		buckets[player] = perPlayer
	end

	local state = perPlayer[remoteName]
	if not state then
		state = { tokens = config.capacity, updatedAt = now, rejected = 0 }
		perPlayer[remoteName] = state
	end

	local elapsed = now - state.updatedAt
	state.tokens = math.min(config.capacity, state.tokens + elapsed * config.refillPerSecond)
	state.updatedAt = now

	if state.tokens >= 1 then
		state.tokens -= 1
		return true, state.rejected
	end
	state.rejected += 1
	return false, state.rejected
end

function RateLimiter.reset(player: Player)
	buckets[player] = nil
end

Players.PlayerRemoving:Connect(RateLimiter.reset)

return RateLimiter
