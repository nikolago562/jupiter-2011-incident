--!strict
-- Keys (dropped by Keis, pulled toward players) and supply crates (opened with keys between waves).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Loot = {}

Loot.hooks = {
	crewChars = function(): { Model }
		return {}
	end,
	magnetRange = function(_player: Player): number
		return 8
	end,
	onKeysCollected = function(_player: Player, _amount: number) end,
	onCrateReward = function(_player: Player, _kind: string) end,
}

local folder = Instance.new("Folder")
folder.Name = "Loot"
folder.Parent = workspace

local BRASS = Color3.fromRGB(214, 172, 70)
local GOLD = Color3.fromRGB(255, 205, 64)

type Key = { model: Model, value: number, born: number, base: Vector3 }
local keys: { Key } = {}
local crates: { Model } = {}

function Loot.getKeys(player: Player): number
	return (player:GetAttribute("Keys") :: number?) or 0
end

function Loot.addKeys(player: Player, amount: number)
	player:SetAttribute("Keys", Loot.getKeys(player) + amount)
end

function Loot.spendKeys(player: Player, amount: number): boolean
	local have = Loot.getKeys(player)
	if have < amount then
		return false
	end
	player:SetAttribute("Keys", have - amount)
	return true
end

function Loot.resetKeys(player: Player)
	player:SetAttribute("Keys", 0)
end

local function keyModel(pos: Vector3, golden: boolean): Model
	local m = Instance.new("Model")
	m.Name = "KeyPickup"
	local color = if golden then GOLD else BRASS
	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = Vector3.new(0.3, 1.4, 0.3)
	shaft.Material = Enum.Material.Neon
	shaft.Color = color
	shaft.Anchored = true
	shaft.CanCollide = false
	shaft.CanQuery = false
	shaft.CanTouch = false
	shaft.CFrame = CFrame.new(pos)
	shaft.Parent = m
	local bow = shaft:Clone()
	bow.Name = "Bow"
	bow.Shape = Enum.PartType.Cylinder
	bow.Size = Vector3.new(0.25, 0.9, 0.9)
	bow.CFrame = CFrame.new(pos + Vector3.new(0, 0.95, 0)) * CFrame.Angles(0, math.rad(90), 0)
	bow.Parent = m
	local bit = shaft:Clone()
	bit.Name = "Bit"
	bit.Size = Vector3.new(0.45, 0.25, 0.3)
	bit.CFrame = CFrame.new(pos + Vector3.new(0.25, -0.5, 0))
	bit.Parent = m
	m.PrimaryPart = shaft
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = if golden then 12 else 7
	light.Brightness = 1.5
	light.Parent = shaft
	m.Parent = folder
	return m
end

function Loot.dropKeys(pos: Vector3, count: number, golden: boolean?)
	for i = 1, count do
		local offset = Vector3.new(math.random(-20, 20) / 10, 1.6, math.random(-20, 20) / 10)
		local base = pos + offset
		table.insert(keys, { model = keyModel(base, golden == true), value = if golden then 3 else 1, born = os.clock() + i * 0.05, base = base })
	end
end

function Loot.clearKeys()
	for _, k in keys do
		k.model:Destroy()
	end
	keys = {}
end

-- spin, bob, magnet and collect
task.spawn(function()
	while true do
		local dt = task.wait(0.05)
		local now = os.clock()
		local players = {}
		for _, p in Players:GetPlayers() do
			if p:GetAttribute("CrewStatus") == "alive" and p.Character then
				local hrp = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					table.insert(players, { player = p, pos = hrp.Position, range = Loot.hooks.magnetRange(p) })
				end
			end
		end
		for i = #keys, 1, -1 do
			local k = keys[i]
			if now - k.born > 45 or not k.model.Parent then
				k.model:Destroy()
				table.remove(keys, i)
				continue
			end
			local target, best = nil, math.huge
			for _, e in players do
				local d = (e.pos - k.base).Magnitude
				if d < e.range and d < best then
					target, best = e, d
				end
			end
			if target and best < 3 then
				Loot.addKeys(target.player, k.value)
				Loot.hooks.onKeysCollected(target.player, k.value)
				k.model:Destroy()
				table.remove(keys, i)
				continue
			elseif target then
				k.base = k.base:Lerp(target.pos, math.min(dt * 9, 1))
			end
			local spin = CFrame.Angles(0, now * 3, 0)
			k.model:PivotTo(CFrame.new(k.base + Vector3.new(0, math.sin(now * 3 + i) * 0.25, 0)) * spin)
		end
	end
end)

-- Supply crates -------------------------------------------------------------------------------------
local REWARDS = {
	{ kind = "Credits", w = 38 },
	{ kind = "Heal", w = 20 },
	{ kind = "Perk", w = 24 },
	{ kind = "Keys", w = 12 },
	{ kind = "Legendary", w = 6 },
}

local function rollReward(): string
	local total = 0
	for _, r in REWARDS do
		total += r.w
	end
	local roll = math.random() * total
	for _, r in REWARDS do
		roll -= r.w
		if roll <= 0 then
			return r.kind
		end
	end
	return "Credits"
end

local function crate(pos: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "SupplyCrate"
	local function piece(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = collide
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.Parent = m
		return p
	end
	local body = piece("Body", Vector3.new(4.2, 2.6, 2.8), CFrame.new(pos + Vector3.new(0, 1.3, 0)), Color3.fromRGB(70, 74, 82), Enum.Material.DiamondPlate, true)
	piece("Lid", Vector3.new(4.4, 0.5, 3), CFrame.new(pos + Vector3.new(0, 2.85, 0)), Color3.fromRGB(90, 95, 104), Enum.Material.Metal, false)
	piece("Stripe", Vector3.new(4.25, 0.35, 2.85), CFrame.new(pos + Vector3.new(0, 1.9, 0)), Color3.fromRGB(255, 138, 61), Enum.Material.SmoothPlastic, false)
	local lock = piece("Lock", Vector3.new(0.7, 0.7, 0.2), CFrame.new(pos + Vector3.new(0, 1.9, -1.5)), Color3.fromRGB(255, 205, 64), Enum.Material.Neon, false)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 205, 64)
	l.Range = 9
	l.Parent = lock
	m.PrimaryPart = body
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Unlock (1 key)"
	prompt.ObjectText = "SUPPLY CRATE"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("CrewStatus") ~= "alive" or not prompt.Enabled then
			return
		end
		if not Loot.spendKeys(player, 1) then
			return
		end
		prompt.Enabled = false
		local lid = m:FindFirstChild("Lid") :: BasePart
		TweenService:Create(lid, TweenInfo.new(0.4, Enum.EasingStyle.Back), { CFrame = lid.CFrame * CFrame.new(0, 0.8, 1.2) * CFrame.Angles(math.rad(-70), 0, 0) }):Play()
		lock.Color = Color3.fromRGB(110, 230, 150)
		l.Color = lock.Color
		Loot.hooks.onCrateReward(player, rollReward())
		Debris:AddItem(m, 6)
	end)
	m.Parent = folder
	return m
end

function Loot.spawnCrates(points: { Vector3 }, count: number)
	Loot.clearCrates()
	local pool = table.clone(points)
	for _ = 1, math.min(count, #pool) do
		local i = math.random(1, #pool)
		local p = pool[i]
		table.remove(pool, i)
		table.insert(crates, crate(p))
	end
end

function Loot.clearCrates()
	for _, c in crates do
		c:Destroy()
	end
	crates = {}
end

return Loot
