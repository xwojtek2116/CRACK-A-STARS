--!strict
-- ToolFxController — ruch części narzędzi (T11): kręci części z tagiem "ToolSpin" (tarcza Plasma Saw,
-- pierścienie Gravity Hammer, galaktyka Galaxy Hammer). Tylko wygląd: obraca lokalnie Weld.C0 części
-- względem Handle (oś `SpinAxis` w układzie Handle, `SpinSpeed` w stopniach/s — atrybuty z importu modeli).
-- Kręci tylko narzędzia w Workspace (w ręku postaci), nie w plecaku.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG = "ToolSpin"

type Spin = { weld: Weld, base: CFrame, axis: Vector3, speed: number }

local spins: { [BasePart]: Spin } = {}

local function add(inst: Instance)
	if not inst:IsA("BasePart") or spins[inst] then
		return
	end
	-- Część z tagiem może przyjść z serwera przed swoim Weldem — poczekaj chwilę.
	local weld = inst:FindFirstChild("ToolWeld") or inst:WaitForChild("ToolWeld", 5)
	if not weld or not weld:IsA("Weld") or spins[inst] then
		return
	end
	local axis = inst:GetAttribute("SpinAxis")
	local speed = inst:GetAttribute("SpinSpeed")
	if typeof(axis) ~= "Vector3" or axis.Magnitude < 1e-3 or type(speed) ~= "number" then
		return
	end
	spins[inst] = { weld = weld, base = weld.C0, axis = axis.Unit, speed = math.rad(speed) }
end

local function remove(inst: Instance)
	local s = spins[inst :: BasePart]
	if s then
		s.weld.C0 = s.base
		spins[inst :: BasePart] = nil
	end
end

local ToolFxController = {}

function ToolFxController.Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(inst)
		task.spawn(add, inst)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	for _, inst in CollectionService:GetTagged(TAG) do
		task.spawn(add, inst)
	end
	RunService.PreRender:Connect(function()
		local t = os.clock()
		for part, s in spins do
			if not part.Parent then
				spins[part] = nil
			elseif part:IsDescendantOf(Workspace) then
				s.weld.C0 = s.base * CFrame.fromAxisAngle(s.axis, (t * s.speed) % (2 * math.pi))
			end
		end
	end)
end

return ToolFxController
