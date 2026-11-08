--!strict
-- Round — tarcza minigry na powierzchni gwiazdy (BillboardGui na Attachmentach w Terrain), T06 v2.
-- Punkty z Shared/CrackRound (ten sam seed co serwer) pojawiają się kolejno w stożku zwróconym do kamery,
-- na prawdziwej powierzchni modelu (CrackFx.surface). Każdy punkt:
--   kryształ (TARGET_CORE) z pulsującą poświatą, złoty pas Perfect, pierścień zbliżania (TARGET_RING)
--   z obracającym się gradientem — biały → złoty w oknie Perfect → czerwony po czasie;
--   z punktu wycieka snop światła (CrackFx.leak), mocniejszy, gdy pierścień się zamyka.
-- Wejście:
--   mysz/dotyk — klik/tap w kółko; szybki tap obok (nie przeciąganie kamery) = Miss najstarszego punktu,
--   pad — ButtonR2/ButtonX trafia najstarszy aktywny punkt (sam timing).
-- Auto Crack: punkt nietrafiony do połowy pasma Good trafia się sam (serwer i tak liczy co najmniej Good).
-- Klient tylko pokazuje i mierzy czasy — ocenę i obrażenia liczy serwer.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AnimConfig = require(Shared.Config.AnimConfig)
local CrackRound = require(Shared.CrackRound)
local VfxIds = require(Shared.Config.VfxIds)

local Client = script.Parent.Parent.Parent
local SoundController = require(Client.Controllers.SoundController)
local CrackFx = require(Client.Fx.CrackFx)
local FxUtil = require(Client.Fx.FxUtil)

type Grade = CrackRound.Grade
type Target = CrackRound.Target

export type Handle = {
	-- Czeka do końca rundy i zwraca czasy trafień (s od startu, -1 = brak).
	wait: (self: Handle) -> { number },
	cancel: (self: Handle) -> (),
	onGrade: ((target: Target, grade: Grade, position: Vector3, normal: Vector3) -> ())?,
}

type Live = {
	target: Target,
	attachment: Attachment,
	gui: BillboardGui,
	ring: ImageLabel,
	ringGradient: UIGradient,
	band: UIStroke,
	glow: ImageLabel,
	leak: CrackFx.Leak,
	resolved: boolean,
	position: Vector3,
	normal: Vector3,
}

local MINIGAME = CrackRound.MINIGAME
local CRACK = AnimConfig.CRACK
local ACTION_NAME = "CrackHit"
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 10
local TAP_MAX_SECONDS = 0.25
local TAP_MAX_MOVE = 12 -- px; dłuższe/dalsze dotknięcie = obrót kamery, nie Miss
local MIN_SPREAD = 7 -- studs; przy małych gwiazdach punkty „orbitują” dalej, żeby kółka się nie nakładały
local GUI_MARGIN = 1.25 -- Billboard większy od pierścienia (miejsce na fale i napisy)

local COLORS = {
	ring = Color3.fromRGB(255, 255, 255),
	weak = Color3.fromRGB(255, 205, 60),
	band = Color3.fromRGB(255, 215, 90),
	late = Color3.fromRGB(255, 90, 80),
	Perfect = Color3.fromRGB(255, 220, 80),
	Good = Color3.fromRGB(110, 235, 130),
	Miss = Color3.fromRGB(170, 170, 185),
}
local LABELS = { Perfect = "PERFECT!", Good = "GOOD", Miss = "MISS" }
local FONT = Enum.Font.FredokaOne

local player = Players.LocalPlayer

local Round = {}

local function image(name: string, id: string, color: Color3, scale: number): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(scale, scale)
	label.BackgroundTransparency = 1
	label.Image = id
	label.ImageColor3 = color
	return label
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService
		:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
		:Play()
end

-- Napis oceny nad punktem: wyskakuje (Back), unosi się i znika. Perfect ze złotym gradientem.
local function popLabel(gui: BillboardGui, grade: Grade, weak: boolean)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.8, 0.22)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.Text = if weak and grade ~= "Miss" then "WEAK SPOT!" else LABELS[grade]
	label.TextColor3 = if grade == "Perfect" then Color3.new(1, 1, 1) else COLORS[grade]
	label.Rotation = Random.new():NextNumber(-8, 8)
	local outline = Instance.new("UIStroke")
	outline.Thickness = 2.5
	outline.Color = Color3.fromRGB(30, 15, 45)
	outline.Parent = label
	if grade == "Perfect" or weak then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 205, 60)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 40)),
		})
		gradient.Rotation = 90
		gradient.Parent = label
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = label
	label.Parent = gui
	tween(scale, 0.25, { Scale = if grade == "Perfect" then 1.15 else 1 }, Enum.EasingStyle.Back)
	task.delay(0.25, function()
		tween(label, 0.4, { Position = UDim2.fromScale(0.5, 0.05), TextTransparency = 1 })
		tween(outline, 0.4, { Transparency = 1 })
	end)
end

-- Fala po trafieniu (pierścień uderzeniowy w kolorze oceny).
local function shockwave(gui: BillboardGui, color: Color3, from: number)
	local wave = image("Wave", VfxIds.SHOCK_RING, color, from)
	wave.ImageTransparency = 0.1
	wave.Parent = gui
	tween(wave, 0.35, { Size = UDim2.fromScale(from * 2.4, from * 2.4), ImageTransparency = 1 })
end

-- Kierunek punktu: stożek wokół kierunku środek → kamera (yaw wokół pionu, pitch w górę).
local function targetDirection(toCamera: Vector3, target: Target): Vector3
	local flat = Vector3.new(toCamera.X, 0, toCamera.Z)
	local forward = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local yawed = CFrame.Angles(0, target.yaw, 0):VectorToWorldSpace(forward)
	return (yawed * math.cos(target.pitch) + Vector3.yAxis * math.sin(target.pitch)).Unit
end

-- Startuje rundę. `star` = model leżącej gwiazdy, `radius` = promień w studs, `glow` = kolor rodzaju gwiazdy.
function Round.play(round: CrackRound.Round, star: Model, radius: number, glow: Color3, autoCrack: boolean): Handle
	local tool = CrackRound.getTool(round.toolId) :: CrackRound.ToolDef
	local camera = Workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local corePx = math.floor(tool.targetSize * math.min(viewport.X, viewport.Y))
	local guiPx = math.floor(corePx * CRACK.ringStart * GUI_MARGIN)
	local coreScale = corePx / guiPx
	local ringMax = coreScale * CRACK.ringStart
	local playerGui = player:WaitForChild("PlayerGui")
	local center = star:GetPivot().Position
	local toCamera = camera.CFrame.Position - center
	local coreColor = FxUtil.lighten(glow, 0.3)
	-- Pas Perfect: pierścień ma średnicę core·(1 + (start-1)·(1-faza)); okno ±perfect.window/2 wokół fazy 1.
	local bandHalf = (CRACK.ringStart - 1) * MINIGAME.perfect.window / 2
	local bandPx = math.clamp(corePx * bandHalf * 0.5, 2, 5)

	local times: { number } = table.create(#round.targets, -1)
	local live: { Live } = {}
	local connections: { RBXScriptConnection } = {}
	local finished = false
	local startedAt = os.clock()
	local waiting: thread? = nil
	local handle: Handle

	local folder = Instance.new("Folder")
	folder.Name = "CrackRound"
	folder.Parent = playerGui

	local function resolve(entry: Live, t: number?)
		if entry.resolved then
			return
		end
		entry.resolved = true
		local grade = CrackRound.grade(round, entry.target, t)
		if t then
			times[entry.target.index] = t
		end
		if autoCrack and CrackRound.rank(grade) < CrackRound.rank("Good") then
			grade = "Good"
		end
		entry.leak:destroy()
		entry.ring.Visible = false
		entry.band.Enabled = false
		local core = entry.gui:FindFirstChild("Core") :: ImageLabel?
		if core then
			if grade == "Miss" then
				-- Pudło: kryształ szarzeje, drży i gaśnie.
				core.ImageColor3 = COLORS.Miss
				for i = 1, 4 do
					task.delay(i * 0.03, function()
						core.Position = UDim2.fromScale(0.5 + (if i % 2 == 0 then 0.03 else -0.03), 0.5)
					end)
				end
				tween(core, 0.35, { ImageTransparency = 1, Size = UDim2.fromScale(coreScale * 0.7, coreScale * 0.7) })
			else
				core.ImageColor3 = Color3.new(1, 1, 1)
				tween(core, 0.12, { Size = UDim2.fromScale(coreScale * 1.4, coreScale * 1.4) }, Enum.EasingStyle.Back)
				task.delay(0.12, function()
					tween(
						core,
						0.25,
						{ ImageTransparency = 1, Size = UDim2.fromScale(coreScale * 0.4, coreScale * 0.4) }
					)
				end)
				shockwave(entry.gui, COLORS[grade], coreScale)
				if grade == "Perfect" then
					task.delay(0.06, shockwave, entry.gui, Color3.new(1, 1, 1), coreScale * 0.7)
				end
			end
		end
		tween(entry.glow, 0.3, { ImageTransparency = 1 })
		popLabel(entry.gui, grade, entry.target.weak)
		task.delay(0.8, function()
			entry.gui:Destroy()
			entry.attachment:Destroy()
		end)
		if handle.onGrade then
			task.spawn(handle.onGrade, entry.target, grade, entry.position, entry.normal)
		end
	end

	-- Najstarszy punkt, który już się pojawił i nie jest rozstrzygnięty (pad, tap obok).
	local function oldest(): Live?
		for _, entry in live do
			if not entry.resolved then
				return entry
			end
		end
		return nil
	end

	local function finish()
		if finished then
			return
		end
		finished = true
		for _, connection in connections do
			connection:Disconnect()
		end
		ContextActionService:UnbindAction(ACTION_NAME)
		for _, entry in live do
			if not entry.resolved then
				entry.leak:destroy()
			end
		end
		task.delay(0.9, function()
			folder:Destroy()
		end)
		if waiting then
			task.spawn(waiting)
		end
	end

	local function spawnTarget(target: Target)
		local dir = targetDirection(toCamera, target)
		local position, normal = CrackFx.surface(star, center, dir, radius)
		if radius < MIN_SPREAD then
			position = center + dir * MIN_SPREAD
			normal = dir
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "CrackTarget"
		attachment.WorldPosition = position + normal * 0.3
		attachment.Parent = Workspace.Terrain

		local gui = Instance.new("BillboardGui")
		gui.Name = `Target{target.index}`
		gui.Adornee = attachment
		gui.AlwaysOnTop = true
		gui.Active = true
		gui.LightInfluence = 0
		gui.Size = UDim2.fromOffset(guiPx, guiPx)
		gui.ResetOnSpawn = false

		local tint = if target.weak then COLORS.weak else coreColor
		local glowImage = image("Glow", VfxIds.FLARE, tint, coreScale * 2.2)
		glowImage.ImageTransparency = 0.88
		glowImage.Parent = gui

		local core = image("Core", VfxIds.TARGET_CORE, tint, coreScale)
		core.ZIndex = 2
		core.Parent = gui
		if target.weak then
			local icon = image("Star", VfxIds.GLINT, Color3.new(1, 1, 1), 1.3)
			icon.ZIndex = 3
			icon.Parent = core
			local spin = TweenService:Create(
				icon,
				TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
				{ Rotation = 360 }
			)
			spin:Play()
		end

		-- Złoty pas Perfect wokół kryształu (gdzie ma być pierścień w idealnej chwili).
		local bandFrame = Instance.new("Frame")
		bandFrame.Name = "Band"
		bandFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		bandFrame.Position = UDim2.fromScale(0.5, 0.5)
		bandFrame.Size = UDim2.fromOffset(corePx, corePx)
		bandFrame.BackgroundTransparency = 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = bandFrame
		local band = Instance.new("UIStroke")
		band.Color = COLORS.band
		band.Thickness = bandPx
		band.Transparency = 0.6
		band.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		band.Parent = bandFrame
		bandFrame.Parent = gui

		local ring = image("Ring", VfxIds.TARGET_RING, COLORS.ring, ringMax)
		ring.ZIndex = 4
		local ringGradient = Instance.new("UIGradient")
		ringGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(1, 0),
		})
		ringGradient.Parent = ring
		ring.Parent = gui

		-- Strefa kliknięcia trochę większa niż kółko (palce na telefonie).
		local button = Instance.new("TextButton")
		button.Name = "Hit"
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.fromScale(0.5, 0.5)
		local hitScale = math.min(coreScale * 1.35, 1)
		button.Size = UDim2.fromScale(hitScale, hitScale)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.ZIndex = 5
		button.Parent = gui

		-- Pojawienie: skok skali (Back) całego punktu.
		local pop = Instance.new("UIScale")
		pop.Scale = 0
		pop.Parent = core
		tween(pop, CRACK.popSeconds, { Scale = 1 }, Enum.EasingStyle.Back)
		gui.Parent = folder

		local entry: Live = {
			target = target,
			attachment = attachment,
			gui = gui,
			ring = ring,
			ringGradient = ringGradient,
			band = band,
			glow = glowImage,
			leak = CrackFx.leak(position, normal, radius, tint),
			resolved = false,
			position = position,
			normal = normal,
		}
		table.insert(live, entry)
		table.insert(
			connections,
			button.Activated:Connect(function()
				if not finished then
					resolve(entry, os.clock() - startedAt)
				end
			end)
		)
		gui:SetAttribute("Weak", target.weak)
		SoundController.play2D("crackSpawn", nil, if target.weak then 1.25 else nil)
	end

	-- Pad: jeden przycisk = trafienie najstarszego punktu. Sink, żeby Tool.Activated nie startował rundy.
	ContextActionService:BindActionAtPriority(ACTION_NAME, function(_, state)
		if state == Enum.UserInputState.Begin and not finished then
			local entry = oldest()
			if entry then
				resolve(entry, os.clock() - startedAt)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, ACTION_PRIORITY, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonX)

	-- Tap obok kółka: krótki, bez przesunięcia → Miss najstarszego punktu.
	local pressStart: { [InputObject]: { at: number, pos: Vector3 } } = {}
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			local kind = input.UserInputType
			if processed or (kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch) then
				return
			end
			pressStart[input] = { at = os.clock(), pos = input.Position }
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			local press = pressStart[input]
			pressStart[input] = nil
			if not press or finished then
				return
			end
			local moved = (input.Position - press.pos).Magnitude
			if os.clock() - press.at <= TAP_MAX_SECONDS and moved <= TAP_MAX_MOVE then
				local entry = oldest()
				if entry and os.clock() - startedAt >= entry.target.spawnAt then
					resolve(entry, nil)
				end
			end
		end)
	)

	local nextIndex = 1
	local autoOffset = tool.shrinkTime * (MINIGAME.perfect.window + MINIGAME.good.window) / 4
	local perfectHalf = MINIGAME.perfect.window / 2
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt)
			if finished then
				return
			end
			local t = os.clock() - startedAt
			while nextIndex <= #round.targets and t >= round.targets[nextIndex].spawnAt do
				spawnTarget(round.targets[nextIndex])
				nextIndex += 1
			end
			local open = nextIndex <= #round.targets
			local pulse = 0.5 + 0.5 * math.sin(t * CRACK.glowPulse * 2 * math.pi)
			for _, entry in live do
				if entry.resolved then
					continue
				end
				local target = entry.target
				if autoCrack and t >= target.closeAt + autoOffset then
					resolve(entry, t)
				elseif t > target.endAt then
					resolve(entry, nil)
				else
					open = true
					-- Pierścień: od ringStart do kółka w chwili closeAt, potem dalej do środka (spóźnienie).
					local phase = (t - target.spawnAt) / tool.shrinkTime
					local scale = math.max(coreScale * (1 + (CRACK.ringStart - 1) * (1 - phase)), 0.03)
					entry.ring.Size = UDim2.fromScale(scale, scale)
					entry.ringGradient.Rotation = (entry.ringGradient.Rotation + CRACK.ringSpin * dt) % 360
					local err = math.abs(phase - 1)
					if err <= perfectHalf then
						entry.ring.ImageColor3 = COLORS.Perfect
						entry.band.Transparency = 0.15
					elseif phase > 1 then
						entry.ring.ImageColor3 = COLORS.late
						entry.band.Transparency = 0.6
					else
						-- Biały → złoty, gdy pierścień dochodzi do pasa.
						entry.ring.ImageColor3 = COLORS.ring:Lerp(COLORS.Perfect, math.clamp(phase, 0, 1) ^ 3)
						entry.band.Transparency = 0.6 - 0.3 * math.clamp(phase, 0, 1) ^ 2
					end
					entry.glow.ImageTransparency = 0.88 - 0.12 * pulse - 0.1 * math.clamp(phase, 0, 1)
					entry.leak:set(phase)
				end
			end
			if not open then
				finish()
			end
		end)
	)

	handle = {
		wait = function(_self: Handle): { number }
			if not finished then
				waiting = coroutine.running()
				coroutine.yield()
			end
			return times
		end,
		cancel = function(_self: Handle)
			finish()
		end,
		onGrade = nil,
	}
	return handle
end

return Round
