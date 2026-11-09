--!strict
-- Theme — motyw UI „kosmiczna czerń” (decyzja 2026-11-08): prawie czarne tła z mgławicami, neonowe obrysy
-- (cyjan/magenta), grube czarne kontury tekstu, nasycone przyciski 3D, zielone ceny, czerwony X.
-- Rozmiary w pikselach dla ekranu bazowego BASE_SIZE; całość skaluje UIScale w App (telefon/PC/4K).
-- Kolory rzadkości z Config/Data/Rarities.json (jedno źródło prawdy).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Data.Rarities) :: any
local VfxIds = require(Shared.Config.VfxIds) :: any

local Theme = {}

Theme.COLORS = {
	ink = Color3.fromHex("#07040F"), -- kontury tekstu i ramek
	space = Color3.fromHex("#0B0718"),
	panel = Color3.fromHex("#140C26"),
	panelLight = Color3.fromHex("#1C1238"),
	nebula = Color3.fromHex("#2A0F3E"),
	neonCyan = Color3.fromHex("#3DF2FF"),
	neonMagenta = Color3.fromHex("#FF3DCB"),
	gold = Color3.fromHex("#FFC83D"),
	starYellow = Color3.fromHex("#FFD84D"),
	text = Color3.fromHex("#FFFFFF"),
	textMuted = Color3.fromHex("#B9A9D9"),
	cash = Color3.fromHex("#5BFF8A"),
	price = Color3.fromHex("#3DDC6A"),
	danger = Color3.fromHex("#FF3B4E"),
	compass = Color3.fromHex("#FF8A2B"),
	-- przyciski menu HUD i nagłówki sklepów
	shop = Color3.fromHex("#FF9A2E"),
	base = Color3.fromHex("#9A5CFF"),
	index = Color3.fromHex("#2EB8F0"),
	rides = Color3.fromHex("#1FD9A8"),
	premium = Color3.fromHex("#FFC21F"),
	overlay = Color3.new(0, 0, 0),
}

Theme.RARITY_COLORS = {} :: { [string]: Color3 }
for id, tier in Rarities.tiers do
	Theme.RARITY_COLORS[id] = Color3.fromHex(tier.color)
end
-- Secret ma w JSON prawie czarny kolor (efekt w grze), w UI dostaje tęczowy gradient i jasny akcent.
Theme.RARITY_COLORS.Secret = Color3.fromHex("#FF4FD8")
Theme.SECRET_GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("#FF3DCB")),
	ColorSequenceKeypoint.new(0.5, Color3.fromHex("#3DF2FF")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("#FFD84D")),
})

-- Rzadkość narzędzia z jego tieru (1 Common … 6 Mythic, 7 Mythic, 8 Secret).
local TIER_RARITY = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Mythic", "Secret" }
function Theme.tierRarity(tier: number): string
	return TIER_RARITY[math.clamp(tier, 1, #TIER_RARITY)]
end

-- Ikony 3D z Blendera (art/ui/build_icons.py → upload Open Cloud, T13; wersja 2 z połyskiem).
Theme.ICONS = {
	coin = "rbxassetid://100441590402887",
	star = "rbxassetid://99338036477586",
	fuel = "rbxassetid://140596732914601",
	shop = "rbxassetid://78830333459609",
	base = "rbxassetid://116878094330744",
	index = "rbxassetid://89753898429765",
	rides = "rbxassetid://90527318240283",
	premium = "rbxassetid://120994393070841",
	-- Zębatka ustawień i powrót do lobby (T14): wbudowane ikony Roblox do czasu renderów z Blendera.
	settings = "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png",
}

-- Rendery narzędzi do kart sklepu (art/ui/build_tool_icons.py). Klucze = Tools.json → order.
Theme.TOOL_RENDERS = {
	stone_pickaxe = "rbxassetid://111934838668648",
	iron_hammer = "rbxassetid://130751804546775",
	crystal_axe = "rbxassetid://123525833261720",
	plasma_saw = "rbxassetid://130523779856707",
	laser_sword = "rbxassetid://129320924967145",
	gravity_hammer = "rbxassetid://140000492473746",
	nova_cannon = "rbxassetid://113112919754407",
	starbreaker = "rbxassetid://84499103926215",
} :: { [string]: string }

-- Tekstury efektów UI (te same co VFX gwiazd, T38): mgławica (bezszwowa), flara, błysk-gwiazdka, iskra.
Theme.FX = {
	nebula = VfxIds.NEBULA,
	flare = VfxIds.FLARE,
	glint = VfxIds.GLINT,
	spark = VfxIds.SPARK,
}

Theme.FONTS = {
	display = Font.fromEnum(Enum.Font.LuckiestGuy), -- liczby, nagłówki, przyciski
	body = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular), -- opisy, małe etykiety
}

Theme.TEXT_SIZE = {
	tiny = 13,
	small = 16,
	body = 20,
	title = 30,
	big = 42,
}

Theme.STROKE = 3 -- kontur tekstu (px przed skalą)
Theme.FRAME_STROKE = 3 -- kontur ramek
Theme.CORNER = UDim.new(0, 18)
Theme.CORNER_SMALL = UDim.new(0, 12)
Theme.PILL = UDim.new(1, 0)
Theme.BUTTON_DEPTH = 5 -- „spód” przycisku 3D
Theme.MIN_TOUCH = 44 -- minimalny cel dotyku po skali

-- Skalowanie: UIScale = clamp(min(ekran / BASE_SIZE), MIN_SCALE, MAX_SCALE).
-- Telefon poziomo (~390 px wysokości) → ~0.65, przyciski menu 76 px → ~50 px (≥ 44).
Theme.BASE_SIZE = Vector2.new(1000, 560)
Theme.MIN_SCALE = 0.6
Theme.MAX_SCALE = 1.35
-- Poniżej tej logicznej wysokości menu HUD układa się w 2 kolumny (telefon).
Theme.COMPACT_HEIGHT = 640

Theme.TOAST_SECONDS = 3
Theme.MAX_TOASTS = 3
Theme.LOW_FUEL = 0.2 -- poniżej tego ułamka pasek paliwa mruga na czerwono

-- Animacje (s). Wejścia = Back (overshoot), zmiany = Quint, pętle „życia” = Sine.
Theme.MOTION = {
	hover = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	press = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	release = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	pop = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), -- otwarcie okna (overshoot)
	close = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), -- szybki zjazd
	smooth = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	count = TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
}

-- Lekkie animacje „życia” UI (pętle w tle). Czas = pół cyklu (tam lub z powrotem).
Theme.IDLE = {
	bobPixels = 3, -- unoszenie przycisków menu
	bobTime = 1.6,
	breatheTime = 1.4, -- oddychanie neonowych obrysów
	wiggleDegrees = 8, -- kołysanie ikony gwiazdy w liczniku
	wiggleTime = 1.2,
	floatPixels = 6, -- ozdoby w rogach okien
	floatTime = 2.2,
	shinePause = 3.5, -- przerwa między błyskami na przyciskach
	shineTime = 0.7,
}

function Theme.lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

function Theme.darken(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

-- Dwutonowy gradient „cukierkowy”: jaśniejsza góra, ciemniejszy i bardziej nasycony dół.
function Theme.duo(color: Color3, strength: number?): ColorSequence
	local k = strength or 1
	local h, s, v = color:ToHSV()
	local top = Color3.fromHSV((h - 0.02 * k) % 1, math.clamp(s - 0.18 * k, 0, 1), math.clamp(v + 0.15 * k, 0, 1))
	local bottom = Color3.fromHSV((h + 0.02 * k) % 1, math.clamp(s + 0.08 * k, 0, 1), math.clamp(v - 0.16 * k, 0, 1))
	return ColorSequence.new(top, bottom)
end

-- Poziomy gradient banera karty oferty: kolor → jaśniej → ciemno.
function Theme.banner(color: Color3): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.darken(color, 0.1)),
		ColorSequenceKeypoint.new(0.55, Theme.lighten(color, 0.15)),
		ColorSequenceKeypoint.new(1, Theme.darken(color, 0.5)),
	})
end

-- Tło okien i pigułek HUD: mgławica u góry, czerń na dole.
Theme.SPACE_GRADIENT = ColorSequence.new(Color3.fromHex("#1C1238"), Color3.fromHex("#07040F"))

-- Pasmo błysku (przesuwane przez Offset gradientu): wąski jasny pas na środku.
Theme.SHINE_BAND = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.42, 1),
	NumberSequenceKeypoint.new(0.5, 0.45),
	NumberSequenceKeypoint.new(0.58, 1),
	NumberSequenceKeypoint.new(1, 1),
})

return Theme
