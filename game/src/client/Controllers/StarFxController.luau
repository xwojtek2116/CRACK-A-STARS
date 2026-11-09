--!strict
-- StarFxController — dyrygent cinematiku spadku gwiazdy (T05 → T38). Stan przychodzi z StarService
-- (StarEvent + RequestStars); klient niczego nie rozstrzyga, tylko odgrywa fazy:
--   ogłoszenie (baner, alarm) → wyrwa w niebie (RiftFx) → wylot i lot (FallFx, rzut kamery od Large)
--   → uderzenie (ImpactFx) → zapadnięcie wyrwy → leżąca gwiazda (LandedFx, napis StarHud) → rozbicie/zgaśnięcie.
-- Niebo i światło całego świata: SkyFx. Jakość efektów: ustawienie lowGraphics + automatycznie z FPS.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimConfig = require(Shared.Config.AnimConfig)
local Logger = require(Shared.Logger)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)

local CinematicController = require(script.Parent.CinematicController)
local SoundController = require(script.Parent.SoundController)
local StateController = require(script.Parent.StateController)
local Fx = script.Parent.Parent:WaitForChild("Fx")
local FallFx = require(Fx.FallFx)
local FxUtil = require(Fx.FxUtil)
local ImpactFx = require(Fx.ImpactFx)
local LandedFx = require(Fx.LandedFx)
local StarVisual = require(Fx.StarVisual)
local RiftFx = require(Fx.RiftFx)
local SkyFx = require(Fx.SkyFx)
local StarHud = require(Fx.StarHud)

type StarInfo = Types.StarInfo

type ClientStar = {
	info: StarInfo,
	rift: RiftFx.Rift?,
	fall: FallFx.Fall?,
	full: boolean,
	impacted: boolean,
	closeAt: number?,
}

local RIFT = AnimConfig.RIFT
local CAMERA = AnimConfig.CAMERA
local QUALITY = AnimConfig.QUALITY
local AUTO_QUALITY = AnimConfig.AUTO_QUALITY
local LABEL_UPDATE_SECONDS = 0.2
local CINEMA = AnimConfig.CINEMA

local log = Logger.new("StarFxController")

local known: { [string]: ClientStar } = {}
local landed: { [Model]: LandedFx.Landed } = {}
local visuals: { [Model]: StarVisual.StarVisual } = {}
local labelClock = 0
local fpsFrames = 0
local fpsClock = 0
local tension: Sound? = nil
local tensionHolders: { [string]: boolean } = {}

local StarFxController = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function lowGraphics(): boolean
	local state = StateController.get()
	local settings = state and (state :: any).settings
	return typeof(settings) == "table" and settings.lowGraphics == true
end

local function fullRiftCount(): number
	local count = 0
	for _, star in known do
		if star.full and star.rift then
			count += 1
		end
	end
	return count
end

local function addStar(info: StarInfo)
	local existing = known[info.id]
	if existing then
		existing.info = info
		return
	end
	local star: ClientStar = {
		info = info,
		rift = nil,
		fall = nil,
		full = false,
		impacted = info.state ~= "Falling",
		closeAt = nil,
	}
	known[info.id] = star
	if info.state ~= "Falling" or now() >= info.impactAt then
		return
	end
	star.full = fullRiftCount() < AnimConfig.MAX_FULL_RIFTS
	local ok, err = pcall(function()
		star.rift = RiftFx.create(info, star.full)
		star.fall = FallFx.create(info, star.full)
	end)
	if not ok then
		log:error(`Efekty spadku {info.id}: {err}`)
	end
	SoundController.play2D("announceSting")
	if FxUtil.atLeast(info.size, CINEMA.fromSize) then
		-- Kino: pasy do chwili po wylocie, karta tytułowa, motyw napięcia do uderzenia.
		StarHud.holdBars(info.id, info.launchedAt + RIFT.emergeAt + CINEMA.barsAfterEmerge)
		StarHud.showTitle(info)
		tensionHolders[info.id] = true
		if not tension then
			tension = SoundController.playMusic("musicTension", CINEMA.musicFadeIn)
		end
	else
		StarHud.showBanner(info)
	end
	-- Rzut kamery na wyrwę tuż przed wylotem gwiazdy (Large+).
	if FxUtil.atLeast(info.size, CAMERA.fromSize) then
		local delay = math.max(0, info.launchedAt + RIFT.emergeAt - 0.3 - now())
		task.delay(delay, function()
			if known[info.id] == star and not star.impacted then
				CinematicController.lookAt(info.startPos)
			end
		end)
	end
end

local function removeStar(id: string)
	local star = known[id]
	if not star then
		return
	end
	if star.fall then
		star.fall.finish()
	end
	if star.rift then
		star.rift.close()
	end
	StarHud.hideBanner(id)
	if tensionHolders[id] then
		tensionHolders[id] = nil
		if next(tensionHolders) == nil and tension then
			SoundController.fadeOut(tension, CINEMA.musicFadeOut)
			tension = nil
		end
	end
	known[id] = nil
end

-- fresh = model przyszedł w trakcie gry (świeże lądowanie → animacja ImpactLanding), nie przy wejściu gracza.
local function onModel(model: Model, fresh: boolean)
	if landed[model] or model:GetAttribute("State") == "Dying" then
		return
	end
	StarHud.addLabel(model)
	-- T40: gwiazdy v2 „żyją” (StarVisual), działa obok LandedFx i trwa także w czasie rozpadu.
	if StarVisual.isV2(model) and not visuals[model] then
		local okVisual, visual = pcall(StarVisual.attach, model, fresh)
		if not okVisual then
			log:error(`StarVisual {model.Name}: {visual}`)
		elseif visual then
			visuals[model] = visual
			local visualState: RBXScriptConnection
			local visualAncestry: RBXScriptConnection
			visualState = model:GetAttributeChangedSignal("State"):Connect(function()
				if model:GetAttribute("State") == "Dying" then
					local reason = model:GetAttribute("EndReason")
					visual.dying(if typeof(reason) == "string" then reason else "Expired")
				end
			end)
			visualAncestry = model.AncestryChanged:Connect(function()
				if not model:IsDescendantOf(Workspace) then
					visual.destroy()
					visuals[model] = nil
					visualState:Disconnect()
					visualAncestry:Disconnect()
				end
			end)
		end
	end
	local ok, handle = pcall(LandedFx.attach, model)
	if not ok then
		log:error(`LandedFx {model.Name}: {handle}`)
		return
	end
	if not handle then
		return
	end
	landed[model] = handle
	local stateConnection: RBXScriptConnection
	local ancestryConnection: RBXScriptConnection
	local function stop()
		stateConnection:Disconnect()
		ancestryConnection:Disconnect()
		landed[model] = nil
	end
	stateConnection = model:GetAttributeChangedSignal("State"):Connect(function()
		if model:GetAttribute("State") == "Dying" then
			StarHud.removeLabel(model)
			local reason = model:GetAttribute("EndReason")
			handle.dying(if typeof(reason) == "string" then reason else "Expired")
			stop()
		end
	end)
	ancestryConnection = model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			StarHud.removeLabel(model)
			handle.destroy()
			stop()
		end
	end)
end

-- Ślady: blednięcie części od FadeAt przez FadeSeconds (serwer usuwa ślad i odtwarza teren).
local function scheduleScarFade(folder: Instance)
	local fadeAt = folder:GetAttribute("FadeAt")
	local fadeSeconds = folder:GetAttribute("FadeSeconds")
	if typeof(fadeAt) ~= "number" or typeof(fadeSeconds) ~= "number" then
		return
	end
	task.delay(math.max(0, fadeAt - now()), function()
		if not folder.Parent then
			return
		end
		local remaining = math.max(0.1, fadeAt + fadeSeconds - now())
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("BasePart") then
				FxUtil.tween(descendant, remaining, { Transparency = 1 }, Enum.EasingStyle.Linear)
			elseif descendant:IsA("ParticleEmitter") then
				descendant.Enabled = false
			end
		end
	end)
end

local function watchScar(folder: Instance)
	folder:GetAttributeChangedSignal("FadeAt"):Once(function()
		scheduleScarFade(folder)
	end)
	scheduleScarFade(folder)
end

local function updateQuality(dt: number)
	fpsFrames += 1
	fpsClock += dt
	if fpsClock < AUTO_QUALITY.sampleSeconds then
		return
	end
	local fps = fpsFrames / fpsClock
	fpsFrames, fpsClock = 0, 0
	local level = if lowGraphics() or fps < AUTO_QUALITY.lowFps
		then QUALITY.Low
		elseif fps < AUTO_QUALITY.mediumFps then QUALITY.Medium
		else QUALITY.High
	FxUtil.setQuality(level)
end

local function onRender(dt: number)
	local serverNow = now()
	updateQuality(dt)
	SkyFx.update(dt)

	local infos: { StarInfo } = {}
	for _, star in known do
		local info = star.info
		table.insert(infos, info)
		local rift = star.rift
		if rift then
			rift.update(serverNow, dt)
			if rift.closed() then
				star.rift = nil
			end
		end
		if star.fall then
			star.fall.update(serverNow, dt)
		end
		if not star.impacted and serverNow >= info.impactAt then
			star.impacted = true
			if star.fall then
				star.fall.finish()
				star.fall = nil
			end
			if tensionHolders[info.id] then
				tensionHolders[info.id] = nil
				SoundController.playMusic("musicImpact", 0)
				if next(tensionHolders) == nil and tension then
					SoundController.fadeOut(tension, CINEMA.musicFadeOut)
					tension = nil
				end
			end
			local ok, err = pcall(ImpactFx.play, info, star.full)
			if not ok then
				log:error(`ImpactFx {info.id}: {err}`)
			end
			star.closeAt = serverNow + RIFT.closeDelay
		end
		if star.closeAt and serverNow >= star.closeAt then
			star.closeAt = nil
			if star.rift then
				star.rift.close()
			end
		end
	end

	for _, handle in landed do
		handle.update(dt)
	end
	for _, visual in visuals do
		visual.update(dt)
	end
	StarHud.update(serverNow, infos)
	labelClock += dt
	if labelClock >= LABEL_UPDATE_SECONDS then
		labelClock = 0
		StarHud.updateLabels(serverNow)
	end
end

local function onStarEvent(kind: unknown, payload: unknown)
	if typeof(payload) ~= "table" then
		return
	end
	local data = payload :: any
	if kind == "Incoming" or kind == "Landed" then
		addStar(data :: StarInfo)
	elseif kind == "Gone" and typeof(data.id) == "string" then
		removeStar(data.id)
	end
end

function StarFxController.Init()
	FxUtil.folder()
	StarHud.build()
	Remotes.connect("StarEvent", onStarEvent)
end

function StarFxController.Start()
	RunService.RenderStepped:Connect(onRender)

	task.spawn(function()
		local activeStars = Workspace:WaitForChild("ActiveStars")
		activeStars.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				-- Model może przyjść bez części (streaming) — chwilę czekamy na Shell.
				if not child.PrimaryPart then
					child:WaitForChild("Shell", 5)
				end
				onModel(child, true)
			end
		end)
		for _, child in activeStars:GetChildren() do
			if child:IsA("Model") then
				task.spawn(onModel, child, false)
			end
		end
	end)
	task.spawn(function()
		local scars = Workspace:WaitForChild("StarScars")
		scars.ChildAdded:Connect(watchScar)
		for _, child in scars:GetChildren() do
			watchScar(child)
		end
	end)

	local list = Remotes.invoke("RequestStars")
	if typeof(list) == "table" then
		for _, info in list :: { StarInfo } do
			addStar(info)
		end
		log:debug(`Aktywne gwiazdy przy wejściu: {#(list :: { any })}`)
	end
end

return StarFxController
