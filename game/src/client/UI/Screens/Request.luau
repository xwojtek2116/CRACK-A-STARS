--!strict
-- Request — prośby ekranów T14 do serwera (sklep, garaż, rebirth, ustawienia, lobby) i toasty z wynikiem.
-- Klient niczego nie przyznaje sam: wysyła prośbę, serwer liczy i odsyła { ok, reason? }, stan wraca deltą.
-- Wywołanie blokuje (InvokeServer), więc przyciski wołają Request.send w osobnym wątku (task.spawn w środku).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)

local UI = script.Parent.Parent
local Sfx = require(UI.Sfx)
local Store = require(UI.Store)

local REASONS: { [string]: string } = {
	ComingSoon = "Coming soon!",
	NoCash = "Not enough cash!",
	NotOwned = "Buy it first!",
	Locked = "Unlock the previous one first!",
	Owned = "You already own it!",
	Max = "Already maxed out!",
	Cooldown = "Wait a moment!",
	InMinigame = "Finish cracking the star first!",
	NoCharacter = "Wait for your character to load.",
	NoLobby = "The lobby is not ready yet.",
	NotLoaded = "Your save is still loading.",
	RateLimited = "Slow down!",
	InvalidArgs = "Something went wrong.",
	Error = "Something went wrong.",
}

export type Result = { ok: boolean, reason: string?, readyAt: number? }

local Request = {}

function Request.reasonText(reason: string?): string
	return REASONS[reason or "Error"] or "Something went wrong."
end

-- Wysyła prośbę w tle. successText = toast po sukcesie (nil = bez toastu). onDone dostaje wynik.
function Request.send(name: Remotes.RemoteName, args: { any }, successText: string?, onDone: ((Result) -> ())?)
	task.spawn(function()
		local ok, result, reason = pcall(Remotes.invoke, name, table.unpack(args))
		local out: Result = if ok and type(result) == "table"
			then result :: any
			else { ok = false, reason = if ok then reason else "Error" }
		if out.ok then
			if successText then
				Sfx.play("uiPop")
				Store.toast(successText, "success")
			end
		elseif out.reason == "ComingSoon" then
			Store.toast(Request.reasonText(out.reason), "info")
		else
			Store.toast(Request.reasonText(out.reason), "error")
		end
		if onDone then
			onDone(out)
		end
	end)
end

return Request
