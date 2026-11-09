--!strict
-- GarageScreen — okno RIDES (garaż): zakładka VEHICLES (Vehicles.json → vehicles) i JETPACK (poziomy).
-- Pojazdy kupuje się w dowolnej kolejności, jetpack poziom po poziomie (następny = cena, dalsze = LOCKED).
-- Kupno liczy serwer (BuyVehicle / BuyJetpack; logika T10, do tego czasu „Coming soon”).
-- Rendery pojazdów dojdą z T24 — na razie ikona RIDES / paliwa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Vehicles = require(ReplicatedStorage:WaitForChild("Shared").Config.Data.Vehicles) :: any

local UI = script.Parent.Parent
local OfferCard = require(UI.Components.OfferCard)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local Common = require(script.Parent.Common)
local Request = require(script.Parent.Request)

local e = React.createElement

local GarageScreen = {}

GarageScreen.TABS = {
	{ id = "vehicles", text = "VEHICLES" },
	{ id = "jetpack", text = "JETPACK" },
}

-- Rzadkość karty (kolor banera) z pozycji na liście: kolejne pojazdy są coraz lepsze.
local VEHICLE_RARITY = { "Rare", "Epic", "Legendary", "Mythic", "Secret" }
local JETPACK_RARITY = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

local function VehicleList()
	local owned = Store.use(function(s)
		return s.vehicles
	end)
	local cards = {}
	for i, id in Vehicles.order do
		local vehicle = Vehicles.vehicles[id]
		local isOwned = owned[id] == true
		cards[id] = e(OfferCard, {
			name = vehicle.name,
			rarity = VEHICLE_RARITY[math.min(i, #VEHICLE_RARITY)],
			image = Theme.ICONS.rides,
			stats = {
				{ label = "SPEED", value = tostring(vehicle.speed) },
				{ label = "SEATS", value = tostring(vehicle.seats) },
				{ label = "TYPE", value = if vehicle.flies then "AIR" else "GROUND" },
			},
			price = vehicle.price,
			currency = "cash",
			owned = isOwned,
			tag = if vehicle.flies then "FLYING!" elseif i == 1 then "STARTER!" else nil,
			layoutOrder = i,
			index = i,
			onBuy = if isOwned
				then nil
				else function()
					Request.send("BuyVehicle", { id }, `{vehicle.name} is yours!`)
				end,
		})
	end
	return e(Common.CardList, { children = cards })
end

local function JetpackList()
	local level = Store.use(function(s)
		return s.jetpackLevel
	end)
	local cards = {}
	for i, entry in Vehicles.jetpack.levels do
		local isOwned = entry.level <= level
		local isNext = entry.level == level + 1
		cards[`L{entry.level}`] = e(OfferCard, {
			name = `JETPACK LV {entry.level}`,
			rarity = JETPACK_RARITY[math.min(i, #JETPACK_RARITY)],
			image = Theme.ICONS.fuel,
			stats = {
				{ label = "FUEL", value = `{entry.fuel}s` },
				{ label = "THRUST", value = `x{entry.thrust}` },
			},
			price = entry.price,
			currency = "cash",
			owned = isOwned,
			tag = if entry.level == level then "CURRENT!" elseif isNext then "NEXT UP!" else nil,
			actionText = if not isOwned and not isNext then "LOCKED" else nil,
			actionColor = if not isOwned and not isNext then Theme.COLORS.panelLight else nil,
			dimmed = not isOwned and not isNext,
			layoutOrder = i,
			index = i,
			onBuy = if isNext
				then function()
					Request.send("BuyJetpack", {}, `Jetpack upgraded to LV {entry.level}!`)
				end
				elseif not isOwned then function()
					Store.toast(Request.reasonText("Locked"), "info")
				end
				else nil,
		})
	end
	return e(Common.CardList, { children = cards })
end

function GarageScreen.Body(props: { tab: string })
	if props.tab == "jetpack" then
		return e(JetpackList)
	end
	return e(VehicleList)
end

return GarageScreen
