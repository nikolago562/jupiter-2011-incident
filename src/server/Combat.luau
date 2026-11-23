--!strict
-- Weapons, credits and upgrades. The server checks every shot and purchase; clients only send intent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Keis = require(script.Parent:WaitForChild("KeisAI"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local PerkSystem = require(script.Parent:WaitForChild("PerkSystem"))
local WeaponModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponModel"))

local Combat = {}

type State = {
	weapon: string,
	attachments: { Optic: string, Laser: string, Muzzle: string },
	owned: { [string]: boolean }, -- "Optic.RedDot" = true
	credits: number,
	upgrades: { [string]: number },
	ammo: number,
	reloading: boolean,
	lastShot: number,
	kills: number,
	damageDealt: number,
}
local states: { [Player]: State } = {}
Combat.adrenalineUntil = {} :: { [Player]: number }
local hitCounter: { [Player]: number } = {}

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
	local function perk(id: string): number
		return PerkSystem.get(player, id)
	end
	local att = if st then st.attachments else { Optic = "Iron", Laser = "None", Muzzle = "None" }
	local overclock = perk("Overclock")
	local adrenaline = if (Combat.adrenalineUntil[player] or 0) > os.clock() then perk("Adrenaline") else 0
	return {
		damage = W.damage * (if att.Muzzle == "LongBarrel" then 1.12 else 1) * (1 + 0.2 * (up.Damage or 0)) * (1 + Config.LEVEL_DAMAGE_BONUS * (level - 1))
			* (1 + 0.15 * perk("HollowPoints")) * (1 + 0.15 * overclock),
		interval = W.interval * (0.88 ^ (up.FireRate or 0)) / (1 + 0.4 * overclock) / (1 + 0.3 * adrenaline),
		mag = math.floor((W.mag + W.magPerLevel * (up.Mag or 0)) * (1 + 0.5 * perk("ExtendedMag"))),
		reload = W.reload * (0.7 ^ perk("QuickHands")),
		jitter = W.jitter * (if att.Laser ~= "None" then 0.5 else 1) * (if att.Muzzle == "Compensator" then 0.6 else 1),
		pellets = 1 + (up.Multishot or 0),
		maxHealth = Config.BASE_HEALTH + 25 * (up.MaxHealth or 0) + 20 * perk("SuitPadding"),
		walkSpeed = (Config.BASE_WALKSPEED + 1.5 * (up.Speed or 0)) * (1 + 0.08 * perk("LightStep")),
		critChance = 0.1 * perk("CritLens") + (if att.Laser == "Red" then 0.03 elseif att.Laser == "Green" then 0.05 else 0),
		critMult = Config.Weapon.CritMultiplier + 0.75 * perk("CritLens"),
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
	player:SetAttribute("Attachments", WeaponModel.encode(st.attachments))
	local owned = {}
	for k in st.owned do
		table.insert(owned, k)
	end
	player:SetAttribute("OwnedAttachments", table.concat(owned, ","))
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
		attachments = { Optic = "Iron", Laser = "None", Muzzle = "None" },
		owned = {},
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

function Combat.refresh(player: Player)
	local st = states[player]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local s = Combat.stats(player)
	if humanoid then
		local ratio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
		humanoid.MaxHealth = s.maxHealth
		humanoid.Health = math.max(1, s.maxHealth * ratio)
		if not player:GetAttribute("Downed") then
			humanoid.WalkSpeed = s.walkSpeed
		end
	end
	if st and not st.reloading then
		st.ammo = math.max(st.ammo, math.min(st.ammo + 0, s.mag))
	end
	publish(player)
end

function Combat.onKill(player: Player)
	if PerkSystem.get(player, "Adrenaline") > 0 then
		Combat.adrenalineUntil[player] = os.clock() + 2
		publish(player)
		task.delay(2.05, function()
			if player.Parent then
				publish(player)
			end
		end)
	end
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

local function makeWeapon(weaponId: string, att: any): Tool
	local tool = Instance.new("Tool")
	tool.Name = if weaponId == "Minigun" then "Minigun" else "Blaster"
	tool.ToolTip = "Hold to fire · R reload · Right-click aim"
	tool.CanBeDropped = false
	tool:SetAttribute("IsWeapon", true)
	tool:SetAttribute("WeaponId", weaponId)
	local built = WeaponModel.build(weaponId, att, tool, "Handle")
	tool.Grip = CFrame.new(built.grip.Position)
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
	local tool = makeWeapon(if st then st.weapon else "Blaster", if st then st.attachments else { Optic = "Iron", Laser = "None", Muzzle = "None" })
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
	do
		local target = remotes:FindFirstChild("CrewAction") :: RemoteEvent
		target:FireAllClients(player.UserId, "Reloading!!")
	end
	task.delay(Combat.stats(player).reload, function()
		if states[player] == st then
			st.ammo = Combat.stats(player).mag
			st.reloading = false
			publish(player)
		end
	end)
end

local arcFrom: (Player, Vector3, number, number, number, any, string) -> ()
local explode: (Player, Vector3, number, any) -> ()

-- deals damage, records stats, tells the shooter (damage numbers / hitmarkers)
local function hitKeis(player: Player, k: any, dmg: number, at: Vector3, crit: boolean): boolean
	local st = states[player]
	if st then
		st.damageDealt += math.min(dmg, k.hp)
	end
	local killed = k:takeDamage(dmg, player)
	do
		local target = remotes:FindFirstChild("HitConfirm") :: RemoteEvent
		target:FireClient(player, at, math.floor(dmg), crit, killed,
		if killed then k.def.reward else 0, k.def.passive == true)
	end
	return killed
end

local function keisNear(pos: Vector3, radius: number, except: any): { any }
	local list = {}
	for _, other in Keis.registry do
		if other.alive and other ~= except and (other.root.Position - pos).Magnitude <= radius then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a, b)
		return (a.root.Position - pos).Magnitude < (b.root.Position - pos).Magnitude
	end)
	return list
end

-- Chain Lightning / Ricochet: jump from Keis to Keis
arcFrom = function(player: Player, from: Vector3, dmg: number, jumps: number, radius: number, first: any, kind: string)
	local points = { from }
	local last, pos = first, from
	for _ = 1, jumps do
		local target = keisNear(pos, radius, last)[1]
		if not target then
			break
		end
		local tp = target.root.Position + Vector3.new(0, 3 * target.def.scale, 0)
		table.insert(points, tp)
		hitKeis(player, target, dmg, tp, false)
		last, pos = target, tp
	end
	if #points > 1 then
		do
			local target = remotes:FindFirstChild("Arc") :: RemoteEvent
			target:FireAllClients(kind, points)
		end
	end
end

-- Explosive Crits
explode = function(player: Player, at: Vector3, dmg: number, except: any)
	for _, k in keisNear(at, 9, except) do
		hitKeis(player, k, dmg, k.root.Position + Vector3.new(0, 3, 0), false)
	end
	do
		local target = remotes:FindFirstChild("Arc") :: RemoteEvent
		target:FireAllClients("boom", { at })
	end
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
				local crit = result.Instance.Name == "Face" or result.Instance.Name == "Bow" or math.random() < s.critChance
				local dmg = s.damage * (if crit then s.critMult else 1)
				local killed = hitKeis(player, k, dmg, hitPos, crit)
				-- perks that trigger on hits
				if crit and PerkSystem.get(player, "ExplosiveCrits") > 0 then
					explode(player, hitPos, s.damage * 0.4 * PerkSystem.get(player, "ExplosiveCrits"), k)
				end
				local chain = PerkSystem.get(player, "ChainLightning")
				if chain > 0 then
					hitCounter[player] = (hitCounter[player] or 0) + 1
					if hitCounter[player] % 5 == 0 then
						arcFrom(player, hitPos, s.damage * 0.5, 1 + 2 * chain, 22, k, "zap")
					end
				end
				local bounces = PerkSystem.get(player, "Ricochet")
				if killed and bounces > 0 then
					arcFrom(player, hitPos, s.damage * 0.6, bounces, 16, k, "ricochet")
				end
			end
		end
	end
	do
		local target = remotes:FindFirstChild("ShotFx") :: RemoteEvent
		target:FireAllClients(player, origin, hits)
	end
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
			do
				local target = remotes:FindFirstChild("Purchased") :: RemoteEvent
				target:FireClient(player, id)
			end
			do
				local target = remotes:FindFirstChild("CrewAction") :: RemoteEvent
				target:FireAllClients(player.UserId, "I GOT A MINIGUN")
			end
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
	do
		local target = remotes:FindFirstChild("Purchased") :: RemoteEvent
		target:FireClient(player, id)
	end
end

local function onAttachment(player: Player, slot: any, id: any)
	if type(slot) ~= "string" or type(id) ~= "string" then
		return
	end
	local st = states[player]
	local def = Config.attachment(slot, id)
	if not st or not def or (slot ~= "Optic" and slot ~= "Laser" and slot ~= "Muzzle") then
		return
	end
	local key = slot .. "." .. id
	if def.price > 0 and not st.owned[key] then
		if st.credits < def.price then
			return
		end
		st.credits -= def.price
		st.owned[key] = true
		do
			local target = remotes:FindFirstChild("Purchased") :: RemoteEvent
			target:FireClient(player, key)
		end
	end
	do
		local target = st.attachments :: any
		target[slot] = id
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		giveWeapon(player, humanoid)
	end
	publish(player)
end

local function onRepair(player: Player)
	local st = states[player]
	if not st or st.credits < Config.REPAIR_COST then
		return
	end
	if Combat.hooks.repairReactor(player) then
		st.credits -= Config.REPAIR_COST
		publish(player)
		do
			local target = remotes:FindFirstChild("Purchased") :: RemoteEvent
			target:FireClient(player, "Repair")
		end
	end
end

function Combat.init(remoteFolder: Folder)
	remotes = remoteFolder
	do
		local target = remotes:FindFirstChild("Shoot") :: RemoteEvent
		target.OnServerEvent:Connect(onShoot)
	end
	do
		local target = remotes:FindFirstChild("Reload") :: RemoteEvent
		target.OnServerEvent:Connect(function(player)
		local st = states[player]
		if st and st.ammo < Combat.stats(player).mag then
			startReload(player)
		end
	end)
	end
	do
		local target = remotes:FindFirstChild("BuyUpgrade") :: RemoteEvent
		target.OnServerEvent:Connect(onBuy)
	end
	do
		local target = remotes:FindFirstChild("RepairReactor") :: RemoteEvent
		target.OnServerEvent:Connect(onRepair)
	end
	do
		local target = remotes:FindFirstChild("Attachment") :: RemoteEvent
		target.OnServerEvent:Connect(onAttachment)
	end
end

return Combat
