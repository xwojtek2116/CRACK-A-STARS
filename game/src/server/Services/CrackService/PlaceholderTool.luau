--!strict
-- PlaceholderTool — TYMCZASOWY Tool narzędzia z części (T06), żeby minigrę dało się grać przed T09.
-- T09 (ToolService) przejmie wydawanie Toola z modeli w ServerStorage.Tools — wtedy ten moduł usuń.
-- Kontrakt dla CrackService: Tool w ręku ma atrybut ToolId = klucz z Tools.json.

local CrackRound = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").CrackRound)

local HANDLE_COLOR = Color3.fromRGB(110, 78, 52)
local HEAD_COLOR = Color3.fromRGB(150, 150, 160)

local PlaceholderTool = {}

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	return p
end

function PlaceholderTool.create(toolId: string): Tool
	local def = CrackRound.getTool(toolId)
	local tool = Instance.new("Tool")
	tool.Name = if def then def.name else toolId
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Hold near a star and click to crack it"
	tool:SetAttribute("ToolId", toolId)
	tool:SetAttribute("Placeholder", true)

	local handle = part("Handle", Vector3.new(0.35, 3, 0.35), HANDLE_COLOR, Enum.Material.Wood)
	handle.Parent = tool
	local head = part("Head", Vector3.new(2.2, 0.5, 0.5), HEAD_COLOR, Enum.Material.Slate)
	head.CFrame = handle.CFrame * CFrame.new(0, 1.35, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = head
	head.Parent = tool
	-- Chwyt przy dolnym końcu trzonka, głowica do przodu.
	tool.Grip = CFrame.new(0, -1, 0) * CFrame.Angles(0, math.rad(90), 0)
	return tool
end

return PlaceholderTool
