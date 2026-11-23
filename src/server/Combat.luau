--!strict
-- Weapons, credits and upgrades. The server checks every shot and purchase; clients only send intent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Keis = require(script.Parent:WaitForChild("KeisAI"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local Combat = {}

type State = {
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
	local W = Config.Weapon
	return {
		damage = W.BaseDamage * (1 + 0.2 * (up.Damage or 0)) * (1 + Config.LEVEL_DAMAGE_BONUS * (level - 1)),
		interval = W.FireInterval * (0.88 ^ (up.FireRate or 0)),
		mag = W.MagSize + 5 * (up.Mag or 0),
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
		credits = 0,
		upgrades = {},
		ammo = Config.Weapon.MagSize,
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

local function makeBlaster(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Blaster"
	tool.ToolTip = "Hold to fire · R to reload"
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -0.2, 0.4)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 1, 0.7)
	handle.Color = Color3.fromRGB(230, 232, 238)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Parent = tool
	local function attach(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
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
	attach("Body", Vector3.new(0.6, 0.6, 2), CFrame.new(0, 0.6, -0.6), Color3.fromRGB(230, 232, 238), Enum.Material.SmoothPlastic)
	attach("Stripe", Vector3.new(0.62, 0.15, 1.6), CFrame.new(0, 0.75, -0.6), Color3.fromRGB(255, 138, 61), Enum.Material.Neon)
	attach("Muzzle", Vector3.new(0.4, 0.4, 0.3), CFrame.new(0, 0.6, -1.75), Color3.fromRGB(90, 220, 255), Enum.Material.Neon)
	return tool
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
	local backpack = player:WaitForChild("Backpack", 5)
	if backpack and humanoid then
		local tool = makeBlaster()
		tool.Parent = backpack
		task.defer(function()
			if humanoid.Parent then
				humanoid:EquipTool(tool)
			end
		end)
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
	task.delay(Config.Weapon.ReloadTime, function()
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
	local tool = character and character:FindFirstChild("Blaster")
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
		if s.pellets > 1 then
			local angle = (i - (s.pellets + 1) / 2) * Config.Weapon.Spread
			dir = (CFrame.fromAxisAngle(Vector3.yAxis, angle) * baseDir)
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
