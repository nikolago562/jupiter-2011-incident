--!strict
-- Animates the Keis' spider legs on each client (tripod gait), so the server only moves the body.

local RunService = game:GetService("RunService")

local camera = workspace.CurrentCamera
local MAX_DISTANCE = 140

type Rig = { root: BasePart, legs: { { motor: Motor6D, group: number, side: number } }, phase: number }
local rigs: { [Model]: Rig } = {}

local function register(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not root then
		return
	end
	task.wait() -- let the motors replicate
	local legs = {}
	for _, m in root:GetChildren() do
		if m:IsA("Motor6D") and string.sub(m.Name, 1, 3) == "Leg" then
			local index = tonumber(string.sub(m.Name, 4)) or 1
			table.insert(legs, { motor = m, group = (m:GetAttribute("Group") :: number?) or (index % 2), side = if index <= 3 then 1 else -1 })
		end
	end
	if #legs > 0 then
		rigs[model] = { root = root, legs = legs, phase = math.random() * math.pi * 2 }
	end
end

local function watch(folder: Instance)
	for _, m in folder:GetChildren() do
		task.spawn(register, m)
	end
	folder.ChildAdded:Connect(function(m)
		task.spawn(register, m)
	end)
	folder.ChildRemoved:Connect(function(m)
		rigs[m :: Model] = nil
	end)
end

task.spawn(function()
	watch(workspace:WaitForChild("Keis"))
end)

RunService.RenderStepped:Connect(function(dt)
	local camPos = camera.CFrame.Position
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		if (rig.root.Position - camPos).Magnitude > MAX_DISTANCE then
			continue
		end
		local v = rig.root.AssemblyLinearVelocity
		local speed = Vector3.new(v.X, 0, v.Z).Magnitude
		local moving = math.clamp(speed / 10, 0, 1)
		rig.phase += dt * (3 + speed * 0.9)
		for _, leg in rig.legs do
			local p = rig.phase + (if leg.group == 1 then math.pi else 0)
			local swing = math.sin(p) * 0.45 * moving + math.sin(rig.phase * 7 + leg.side) * 0.03 -- twitch when idle
			local lift = math.max(0, math.cos(p)) * 0.35 * moving
			leg.motor.Transform = CFrame.Angles(0, swing * leg.side, 0) * CFrame.Angles(0, 0, lift)
		end
	end
end)
