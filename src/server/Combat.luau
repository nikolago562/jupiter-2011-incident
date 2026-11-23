--!strict
-- Weapons, credits and upgrades. The server checks every shot and purchase; clients only send intent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Keis = require(script.Parent:WaitForChild("KeisAI"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local Combat = {}

type State = {
	weapon: string,
	credits: number,
	upgrades: { [string]: number },
	ammo: number,
	reloading: boolean,
	lastShot: number,
	kills: number,
	damageDealt: number,
}
local states: { [Player]: State } = {}

Combat.hooks = {
	canShoot = function(_player: Player): boolean
		return true
	end,
	repairReactor = function(_player: Player): boolean
		return false
	end,
}

local remotes: Folder

local function upgradeDef(id: string)
	for _, u in Config.Upgrades do
		if u.id == id then
			return u
		end
	end
	return nil
end

function Combat.stats(player: Player)
	local st = states[player]
	local up = if st then st.upgrades else {}
	local data = PlayerData.get(player)
	local level = if data then data.Level else 1
	local W = Config.Weapons[if st then st.weapon else "Blaster"] or Config.Weapons.Blaster
	return {
		damage = W.damage * (1 + 0.2 * (up.Damage or 0)) * (1 + Config.LEVEL_DAMAGE_BONUS * (level - 1)),
		interval = W.interval * (0.88 ^ (up.FireRate or 0)),
		mag = W.mag + W.magPerLevel * (up.Mag or 0),
		reload = W.reload,
		jitter = W.jitter,
		pellets = 1 + (up.Multishot or 0),
		maxHealth = Config.BASE_HEALTH + 25 * (up.MaxHealth or 0),
		walkSpeed = Config.BASE_WALKSPEED + 1.5 * (up.Speed or 0),
	}
end

local function publish(player: Player)
	local st = states[player]
	if not st then
		return
	end
	local s = Combat.stats(player)
	player:SetAttribute("Credits", st.credits)
	player:SetAttribute("Weapon", st.weapon)
	player:SetAttribute("Ammo", st.ammo)
	player:SetAttribute("MagSize", s.mag)
	player:SetAttribute("Reloading", st.reloading)
	player:SetAttribute("FireInterval", s.interval)
	player:SetAttribute("RunKills", st.kills)
	for _, u in Config.Upgrades do
		player:SetAttribute("Up_" .. u.id, st.upgrades[u.id] or 0)
	end
end

function Combat.reset(player: Player)
	states[player] = {
		weapon = "Blaster",
		credits = 0,
		upgrades = {},
		ammo = Config.Weapons.Blaster.mag,
		reloading = false,
		lastShot = 0,
		kills = 0,
		damageDealt = 0,
	}
	publish(player)
end

function Combat.remove(player: Player)
	states[player] = nil
end

function Combat.getRunStats(player: Player): (number, number)
	local st = states[player]
	if not st then
		return 0, 0
	end
	return st.kills, math.floor(st.damageDealt)
end

function Combat.addCredits(player: Player, amount: number)
	local st = states[player]
	if st then
		st.credits += amount
		publish(player)
	end
end

function Combat.addKill(player: Player)
	local st = states[player]
	if st then
		st.kills += 1
		publish(player)
	end
end

local function makeWeapon(weaponId: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = if weaponId == "Minigun" then "Minigun" else "Blaster"
	tool.ToolTip = "Hold to fire · R to reload"
	tool.CanBeDropped = false
	tool:SetAttribute("IsWeapon", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 1, 0.7)
	handle.Color = Color3.fromRGB(60, 60, 64)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool
	local function attach(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.Massless = true
		p.CFrame = handle.CFrame * offset
		p.Parent = tool
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
	end
	if weaponId == "Minigun" then
		tool.Grip = CFrame.new(0, -0.3, 0.9)
		local gunmetal = Color3.fromRGB(45, 46, 50)
		attach("Body", Vector3.new(1, 1, 2.2), CFrame.new(0, 0.6, -0.9), gunmetal, Enum.Material.Metal)
		-- six rotating-style barrels around a hub
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			attach("Barrel", Vector3.new(3.2, 0.22, 0.22), CFrame.new(math.cos(a) * 0.32, 0.6 + math.sin(a) * 0.32, -3.3) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(70, 70, 74), Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		attach("Hub", Vector3.new(0.3, 1, 1), CFrame.new(0, 0.6, -2.2) * CFrame.Angles(0, math.rad(90), 0), gunmetal, Enum.Material.Metal, Enum.PartType.Cylinder)
		attach("Drum", Vector3.new(0.9, 1.1, 1.1), CFrame.new(0.75, 0.3, -0.6) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 120, 60), Enum.Material.Metal, Enum.PartType.Cylinder)
		attach("Stripe", Vector3.new(1.02, 0.15, 1.8), CFrame.new(0, 1.05, -0.9), Color3.fromRGB(255, 138, 61), Enum.Material.Neon)
		attach("Muzzle", Vector3.new(0.3, 0.3, 0.2), CFrame.new(0, 0.6, -4.95), Color3.fromRGB(255, 170, 60), Enum.Material.Neon)
	else
		tool.Grip = CFrame.new(0, -0.2, 0.4)
		attach("Body", Vector3.new(0.6, 0.6, 2), CFrame.new(0, 0.6, -0.6), Color3.fromRGB(230, 232, 238), Enum.Material.SmoothPlastic)
		attach("Stripe", Vector3.new(0.62, 0.15, 1.6), CFrame.new(0, 0.75, -0.6), Color3.fromRGB(255, 138, 61), Enum.Material.Neon)
		attach("Muzzle", Vector3.new(0.4, 0.4, 0.3), CFrame.new(0, 0.6, -1.75), Color3.fromRGB(90, 220, 255), Enum.Material.Neon)
	end
	return tool
end

local function findWeapon(container: Instance?): Tool?
	if not container then
		return nil
	end
	for _, t in container:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("IsWeapon") then
			return t
		end
	end
	return nil
end

local function giveWeapon(player: Player, humanoid: Humanoid)
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in { backpack, player.Character } do
		local old = findWeapon(container)
		while old do
			old:Destroy()
			old = findWeapon(container)
		end
	end
	local st = states[player]
	local tool = makeWeapon(if st then st.weapon else "Blaster")
	tool.Parent = backpack
	task.defer(function()
		if humanoid.Parent and not player:GetAttribute("Downed") then
			humanoid:EquipTool(tool)
		end
	end)
end

function Combat.applyCharacter(player: Player, character: Model)
	if not states[player] then
		Combat.reset(player)
	end
	local s = Combat.stats(player)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if humanoid then
		humanoid.MaxHealth = s.maxHealth
		humanoid.Health = s.maxHealth
		humanoid.WalkSpeed = s.walkSpeed
	end
	local st = states[player]
	st.ammo = s.mag
	st.reloading = false
	publish(player)
	player:WaitForChild("Backpack", 5)
	if humanoid then
		giveWeapon(player, humanoid)
	end
end

local function startReload(player: Player)
	local st = states[player]
	if not st or st.reloading then
		return
	end
	st.reloading = true
	publish(player)
	;(remotes:FindFirstChild("CrewAction") :: RemoteEvent):FireAllClients(player.UserId, "Reloading!!")
	task.delay(Combat.stats(player).reload, function()
		if states[player] == st then
			st.ammo = Combat.stats(player).mag
			st.reloading = false
			publish(player)
		end
	end)
end

local function onShoot(player: Player, aimPos: any)
	if typeof(aimPos) ~= "Vector3" then
		return
	end
	local st = states[player]
	if not st or st.reloading or not Combat.hooks.canShoot(player) then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local tool = findWeapon(character)
	if not character or not head or not tool then
		return
	end
	local s = Combat.stats(player)
	local now = os.clock()
	if now - st.lastShot < s.interval * 0.75 then
		return
	end
	st.lastShot = now
	if st.ammo <= 0 then
		startReload(player)
		return
	end
	st.ammo -= 1

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore

	local origin = head.Position
	local baseDir = (aimPos - origin)
	if baseDir.Magnitude < 0.1 then
		return
	end
	baseDir = baseDir.Unit
	local hits = {}
	for i = 1, s.pellets do
		local dir = baseDir
		if s.jitter > 0 then
			dir = (CFrame.fromAxisAngle(Vector3.yAxis, (math.random() - 0.5) * s.jitter)
				* CFrame.fromAxisAngle(Vector3.xAxis, (math.random() - 0.5) * s.jitter) * dir).Unit
		end
		if s.pellets > 1 then
			local angle = (i - (s.pellets + 1) / 2) * Config.Weapon.Spread
			dir = (CFrame.fromAxisAngle(Vector3.yAxis, angle) * dir)
		end
		local result = workspace:Raycast(origin, dir * Config.Weapon.Range, params)
		local hitPos = if result then result.Position else origin + dir * Config.Weapon.Range
		table.insert(hits, hitPos)
		if result then
			local k = Keis.fromPart(result.Instance)
			if k and k.alive then
				local crit = result.Instance.Name == "Face" or result.Instance.Name == "Bow"
				local dmg = s.damage * (if crit then Config.Weapon.CritMultiplier else 1)
				st.damageDealt += math.min(dmg, k.hp)
				local killed = k:takeDamage(dmg, player)
				;(remotes:FindFirstChild("HitConfirm") :: RemoteEvent):FireClient(player, hitPos, math.floor(dmg), crit, killed,
					if killed then k.def.reward else 0, k.def.passive == true)
			end
		end
	end
	;(remotes:FindFirstChild("ShotFx") :: RemoteEvent):FireAllClients(player, origin, hits)
	if st.ammo <= 0 then
		startReload(player)
	else
		publish(player)
	end
end

local function onBuy(player: Player, id: any)
	if type(id) ~= "string" then
		return
	end
	local st = states[player]
	if id == "Minigun" then
		local cost = Config.Weapons.Minigun.cost
		if st and st.weapon ~= "Minigun" and st.credits >= cost then
			st.credits -= cost
			st.weapon = "Minigun"
			st.reloading = false
			st.ammo = Combat.stats(player).mag
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				giveWeapon(player, humanoid)
			end
			publish(player)
			;(remotes:FindFirstChild("Purchased") :: RemoteEvent):FireClient(player, id)
			;(remotes:FindFirstChild("CrewAction") :: RemoteEvent):FireAllClients(player.UserId, "I GOT A MINIGUN")
		end
		return
	end
	local def = upgradeDef(id)
	if not st or not def then
		return
	end
	local level = st.upgrades[id] or 0
	if level >= def.max then
		return
	end
	local cost = Config.upgradeCost(def, level)
	if st.credits < cost then
		return
	end
	st.credits -= cost
	st.upgrades[id] = level + 1
	-- apply health/speed right away
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local s = Combat.stats(player)
	if humanoid then
		if id == "MaxHealth" then
			humanoid.MaxHealth = s.maxHealth
			humanoid.Health = math.min(humanoid.Health + 25, s.maxHealth)
		elseif id == "Speed" and not player:GetAttribute("Downed") then
			humanoid.WalkSpeed = s.walkSpeed
		end
	end
	if id == "Mag" and not st.reloading then
		st.ammo = s.mag
	end
	publish(player)
	;(remotes:FindFirstChild("Purchased") :: RemoteEvent):FireClient(player, id)
end

local function onRepair(player: Player)
	local st = states[player]
	if not st or st.credits < Config.REPAIR_COST then
		return
	end
	if Combat.hooks.repairReactor(player) then
		st.credits -= Config.REPAIR_COST
		publish(player)
		;(remotes:FindFirstChild("Purchased") :: RemoteEvent):FireClient(player, "Repair")
	end
end

function Combat.init(remoteFolder: Folder)
	remotes = remoteFolder
	;(remotes:FindFirstChild("Shoot") :: RemoteEvent).OnServerEvent:Connect(onShoot)
	;(remotes:FindFirstChild("Reload") :: RemoteEvent).OnServerEvent:Connect(function(player)
		local st = states[player]
		if st and st.ammo < Combat.stats(player).mag then
			startReload(player)
		end
	end)
	;(remotes:FindFirstChild("BuyUpgrade") :: RemoteEvent).OnServerEvent:Connect(onBuy)
	;(remotes:FindFirstChild("RepairReactor") :: RemoteEvent).OnServerEvent:Connect(onRepair)
end

return Combat
