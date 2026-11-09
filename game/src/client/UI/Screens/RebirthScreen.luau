--!strict
-- RebirthScreen — zakładka REBIRTH okna STAR INDEX (w lobby: Index Hall z portalem Rebirth).
--   • u góry: numer rebirthu, mnożnik dochodu teraz → po rebircie, koszt i ile kasy ma gracz,
--   • dwie kolumny: YOU LOSE (Economy.rebirth.resets) i YOU KEEP (keeps),
--   • przycisk REBIRTH → „Are you sure?” (reset nieodwracalny) → prośba Rebirth do serwera
--     (serwer sprawdza saldo i robi reset; logika T19, do tego czasu „Coming soon”).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages").React)

local RebirthMath = require(ReplicatedStorage:WaitForChild("Shared").RebirthMath)

local UI = script.Parent.Parent
local Button = require(UI.Components.Button)
local Label = require(UI.Components.Label)
local SpaceFx = require(UI.Components.SpaceFx)
local Format = require(UI.Format)
local Store = require(UI.Store)
local Theme = require(UI.Theme)
local Common = require(script.Parent.Common)
local Request = require(script.Parent.Request)

local e = React.createElement

-- Napisy dla kluczy z Economy.json → rebirth.resets / keeps.
local LABELS: { [string]: string } = {
	cash = "Cash",
	tools = "Tools",
	baseItems = "Items on your base",
	slots = "Extra pedestals",
	vehicles = "Rides & jetpack",
	index = "Star Index & luck bonus",
	gamepasses = "Game passes",
}

local function Column(props: { title: string, color: Color3, keys: { string }, mark: string, order: number })
	local rows: { [string]: any } = {
		List = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Pad = e("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 16) }),
	}
	for i, key in props.keys do
		rows[key] = e(Label, {
			text = `<font color="#{props.color:ToHex()}">{props.mark}</font>  {LABELS[key] or key}`,
			richText = true,
			font = Theme.FONTS.body,
			textSize = Theme.TEXT_SIZE.body,
			xAlignment = Enum.TextXAlignment.Left,
			size = UDim2.new(1, -16, 0, 28),
			layoutOrder = i,
		})
	end
	rows.Title = e(Label, {
		text = props.title,
		textSize = Theme.TEXT_SIZE.title - 4,
		color = props.color,
		-- Pierwszy w UIListLayout (layoutOrder 0) — nad wierszami.
		xAlignment = Enum.TextXAlignment.Left,
		size = UDim2.new(1, -16, 0, 36),
		layoutOrder = 0,
	})
	return e(Common.Panel, {
		color = props.color,
		size = UDim2.new(0.5, -8, 1, 0),
		layoutOrder = props.order,
	}, rows)
end

local function RebirthScreen()
	local rebirths = Store.use(function(s)
		return s.rebirths
	end)
	local cash = Store.use(function(s)
		return s.cash
	end)
	local confirming, setConfirming = React.useState(false)
	local cost = RebirthMath.cost(rebirths)
	local nowMult = RebirthMath.incomeMult(rebirths)
	local nextMult = RebirthMath.incomeMult(rebirths + 1)
	local canAfford = cash >= cost

	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Glow = e(SpaceFx.Flare, {
			color = Theme.COLORS.neonMagenta,
			size = 320,
			position = UDim2.new(0.5, 0, 0, 40),
			transparency = 0.6,
		}),
		Title = e(Label, {
			text = `REBIRTH #{rebirths + 1}`,
			textSize = Theme.TEXT_SIZE.big,
			color = Theme.COLORS.neonMagenta,
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.fromScale(0.5, 0),
			zIndex = 2,
		}),
		Mult = e(Label, {
			text = `INCOME x{nowMult}  →  <font color="#5BFF8A">x{nextMult}</font>`,
			richText = true,
			textSize = Theme.TEXT_SIZE.title - 4,
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.new(0.5, 0, 0, 50),
			zIndex = 2,
		}),
		Columns = e("Frame", {
			Position = UDim2.fromOffset(0, 96),
			Size = UDim2.new(1, 0, 1, -180),
			BackgroundTransparency = 1,
		}, {
			List = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 16),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Lose = e(Column, {
				title = "YOU LOSE",
				color = Theme.COLORS.danger,
				keys = RebirthMath.RESETS,
				mark = "X",
				order = 1,
			}),
			Keep = e(Column, {
				title = "YOU KEEP",
				color = Theme.COLORS.cash,
				keys = RebirthMath.KEEPS,
				mark = "✓",
				order = 2,
			}),
		}),
		Cost = e(Label, {
			text = `COST <font color="#FFC83D">{Format.cash(cost)}</font>   YOU HAVE <font color="{if canAfford
				then "#5BFF8A"
				else "#FF3B4E"}">{Format.cash(cash)}</font>`,
			richText = true,
			textSize = Theme.TEXT_SIZE.body,
			xAlignment = Enum.TextXAlignment.Left,
			anchorPoint = Vector2.new(0, 1),
			position = UDim2.new(0, 8, 1, -22),
		}),
		Rebirth = e(Button, {
			text = "REBIRTH",
			color = Theme.COLORS.neonMagenta,
			size = UDim2.fromOffset(230, 62),
			anchorPoint = Vector2.new(1, 1),
			position = UDim2.new(1, -8, 1, -8),
			textSize = Theme.TEXT_SIZE.title,
			shine = canAfford,
			onActivated = function()
				if not canAfford then
					Store.toast(`You need {Format.cash(cost)} to rebirth!`, "error")
					return
				end
				setConfirming(true)
			end,
		}),
		Confirm = if confirming
			then e(Common.Confirm, {
				title = "ARE YOU SURE?",
				text = `Your cash, tools and base reset.\nYou keep rides, Star Index and passes.\nIncome becomes <font color="#5BFF8A">x{nextMult}</font> forever!`,
				confirmText = "REBIRTH!",
				color = Theme.COLORS.neonMagenta,
				onCancel = function()
					setConfirming(false)
				end,
				onConfirm = function()
					setConfirming(false)
					Request.send("Rebirth", {}, `Rebirth #{rebirths + 1}! Income x{nextMult}`)
				end,
			})
			else nil,
	})
end

return RebirthScreen
