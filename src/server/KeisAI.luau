--!strict
-- The Keis: key-shaped entities with faces that chant "keis keis keis o algo o algo".
-- They crawl out of the vents and go for the reactor, or for any crew member who gets close.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Keis = {}
Keis.__index = Keis

-- Set by the GameManager -----------------------------------------------------------------
Keis.registry = {} :: { [Model]: any }
Keis.chantsPlaying = 0 -- how many chant sounds are playing right now (capped so it never turns into noise)
Keis.hooks = {
	folder = nil :: Folder?,
	reactor = nil :: BasePart?,
	reactorRadius = 8,
	roomCenters = {} :: { Vector3 },
	speedBonus = 0,
	getTargets = function(): { Model }
		return {}
	end,
	onKilled = function(_keis: any, _killer: Player?) end,
	onAttackPlayer = function(_keis: any, _character: Model, _damage: number) end,
	onAttackReactor = function(_keis: any, _damage: number) end,
	onSummon = function(_keis: any) end,
	onExpired = function(_keis: any) end,
}

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

local function buildModel(def: any, position: Vector3)
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

function Keis.new(typeId: string, position: Vector3, hpScale: number)
	local def = (Config.KeisTypes :: any)[typeId]
	assert(def, "unknown Keis type " .. typeId)
	local self = setmetatable({}, Keis)
	local model, humanoid, root, face, bodyParts, chant, barBack, barFill = buildModel(def, position)
	self.typeId = typeId
	self.def = def
	self.model = model
	self.humanoid = humanoid
	self.root = root
	self.face = face
	self.bodyParts = bodyParts
	self.chant = chant
	self.barBack = barBack
	self.barFill = barFill
	self.maxHp = def.hp * hpScale
	self.hp = self.maxHp
	self.alive = true
	self.bornAt = os.clock()
	self.lastAttack = 0
	self.lastSummon = os.clock()
	self.lastPath = 0
	self.waypoints = nil :: { PathWaypoint }?
	self.wpIndex = 1
	self.lastPos = root.Position
	self.lastProgress = os.clock()
	self.wanderGoal = nil :: Vector3?
	self.path = PathfindingService:CreatePath({
		AgentRadius = math.min(1.6 * def.scale, 3.5),
		AgentHeight = math.min(10 * def.scale, 14),
		AgentCanJump = false,
		WaypointSpacing = 6,
	})

	model.Parent = Keis.hooks.folder or workspace
	root:SetNetworkOwner(nil)
	Keis.registry[model] = self

	task.spawn(function()
		task.wait(math.random() * 0.15)
		while self.alive do
			local ok, err = pcall(self.step, self)
			if not ok then
				warn("[Keis] step error:", err)
			end
			task.wait(0.15)
		end
	end)
	-- the chant: "keis keis keis o algo o algo" — text + sound together, now and then
	task.spawn(function()
		local rng = Random.new()
		local sound = root:FindFirstChild("Chant") :: Sound?
		task.wait(rng:NextNumber(0.3, 2.5))
		while self.alive do
			if def.boss or rng:NextNumber() < Config.KEIS_CHANT_CHANCE then
				self.chant.Text = Config.KeisChatter[rng:NextInteger(1, #Config.KeisChatter)]
				self.chant.Rotation = rng:NextNumber(-5, 5)
				local duration = rng:NextNumber(1.5, 2.6)
				if sound and sound.Parent and (def.boss or Keis.chantsPlaying < Config.MAX_SIMULTANEOUS_CHANTS) then
					local speed = ((sound:GetAttribute("BaseSpeed") :: number?) or 1) * rng:NextNumber(0.92, 1.08)
					sound.PlaybackSpeed = speed
					sound.TimePosition = 0
					sound:Play()
					Keis.chantsPlaying += 1
					duration = if sound.TimeLength > 0 then sound.TimeLength / speed else 5
					task.delay(duration, function()
						Keis.chantsPlaying -= 1
					end)
				end
				task.wait(duration)
				self.chant.Text = ""
			end
			task.wait(if def.boss then rng:NextNumber(1, 2.5) else rng:NextNumber(2, 6))
		end
	end)
	return self
end

function Keis.fromPart(instance: Instance): any?
	local node: Instance? = instance
	while node and node ~= workspace do
		if node:IsA("Model") and Keis.registry[node] then
			return Keis.registry[node]
		end
		node = node.Parent
	end
	return nil
end

function Keis.countHostile(): number
	local n = 0
	for _, k in Keis.registry do
		if k.alive and not k.def.passive then
			n += 1
		end
	end
	return n
end

function Keis.clearAll()
	for _, k in Keis.registry do
		k:destroy()
	end
	Keis.registry = {}
end

-- Damage ----------------------------------------------------------------------------------
function Keis:takeDamage(amount: number, killer: Player?): boolean
	if not self.alive then
		return false
	end
	self.hp -= amount
	self.barBack.Visible = true
	self.barFill.Size = UDim2.fromScale(math.clamp(self.hp / self.maxHp, 0, 1), 1)
	-- hit flash
	for _, p in self.bodyParts do
		p.Color = Color3.new(1, 1, 1)
	end
	task.delay(0.07, function()
		for _, p in self.bodyParts do
			if p.Parent then
				p.Color = (p:GetAttribute("BaseColor") :: Color3?) or self.def.color
			end
		end
	end)
	if self.hp <= 0 then
		self:die(killer)
		return true
	end
	return false
end

function Keis:die(killer: Player?)
	if not self.alive then
		return
	end
	self.alive = false
	Keis.registry[self.model] = nil
	Keis.hooks.onKilled(self, killer)

	-- pop: shrink + fade, and a burst
	local center = self.root.Position + Vector3.new(0, 4 * self.def.scale, 0)
	local burst = Instance.new("Part")
	burst.Shape = Enum.PartType.Ball
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.Material = Enum.Material.Neon
	burst.Color = if self.def.passive then Color3.fromRGB(255, 215, 70) else Color3.fromRGB(255, 120, 60)
	burst.Size = Vector3.one * 2
	burst.CFrame = CFrame.new(center)
	burst.Parent = workspace
	TweenService:Create(burst, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * 9 * self.def.scale, Transparency = 1 }):Play()
	task.delay(0.4, function()
		burst:Destroy()
	end)
	for _, d in self.model:GetDescendants() do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		end
	end
	local chant = self.root:FindFirstChild("Chant")
	if chant then
		chant:Destroy()
	end
	self.humanoid.WalkSpeed = 0
	task.delay(0.3, function()
		self.model:Destroy()
	end)
end

function Keis:destroy()
	self.alive = false
	Keis.registry[self.model] = nil
	self.model:Destroy()
end

-- Movement ----------------------------------------------------------------------------------
function Keis:hasLineOfSight(pos: Vector3, ignore: Instance?): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list: { Instance } = { Keis.hooks.folder or self.model }
	if ignore then
		table.insert(list, ignore)
	end
	params.FilterDescendantsInstances = list
	local from = self.root.Position + Vector3.new(0, 1, 0)
	local to = Vector3.new(pos.X, from.Y, pos.Z)
	return workspace:Raycast(from, to - from, params) == nil
end

function Keis:pathTo(pos: Vector3)
	self.lastPath = os.clock()
	local ok = pcall(function()
		self.path:ComputeAsync(self.root.Position, pos)
	end)
	if ok and self.path.Status == Enum.PathStatus.Success then
		self.waypoints = self.path:GetWaypoints()
		self.wpIndex = 2
	else
		self.waypoints = nil
	end
end

function Keis:moveTowards(pos: Vector3, ignore: Instance?)
	local flat = Vector3.new(pos.X - self.root.Position.X, 0, pos.Z - self.root.Position.Z)
	if flat.Magnitude < 45 and self:hasLineOfSight(pos, ignore) then
		self.waypoints = nil
		self.humanoid:MoveTo(pos)
		return
	end
	if self.waypoints == nil or os.clock() - self.lastPath > 1.2 then
		self:pathTo(pos)
	end
	local wps = self.waypoints
	if wps and self.wpIndex <= #wps then
		local wp = wps[self.wpIndex]
		self.humanoid:MoveTo(wp.Position)
		local d = Vector3.new(wp.Position.X - self.root.Position.X, 0, wp.Position.Z - self.root.Position.Z)
		if d.Magnitude < 3 * math.max(1, self.def.scale) then
			self.wpIndex += 1
		end
	end
end

function Keis:step()
	if not self.model.Parent then
		self.alive = false
		Keis.registry[self.model] = nil
		return
	end
	local def = self.def
	local hooks = Keis.hooks
	self.humanoid.WalkSpeed = def.speed + (if def.passive then 0 else hooks.speedBonus)

	-- unstick
	if (self.root.Position - self.lastPos).Magnitude > 1 then
		self.lastPos = self.root.Position
		self.lastProgress = os.clock()
	elseif os.clock() - self.lastProgress > 2.5 then
		self.waypoints = nil
		self.lastPath = 0
		self.wanderGoal = nil
		self.lastProgress = os.clock()
	end

	-- golden keis: runs around, then escapes
	if def.passive then
		if os.clock() - self.bornAt > (def.lifetime or 25) then
			self.alive = false
			Keis.registry[self.model] = nil
			hooks.onExpired(self)
			self.model:Destroy()
			return
		end
		if self.wanderGoal == nil or (self.root.Position - self.wanderGoal).Magnitude < 6 then
			local rooms = hooks.roomCenters
			self.wanderGoal = rooms[math.random(1, #rooms)] + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
			self.waypoints = nil
		end
		self:moveTowards(self.wanderGoal :: Vector3)
		return
	end

	-- the boss summons minis
	if def.summon and os.clock() - self.lastSummon > (def.summonEvery or 8) then
		self.lastSummon = os.clock()
		hooks.onSummon(self)
	end

	-- pick a target: a nearby crew member, otherwise the reactor
	local aggro = if def.boss then 70 else 45
	local best: Model? = nil
	local bestDist = aggro
	for _, character in hooks.getTargets() do
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local d = (hrp.Position - self.root.Position).Magnitude
			if d < bestDist then
				best, bestDist = character, d
			end
		end
	end

	local now = os.clock()
	local cooldown = if def.boss then 1.4 else 1
	if best then
		local hrp = best:FindFirstChild("HumanoidRootPart") :: BasePart
		if bestDist <= 3.5 + 1.6 * def.scale then
			self.humanoid:MoveTo(hrp.Position)
			if now - self.lastAttack > cooldown then
				self.lastAttack = now
				hooks.onAttackPlayer(self, best, def.damage)
			end
			return
		end
		self:moveTowards(hrp.Position, best)
		return
	end

	local reactor = hooks.reactor
	if reactor then
		local flat = Vector3.new(reactor.Position.X - self.root.Position.X, 0, reactor.Position.Z - self.root.Position.Z)
		if flat.Magnitude <= hooks.reactorRadius + 2 + 1.6 * def.scale then
			self.humanoid:MoveTo(self.root.Position)
			if now - self.lastAttack > cooldown then
				self.lastAttack = now
				hooks.onAttackReactor(self, def.damage)
			end
			return
		end
		-- walk to the edge of the reactor (its center is solid, so a path there would fail)
		local out = Vector3.new(-flat.X, 0, -flat.Z)
		if out.Magnitude < 0.1 then
			out = Vector3.new(1, 0, 0)
		end
		local goal = Vector3.new(reactor.Position.X, self.root.Position.Y, reactor.Position.Z) + out.Unit * (hooks.reactorRadius + 1.5)
		self:moveTowards(goal)
	end
end

return Keis
