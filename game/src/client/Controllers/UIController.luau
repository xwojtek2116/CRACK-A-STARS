--!strict
-- UIController — korzeń React (ScreenGui "MainUI") i zasilanie UI/Store:
--   cash            ← StateController (PlayerState.cash),
--   incomePerSec    ← atrybut gracza IncomePerSec (ustawia baza, T08),
--   fuel / fuelMax  ← atrybuty gracza Fuel / FuelMax (ustawia jetpack, T10; brak Fuel = pasek ukryty),
--   nextStarAt      ← atrybut Workspace.NextStarAt (StarService, czas serwera).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local Logger = require(ReplicatedStorage:WaitForChild("Shared").Logger)

local StateController = require(script.Parent.StateController)

local UI = script.Parent.Parent:WaitForChild("UI")
local App = require(UI.App)
local Store = require(UI.Store)

local log = Logger.new("UIController")
local player = Players.LocalPlayer

local ATTR_INCOME = "IncomePerSec"
local ATTR_FUEL = "Fuel"
local ATTR_FUEL_MAX = "FuelMax"
local ATTR_NEXT_STAR = "NextStarAt"

local function number(value: any): number?
	return if type(value) == "number" and value == value then value else nil
end

local function syncAttributes()
	local fuel = number(player:GetAttribute(ATTR_FUEL))
	Store.set({
		incomePerSec = number(player:GetAttribute(ATTR_INCOME)) or 0,
		fuel = if fuel then fuel else Store.none,
		fuelMax = number(player:GetAttribute(ATTR_FUEL_MAX)) or 1,
	})
end

-- Pola stanu gracza kopiowane 1:1 do Store (ekrany T14). Wartość nil zostawia domyślną.
local PROFILE_KEYS = { "tools", "equippedTool", "vehicles", "jetpackLevel", "rebirths", "index", "settings" }

local function syncProfile(state: { [string]: any }?)
	if not state then
		return
	end
	local patch = {}
	for _, key in PROFILE_KEYS do
		if state[key] ~= nil then
			patch[key] = state[key]
		end
	end
	Store.set(patch)
end

local function syncNextStar()
	local at = number(Workspace:GetAttribute(ATTR_NEXT_STAR))
	Store.set({ nextStarAt = if at then at else Store.none })
end

local UIController = {}

function UIController.Init() end

function UIController.Start()
	local screen = Instance.new("ScreenGui")
	screen.Name = "MainUI"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.DisplayOrder = 10 -- nad banerami gwiazd (StarBanner = 6), żeby okna je przykrywały
	screen.Parent = player:WaitForChild("PlayerGui")

	local root = ReactRoblox.createRoot(screen)
	root:render(React.createElement(App, { screen = screen }))

	StateController.onLoaded(function(state)
		Store.setCash(state.cash)
		syncProfile(state :: any)
	end)
	for _, key in PROFILE_KEYS do
		StateController.onChanged(key, function()
			syncProfile(StateController.get() :: any)
		end)
	end
	StateController.onChanged("cash", function(newValue)
		if type(newValue) == "number" then
			Store.setCash(newValue)
		end
	end)
	local current = StateController.get()
	if current then
		Store.setCash(current.cash)
		syncProfile(current :: any)
	end

	for _, name in { ATTR_INCOME, ATTR_FUEL, ATTR_FUEL_MAX } do
		player:GetAttributeChangedSignal(name):Connect(syncAttributes)
	end
	Workspace:GetAttributeChangedSignal(ATTR_NEXT_STAR):Connect(syncNextStar)
	-- Tylko Studio: atrybut gracza DevCash podmienia wyświetlaną kasę (test licznika i monet przez MCP,
	-- bo execute_luau ma osobny cache require i nie dosięga DataService). Nie zmienia danych gracza.
	if RunService:IsStudio() then
		-- DevWindow = "Shop" | "Shop/exclusives" | "Base" | … otwiera okno (i zakładkę) (test UI przez MCP bez klikania), "" zamyka.
		player:GetAttributeChangedSignal("DevWindow"):Connect(function()
			local id = player:GetAttribute("DevWindow")
			if type(id) == "string" and id ~= "" then
				local window, tab = string.match(id, "^([^/]+)/?(.*)$")
				Store.set({ window = window, tab = if tab ~= "" then tab else Store.none })
			else
				Store.closeWindow()
			end
		end)
		player:GetAttributeChangedSignal("DevCash"):Connect(function()
			local cash = number(player:GetAttribute("DevCash"))
			if cash then
				Store.setCash(cash)
			end
		end)
	end
	syncAttributes()
	syncNextStar()
	log:debug("gotowy")
end

return UIController
