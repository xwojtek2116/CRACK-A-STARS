--!strict
-- RibbonHeader — nagłówek okna: duża ikona 3D po lewej (lekko się kołysze), wstążka w kolorze sklepu
-- z tytułem i ściętym prawym końcem. Wystaje ponad lewy górny róg okna.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Motion = require(script.Parent.Parent.Motion)
local Theme = require(script.Parent.Parent.Theme)
local Label = require(script.Parent.Label)

local e = React.createElement

export type Props = {
	title: string,
	icon: string,
	color: Color3,
}

local ICON = 96
local RIBBON_HEIGHT = 58

local function RibbonHeader(props: Props)
	local iconRef = React.useRef(nil :: ImageLabel?)
	Motion.useLoop(iconRef :: any, Theme.IDLE.wiggleTime * 1.4, { Rotation = 6 }, {})

	return e("Frame", {
		Position = UDim2.fromOffset(-30, -44),
		Size = UDim2.fromOffset(0, ICON),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		ZIndex = 10,
	}, {
		Ribbon = e("Frame", {
			Position = UDim2.fromOffset(ICON - 30, (ICON - RIBBON_HEIGHT) / 2),
			Size = UDim2.fromOffset(0, RIBBON_HEIGHT),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 1,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 16) }),
			Gradient = e("UIGradient", { Color = Theme.duo(props.color), Rotation = 90 }),
			Stroke = e("UIStroke", {
				Color = Theme.COLORS.ink,
				Thickness = 4,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 40), PaddingRight = UDim.new(0, 30) }),
			Title = e(Label, {
				text = props.title,
				textSize = Theme.TEXT_SIZE.big,
				stroke = 4,
				size = UDim2.fromScale(0, 1),
				automaticSize = Enum.AutomaticSize.X,
				position = UDim2.fromOffset(0, 2),
			}),
		}),
		Shadow = e("ImageLabel", {
			Image = props.icon,
			ImageColor3 = Color3.new(0, 0, 0),
			ImageTransparency = 0.5,
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.fromOffset(ICON, ICON),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}),
		Icon = e("ImageLabel", {
			ref = iconRef,
			Image = props.icon,
			Rotation = -6,
			Size = UDim2.fromOffset(ICON, ICON),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}),
	})
end

return RibbonHeader
