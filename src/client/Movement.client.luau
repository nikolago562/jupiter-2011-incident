--!strict
-- Movement feel: over-the-shoulder shooter camera, sprint, camera bob, hit shake, moon dust.

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local SHOULDER = Vector3.new(1.9, 0.5, 0)
local SPRINT_MULT = 1.45

player.CameraMinZoomDistance = 6
player.CameraMaxZoomDistance = 22

local sprinting = false
local sprintBase = 16
local shoulderWas = false
local offset = Vector3.zero
local shake = 0
local bobT = 0

local function getHumanoid(): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function hasWeapon(): boolean
	local c = player.Character
	if not c then
		return false
	end
	for _, t in c:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("IsWeapon") then
			return true
		end
	end
	return false
end

local function setSprint(on: boolean)
	local humanoid = getHumanoid()
	if not humanoid or player:GetAttribute("Downed") then
		on = false
	end
	if on == sprinting then
		return
	end
	sprinting = on
	player:SetAttribute("Sprinting", on) -- local only; Combat.client won't fire while sprinting
	if humanoid then
		if on then
			sprintBase = humanoid.WalkSpeed
			humanoid.WalkSpeed = sprintBase * SPRINT_MULT
		else
			humanoid.WalkSpeed = sprintBase
		end
	end
end

ContextActionService:BindAction("JupiterSprint", function(_, state)
	setSprint(state == Enum.UserInputState.Begin)
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("JupiterSprint", "RUN")

player.CharacterAdded:Connect(function()
	sprinting = false
	player:SetAttribute("Sprinting", false)
end)

Remotes:WaitForChild("PlayerHurt").OnClientEvent:Connect(function(damage: number)
	shake = math.clamp(0.15 + damage / 60, 0.15, 0.6)
end)

-- moon dust ---------------------------------------------------------------------------------------
local lastDust = 0
local wasAirborne = false
local function puff(pos: Vector3, size: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(210, 180, 110)
	p.Transparency = 0.45
	p.Size = Vector3.one * size
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * size * 3, Transparency = 1, CFrame = CFrame.new(pos + Vector3.new(0, size, 0)) }):Play()
	Debris:AddItem(p, 1.3)
end

RunService:BindToRenderStep("JupiterMovement", Enum.RenderPriority.Camera.Value + 2, function(dt)
	local character = player.Character
	local humanoid = getHumanoid()
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local alive = humanoid.Health > 0 and not player:GetAttribute("Downed")
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local shoulder = alive and hasWeapon() and not touchOnly and not sprinting

	if shoulder then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		humanoid.AutoRotate = false
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
		end
	elseif shoulderWas then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		humanoid.AutoRotate = true
	end
	shoulderWas = shoulder

	-- walking bob
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local amount = math.clamp(speed / 16, 0, 1.6)
	bobT += dt * (if sprinting then 11 else 8)
	local bob = if humanoid.FloorMaterial ~= Enum.Material.Air
		then Vector3.new(math.sin(bobT) * 0.07, math.abs(math.cos(bobT)) * 0.1, 0) * amount
		else Vector3.zero
	local target = (if shoulder then SHOULDER else Vector3.zero) + bob
	offset = offset:Lerp(target, math.min(dt * 10, 1))
	humanoid.CameraOffset = offset

	-- sprint FOV kick
	local fov = 70 + (if sprinting and speed > 2 then 9 else 0)
	camera.FieldOfView += (fov - camera.FieldOfView) * math.min(dt * 6, 1)

	-- hit shake
	if shake > 0 then
		shake = math.max(0, shake - dt)
		local a = shake * 0.03
		camera.CFrame *= CFrame.Angles((math.random() - 0.5) * a, (math.random() - 0.5) * a, (math.random() - 0.5) * a)
	end

	-- dust on Io: footsteps + landings
	if ReplicatedStorage:GetAttribute("Stage") == "Moon" then
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 - 0.3, 0)
		if grounded and wasAirborne then
			for _ = 1, 5 do
				puff(feet + Vector3.new(math.random(-15, 15) / 10, 0, math.random(-15, 15) / 10), 1.6)
			end
		elseif grounded and speed > 4 and os.clock() - lastDust > 0.28 then
			lastDust = os.clock()
			puff(feet, 0.9)
		end
		wasAirborne = not grounded
	end
end)
