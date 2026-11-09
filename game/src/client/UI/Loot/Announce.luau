--!strict
-- Loot/Announce — rzadki łup innych graczy (Announcement kind = "Loot", LootService):
--   od Epic       → wiadomość systemowa na czacie (kolor rzadkości),
--   od Legendary  → baner u góry ekranu dla całego serwera (kolejka, jeden naraz),
--   od Mythic     → do tego błysk ekranu i dźwięk u wszystkich.
-- Własny łup gracz widzi na karcie (Reveal), więc baner i błysk pokazujemy tylko dla cudzego łupu; czat dla wszystkich.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LootConfig = require(Shared.Config.LootConfig)
local Logger = require(Shared.Logger)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Fx = require(script.Parent.Fx)
local SoundController = require(UI.Parent.Controllers.SoundController)

local REVEAL = LootConfig.REVEAL
local ANNOUNCE = LootConfig.ANNOUNCE

export type AnnouncedDrop = { itemId: string, rarity: string, mutation: string }
export type LootAnnouncement = {
	kind: "Loot",
	userId: number,
	name: string,
	star: string,
	drops: { AnnouncedDrop },
}

local log = Logger.new("Announce")
local player = Players.LocalPlayer
local screen: ScreenGui? = nil
local queue: { { text: string, rarity: string } } = {}
local showing = false

local Announce = {}

local function rank(rarity: string): number
	return LootConfig.rarityRank(rarity)
end

local function getScreen(): ScreenGui
	if screen and screen.Parent then
		return screen
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LootAnnounce"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	screen = gui
	return gui
end

local function itemName(itemId: string): string
	local item = LootConfig.ITEMS[itemId]
	return if item then item.name else itemId
end

local function describe(drop: AnnouncedDrop): string
	local mutation = if drop.mutation ~= "None" then `{drop.mutation} ` else ""
	return `{mutation}{drop.rarity} {itemName(drop.itemId)}`
end

local function chat(data: LootAnnouncement, drop: AnnouncedDrop)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local system = channels and channels:FindFirstChild("RBXSystem")
	if not system or not system:IsA("TextChannel") then
		return
	end
	local color = Fx.rarityColor(drop.rarity):ToHex()
	local text = `<font color="#{color}">★ {Fx.escape(data.name)} found {describe(drop)} in a {data.star}!</font>`
	local ok, err = pcall(function()
		system:DisplaySystemMessage(text)
	end)
	if not ok then
		log:warn(`czat: {err}`)
	end
end

local function showNext()
	local entry = table.remove(queue, 1)
	if not entry then
		showing = false
		return
	end
	showing = true
	local gui = getScreen()
	local color = Fx.rarityColor(entry.rarity)

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.fromScale(0.5, -0.2)
	banner.Size = UDim2.fromOffset(700, 58)
	banner.BackgroundColor3 = Color3.new(1, 1, 1)
	Fx.corner(banner, Theme.PILL)
	Fx.gradient(banner, if entry.rarity == "Secret" then Theme.SECRET_GRADIENT else Theme.banner(color), 0)
	Fx.stroke(banner, Theme.COLORS.ink, 4)
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = Fx.screenScale(gui)
	uiScale.Parent = banner
	local label = Fx.text(banner, {
		text = entry.text,
		size = UDim2.fromScale(0.9, 0.7),
		position = UDim2.fromScale(0.5, 0.5),
		maxSize = 24,
		rich = true,
	})
	label.ZIndex = 2
	for _, x in { 0.04, 0.96 } do
		local star = Instance.new("ImageLabel")
		star.Image = Theme.FX.glint
		star.BackgroundTransparency = 1
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(x, 0.5)
		star.Size = UDim2.fromOffset(46, 46)
		star.ZIndex = 3
		star.Parent = banner
		Fx.loop(star, 1.6, { Rotation = 360 }, false)
	end
	banner.Parent = gui
	Fx.shine(banner, 0.9, 1.1)
	Fx.tween(banner, 0.45, { Position = UDim2.fromScale(0.5, 0.3) }, Enum.EasingStyle.Back)

	task.delay(REVEAL.bannerSeconds, function()
		Fx.tween(banner, 0.3, { Position = UDim2.fromScale(0.5, -0.2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.32, function()
			banner:Destroy()
			showNext()
		end)
	end)
end

function Announce.handle(data: LootAnnouncement)
	if type(data.drops) ~= "table" or #data.drops == 0 then
		return
	end
	local best = data.drops[1]
	for _, drop in data.drops do
		if rank(drop.rarity) >= rank(ANNOUNCE.chatFrom) then
			chat(data, drop)
		end
		if rank(drop.rarity) > rank(best.rarity) then
			best = drop
		end
	end
	if data.userId == player.UserId then
		return
	end

	local bestRank = rank(best.rarity)
	if bestRank >= rank(ANNOUNCE.bannerFrom) then
		local color = Fx.rarityColor(best.rarity):ToHex()
		local mutation = if best.mutation ~= "None" then `{string.upper(best.mutation)} ` else ""
		table.insert(queue, {
			text = `{Fx.escape(data.name)} found <font color="#{color}">{mutation}{string.upper(best.rarity)}</font> {itemName(
				best.itemId
			)}!`,
			rarity = best.rarity,
		})
		if not showing then
			showNext()
		end
		SoundController.play2D("announceSting", 0.7)
	end
	if bestRank >= rank(ANNOUNCE.effectFrom) then
		Fx.flash(getScreen(), Fx.rarityColor(best.rarity), REVEAL.flashAlpha * 0.6, 0.9)
		SoundController.play2D("musicImpact", 0.6)
	end
end

return Announce
