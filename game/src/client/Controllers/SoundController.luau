--!strict
-- SoundController — odtwarzanie własnych dźwięków (Shared/Config/SoundIds): 2D (interfejs, cała mapa),
-- 3D w punkcie świata albo przypięte do części (pętle). Wszystko w SoundGroup "SFX", wyciszane ustawieniem `sfx`.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Logger = require(Shared.Logger)
local SoundIds = require(Shared.Config.SoundIds)
local StateController = require(script.Parent.StateController)

local SOUNDS = SoundIds.SOUNDS
local DEFAULT_TAIL = 8 -- s zapasu na usunięcie jednorazowego dźwięku, gdy długość nieznana

local log = Logger.new("SoundController")
local rng = Random.new()
local group: SoundGroup

local SoundController = {}

local function build(name: string, volumeMult: number?): Sound?
	local def = SOUNDS[name]
	if not def then
		log:warn(`Nieznany dźwięk {name}`)
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.id
	sound.Volume = def.volume * (volumeMult or 1)
	sound.Looped = def.looped == true
	sound.SoundGroup = group
	if def.pitchVariance then
		sound.PlaybackSpeed = 1 + rng:NextNumber(-def.pitchVariance, def.pitchVariance)
	end
	local rolloff = def.rolloff
	if rolloff then
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = rolloff[1]
		sound.RollOffMaxDistance = rolloff[2]
	end
	return sound
end

local function cleanupAfter(sound: Sound, holder: Instance?)
	local length = if sound.TimeLength > 0 then sound.TimeLength / sound.PlaybackSpeed else DEFAULT_TAIL
	Debris:AddItem(holder or sound, length + 0.5)
end

-- Dźwięk bez położenia (interfejs, grzmot na całą mapę).
function SoundController.play2D(name: string, volumeMult: number?)
	local sound = build(name, volumeMult)
	if not sound then
		return
	end
	sound.Parent = SoundService
	sound:Play()
	cleanupAfter(sound)
end

-- Jednorazowy dźwięk 3D w punkcie świata (Attachment w Terrain, bez części).
function SoundController.playAt(name: string, position: Vector3, volumeMult: number?, delay: number?)
	local function play()
		local sound = build(name, volumeMult)
		if not sound then
			return
		end
		local holder = Instance.new("Attachment")
		holder.Name = `Sfx_{name}`
		holder.WorldPosition = position
		holder.Parent = Workspace.Terrain
		sound.Parent = holder
		sound:Play()
		cleanupAfter(sound, holder)
	end
	if delay and delay > 0 then
		task.delay(delay, play)
	else
		play()
	end
end

-- Dźwięk przypięty do instancji (część/Attachment) — zwykle pętla. Zwraca Sound do zatrzymania przez fadeOut.
function SoundController.attach(name: string, parent: Instance, volumeMult: number?): Sound?
	local sound = build(name, volumeMult)
	if not sound then
		return nil
	end
	sound.Parent = parent
	sound:Play()
	if not sound.Looped then
		cleanupAfter(sound)
	end
	return sound
end

function SoundController.fadeOut(sound: Sound?, seconds: number)
	if not sound or not sound.Parent then
		return
	end
	TweenService:Create(sound, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Volume = 0 }):Play()
	Debris:AddItem(sound, seconds + 0.1)
end

local function applySettings()
	local state = StateController.get()
	local settings = state and (state :: any).settings
	local enabled = not (typeof(settings) == "table" and settings.sfx == false)
	group.Volume = if enabled then 1 else 0
end

function SoundController.Init()
	group = Instance.new("SoundGroup")
	group.Name = "SFX"
	group.Volume = 1
	group.Parent = SoundService
end

function SoundController.Start()
	StateController.onLoaded(applySettings)
	StateController.onChanged("settings", applySettings)
	-- Wstępne wczytanie, żeby pierwszy spadek nie był niemy.
	task.spawn(function()
		local list = {}
		for name, def in SOUNDS do
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = def.id
			table.insert(list, sound)
		end
		local ok, err = pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(list)
		end)
		if not ok then
			log:warn(`Preload dźwięków: {err}`)
		end
		for _, sound in list do
			sound:Destroy()
		end
	end)
end

return SoundController
