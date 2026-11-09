--!strict
-- PlotService — działki graczy (wzór: CarImportEmpire): przypisanie wolnej działki przy wejściu, teleport
-- na Spawn działki (też po respawnie), tabliczka z nazwą właściciela (BillboardGui), zwolnienie przy wyjściu.
-- Działki są w mapie: Workspace.Plots/Plot_1..8 (PlotId, OwnerUserId, Points/Spawn, Sign, BuildOrigin) —
-- vault/02 Systemy/Mapa. Inne serwisy słuchają przez onAssigned/onReleased (BaseService buduje postumenty).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.Logger)
local BaseConfig = require(Shared.Config.BaseConfig)

local log = Logger.new("PlotService")

-- Działki posortowane po numerze (PlotId) — wolną bierzemy od najniższego numeru.
local plots: { Instance } = {}
local ownerByPlot: { [Instance]: Player } = {}
local plotByPlayer: { [Player]: Instance } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}
local assignedCallbacks: { (player: Player, plot: Instance) -> () } = {}
local releasedCallbacks: { (player: Player, plot: Instance) -> () } = {}

local PlotService = {}

-- Punkt działki po nazwie (Spawn) albo nil.
function PlotService.getPoint(plot: Instance, name: string): BasePart?
	local points = plot:FindFirstChild("Points")
	local point = points and points:FindFirstChild(name)
	if point and point:IsA("BasePart") then
		return point
	end
	return nil
end

function PlotService.getPlot(player: Player): Instance?
	return plotByPlayer[player]
end

function PlotService.getOwner(plot: Instance): Player?
	return ownerByPlot[plot]
end

-- CFrame środka działki; LookVector = w stronę lobby. Od niego liczy się siatka postumentów.
function PlotService.getBuildOrigin(plot: Instance): CFrame?
	local origin = plot:FindFirstChild("BuildOrigin")
	if origin and origin:IsA("CFrameValue") then
		return origin.Value
	end
	return nil
end

local function setSignText(plot: Instance, text: string)
	local sign = plot:FindFirstChild("Sign")
	if not sign or not sign:IsA("BasePart") then
		log:warn(`{plot.Name}: brak Sign`)
		return
	end
	local gui = sign:FindFirstChild("NameTag") :: BillboardGui?
	local label: TextLabel
	if gui then
		label = gui:FindFirstChild("Label") :: TextLabel
	else
		local cfg = BaseConfig.SIGN
		local newGui = Instance.new("BillboardGui")
		newGui.Name = "NameTag"
		newGui.Size = cfg.SIZE
		newGui.StudsOffset = cfg.STUDS_OFFSET
		newGui.MaxDistance = cfg.MAX_DISTANCE
		newGui.Adornee = sign
		newGui.ResetOnSpawn = false

		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = cfg.BACKGROUND_COLOR
		label.BackgroundTransparency = cfg.BACKGROUND_TRANSPARENCY
		label.TextColor3 = cfg.TEXT_COLOR
		label.TextScaled = true
		label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		label.Parent = newGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.25, 0)
		corner.Parent = label

		newGui.Parent = sign
	end
	label.Text = text
end

local function teleportToSpawn(player: Player, character: Model)
	local plot = plotByPlayer[player]
	local spawnPoint = plot and PlotService.getPoint(plot, "Spawn")
	if not plot or not spawnPoint then
		return
	end
	local target = spawnPoint.CFrame + Vector3.new(0, BaseConfig.SPAWN_HEIGHT_OFFSET, 0)

	-- StreamingEnabled: najpierw ładujemy okolicę działki u klienta, potem przenosimy postać.
	local ok, err = pcall(player.RequestStreamAroundAsync, player, target.Position)
	if not ok then
		log:debug(`RequestStreamAroundAsync {player.Name}: {err}`)
	end
	local root = character:WaitForChild("HumanoidRootPart", BaseConfig.CHARACTER_WAIT_TIMEOUT)
	if not root or character.Parent == nil or plotByPlayer[player] ~= plot then
		return
	end
	character:PivotTo(target)
end

local function assign(player: Player)
	if plotByPlayer[player] then
		return
	end
	local free: Instance? = nil
	for _, plot in plots do
		if not ownerByPlot[plot] then
			free = plot
			break
		end
	end
	if not free then
		log:warn(`Brak wolnej działki dla {player.Name}`)
		player:Kick(BaseConfig.FULL_SERVER_MESSAGE)
		return
	end

	ownerByPlot[free] = player
	plotByPlayer[player] = free
	free:SetAttribute(BaseConfig.OWNER_ATTRIBUTE, player.UserId)
	player:SetAttribute(BaseConfig.PLAYER_PLOT_ATTRIBUTE, free:GetAttribute("PlotId"))
	setSignText(free, string.format(BaseConfig.SIGN.OWNER_FORMAT, player.DisplayName))
	log:info(`{player.Name} → {free.Name}`)

	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		teleportToSpawn(player, character)
	end)
	if player.Character then
		task.spawn(teleportToSpawn, player, player.Character)
	end
	for _, callback in assignedCallbacks do
		task.spawn(callback, player, free)
	end
end

local function release(player: Player)
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
		characterConnections[player] = nil
	end
	local plot = plotByPlayer[player]
	if not plot then
		return
	end
	plotByPlayer[player] = nil
	ownerByPlot[plot] = nil
	plot:SetAttribute(BaseConfig.OWNER_ATTRIBUTE, 0)
	setSignText(plot, BaseConfig.SIGN.FREE_TEXT)
	log:info(`{player.Name} zwolnił {plot.Name}`)
	for _, callback in releasedCallbacks do
		task.spawn(callback, player, plot)
	end
end

-- callback(player, plot) po przydzieleniu działki (też dla już przydzielonych w chwili rejestracji).
function PlotService.onAssigned(callback: (player: Player, plot: Instance) -> ())
	table.insert(assignedCallbacks, callback)
	for player, plot in plotByPlayer do
		task.spawn(callback, player, plot)
	end
end

-- callback(player, plot) po zwolnieniu działki (gracz wyszedł).
function PlotService.onReleased(callback: (player: Player, plot: Instance) -> ())
	table.insert(releasedCallbacks, callback)
end

function PlotService.Init()
	local folder = workspace:FindFirstChild(BaseConfig.PLOTS_FOLDER)
	if not folder then
		log:error(`Brak Workspace.{BaseConfig.PLOTS_FOLDER} — działki niedostępne`)
		return
	end
	for _, plot in folder:GetChildren() do
		if
			string.sub(plot.Name, 1, #BaseConfig.PLOT_PREFIX) == BaseConfig.PLOT_PREFIX
			and typeof(plot:GetAttribute("PlotId")) == "number"
		then
			table.insert(plots, plot)
		end
	end
	table.sort(plots, function(a, b)
		return (a:GetAttribute("PlotId") :: number) < (b:GetAttribute("PlotId") :: number)
	end)
	for _, plot in plots do
		plot:SetAttribute(BaseConfig.OWNER_ATTRIBUTE, 0)
		setSignText(plot, BaseConfig.SIGN.FREE_TEXT)
	end
	if Players.MaxPlayers > #plots then
		log:warn(`MaxPlayers {Players.MaxPlayers} > liczba działek {#plots} — ustaw w Game Settings`)
	end
end

function PlotService.Start()
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(assign, player)
	end
end

return PlotService
