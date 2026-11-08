--!strict
-- Types — wspólne typy serwera i klienta. Dane balansu (gwiazdy, łup, narzędzia) są w Config/Data/*.json.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"
export type Mutation = "None" | "Shiny" | "Golden"

-- Przedmiot gracza (łup z gwiazdy). uid = GUID, itemId = klucz z Items.json.
export type OwnedItem = {
	itemId: string,
	mutation: Mutation,
	obtainedAt: number,
	slot: number?, -- numer postumentu w bazie; nil = w ekwipunku
}

export type PlayerData = {
	schemaVersion: number,
	cash: number,
	rebirths: number,
	tools: { [string]: boolean },
	equippedTool: string,
	vehicles: { [string]: boolean },
	jetpackLevel: number,
	items: { [string]: OwnedItem },
	slots: number,
	index: { [string]: boolean },
	pity: { [string]: number },
	boosts: { [string]: number }, -- id → czas końca (os.time)
	stats: { [string]: number },
	daily: { lastClaim: number, streak: number },
	codesUsed: { [string]: boolean },
	tutorialStep: number,
	settings: { [string]: boolean },
	purchases: { [string]: boolean },
	lastOnline: number,
}

-- Gwiazda (StarService → klienci). Czasy = workspace:GetServerTimeNow().
export type StarState = "Falling" | "Landed" | "Dying"
export type StarInfo = {
	id: string,
	size: string, -- klucz z Stars.json → classes
	type: string, -- klucz z Themes.json → themes
	state: StarState,
	startPos: Vector3, -- początek toru lotu (niebo)
	impactPos: Vector3, -- punkt uderzenia na ziemi
	normal: Vector3, -- normalna terenu w punkcie uderzenia
	launchedAt: number,
	impactAt: number,
	expiresAt: number?, -- po wylądowaniu: koniec lifetime
	hp: number,
	maxHp: number,
}

return nil
