--!strict
-- Wave missions. Every wave picks one, so no two waves play the same.
--   Defend   – destroy every Keis (classic)
--   Boss     – the Master Keis boards (every 5th wave)
--   Blackout – power is dead: find 3 fuses and carry them to the fuse box
--   Upload   – stand in the beacon zone until the signal is transmitted
--   Hunt     – kill the Keymaster before it escapes
--   GoldRush – golden Keis everywhere for a short time

local Players = game:GetService("Players")

local Missions = {}

Missions.Defs = {
	Defend = { name = "HOLD THE LINE", desc = "DESTROY EVERY KEIS", weight = 4, minWave = 1 },
	Blackout = { name = "BLACKOUT", desc = "FIND 3 FUSES · BRING THEM TO THE FUSE BOX", weight = 3, minWave = 2 },
	Upload = { name = "TRANSMIT", desc = "HOLD THE BEACON ZONE UNTIL THE SIGNAL IS SENT", weight = 3, minWave = 3 },
	Hunt = { name = "KEYMASTER HUNT", desc = "KILL THE KEYMASTER BEFORE IT ESCAPES", weight = 2, minWave = 4 },
	GoldRush = { name = "GOLD RUSH", desc = "GOLDEN KEIS EVERYWHERE · GRAB WHAT YOU CAN", weight = 1, minWave = 4 },
	Boss = { name = "MASTER KEIS", desc = "DESTROY THE MASTER KEIS", weight = 0, minWave = 99 },
}

function Missions.pick(n: number, rng: Random, last: string?, bossEvery: number): string
	if n % bossEvery == 0 then
		return "Boss"
	end
	if n == 1 then
		return "Defend"
	end
	local pool, total = {}, 0
	for kind, def in Missions.Defs do
		if def.weight > 0 and n >= def.minWave and kind ~= last then
			table.insert(pool, { kind = kind, w = def.weight })
			total += def.weight
		end
	end
	local roll = rng:NextNumber() * total
	for _, e in pool do
		roll -= e.w
		if roll <= 0 then
			return e.kind
		end
	end
	return "Defend"
end

export type Ctx = {
	n: number,
	rng: Random,
	folder: Instance,
	reactorPos: Vector3,
	points: { Vector3 }, -- floor positions around the map (room centers / moon spots)
	count: number, -- how many Keis a count-based wave spawns
	spawnKeis: (typeId: string, at: Vector3?, hpScale: number) -> any,
	hpScale: number,
	isAlive: (player: Player) -> boolean,
	setPower: (on: boolean) -> (),
	narrate: (key: string, name: string?) -> (),
	notify: (text: string, color: string) -> (),
	setObjective: (text: string, progress: number?) -> (),
	damageReactor: (amount: number) -> (),
}

local function neon(parent: Instance, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Parent = parent
	return p
end

local function billboard(adornee: BasePart, text: string, color: Color3): TextLabel
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 40)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	bb.Adornee = adornee
	bb.Parent = adornee
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.3
	l.Text = text
	l.Parent = bb
	return l
end

local function farPoints(ctx: Ctx, minDist: number): { Vector3 }
	local list = {}
	for _, p in ctx.points do
		if (Vector3.new(p.X, 0, p.Z) - Vector3.new(ctx.reactorPos.X, 0, ctx.reactorPos.Z)).Magnitude >= minDist then
			table.insert(list, p)
		end
	end
	return if #list > 0 then list else ctx.points
end

local function aliveChars(ctx: Ctx): { [Player]: BasePart }
	local out = {}
	for _, p in Players:GetPlayers() do
		if ctx.isAlive(p) and p.Character then
			local hrp = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				out[p] = hrp
			end
		end
	end
	return out
end

-- A mission: spawnMode "count" (wave ends when all Keis are dead) or "timed" (Keis keep coming until tick() says done)
export type Mission = {
	kind: string,
	spawnMode: string,
	success: boolean,
	start: (self: Mission) -> (),
	tick: (self: Mission, dt: number, hostileLeft: number) -> boolean,
	cleanup: (self: Mission) -> (),
}

function Missions.create(kind: string, ctx: Ctx): Mission
	local m: any = { kind = kind, spawnMode = "count", success = true }
	local objects = Instance.new("Folder")
	objects.Name = "MissionObjects"
	objects.Parent = ctx.folder

	function m:cleanup()
		objects:Destroy()
		for _, p in Players:GetPlayers() do
			p:SetAttribute("CarryingFuse", nil)
		end
	end

	if kind == "Defend" or kind == "Boss" then
		function m:start()
			if kind == "Boss" then
				ctx.spawnKeis("Master", nil, ctx.hpScale * (1 + 0.35 * (#Players:GetPlayers() - 1)))
				ctx.narrate("Boss")
			end
		end
		function m:tick(_dt: number, hostileLeft: number): boolean
			ctx.setObjective(`{Missions.Defs[kind].desc} · {hostileLeft} LEFT`, nil)
			return false -- count mode: the wave loop ends it
		end

	elseif kind == "Blackout" then
		m.spawnMode = "timed"
		local inserted = 0
		local fuses: { { part: BasePart, prompt: ProximityPrompt, carrier: Player?, home: Vector3, done: boolean } } = {}
		local box: BasePart
		function m:start()
			ctx.setPower(false)
			ctx.narrate("Outage")
			-- fuse box next to the reactor
			local bp = ctx.reactorPos + Vector3.new(11, 0, 11)
			box = Instance.new("Part")
			box.Anchored = true
			box.Size = Vector3.new(3, 5, 1.5)
			box.CFrame = CFrame.new(Vector3.new(bp.X, ctx.points[1].Y + 2.5, bp.Z))
			box.Color = Color3.fromRGB(60, 62, 70)
			box.Material = Enum.Material.Metal
			box.Name = "FuseBox"
			box.Parent = objects
			neon(objects, Vector3.new(3.1, 0.4, 1.6), box.CFrame * CFrame.new(0, 1.8, 0), Color3.fromRGB(255, 200, 40))
			billboard(box, "FUSE BOX", Color3.fromRGB(255, 205, 64))
			local boxPrompt = Instance.new("ProximityPrompt")
			boxPrompt.ActionText = "Insert fuse"
			boxPrompt.ObjectText = "FUSE BOX"
			boxPrompt.HoldDuration = 0.6
			boxPrompt.RequiresLineOfSight = false
			boxPrompt.MaxActivationDistance = 9
			boxPrompt.Parent = box
			boxPrompt.Triggered:Connect(function(player)
				for _, f in fuses do
					if f.carrier == player and not f.done then
						f.done = true
						f.carrier = nil
						player:SetAttribute("CarryingFuse", nil)
						f.part:Destroy()
						inserted += 1
						ctx.notify(`{player.DisplayName} inserted a fuse ({inserted}/3)`, "gold")
						break
					end
				end
			end)
			-- 3 fuses in far rooms
			local spots = farPoints(ctx, 25)
			for i = 1, 3 do
				local _ = i
				local p = spots[ctx.rng:NextInteger(1, #spots)] + Vector3.new(ctx.rng:NextNumber(-5, 5), 1.2, ctx.rng:NextNumber(-5, 5))
				local fuse = neon(objects, Vector3.new(2.2, 0.9, 0.9), CFrame.new(p) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 200, 40), Enum.PartType.Cylinder)
				fuse.Name = "Fuse"
				local l = Instance.new("PointLight")
				l.Color = fuse.Color
				l.Range = 14
				l.Brightness = 2
				l.Parent = fuse
				billboard(fuse, "FUSE", Color3.fromRGB(255, 205, 64))
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Pick up"
				prompt.ObjectText = "FUSE"
				prompt.RequiresLineOfSight = false
				prompt.MaxActivationDistance = 8
				prompt.Parent = fuse
				local entry = { part = fuse :: BasePart, prompt = prompt, carrier = nil :: Player?, home = p, done = false }
				prompt.Triggered:Connect(function(player)
					if entry.carrier or not ctx.isAlive(player) or player:GetAttribute("CarryingFuse") then
						return
					end
					entry.carrier = player
					player:SetAttribute("CarryingFuse", true)
					prompt.Enabled = false
				end)
				table.insert(fuses, entry)
			end
		end
		function m:tick(_dt: number, _hostile: number): boolean
			for _, f in fuses do
				if f.carrier and not f.done then
					local c = f.carrier :: Player
					local hrp = c.Character and c.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if not ctx.isAlive(c) or not hrp then
						-- dropped where the carrier went down
						c:SetAttribute("CarryingFuse", nil)
						f.carrier = nil
						f.prompt.Enabled = true
						if hrp then
							f.part.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, 0, math.rad(90))
						end
					else
						f.part.CFrame = hrp.CFrame * CFrame.new(0, 0.5, 1.2) * CFrame.Angles(0, 0, math.rad(90))
					end
				end
			end
			ctx.setObjective(`FUSES {inserted} / 3 · BRING THEM TO THE FUSE BOX`, inserted / 3)
			if inserted >= 3 then
				ctx.setPower(true)
				ctx.narrate("PowerBack")
				return true
			end
			return false
		end

	elseif kind == "Upload" then
		m.spawnMode = "timed"
		local progress = 0
		local center: Vector3
		local label: TextLabel
		local RADIUS = 10
		function m:start()
			local spots = farPoints(ctx, 20)
			center = spots[ctx.rng:NextInteger(1, #spots)]
			neon(objects, Vector3.new(0.3, RADIUS * 2, RADIUS * 2), CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(90, 220, 255), Enum.PartType.Cylinder).Transparency = 0.55
			local beam = neon(objects, Vector3.new(60, 3, 3), CFrame.new(center + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(90, 220, 255), Enum.PartType.Cylinder)
			beam.Transparency = 0.7
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(90, 220, 255)
			l.Range = 30
			l.Brightness = 2
			l.Parent = beam
			label = billboard(beam, "UPLOAD 0%", Color3.fromRGB(90, 220, 255))
			ctx.notify("A beacon is online. Stand in the zone to transmit", "cyan")
		end
		function m:tick(dt: number, _hostile: number): boolean
			local inside = 0
			for _, hrp in aliveChars(ctx) do
				if (Vector3.new(hrp.Position.X - center.X, 0, hrp.Position.Z - center.Z)).Magnitude <= RADIUS then
					inside += 1
				end
			end
			if inside > 0 then
				progress += dt / 40 * (1 + 0.3 * (inside - 1))
			else
				progress = math.max(0, progress - dt / 120)
			end
			progress = math.min(progress, 1)
			label.Text = `UPLOAD {math.floor(progress * 100)}%`
			ctx.setObjective(if inside > 0 then `TRANSMITTING · {math.floor(progress * 100)}%` else `GET IN THE BEACON ZONE · {math.floor(progress * 100)}%`, progress)
			return progress >= 1
		end

	elseif kind == "Hunt" then
		m.spawnMode = "timed"
		local keymaster: any = nil
		local deadline = 0
		function m:start()
			keymaster = ctx.spawnKeis("Keymaster", nil, ctx.hpScale)
			local hl = Instance.new("Highlight")
			hl.FillColor = Color3.fromRGB(255, 200, 40)
			hl.OutlineColor = Color3.fromRGB(255, 60, 30)
			hl.FillTransparency = 0.6
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.Parent = keymaster.model
			billboard(keymaster.root, "▼ KEYMASTER ▼", Color3.fromRGB(255, 205, 64))
			deadline = os.clock() + 75
		end
		function m:tick(_dt: number, _hostile: number): boolean
			local left = math.max(0, math.ceil(deadline - os.clock()))
			ctx.setObjective(string.format("KILL THE KEYMASTER · %d:%02d", left // 60, left % 60), 1 - left / 75)
			if keymaster and not keymaster.alive then
				return true
			end
			if left <= 0 then
				m.success = false
				if keymaster and keymaster.alive then
					keymaster:destroy()
				end
				ctx.damageReactor(250)
				ctx.notify("The Keymaster escaped and sabotaged the reactor", "red")
				return true
			end
			return false
		end

	elseif kind == "GoldRush" then
		m.spawnMode = "timed"
		local endsAt = 0
		local nextGold = 0
		function m:start()
			endsAt = os.clock() + 35
			ctx.narrate("Golden")
		end
		function m:tick(_dt: number, _hostile: number): boolean
			local now = os.clock()
			if now >= nextGold then
				nextGold = now + 1.1
				ctx.spawnKeis("Golden", nil, 1 + ctx.n * 0.05)
			end
			local left = math.max(0, math.ceil(endsAt - now))
			ctx.setObjective(`GOLD RUSH · {left}s`, 1 - left / 35)
			return now >= endsAt
		end
	end

	return m :: Mission
end

return Missions
