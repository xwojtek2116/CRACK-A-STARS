--!strict
-- ToolsScreen — zakładka TOOLS sklepu: 8 narzędzi z Tools.json (kolejne tiery kupuje się po kolei).
-- Stan karty z danych gracza (Store.tools / equippedTool):
--   wyposażone → „EQUIPPED”, posiadane → „EQUIP”, następny tier → cena (kasa), dalsze → „LOCKED” (przyciemnione).
-- Kupno i wyposażanie liczy serwer (BuyTool / EquipTool → ToolService, T09). Po kupnie ekran „NEW TOOL UNLOCKED!”
-- (Tools/Unlock) i zamknięcie sklepu — narzędzie jest już w ręku.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Tools = require(ReplicatedStorage:WaitForChild("Shared").Config.Data.Tools) :: any
local ToolConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.ToolConfig)

local UI = script.Parent.Parent
local OfferCard = require(UI.Components.OfferCard)
local Unlock = require(UI.Tools.Unlock)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local Common = require(script.Parent.Common)
local Request = require(script.Parent.Request)

local e = React.createElement

local function ToolsScreen()
	local owned = Store.use(function(s)
		return s.tools
	end)
	local equipped = Store.use(function(s)
		return s.equippedTool
	end)

	local cards = {}
	for i, id in Tools.order do
		local tool = Tools.tools[id]
		local isOwned = owned[id] == true or tool.price == 0
		local previous = Tools.order[i - 1]
		local isNext = not isOwned and (previous == nil or owned[previous] == true)
		local actionText, actionColor, onBuy, tag = nil, nil, nil, nil
		if isOwned and equipped == id then
			actionText, actionColor = "EQUIPPED", Theme.COLORS.index
		elseif isOwned then
			actionText, actionColor = "EQUIP", Theme.COLORS.neonCyan
			onBuy = function()
				Request.send("EquipTool", { id }, `{tool.name} equipped!`)
			end
		elseif isNext then
			tag = "NEXT UP!"
			onBuy = function()
				local before = Store.get().equippedTool
				Request.send("BuyTool", { id }, nil, function(result)
					if result.ok then
						Store.closeWindow()
						task.delay(ToolConfig.UNLOCK.delay, Unlock.show, id, before)
					end
				end)
			end
		else
			actionText, actionColor = "LOCKED", Theme.COLORS.panelLight
			onBuy = function()
				Store.toast(Request.reasonText("Locked"), "info")
			end
		end
		cards[id] = e(OfferCard, {
			name = tool.name,
			rarity = Theme.tierRarity(tool.tier),
			image = Theme.TOOL_RENDERS[id] or Theme.ICONS.star,
			stats = {
				{ label = "DMG", value = tostring(tool.damage) },
				{ label = "CD", value = `{tool.cooldown}s` },
				{ label = "TIER", value = tostring(tool.tier) },
			},
			price = tool.price,
			currency = "cash",
			tag = tag,
			actionText = actionText,
			actionColor = actionColor,
			dimmed = actionText == "LOCKED",
			layoutOrder = i,
			index = i,
			onBuy = onBuy,
		})
	end
	return e(Common.CardList, { children = cards })
end

return ToolsScreen
