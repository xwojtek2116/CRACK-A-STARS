--!strict
-- RebirthMath — wzory rebirthu wspólne dla serwera (RebirthService, T19) i ekranu REBIRTH (T14).
-- Liczby: Economy.json → rebirth (koszt = costBase × costGrowth^rebirths, dochód × (1 + cashMult × rebirths)).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage:WaitForChild("Shared").Config.Data.Economy) :: any

local REBIRTH = Economy.rebirth

local RebirthMath = {}

RebirthMath.KEEPS = REBIRTH.keeps :: { string }
RebirthMath.RESETS = REBIRTH.resets :: { string }

-- Koszt następnego rebirthu przy `rebirths` wykonanych.
function RebirthMath.cost(rebirths: number): number
	return math.floor((REBIRTH.costBase :: number) * (REBIRTH.costGrowth :: number) ^ rebirths)
end

-- Mnożnik dochodu po `rebirths` rebirthach.
function RebirthMath.incomeMult(rebirths: number): number
	return 1 + (REBIRTH.cashMultPerRebirth :: number) * rebirths
end

return RebirthMath
