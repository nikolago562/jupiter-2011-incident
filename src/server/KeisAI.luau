--!strict
-- The Keis: key-shaped entities that hunt the crew and chant "keis keis keis".

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local BRASS = Color3.fromRGB(176, 142, 66)

local Keis = {}
Keis.__index = Keis

export type KeisOptions = {
	position: Vector3,
	cells: { Vector3 },
	parent: Instance,
	getSpeed: () -> number,
	getTargets: () -> { Model },
	onKill: (character: Model) -> (),
}

local function weldTo(root: BasePart, part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = part
	w.Parent = part
end

local function buildModel(position: Vector3): (Model, Humanoid, BasePart, TextLabel, BasePart)
	local model = Instance.new("Model")
	model.Name = "Keis"

	local HIP = 2
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CFrame = CFrame.new(position + Vector3.new(0, HIP + 1, 0))
	root.Parent = model
	model.PrimaryPart = root

	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.Color = color
		p.Material = material
		p.CFrame = root.CFrame * offset
		p.Parent = model
		weldTo(root, p)
		return p
	end

	-- shaft + teeth
	piece("Shaft", Vector3.new(0.9, 6.5, 0.9), CFrame.new(0, 0.75, 0), BRASS, Enum.Material.Metal)
	piece("ToothA", Vector3.new(1.4, 0.8, 0.9), CFrame.new(0.9, -1.6, 0), BRASS, Enum.Material.Metal)
	piece("ToothB", Vector3.new(1.0, 0.8, 0.9), CFrame.new(0.7, -0.4, 0), BRASS, Enum.Material.Metal)
	-- the bow (ring head), facing forward
	local bow = piece("Bow", Vector3.new(0.9, 5.5, 5.5), CFrame.new(0, 6.5, 0) * CFrame.Angles(0, math.rad(90), 0), BRASS, Enum.Material.Metal, Enum.PartType.Cylinder)
	-- the face in the bow (like the meme keys). Uses Config.KeisFaceImage if set, otherwise a drawn face.
	local eye = piece("Face", Vector3.new(3.6, 3.6, 0.1), CFrame.new(0, 6.5, -0.5), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	eye.Transparency = 1
	local faceGui = Instance.new("SurfaceGui")
	faceGui.Face = Enum.NormalId.Front
	faceGui.LightInfluence = 0.4
	faceGui.CanvasSize = Vector2.new(200, 200)
	faceGui.Parent = eye
	local skin = Instance.new("Frame")
	skin.Size = UDim2.fromScale(1, 1)
	skin.BackgroundColor3 = Color3.fromRGB(196, 160, 130)
	skin.Parent = faceGui
	Instance.new("UICorner", skin).CornerRadius = UDim.new(0.5, 0)
	if Config.KeisFaceImage ~= "" then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.Image = Config.KeisFaceImage
		img.Parent = skin
		Instance.new("UICorner", img).CornerRadius = UDim.new(0.5, 0)
	else
		local function blob(x: number, y: number, w: number, h: number, color: Color3)
			local f = Instance.new("Frame")
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Position = UDim2.fromScale(x, y)
			f.Size = UDim2.fromScale(w, h)
			f.BackgroundColor3 = color
			f.BorderSizePixel = 0
			f.Parent = skin
			Instance.new("UICorner", f).CornerRadius = UDim.new(0.5, 0)
		end
		blob(0.32, 0.36, 0.2, 0.14, Color3.new(0.05, 0.05, 0.05)) -- eyes
		blob(0.68, 0.36, 0.2, 0.14, Color3.new(0.05, 0.05, 0.05))
		blob(0.32, 0.36, 0.06, 0.06, Color3.fromRGB(255, 30, 30)) -- pupils
		blob(0.68, 0.36, 0.06, 0.06, Color3.fromRGB(255, 30, 30))
		blob(0.5, 0.72, 0.62, 0.3, Color3.fromRGB(120, 60, 60)) -- big lips
		blob(0.5, 0.72, 0.5, 0.06, Color3.fromRGB(40, 15, 15))
	end

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 20, 20)
	glow.Range = 14
	glow.Brightness = 3
	glow.Parent = eye

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = HIP
	humanoid.WalkSpeed = Config.KEIS_BASE_SPEED
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model
	for _, state in { Enum.HumanoidStateType.Dead, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Seated } do
		humanoid:SetStateEnabled(state, false)
	end

	-- floating chant text
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(260, 50)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.MaxDistance = 70
	billboard.AlwaysOnTop = false
	billboard.Adornee = bow
	billboard.Parent = model
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(255, 40, 40)
	text.TextStrokeTransparency = 0.3
	text.Font = Enum.Font.Arcade
	text.TextScaled = true
	text.Text = "KEIS KEIS KEIS"
	text.Parent = billboard

	if Config.Sounds.KeisChant ~= "" then
		local chant = Instance.new("Sound")
		chant.Name = "Chant"
		chant.SoundId = Config.Sounds.KeisChant
		chant.Looped = true
		chant.Volume = 1
		chant.RollOffMaxDistance = 90
		chant.RollOffMinDistance = 8
		chant.RollOffMode = Enum.RollOffMode.InverseTapered
		local pitch = Instance.new("PitchShiftSoundEffect")
		pitch.Octave = 0.8
		pitch.Parent = chant
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime = 4
		reverb.Parent = chant
		chant.Parent = root
		chant:Play()
	end

	return model, humanoid, root, text, eye
end

function Keis.new(opts: KeisOptions)
	local self = setmetatable({}, Keis)
	local model, humanoid, root, text, eye = buildModel(opts.position)
	self.model = model
	self.humanoid = humanoid
	self.root = root
	self.text = text
	self.eye = eye
	self.opts = opts
	self.alive = true
	self.waypoints = nil :: { PathWaypoint }?
	self.wpIndex = 1
	self.lastPath = 0
	self.lastKill = 0
	self.stunnedUntil = 0
	self.lastProgress = os.clock()
	self.lastPos = root.Position
	self.path = PathfindingService:CreatePath({
		AgentRadius = 2.2,
		AgentHeight = 10,
		AgentCanJump = false,
		WaypointSpacing = 6,
	})

	model.Parent = opts.parent
	root:SetNetworkOwner(nil)

	task.spawn(function()
		while self.alive do
			self:step()
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		local rng = Random.new()
		while self.alive do
			self.text.Text = Config.KeisChatter[rng:NextInteger(1, #Config.KeisChatter)]
			self.text.Rotation = rng:NextNumber(-6, 6)
			task.wait(rng:NextNumber(0.6, 2.2))
		end
	end)

	return self
end

function Keis:findTarget(): (Model?, number)
	local best, bestDist = nil, math.huge
	for _, character in self.opts.getTargets() do
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - self.root.Position).Magnitude
			if d < bestDist and d <= Config.KEIS_HEARING_RANGE then
				best, bestDist = character, d
			end
		end
	end
	return best, bestDist
end

function Keis:canSee(character: Model): boolean
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.model, character }
	local from = self.root.Position + Vector3.new(0, 2, 0)
	return workspace:Raycast(from, hrp.Position - from, params) == nil
end

function Keis:pathTo(position: Vector3)
	self.lastPath = os.clock()
	local ok = pcall(function()
		self.path:ComputeAsync(self.root.Position, position)
	end)
	if ok and self.path.Status == Enum.PathStatus.Success then
		self.waypoints = self.path:GetWaypoints()
		self.wpIndex = 2
	else
		self.waypoints = nil
	end
end

function Keis:kill(character: Model)
	if os.clock() - self.lastKill < 1.5 then
		return
	end
	self.lastKill = os.clock()
	self.opts.onKill(character)
end

function Keis:step()
	if not self.model.Parent then
		self.alive = false
		return
	end
	local light = self.eye:FindFirstChildOfClass("PointLight")
	if os.clock() < self.stunnedUntil then
		self.humanoid:MoveTo(self.root.Position)
		if light then
			light.Enabled = math.random() < 0.3
		end
		return
	elseif light then
		light.Enabled = true
	end
	self.humanoid.WalkSpeed = self.opts.getSpeed()

	-- unstick: if we haven't moved in a while, drop the path
	if (self.root.Position - self.lastPos).Magnitude > 1 then
		self.lastPos = self.root.Position
		self.lastProgress = os.clock()
	elseif os.clock() - self.lastProgress > 2.5 then
		self.waypoints = nil
		self.lastPath = 0
		self.lastProgress = os.clock()
	end

	local target, dist = self:findTarget()
	if target then
		local hrp = target:FindFirstChild("HumanoidRootPart") :: BasePart
		if dist <= Config.KEIS_KILL_RANGE then
			self:kill(target)
			return
		end
		if dist <= Config.KEIS_DIRECT_CHASE_RANGE and self:canSee(target) then
			self.waypoints = nil
			self.humanoid:MoveTo(hrp.Position)
			return
		end
		if os.clock() - self.lastPath > 0.8 then
			self:pathTo(hrp.Position)
		end
	else
		local done = self.waypoints == nil or self.wpIndex > #(self.waypoints :: { PathWaypoint })
		if done and os.clock() - self.lastPath > 1.5 then
			local cells = self.opts.cells
			self:pathTo(cells[math.random(1, #cells)])
		end
	end

	local wps = self.waypoints
	if wps and self.wpIndex <= #wps then
		local wp = wps[self.wpIndex]
		self.humanoid:MoveTo(wp.Position)
		local flat = Vector3.new(wp.Position.X - self.root.Position.X, 0, wp.Position.Z - self.root.Position.Z)
		if flat.Magnitude < 3 then
			self.wpIndex += 1
		end
	end
end

function Keis:stun(seconds: number)
	self.stunnedUntil = os.clock() + seconds
	self.text.Text = "K E I S . . ."
	self.waypoints = nil
end

function Keis:destroy()
	self.alive = false
	self.model:Destroy()
end

return Keis
