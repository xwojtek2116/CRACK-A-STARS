--!strict
-- Label — tekst w stylu gry: Luckiest Guy z grubym czarnym konturem (UIStroke). Domyślnie AutomaticSize XY.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local Theme = require(script.Parent.Parent.Theme)

local e = React.createElement

export type Props = {
	text: string,
	textSize: number?,
	color: Color3?,
	font: Font?,
	stroke: number?, -- 0 = bez konturu
	strokeColor: Color3?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	xAlignment: Enum.TextXAlignment?,
	yAlignment: Enum.TextYAlignment?,
	layoutOrder: number?,
	rotation: number?,
	wrapped: boolean?,
	zIndex: number?,
	visible: boolean?,
	richText: boolean?,
	labelRef: any?,
	automaticSize: Enum.AutomaticSize?,
	children: any?,
}

local function Label(props: Props)
	local stroke = props.stroke or Theme.STROKE
	return e("TextLabel", {
		ref = props.labelRef,
		Text = props.text,
		TextSize = props.textSize or Theme.TEXT_SIZE.body,
		TextColor3 = props.color or Theme.COLORS.text,
		FontFace = props.font or Theme.FONTS.display,
		RichText = props.richText,
		BackgroundTransparency = 1,
		Size = props.size or UDim2.new(),
		AutomaticSize = props.automaticSize or (if props.size then Enum.AutomaticSize.None else Enum.AutomaticSize.XY),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		TextXAlignment = props.xAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.yAlignment or Enum.TextYAlignment.Center,
		TextWrapped = props.wrapped,
		LayoutOrder = props.layoutOrder,
		Rotation = props.rotation,
		ZIndex = props.zIndex,
		Visible = props.visible,
	}, {
		Stroke = if stroke > 0
			then e("UIStroke", {
				Thickness = stroke,
				Color = props.strokeColor or Theme.COLORS.ink,
				LineJoinMode = Enum.LineJoinMode.Round,
			})
			else nil,
		Children = if props.children then e(React.Fragment, nil, props.children) else nil,
	})
end

return Label
