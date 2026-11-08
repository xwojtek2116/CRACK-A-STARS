--!strict
-- Sfx — dźwięki interfejsu przez SoundController (klik, pop okna, zamknięcie, moneta). Z ograniczeniem
-- częstotliwości, żeby seria monet albo szybkie klikanie nie nakładały kilkunastu dźwięków naraz.

local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local MIN_GAP = 0.05 -- s między dźwiękami tego samego rodzaju
local lastAt: { [string]: number } = {}

local Sfx = {}

function Sfx.play(name: "uiClick" | "uiPop" | "uiClose" | "uiCoin", volumeMult: number?)
	local now = os.clock()
	if now - (lastAt[name] or 0) < MIN_GAP then
		return
	end
	lastAt[name] = now
	SoundController.play2D(name, volumeMult)
end

return Sfx
