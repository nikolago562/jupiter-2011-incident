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

local KeisModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("KeisModel"))
local buildModel = KeisModel.build


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
