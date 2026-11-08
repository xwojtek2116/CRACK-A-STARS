--!strict
-- StarBar — jeden cienki pasek gwiazdy u góry ekranu (zastępuje licznik i duże banery „INCOMING”):
--   cisza:   ✦ NEXT STAR ............ 02:14   (magenta, z Workspace.NextStarAt)
--   spadek:  ✦ LARGE LAVA STAR ... IMPACT 0:04 (kolor rodzaju gwiazdy, z Store.incoming)
--   po uderzeniu: „LANDED!” przez kilka sekund; przy kilku gwiazdach plakietka „+N”.
-- Pod tekstem cienka linia postępu z „kometą” na końcu. Nowa gwiazda = wjazd z góry z glitchem
-- (przesunięte kopie tekstu cyjan/magenta, migotanie, błysk w kolorze gwiazdy).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local UI = script.Parent.Parent
local Format = require(UI.Format)
local Motion = require(UI.Motion)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local Label = require(script.Parent.Label)
local SpaceFx = require(script.Parent.SpaceFx)

local e = React.createElement

type Ref<T> = { current: T? }

local WIDTH = 440
local HEIGHT = 50
local GLITCH_SECONDS = 0.55
local TICK = 0.1

local function StarBar(props: { frameRef: Ref<Frame>? })
	local nextStarAt = Store.use(function(state)
		return state.nextStarAt
	end)
	local incoming = Store.use(function(state)
		return state.incoming
	end)
	local now, setNow = React.useState(Workspace:GetServerTimeNow())
	local slideRef = React.useRef(nil :: Frame?)
	local flashRef = React.useRef(nil :: Frame?)
	local ghostARef = React.useRef(nil :: TextLabel?)
	local ghostBRef = React.useRef(nil :: TextLabel?)
	local titleRef = React.useRef(nil :: TextLabel?)

	local current = incoming[1]
	local key = if current then current.id else "idle"

	React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				setNow(Workspace:GetServerTimeNow())
				task.wait(TICK)
			end
		end)
		return function()
			running = false
		end
	end, {})

	-- Wjazd + glitch przy każdej nowej gwieździe (i przy powrocie do ciszy — bez glitcha).
	React.useEffect(function()
		local slide = slideRef.current
		if not slide then
			return nil
		end
		slide.Position = UDim2.fromOffset(0, -HEIGHT - 20)
		Motion.tween(slide, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(0, 0),
		})
		if not current then
			return nil
		end
		local flash = flashRef.current
		if flash then
			flash.BackgroundTransparency = 0.2
			Motion.tween(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			})
		end
		local rng = Random.new()
		local started = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function()
			local t = os.clock() - started
			local a, b, title = ghostARef.current, ghostBRef.current, titleRef.current
			if t > GLITCH_SECONDS then
				connection:Disconnect()
				if a and b and title then
					a.Visible, b.Visible = false, false
					title.TextTransparency = 0
					title.Position = UDim2.new()
				end
				return
			end
			if a and b and title then
				local amp = 6 * (1 - t / GLITCH_SECONDS)
				a.Visible, b.Visible = true, true
				a.Position = UDim2.fromOffset(rng:NextNumber(-amp, amp), rng:NextNumber(-2, 2))
				b.Position = UDim2.fromOffset(rng:NextNumber(-amp, amp), rng:NextNumber(-2, 2))
				title.TextTransparency = if rng:NextNumber() < 0.3 then 0.6 else 0
				title.Position = UDim2.fromOffset(rng:NextInteger(-2, 2), 0)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { key })

	local color = if current then current.color else Theme.COLORS.neonMagenta
	local glow = if current then current.glow else Theme.COLORS.starYellow
	local title, caption, timeText, fraction
	if current then
		local left = current.impactAt - now
		local total = math.max(current.impactAt - current.launchedAt, 0.01)
		fraction = math.clamp(1 - left / total, 0, 1)
		title = string.upper(current.name)
		if left > 0 then
			caption, timeText = "IMPACT", Format.duration(left + 0.99)
		else
			caption, timeText = "", "LANDED!"
		end
	else
		title = "NEXT STAR"
		caption = ""
		if nextStarAt then
			local left = nextStarAt - now
			timeText = if left > 0 then Format.duration(left + 0.99) else "SOON"
			fraction = 0
		else
			timeText = "--:--"
			fraction = 0
		end
	end
	local extra = #incoming - 1

	return e("Frame", {
		ref = props.frameRef,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 1,
		Visible = current ~= nil or nextStarAt ~= nil,
	}, {
		Slide = e("Frame", {
			ref = slideRef,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Shadow = e("Frame", {
				Position = UDim2.fromOffset(0, 4),
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.COLORS.ink,
				BackgroundTransparency = 0.2,
				ZIndex = 1,
			}, { Corner = e("UICorner", { CornerRadius = Theme.PILL }) }),
			Body = e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.05,
				ClipsDescendants = true,
				ZIndex = 2,
			}, {
				Corner = e("UICorner", { CornerRadius = Theme.PILL }),
				Gradient = e("UIGradient", { Color = Theme.SPACE_GRADIENT, Rotation = 90 }),
				Neon = e(SpaceFx.NeonBorder, {
					thickness = 2.5,
					speed = if current then 1.6 else 5,
					colors = ColorSequence.new({
						ColorSequenceKeypoint.new(0, color),
						ColorSequenceKeypoint.new(0.5, Theme.lighten(glow, 0.3)),
						ColorSequenceKeypoint.new(1, color),
					}),
				}),
				Nebula = e(SpaceFx.Nebula, { color = color, transparency = 0.75, speed = 25 }),
				-- Błysk w kolorze gwiazdy przy wjeździe.
				Flash = e("Frame", {
					ref = flashRef,
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Theme.lighten(color, 0.4),
					BackgroundTransparency = 1,
					ZIndex = 9,
				}, { Corner = e("UICorner", { CornerRadius = Theme.PILL }) }),
				Content = e("Frame", {
					Size = UDim2.new(1, -24, 1, -10),
					Position = UDim2.fromOffset(6, 0),
					BackgroundTransparency = 1,
					ZIndex = 5,
				}, {
					Flare = e(SpaceFx.Flare, {
						color = color,
						size = 70,
						position = UDim2.new(0, 22, 0.5, 2),
						transparency = 0.35,
					}),
					Star = e("ImageLabel", {
						Image = Theme.ICONS.star,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0, 22, 0.5, 2),
						Size = UDim2.fromOffset(34, 34),
						BackgroundTransparency = 1,
						ZIndex = 2,
					}),
					TitleHolder = e("Frame", {
						Position = UDim2.fromOffset(46, 0),
						Size = UDim2.new(1, -170, 1, 0),
						BackgroundTransparency = 1,
						ZIndex = 3,
					}, {
						GhostA = e("TextLabel", {
							ref = ghostARef,
							Text = title,
							FontFace = Theme.FONTS.display,
							TextSize = 22,
							TextColor3 = Theme.COLORS.neonCyan,
							TextTransparency = 0.35,
							TextXAlignment = Enum.TextXAlignment.Left,
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),
							Visible = false,
						}),
						GhostB = e("TextLabel", {
							ref = ghostBRef,
							Text = title,
							FontFace = Theme.FONTS.display,
							TextSize = 22,
							TextColor3 = Theme.COLORS.neonMagenta,
							TextTransparency = 0.35,
							TextXAlignment = Enum.TextXAlignment.Left,
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),
							Visible = false,
						}),
						Title = e(Label, {
							labelRef = titleRef,
							text = title,
							textSize = 22,
							color = if current then Theme.lighten(color, 0.35) else Theme.COLORS.text,
							xAlignment = Enum.TextXAlignment.Left,
							size = UDim2.fromScale(1, 1),
							stroke = 3,
						}),
					}),
					Right = e("Frame", {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.new(0, 120, 1, 0),
						BackgroundTransparency = 1,
						ZIndex = 3,
					}, {
						List = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Right,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0, 6),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						Caption = if caption ~= ""
							then e(Label, {
								text = caption,
								textSize = Theme.TEXT_SIZE.tiny,
								font = Theme.FONTS.body,
								color = Theme.COLORS.textMuted,
								stroke = 2,
								layoutOrder = 1,
							})
							else nil,
						Time = e(Label, {
							text = timeText,
							textSize = 24,
							stroke = 3,
							color = if current and caption == "" then Theme.COLORS.starYellow else Theme.COLORS.text,
							layoutOrder = 2,
						}),
					}),
				}),
				-- Linia postępu z „kometą” (błysk) na końcu.
				Track = e("Frame", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -6),
					Size = UDim2.new(1, -44, 0, 3),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0.85,
					ZIndex = 6,
					Visible = current ~= nil,
				}, {
					Corner = e("UICorner", { CornerRadius = Theme.PILL }),
					Fill = e("Frame", {
						Size = UDim2.fromScale(fraction, 1),
						BackgroundColor3 = Color3.new(1, 1, 1),
					}, {
						Corner = e("UICorner", { CornerRadius = Theme.PILL }),
						Gradient = e("UIGradient", { Color = ColorSequence.new(color, Theme.lighten(glow, 0.5)) }),
						Comet = e("ImageLabel", {
							Image = Theme.FX.glint,
							ImageColor3 = Theme.lighten(glow, 0.6),
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(1, 0.5),
							Size = UDim2.fromOffset(18, 18),
							BackgroundTransparency = 1,
						}),
					}),
				}),
			}),
			Extra = if extra > 0
				then e(Label, {
					text = `+{extra}`,
					textSize = Theme.TEXT_SIZE.small,
					color = Theme.COLORS.starYellow,
					anchorPoint = Vector2.new(0.5, 0.5),
					position = UDim2.new(1, 2, 0, 4),
					rotation = 8,
					zIndex = 10,
				})
				else nil,
		}),
	})
end

return StarBar
