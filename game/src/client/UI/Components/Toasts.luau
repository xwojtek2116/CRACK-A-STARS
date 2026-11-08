--!strict
-- Toasts — krótkie komunikaty u dołu ekranu (pop z overshootem). Lista z Store.toasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Motion = require(script.Parent.Parent.Motion)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.Theme)
local Label = require(script.Parent.Label)

local e = React.createElement

local KIND_COLORS = {
	info = Theme.COLORS.neonCyan,
	success = Theme.COLORS.cash,
	error = Theme.COLORS.danger,
}

local function Toast(props: { toast: Store.Toast, order: number })
	local scaleRef = Motion.useEnter(0.5)
	return e("Frame", {
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.COLORS.space,
		LayoutOrder = props.order,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		Corner = e("UICorner", { CornerRadius = Theme.PILL }),
		Stroke = e("UIStroke", {
			Color = KIND_COLORS[props.toast.kind] or Theme.COLORS.neonCyan,
			Thickness = 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20) }),
		Text = e(Label, {
			text = props.toast.text,
			textSize = Theme.TEXT_SIZE.body,
			size = UDim2.fromScale(0, 1),
			automaticSize = Enum.AutomaticSize.X,
		}),
	})
end

local function Toasts()
	local toasts = Store.use(function(state)
		return state.toasts
	end)
	local children: { [string]: any } = {
		List = e("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, toast in toasts do
		children[`Toast{toast.id}`] = e(Toast, { toast = toast, order = i })
	end
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(600, 200),
		BackgroundTransparency = 1,
		ZIndex = 80,
	}, children)
end

return Toasts
