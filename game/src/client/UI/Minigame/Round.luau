--!strict
-- Round — tarcza minigry na powierzchni gwiazdy (BillboardGui na Attachmentach w Terrain).
-- Punkty z Shared/CrackRound (ten sam seed co serwer) pojawiają się kolejno w stożku zwróconym do kamery;
-- pierścień kurczy się do kółka, chwila zamknięcia = Perfect. Wejście:
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
local CrackRound = require(Shared.CrackRound)

type Grade = CrackRound.Grade
type Target = CrackRound.Target

export type Handle = {
	-- Czeka do końca rundy i zwraca czasy trafień (s od startu, -1 = brak).
	wait: (self: Handle) -> { number },
	cancel: (self: Handle) -> (),
	onGrade: ((target: Target, grade: Grade, position: Vector3) -> ())?,
}

type Live = {
	target: Target,
	attachment: Attachment,
	gui: BillboardGui,
	ring: Frame,
	resolved: boolean,
	position: Vector3,
}

local MINIGAME = CrackRound.MINIGAME
local ACTION_NAME = "CrackHit"
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 10
local TAP_MAX_SECONDS = 0.25
local TAP_MAX_MOVE = 12 -- px; dłuższe/dalsze dotknięcie = obrót kamery, nie Miss
local RING_START = 2.3 -- średnica pierścienia na starcie (× kółko)
local SURFACE = 0.92 -- punkty lekko pod powierzchnią bryły (gwiazdy nie są idealnymi kulami)
local MIN_SPREAD = 7 -- studs; przy małych gwiazdach punkty „orbitują” dalej, żeby kółka się nie nakładały

local COLORS = {
	ring = Color3.fromRGB(255, 255, 255),
	core = Color3.fromRGB(120, 220, 255),
	weak = Color3.fromRGB(255, 205, 60),
	Perfect = Color3.fromRGB(255, 220, 80),
	Good = Color3.fromRGB(110, 235, 130),
	Miss = Color3.fromRGB(200, 200, 210),
}
local FONT = Enum.Font.FredokaOne

local player = Players.LocalPlayer

local Round = {}

local function circle(name: string, color: Color3, transparency: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	return frame
end

local function stroke(parent: GuiObject, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

-- Krótki napis nad punktem (PERFECT! / GOOD / MISS) — znika sam.
local function popLabel(gui: BillboardGui, grade: Grade)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1.6, 0.45)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.Text = if grade == "Perfect" then "PERFECT!" elseif grade == "Good" then "GOOD" else "MISS"
	label.TextColor3 = COLORS[grade]
	stroke(label, Color3.new(0, 0, 0), 2)
	label.Parent = gui
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { Position = UDim2.fromScale(0.5, 0.1), TextTransparency = 1 }):Play()
end

-- Punkt na powierzchni gwiazdy: stożek wokół kierunku środek → kamera (yaw wokół pionu, pitch w górę).
local function surfacePoint(center: Vector3, radius: number, toCamera: Vector3, target: Target): Vector3
	local flat = Vector3.new(toCamera.X, 0, toCamera.Z)
	local forward = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local yawed = CFrame.Angles(0, target.yaw, 0):VectorToWorldSpace(forward)
	local dir = yawed * math.cos(target.pitch) + Vector3.yAxis * math.sin(target.pitch)
	return center + dir.Unit * math.max(radius * SURFACE, MIN_SPREAD)
end

-- Startuje rundę. `star` = model leżącej gwiazdy, `radius` = promień w studs.
function Round.play(round: CrackRound.Round, star: Model, radius: number, autoCrack: boolean): Handle
	local tool = CrackRound.getTool(round.toolId) :: CrackRound.ToolDef
	local camera = Workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local corePx = math.floor(tool.targetSize * math.min(viewport.X, viewport.Y))
	local guiPx = math.floor(corePx * RING_START)
	local playerGui = player:WaitForChild("PlayerGui")
	local center = star:GetPivot().Position
	local toCamera = camera.CFrame.Position - center

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
		entry.ring.Visible = false
		local core = entry.gui:FindFirstChild("Core") :: Frame?
		if core then
			core.BackgroundColor3 = COLORS[grade]
			local info = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			TweenService:Create(core, info, { Size = UDim2.fromScale(0.6, 0.6), BackgroundTransparency = 1 }):Play()
		end
		popLabel(entry.gui, grade)
		task.delay(0.5, function()
			entry.gui:Destroy()
			entry.attachment:Destroy()
		end)
		if handle.onGrade then
			task.spawn(handle.onGrade, entry.target, grade, entry.position)
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
		task.delay(0.6, function()
			folder:Destroy()
		end)
		if waiting then
			task.spawn(waiting)
		end
	end

	local function spawnTarget(target: Target)
		local position = surfacePoint(center, radius, toCamera, target)
		local attachment = Instance.new("Attachment")
		attachment.Name = "CrackTarget"
		attachment.WorldPosition = position
		attachment.Parent = Workspace.Terrain

		local gui = Instance.new("BillboardGui")
		gui.Name = `Target{target.index}`
		gui.Adornee = attachment
		gui.AlwaysOnTop = true
		gui.Active = true
		gui.LightInfluence = 0
		gui.Size = UDim2.fromOffset(guiPx, guiPx)
		gui.ResetOnSpawn = false

		local scale = corePx / guiPx
		local color = if target.weak then COLORS.weak else COLORS.core
		local core = circle("Core", color, 0.15)
		core.Size = UDim2.fromScale(scale, scale)
		stroke(core, Color3.new(1, 1, 1), if target.weak then 4 else 2)
		core.Parent = gui
		if target.weak then
			local icon = Instance.new("TextLabel")
			icon.Size = UDim2.fromScale(1, 1)
			icon.BackgroundTransparency = 1
			icon.Font = FONT
			icon.TextScaled = true
			icon.Text = "★"
			icon.TextColor3 = Color3.new(1, 1, 1)
			icon.Parent = core
		end

		local ring = circle("Ring", COLORS.ring, 1)
		ring.Size = UDim2.fromScale(1, 1)
		stroke(ring, if target.weak then COLORS.weak else COLORS.ring, 3)
		ring.Parent = gui

		-- Strefa kliknięcia trochę większa niż kółko (palce na telefonie).
		local button = Instance.new("TextButton")
		button.Name = "Hit"
		button.AnchorPoint = Vector2.new(0.5, 0.5)
		button.Position = UDim2.fromScale(0.5, 0.5)
		button.Size = UDim2.fromScale(math.min(scale * 1.35, 1), math.min(scale * 1.35, 1))
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Parent = gui
		gui.Parent = folder

		local entry: Live = {
			target = target,
			attachment = attachment,
			gui = gui,
			ring = ring,
			resolved = false,
			position = position,
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
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function()
			if finished then
				return
			end
			local t = os.clock() - startedAt
			while nextIndex <= #round.targets and t >= round.targets[nextIndex].spawnAt do
				spawnTarget(round.targets[nextIndex])
				nextIndex += 1
			end
			local open = nextIndex <= #round.targets
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
					-- Pierścień: od RING_START do kółka w chwili closeAt, potem dalej do środka (spóźnienie).
					local phase = (t - target.spawnAt) / tool.shrinkTime
					local scale = (corePx / guiPx) * (1 + (RING_START - 1) * (1 - phase))
					entry.ring.Size = UDim2.fromScale(math.max(scale, 0.05), math.max(scale, 0.05))
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
