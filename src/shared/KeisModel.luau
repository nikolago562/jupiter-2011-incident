--!strict
-- Builds a Keis model (key body, spider legs on Motor6Ds, toothy mouth, chant text, chant sound).
-- Shared so the server (real Keis) and the client (menu scene) build the exact same creature.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local KeisModel = {}

local function weldTo(root: BasePart, p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
end

-- the "face": a ring of teeth around a fleshy throat inside the key's bow
local function drawMouth(faceGui: SurfaceGui, def: any)
	local flesh = Instance.new("Frame")
	flesh.Size = UDim2.fromScale(1, 1)
	flesh.BackgroundColor3 = if def.passive then Color3.fromRGB(255, 190, 60) else Color3.fromRGB(120, 18, 22)
	flesh.BorderSizePixel = 0
	flesh.Parent = faceGui
	Instance.new("UICorner", flesh).CornerRadius = UDim.new(0.5, 0)
	if Config.KeisFaceImage ~= "" then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = Config.KeisFaceImage
		img.Parent = flesh
		Instance.new("UICorner", img).CornerRadius = UDim.new(0.5, 0)
		return
	end
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 120))
	grad.Parent = flesh
	local throat = Instance.new("Frame")
	throat.AnchorPoint = Vector2.new(0.5, 0.5)
	throat.Position = UDim2.fromScale(0.5, 0.5)
	throat.Size = UDim2.fromScale(0.5, 0.5)
	throat.BackgroundColor3 = Color3.fromRGB(12, 2, 4)
	throat.BorderSizePixel = 0
	throat.Parent = flesh
	Instance.new("UICorner", throat).CornerRadius = UDim.new(0.5, 0)
	-- two rings of teeth pointing inward
	local rings = if def.boss then { { r = 0.4, n = 18, len = 0.16 }, { r = 0.28, n = 14, len = 0.11 } } else { { r = 0.36, n = 14, len = 0.14 } }
	for _, ring in rings do
		for i = 1, ring.n do
			local a = (i / ring.n) * math.pi * 2
			local tooth = Instance.new("Frame")
			tooth.AnchorPoint = Vector2.new(0.5, 0.5)
			tooth.Position = UDim2.fromScale(0.5 + math.cos(a) * ring.r, 0.5 + math.sin(a) * ring.r)
			tooth.Size = UDim2.fromScale(0.05, ring.len)
			tooth.Rotation = math.deg(a) + 90
			tooth.BackgroundColor3 = Color3.fromRGB(235, 228, 205)
			tooth.BorderSizePixel = 0
			tooth.Parent = flesh
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = tooth
		end
	end
end

local LEG_COLOR = Color3.fromRGB(58, 52, 50)

function KeisModel.build(def: any, position: Vector3)
	local s = def.scale
	local model = Instance.new("Model")
	model.Name = def.name

	local HIP = 2.5 * s -- the spider legs hold the key up off the floor
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * s
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = CFrame.new(position + Vector3.new(0, HIP + s, 0))
	root.Parent = model
	model.PrimaryPart = root

	local material = if def.passive then Enum.Material.Neon else Enum.Material.Metal
	local bodyParts: { BasePart } = {}
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size * s
		p.Color = color
		p.Material = mat
		p.CFrame = root.CFrame * (offset - offset.Position + offset.Position * s)
		p:SetAttribute("BaseColor", color)
		p.Parent = model
		weldTo(root, p)
		return p
	end

	-- the key: shaft, bit (teeth) and bow
	table.insert(bodyParts, piece("Shaft", Vector3.new(0.9, 5.5, 0.9), CFrame.new(0, 0.5, 0), def.color, material))
	table.insert(bodyParts, piece("ToothA", Vector3.new(1.4, 0.7, 0.9), CFrame.new(0.9, -1.6, 0), def.color, material))
	table.insert(bodyParts, piece("ToothB", Vector3.new(1.0, 0.7, 0.9), CFrame.new(0.7, -0.6, 0), def.color, material))
	table.insert(bodyParts, piece("Collar", Vector3.new(0.6, 1.5, 1.5), CFrame.new(0, 2.9, 0) * CFrame.Angles(0, 0, math.rad(90)), def.color, material, Enum.PartType.Cylinder))
	local bow = piece("Bow", Vector3.new(0.9, 4.8, 4.8), CFrame.new(0, 5.5, 0) * CFrame.Angles(0, math.rad(90), 0), def.color, material, Enum.PartType.Cylinder)
	table.insert(bodyParts, bow)
	if def.splitInto then
		local ring = piece("Ring", Vector3.new(0.4, 3, 3), CFrame.new(0, 9, 0) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(200, 200, 210), Enum.Material.Metal, Enum.PartType.Cylinder)
		table.insert(bodyParts, ring)
		for i = -1, 1, 2 do
			table.insert(bodyParts, piece("Charm", Vector3.new(0.5, 2.2, 0.5), CFrame.new(i * 2.6, 6.6, 0) * CFrame.Angles(0, 0, math.rad(i * 25)), def.color, material))
		end
	end

	-- the mouth inside the bow (named "Face": shots here are crits)
	local face = piece("Face", Vector3.new(3.4, 3.4, 0.1), CFrame.new(0, 5.5, -0.5), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	face.Transparency = 1
	local faceGui = Instance.new("SurfaceGui")
	faceGui.Face = Enum.NormalId.Front
	faceGui.CanvasSize = Vector2.new(200, 200)
	faceGui.LightInfluence = 0.5
	faceGui.Parent = face
	drawMouth(faceGui, def)

	local glow = Instance.new("PointLight")
	glow.Color = if def.passive then Color3.fromRGB(255, 210, 60) else Color3.fromRGB(255, 50, 40)
	glow.Range = 10 * s
	glow.Brightness = if def.boss then 4 else 1.2
	glow.Parent = face

	-- six spider legs. Each leg hangs on a Motor6D ("Leg1".."Leg6") that clients animate (KeisAnimator).
	local hipY = 0.6 -- relative to the root center, before scaling
	local upperLen, upperAngle = 3.2, math.rad(40)
	local kneeOut, kneeUp = math.cos(upperAngle) * upperLen, math.sin(upperAngle) * upperLen
	local footOut = kneeOut + 1.3
	local footDown = (HIP / s + 1 + hipY) -- from hip height down to the floor
	local legIndex = 0
	for _, side in { 1, -1 } do
		for _, yawDeg in { -38, 0, 38 } do
			legIndex += 1
			local yaw = math.rad(yawDeg) + (if side == 1 then 0 else math.pi)
			local hip = CFrame.new(0, hipY * s, 0) * CFrame.Angles(0, yaw, 0)

			local upperLocal = CFrame.new(kneeOut / 2 * s, kneeUp / 2 * s, 0) * CFrame.Angles(0, 0, upperAngle)
			local upper = Instance.new("Part")
			upper.Name = "LegUpper"
			upper.Size = Vector3.new(upperLen, 0.32, 0.32) * s
			upper.Color = LEG_COLOR
			upper.Material = Enum.Material.Metal
			upper.CanCollide = false
			upper.Massless = true
			upper.CFrame = root.CFrame * hip * upperLocal
			upper:SetAttribute("BaseColor", LEG_COLOR)
			upper.Parent = model

			local motor = Instance.new("Motor6D")
			motor.Name = "Leg" .. legIndex
			motor.Part0 = root
			motor.Part1 = upper
			motor.C0 = hip
			motor.C1 = upperLocal:Inverse()
			motor:SetAttribute("Group", legIndex % 2) -- tripod gait: legs alternate in two groups
			motor.Parent = root

			local knee = Vector3.new(kneeOut, kneeUp, 0) * s
			local foot = Vector3.new(footOut, -footDown, 0) * s
			local lowerVec = foot - knee
			local lowerLocal = CFrame.lookAt(knee + lowerVec / 2, foot) -- Z axis along the leg
			local lower = Instance.new("Part")
			lower.Name = "LegLower"
			lower.Size = Vector3.new(0.24 * s, 0.24 * s, lowerVec.Magnitude)
			lower.Color = LEG_COLOR
			lower.Material = Enum.Material.Metal
			lower.CanCollide = false
			lower.Massless = true
			lower.CFrame = root.CFrame * hip * lowerLocal
			lower:SetAttribute("BaseColor", LEG_COLOR)
			lower.Parent = model
			local w = Instance.new("WeldConstraint")
			w.Part0 = upper
			w.Part1 = lower
			w.Parent = lower
			table.insert(bodyParts, upper)
			table.insert(bodyParts, lower)
		end
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15 -- R15 uses HipHeight (the legs are only visual)
	humanoid.HipHeight = HIP
	humanoid.WalkSpeed = def.speed
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	for _, state in { Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Seated, Enum.HumanoidStateType.Climbing } do
		humanoid:SetStateEnabled(state, false)
	end

	-- name, health bar, chant text
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(170, 52)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.2 * s, 0)
	billboard.MaxDistance = if def.boss then 200 else 90
	billboard.Adornee = bow
	billboard.LightInfluence = 0
	billboard.Parent = model
	local chant = Instance.new("TextLabel")
	chant.Size = UDim2.new(1, 0, 0, 22)
	chant.BackgroundTransparency = 1
	chant.Font = Enum.Font.Code
	chant.TextScaled = true
	chant.TextColor3 = if def.passive then Color3.fromRGB(255, 215, 70) else Color3.fromRGB(255, 70, 60)
	chant.TextStrokeTransparency = 0.3
	chant.Text = ""
	chant.Parent = billboard
	local barBack = Instance.new("Frame")
	barBack.AnchorPoint = Vector2.new(0.5, 0)
	barBack.Position = UDim2.new(0.5, 0, 0, 30)
	barBack.Size = UDim2.new(if def.boss then 1 else 0.6, 0, 0, if def.boss then 10 else 6)
	barBack.BackgroundColor3 = Color3.fromRGB(20, 15, 20)
	barBack.BorderSizePixel = 0
	barBack.Visible = def.boss == true
	barBack.Parent = billboard
	Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)
	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = if def.passive then Color3.fromRGB(255, 215, 70) else Color3.fromRGB(255, 90, 60)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

	local chantId = if def.boss and Config.Sounds.BossChant ~= "" then Config.Sounds.BossChant else Config.Sounds.KeisChant
	if chantId ~= "" and not def.passive then
		local sound = Instance.new("Sound")
		sound.Name = "Chant"
		sound.SoundId = chantId
		sound.Looped = false -- played in sync with the floating chant text (see Keis.new)
		sound.Volume = if def.boss then 1.8 else 0.9
		-- the boss uses the normal chant slowed down unless it has its own BossChant
		sound:SetAttribute("BaseSpeed", if def.boss and Config.Sounds.BossChant == "" then 0.78 else 1)
		sound.RollOffMinDistance = 8
		sound.RollOffMaxDistance = if def.boss then 160 else 75
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.Parent = root
	end

	return model, humanoid, root, face, bodyParts, chant, barBack, barFill
end

return KeisModel
