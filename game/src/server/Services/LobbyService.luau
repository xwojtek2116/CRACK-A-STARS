--!strict
-- LobbyService — przycisk „Return to Lobby” w HUD (T14): teleport postaci na spawn lobby.
-- Serwer pilnuje: postać żyje, gracz nie jest w trakcie minigry (CrackService.isInRound), cooldown
-- Economy.map.returnToLobbyCooldown. Miejsce = Workspace.Map.Lobby.Spawn + losowe przesunięcie w kole
-- (lobbyTeleportSpread), żeby kilku graczy nie lądowało w sobie.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Data.Economy) :: any
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)

local CrackService = require(script.Parent.CrackService)

local log = Logger.new("LobbyService")
local rng = Random.new()

local COOLDOWN: number = Economy.map.returnToLobbyCooldown
local SPREAD: number = Economy.map.lobbyTeleportSpread
local SPAWN_HEIGHT = 4 -- nad SpawnLocation (połowa wysokości postaci + zapas)

local readyAt: { [Player]: number } = {}

local function findSpawn(): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local lobby = map and map:FindFirstChild("Lobby")
	local spawn = lobby and lobby:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn
	end
	return nil
end

type Result = { ok: boolean, reason: string?, readyAt: number? }

local function returnToLobby(player: Player): Result
	local now = Workspace:GetServerTimeNow()
	local nextAt = readyAt[player] or 0
	if now < nextAt then
		return { ok = false, reason = "Cooldown", readyAt = nextAt }
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return { ok = false, reason = "NoCharacter" }
	end
	if CrackService.isInRound(player) then
		return { ok = false, reason = "InMinigame" }
	end
	local spawn = findSpawn()
	if not spawn then
		log:warn("Brak Workspace.Map.Lobby.Spawn — Return to Lobby nie działa")
		return { ok = false, reason = "NoLobby" }
	end

	if humanoid.Sit then
		humanoid.Sit = false -- wysiadka z pojazdu (T10) przed teleportem
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(0, SPREAD)
	local offset = Vector3.new(math.cos(angle) * distance, spawn.Size.Y / 2 + SPAWN_HEIGHT, math.sin(angle) * distance)
	local look = (root.CFrame.LookVector * Vector3.new(1, 0, 1))
	local position = spawn.Position + offset
	local target = if look.Magnitude > 0.01 then CFrame.lookAt(position, position + look.Unit) else CFrame.new(position)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(target)

	local nextReady = now + COOLDOWN
	readyAt[player] = nextReady
	return { ok = true, readyAt = nextReady }
end

local LobbyService = {}

function LobbyService.Init()
	Remotes.onInvoke("ReturnToLobby", returnToLobby)
end

function LobbyService.Start()
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return LobbyService
