--!strict
-- First person: weapon viewmodel with arms, sway, bob, recoil, reload/sprint poses, aim down sights (right click),
-- scope overlay, Q/E lean, laser beam, spinning minigun barrels.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WeaponModel = require(Shared:WaitForChild("WeaponModel"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera


local SUIT = Color3.fromRGB(232, 232, 228)
local GLOVE = Color3.fromRGB(60, 62, 68)
local CUFF = Color3.fromRGB(255, 138, 61)

-- state
local vm: any = nil
local vmKey = ""
local aiming = false
local aimBlend = 0
local leanTarget = 0
local lean = 0
local sway = Vector2.zero
local bobT = 0
local kick = 0
local lastShotSeen = 0
local spinAngle, spinSpeed = 0, 0
local sprintBlend, reloadBlend = 0, 0
local laserDot: Part? = nil

-- scope overlay (black ring around a clear circle + crosshair)
local scopeGui = Instance.new("ScreenGui")
scopeGui.Name = "Scope"
scopeGui.IgnoreGuiInset = true
scopeGui.ResetOnSpawn = false
scopeGui.DisplayOrder = 4
scopeGui.Enabled = false
scopeGui.Parent = player:WaitForChild("PlayerGui")
local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.fromScale(0.5, 0.5)
ring.Size = UDim2.fromScale(0.62, 0.62)
ring.SizeConstraint = Enum.SizeConstraint.RelativeYY
ring.BackgroundTransparency = 1
ring.Parent = scopeGui
Instance.new("UICorner", ring).CornerRadius = UDim.new(0.5, 0)
local ringStroke = Instance.new("UIStroke")
ringStroke.Thickness = 2000 -- everything outside the circle is black
ringStroke.Color = Color3.new(0, 0, 0)
ringStroke.Parent = ring
for _, d in { { 1, 0.004 }, { 0.004, 1 } } do
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.Size = UDim2.fromScale(d[1], d[2])
	line.BackgroundColor3 = Color3.new(0, 0, 0)
	line.BorderSizePixel = 0
	line.Parent = ring
end
local reticleDot = Instance.new("Frame")
reticleDot.AnchorPoint = Vector2.new(0.5, 0.5)
reticleDot.Position = UDim2.fromScale(0.5, 0.5)
reticleDot.Size = UDim2.fromOffset(5, 5)
reticleDot.BackgroundColor3 = Color3.fromRGB(255, 40, 30)
reticleDot.BorderSizePixel = 0
reticleDot.Parent = ring
Instance.new("UICorner", reticleDot).CornerRadius = UDim.new(1, 0)

local function equippedTool(): Tool?
	local c = player.Character
	if not c then
		return nil
	end
	for _, t in c:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("IsWeapon") then
			return t
		end
	end
	return nil
end

local function destroyVM()
	if vm then
		vm.model:Destroy()
		vm = nil
	end
	vmKey = ""
	if laserDot then
		laserDot:Destroy()
		laserDot = nil
	end
	scopeGui.Enabled = false
end

-- a suited forearm from the hand back toward the screen edge
local function arm(model: Model, root: BasePart, hand: Vector3, toShoulder: Vector3)
	local shoulder = hand + toShoulder
	local len = toShoulder.Magnitude
	local function piece(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = root.CFrame * cf
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
	end
	local dirCF = CFrame.lookAt(hand, shoulder)
	piece("Sleeve", Vector3.new(0.46, 0.46, len), CFrame.lookAt((hand + shoulder) / 2, shoulder), SUIT, Enum.Material.Fabric)
	piece("Cuff", Vector3.new(0.5, 0.5, 0.14), dirCF * CFrame.new(0, 0, -0.32), CUFF, Enum.Material.SmoothPlastic)
	piece("Glove", Vector3.new(0.36, 0.38, 0.46), dirCF * CFrame.new(0, 0, -0.05), GLOVE, Enum.Material.Fabric)
end

local function build(tool: Tool)
	destroyVM()
	local weaponId = (tool:GetAttribute("WeaponId") :: string?) or "Blaster"
	local att = WeaponModel.decode(player:GetAttribute("Attachments") :: string?)
	local model = Instance.new("Model")
	model.Name = "Viewmodel"
	local built = WeaponModel.build(weaponId, att, model, "Root")
	built.root.Anchored = true
	if weaponId == "Minigun" then
		arm(model, built.root, built.grip.Position, Vector3.new(0.4, -0.9, 2.2))
		arm(model, built.root, built.foregrip.Position, Vector3.new(-0.8, -1, 1.6))
	else
		arm(model, built.root, built.grip.Position, Vector3.new(0.35, -0.95, 2.1))
		arm(model, built.root, built.foregrip.Position, Vector3.new(-0.95, -0.85, 1.7))
	end
	model.Parent = camera
	local opticDef = Config.attachment("Optic", att.Optic)
	vm = {
		model = model,
		built = built,
		weaponId = weaponId,
		att = att,
		zoom = if opticDef then opticDef.zoom else 1.15,
		scoped = att.Optic == "ACOG" or att.Optic == "Sniper",
		hip = if weaponId == "Minigun" then CFrame.new(1.05, -1.3, -1.5) else CFrame.new(0.95, -0.9, -2.05),
	}
	if built.laser then
		local dot = Instance.new("Part")
		dot.Name = "LaserDot"
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.one * 0.18
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.Material = Enum.Material.Neon
		dot.Color = (built.laser:GetAttribute("Color") :: Color3?) or Color3.new(1, 0, 0)
		dot.Parent = camera
		local a0 = Instance.new("Attachment")
		a0.Parent = built.laser
		local a1 = Instance.new("Attachment")
		a1.Parent = dot
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 0.03
		beam.Width1 = 0.03
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Color = ColorSequence.new(dot.Color)
		beam.Transparency = NumberSequence.new(0.35, 0.8)
		beam.Parent = built.laser
		laserDot = dot
	end
	vmKey = weaponId .. "|" .. WeaponModel.encode(att)
end

-- Input ---------------------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and not processed then
		aiming = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		aiming = false
	end
end)
ContextActionService:BindAction("JupiterAim", function(_, state)
	if state == Enum.UserInputState.Begin then
		aiming = not aiming -- touch / gamepad: toggle
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.ButtonL2)
ContextActionService:SetTitle("JupiterAim", "AIM")
ContextActionService:BindAction("JupiterLean", function(name, state, input)
	local dir = if input.KeyCode == Enum.KeyCode.Q then -1 else 1
	if state == Enum.UserInputState.Begin then
		leanTarget = dir
	elseif state == Enum.UserInputState.End and leanTarget == dir then
		leanTarget = 0
	end
	local _ = name
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Q, Enum.KeyCode.E)

-- Frame ---------------------------------------------------------------------------------------------
RunService:BindToRenderStep("JupiterViewmodel", Enum.RenderPriority.Camera.Value + 3, function(dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local tool = equippedTool()
	local inGame = camera.CameraType == Enum.CameraType.Custom
	if not humanoid or not root or not inGame or humanoid.Health <= 0 or player:GetAttribute("Downed") then
		destroyVM()
		player:SetAttribute("ADS", false)
		return
	end

	-- first person from the moment you're in the game (not in the menu)
	if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end

	-- hide your own body, suit and the third-person gun in first person
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		end
	end

	-- lean (Q / E)
	lean += (leanTarget - lean) * math.min(dt * 10, 1)
	if math.abs(lean) > 0.001 then
		camera.CFrame *= CFrame.new(lean * 1.15, -math.abs(lean) * 0.12, 0) * CFrame.Angles(0, 0, -lean * math.rad(13))
	end

	if not tool then
		destroyVM()
		player:SetAttribute("ADS", false)
		camera.FieldOfView += (70 - camera.FieldOfView) * math.min(dt * 8, 1)
		return
	end
	local key = ((tool:GetAttribute("WeaponId") :: string?) or "Blaster") .. "|" .. WeaponModel.encode(WeaponModel.decode(player:GetAttribute("Attachments") :: string?))
	if not vm or key ~= vmKey then
		build(tool)
	end
	local built = vm.built

	local sprinting = player:GetAttribute("Sprinting") == true
	local reloading = player:GetAttribute("Reloading") == true
	local ads = aiming and not sprinting and not reloading and not player:GetAttribute("UIOpen")
	aimBlend += ((if ads then 1 else 0) - aimBlend) * math.min(dt * 12, 1)
	sprintBlend += ((if sprinting then 1 else 0) - sprintBlend) * math.min(dt * 8, 1)
	reloadBlend += ((if reloading then 1 else 0) - reloadBlend) * math.min(dt * 8, 1)
	player:SetAttribute("ADS", aimBlend > 0.5)

	-- recoil: Combat.client stamps LastShot on every shot
	local shot = (player:GetAttribute("LastShot") :: number?) or 0
	if shot ~= lastShotSeen then
		lastShotSeen = shot
		local k = if vm.weaponId == "Minigun" then 0.35 else 1
		if vm.att.Muzzle == "Compensator" then
			k *= 0.5
		end
		kick = math.min(kick + k * (1 - aimBlend * 0.5), 1.5)
		spinSpeed = 30
	end
	kick *= math.exp(-dt * 14)

	-- sway from mouse movement + walking bob
	local md = UserInputService:GetMouseDelta()
	local swayTarget = Vector2.new(math.clamp(-md.X * 0.0025, -0.08, 0.08), math.clamp(-md.Y * 0.0025, -0.08, 0.08)) * (1 - aimBlend * 0.85)
	sway = sway:Lerp(swayTarget, math.min(dt * 10, 1))
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local moving = math.clamp(speed / 16, 0, 1.5) * (if humanoid.FloorMaterial == Enum.Material.Air then 0.2 else 1)
	bobT += dt * (6 + speed * 0.35)
	local bobAmt = moving * (1 - aimBlend * 0.85)
	local bob = CFrame.new(math.sin(bobT) * 0.045 * bobAmt, -math.abs(math.cos(bobT)) * 0.05 * bobAmt, 0) * CFrame.Angles(0, 0, math.sin(bobT) * 0.02 * bobAmt)

	-- poses
	local adsCF = CFrame.new(0, 0, -0.12) * CFrame.new(-built.sight.Position)
	local pose = vm.hip:Lerp(adsCF, aimBlend)
	local sprintPose = CFrame.new(0.15 * sprintBlend, -0.25 * sprintBlend, 0.1 * sprintBlend) * CFrame.Angles(-0.25 * sprintBlend, 0.7 * sprintBlend, 0.3 * sprintBlend)
	local reloadPose = CFrame.new(0, -0.3 * reloadBlend, 0) * CFrame.Angles(-0.5 * reloadBlend, 0.25 * reloadBlend, 0.55 * reloadBlend)
	local recoil = CFrame.new(0, 0.02 * kick, 0.22 * kick) * CFrame.Angles(0.07 * kick, 0, 0)
	local swayCF = CFrame.Angles(sway.Y, sway.X, sway.X * 0.6)
	built.root.CFrame = camera.CFrame * pose * bob * swayCF * sprintPose * reloadPose * recoil

	-- minigun barrels
	if built.spin then
		spinSpeed = math.max(0, spinSpeed - dt * 25)
		spinAngle += spinSpeed * dt
		built.spin.Transform = CFrame.Angles(spinAngle, 0, 0)
	end

	-- laser dot
	if laserDot and built.laser then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, camera }
		local origin = built.laser.Position
		local dir = built.root.CFrame.LookVector * 250
		local hit = workspace:Raycast(origin, dir, params)
		laserDot.CFrame = CFrame.new(if hit then hit.Position else origin + dir)
	end

	-- scopes: full overlay instead of the model when aimed in
	local scopedIn = vm.scoped and aimBlend > 0.9
	scopeGui.Enabled = scopedIn
	for _, p in vm.model:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = if scopedIn then 1 else 0
		end
	end

	-- field of view: sprint widens, aiming zooms by the optic's magnification
	local fov = 70 + (if sprinting and speed > 2 then 8 else 0)
	fov = fov + ((70 / vm.zoom) - fov) * aimBlend
	camera.FieldOfView += (fov - camera.FieldOfView) * math.min(dt * 14, 1)
end)

player.CharacterAdded:Connect(function()
	destroyVM()
end)
