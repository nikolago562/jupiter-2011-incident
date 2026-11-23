--!strict
-- JUPITER 2011 INCIDENT — run / wave loop.
-- Lobby → Wave 1 → break (shop) → Wave 2 → … → the reactor falls or the whole crew is down → Game Over → Lobby.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ShipBuilder = require(script.Parent:WaitForChild("ShipBuilder"))
local Keis = require(script.Parent:WaitForChild("KeisAI"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local Combat = require(script.Parent:WaitForChild("Combat"))
local Suit = require(script.Parent:WaitForChild("Suit"))
local MoonBuilder = require(script.Parent:WaitForChild("MoonBuilder"))
local PerkSystem = require(script.Parent:WaitForChild("PerkSystem"))
local Loot = require(script.Parent:WaitForChild("Loot"))
local Missions = require(script.Parent:WaitForChild("Missions"))
local Perks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Perks"))
local ServerStorage = game:GetService("ServerStorage")

-- Remotes ---------------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local R: { [string]: RemoteEvent } = {}
for _, name in {
	"Notify", -- (text, colorName)
	"Narrate", -- (text) narrator caption bar
	"CrewAction", -- (userId, text) line in the crew roster
	"Announce", -- (title, subtitle, style) big center banner
	"HitConfirm", -- (pos, dmg, crit, killed, reward, golden) to the shooter
	"ShotFx", -- (shooter, origin, hits) tracers for everyone
	"PlayerHurt", -- (damage)
	"LevelUp", -- (level, title)
	"GameOver", -- (summary)
	"Purchased", -- (id)
	"Transition", -- (text, seconds) fade to black and back
	"PerkOffer", -- (offerId, cards, rarity) pick-1-of-3
	"Arc", -- (kind, points) chain lightning / ricochet / explosion visuals
	"PickPerk", "RerollPerk", -- client → server
	"Shoot", "Reload", "BuyUpgrade", "RepairReactor", "PlayRequest", -- client → server
} do
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	R[name] = r
end
remotes.Parent = ReplicatedStorage

local function setAttr(name: string, value: any)
	ReplicatedStorage:SetAttribute(name, value)
end
local function setPhase(phase: string, timeLeft: number?)
	setAttr("Phase", phase)
	setAttr("TimeLeft", timeLeft or 0)
end

-- players who pressed PLAY in the menu
local function crew(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InGame") then
			table.insert(list, p)
		end
	end
	return list
end

local function narrate(key: string, name: string?)
	local template = (Config.Narration :: any)[key] or key
	R.Narrate:FireAllClients((string.gsub(template, "{name}", name or "someone")))
end

-- World -------------------------------------------------------------------------------------
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end
local ship = ShipBuilder.build()
local keisFolder = Instance.new("Folder")
keisFolder.Name = "Keis"
keisFolder.Parent = workspace

local rng = Random.new()
local running = false
local wave = 0
local reactorHp = Config.REACTOR_MAX_HP
local reactorWarned = false
setAttr("ReactorHP", reactorHp)
setAttr("ReactorMax", Config.REACTOR_MAX_HP)
setAttr("Wave", 0)
setAttr("KeisLeft", 0)
setAttr("PowerOut", false)
setAttr("Alarm", false)
setPhase("Lobby")

-- Reactor visuals: rings spin, core shifts from cyan to red as it takes damage
-- the current stage: the ship, or Io after wave 10
type Stage = { name: string, spawn: SpawnLocation, reactor: BasePart, reactorRadius: number, vents: { Vector3 }, roomCenters: { Vector3 } }
local shipStage: Stage = { name = "Ship", spawn = ship.spawn, reactor = ship.reactor, reactorRadius = ship.reactorRadius,
	vents = ship.vents, roomCenters = ship.roomCenters }
local stage: Stage = shipStage
local moon: any = nil

local rings = {}
local function collectRings()
	rings = {}
	for _, d in (stage.reactor.Parent :: Instance):GetChildren() do
		if d.Name == "ReactorRing" then
			table.insert(rings, { part = d :: BasePart, base = (d :: BasePart).CFrame, speed = (#rings + 1) * 0.6 * (if #rings % 2 == 0 then 1 else -1) })
		end
	end
end
collectRings()
task.spawn(function()
	local angle = 0
	while true do
		angle += 0.05
		for _, r in rings do
			r.part.CFrame = r.base * CFrame.Angles(0, math.sin(angle * r.speed) * 0.45, 0) -- gyroscope wobble
		end
		local frac = reactorHp / Config.REACTOR_MAX_HP
		local core = stage.reactor
		if core.Parent then
			core.Color = Color3.fromRGB(90, 220, 255):Lerp(Color3.fromRGB(255, 50, 40), 1 - frac)
			local l = core:FindFirstChildOfClass("PointLight")
			if l then
				l.Color = core.Color
			end
		end
		task.wait(0.05)
	end
end)

-- Lights: power outage + alarm -------------------------------------------------------------
local modSpeed = 0 -- extra Keis speed from the wave modifier
local lastMission: string? = nil
local activeMod: any = nil -- the current wave modifier (Config.Modifiers entry) or nil
local function setPower(on: boolean)
	setAttr("PowerOut", not on)
	Keis.hooks.speedBonus = modSpeed + (if on then 0 else Config.Waves.OutageSpeedBonus)
	for _, panel in CollectionService:GetTagged("ShipLight") do
		local l = panel:FindFirstChildOfClass("PointLight")
		if l then
			l.Enabled = on
		end
		if panel:IsA("BasePart") then
			panel.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
	for _, player in Players:GetPlayers() do
		local head = player.Character and player.Character:FindFirstChild("Head")
		local flashlight = head and head:FindFirstChild("Flashlight") :: SpotLight?
		if flashlight then
			flashlight.Enabled = not on
		end
	end
end

local alarmOn = false
local function setAlarm(on: boolean)
	alarmOn = on
	setAttr("Alarm", on)
	for _, beacon in CollectionService:GetTagged("AlarmLight") do
		local l = beacon:FindFirstChildOfClass("PointLight")
		if l then
			l.Enabled = on
		end
		if beacon:IsA("BasePart") then
			beacon.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end
task.spawn(function()
	while true do
		if alarmOn then
			local b = (math.sin(os.clock() * 4) + 1) * 0.6
			for _, beacon in CollectionService:GetTagged("AlarmLight") do
				local l = beacon:FindFirstChildOfClass("PointLight")
				if l then
					l.Brightness = b
				end
			end
		end
		task.wait(0.1)
	end
end)

-- XP & rewards -------------------------------------------------------------------------------
local function grantXP(player: Player, amount: number)
	local gained = PlayerData.addXP(player, amount)
	if gained > 0 then
		local data = PlayerData.get(player)
		if data then
			local title = Config.titleFor(data.Level)
			R.LevelUp:FireClient(player, data.Level, title)
			R.Notify:FireAllClients(`{player.DisplayName} reached LEVEL {data.Level} · {title}`, "gold")
		end
	end
end

-- Crew: health, downed, revive ------------------------------------------------------------------
local function crewStatus(player: Player): string?
	return player:GetAttribute("CrewStatus") :: string?
end

local function aliveCrew(): number
	local n = 0
	for _, p in crew() do
		if crewStatus(p) == "alive" then
			n += 1
		end
	end
	return n
end

local function revive(player: Player, by: Player?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not player:GetAttribute("Downed") then
		return
	end
	player:SetAttribute("Downed", false)
	player:SetAttribute("CrewStatus", "alive")
	local s = Combat.stats(player)
	humanoid.Health = humanoid.MaxHealth * Config.REVIVE_HEALTH
	humanoid.WalkSpeed = s.walkSpeed
	local hrp = (character :: Model):FindFirstChild("HumanoidRootPart")
	local prompt = hrp and hrp:FindFirstChild("RevivePrompt")
	if prompt then
		prompt:Destroy()
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool: Tool? = nil
	if backpack then
		for _, t in backpack:GetChildren() do
			if t:IsA("Tool") and t:GetAttribute("IsWeapon") then
				tool = t
			end
		end
	end
	if tool then
		humanoid:EquipTool(tool)
	end
	if by then
		narrate("Revived", player.DisplayName)
		R.CrewAction:FireAllClients(by.UserId, "*Revives " .. player.DisplayName .. "*")
		Combat.addCredits(by, 10)
		grantXP(by, 10)
	end
end

local function down(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp or player:GetAttribute("Downed") then
		return
	end
	if PerkSystem.get(player, "SecondWind") > 0 and not player:GetAttribute("SecondWindUsed") then
		player:SetAttribute("SecondWindUsed", true)
		humanoid.Health = humanoid.MaxHealth * 0.5
		R.CrewAction:FireAllClients(player.UserId, "*Second Wind*")
		R.Notify:FireAllClients(`{player.DisplayName} refused to go down (SECOND WIND)`, "gold")
		return
	end
	player:SetAttribute("Downed", true)
	player:SetAttribute("CrewStatus", "downed")
	humanoid.Health = 1
	humanoid.WalkSpeed = 4
	humanoid:UnequipTools()
	narrate("Downed", player.DisplayName)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = Config.REVIVE_TIME
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = hrp
	prompt.Triggered:Connect(function(by)
		if by ~= player and crewStatus(by) == "alive" then
			revive(player, by)
		end
	end)

	local downedAt = os.clock()
	player:SetAttribute("DownedUntil", workspace:GetServerTimeNow() + Config.DOWNED_BLEEDOUT)
	task.spawn(function()
		while player.Parent and player:GetAttribute("Downed") and humanoid.Parent and humanoid.Health > 0 do
			if os.clock() - downedAt >= Config.DOWNED_BLEEDOUT then
				humanoid.Health = 0
				break
			end
			task.wait(0.25)
		end
	end)
end

local function hurt(player: Player, damage: number)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or player:GetAttribute("Downed") then
		return
	end
	R.PlayerHurt:FireClient(player, damage)
	if humanoid.Health - damage <= 1 then
		down(player)
	else
		humanoid:TakeDamage(damage)
	end
end

local function onCharacter(player: Player, character: Model)
	player:SetAttribute("Downed", false)
	player:SetAttribute("CrewStatus", "alive")
	local head = character:WaitForChild("Head", 5)
	if head then
		local flashlight = Instance.new("SpotLight")
		flashlight.Name = "Flashlight"
		flashlight.Range = 45
		flashlight.Angle = 55
		flashlight.Brightness = 3
		flashlight.Color = Color3.fromRGB(255, 240, 215)
		flashlight.Shadows = true
		flashlight.Enabled = ReplicatedStorage:GetAttribute("PowerOut") == true
		flashlight.Parent = head
	end
	Combat.applyCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = if stage.name == "Moon" then Config.MOON_JUMP_POWER else 50
		humanoid.Died:Connect(function()
			player:SetAttribute("Downed", false)
			if running then
				player:SetAttribute("CrewStatus", "dead")
				narrate("Deceased", player.DisplayName)
				-- comes back at the next break
			else
				task.delay(3, function()
					if player.Parent and not running and player:GetAttribute("InGame") then
						player:LoadCharacter()
					end
				end)
			end
		end)
	end
end

Players.CharacterAutoLoads = false
local function onPlayerAdded(player: Player)
	PlayerData.load(player)
	Combat.reset(player)
	PerkSystem.reset(player)
	Loot.resetKeys(player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	player.CharacterAppearanceLoaded:Connect(function(character)
		if Config.SPACESUITS then
			Suit.apply(character)
		end
	end)
	-- the character spawns when the player presses PLAY in the menu (PlayRequest)
end
R.PlayRequest.OnServerEvent:Connect(function(player)
	if player:GetAttribute("InGame") then
		return
	end
	player:SetAttribute("InGame", true)
	player:LoadCharacter()
	if running then
		R.Notify:FireAllClients(`{player.DisplayName} joined the crew`, "cyan")
	end
end)
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end
Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
	Combat.remove(player)
	PerkSystem.remove(player)
end)
game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		PlayerData.save(p)
	end
end)

-- Keis wiring ----------------------------------------------------------------------------------
local function spawnKeis(typeId: string, at: Vector3?, hpScale: number)
	local pos = at or stage.vents[rng:NextInteger(1, #stage.vents)]
	pos += Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
	if stage.name == "Moon" then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { keisFolder }
		local hit = workspace:Raycast(pos + Vector3.new(0, 80, 0), Vector3.new(0, -200, 0), params)
		if hit then
			pos = hit.Position + Vector3.new(0, 3, 0)
		end
	end
	return Keis.new(typeId, pos, hpScale)
end

local currentHpScale = 1
Keis.hooks.folder = keisFolder
Keis.hooks.reactor = ship.reactor
Keis.hooks.reactorRadius = ship.reactorRadius
Keis.hooks.roomCenters = ship.roomCenters
Keis.hooks.getTargets = function(): { Model }
	local list = {}
	for _, p in crew() do
		if crewStatus(p) == "alive" and p.Character then
			table.insert(list, p.Character)
		end
	end
	return list
end
Keis.hooks.onAttackPlayer = function(_k, character: Model, damage: number)
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		hurt(player, damage)
	end
end
Keis.hooks.onAttackReactor = function(_k, damage: number)
	if not running then
		return
	end
	reactorHp = math.max(0, reactorHp - damage)
	setAttr("ReactorHP", reactorHp)
	if not reactorWarned and reactorHp < Config.REACTOR_MAX_HP * 0.3 then
		reactorWarned = true
		narrate("ReactorLow")
	end
end
Keis.hooks.onSummon = function(k)
	for _ = 1, k.def.summonCount or 3 do
		local offset = Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
		spawnKeis(k.def.summon, k.root.Position - Vector3.new(0, k.root.Position.Y - 3, 0) + offset, currentHpScale)
	end
	R.Notify:FireAllClients("KEIS KEIS KEIS O ALGO O ALGO", "red")
end
Keis.hooks.onExpired = function(k)
	if k.def.passive then
		narrate("GoldenEscaped")
	end
end
Keis.hooks.onKilled = function(k, killer: Player?)
	local def = k.def
	local mod = activeMod or {}
	local dropAt = k.root.Position
	if killer then
		local creditMult = (1 + 0.25 * PerkSystem.get(killer, "Scavenger")) * (mod.credits or 1)
		Combat.addCredits(killer, math.floor(def.reward * creditMult))
		Combat.onKill(killer)
		local vamp = PerkSystem.get(killer, "Vampire")
		local hum = killer.Character and killer.Character:FindFirstChildOfClass("Humanoid")
		if vamp > 0 and hum and hum.Health > 0 and not killer:GetAttribute("Downed") then
			hum.Health = math.min(hum.MaxHealth, hum.Health + 4 * vamp)
		end
		if PerkSystem.get(killer, "GoldenTouch") > 0 and rng:NextNumber() < 0.08 then
			Loot.dropKeys(dropAt, 1, true)
			Combat.addCredits(killer, 15)
		end
		local keyChance = Config.KEY_DROP_CHANCE * (1 + 0.2 * PerkSystem.get(killer, "KeyMagnet"))
		local keyCount = def.keys or (if def.boss then 6 elseif def.passive then 2 elseif rng:NextNumber() < keyChance then 1 else 0)
		if keyCount > 0 then
			Loot.dropKeys(dropAt, keyCount * (mod.keys or 1), def.passive == true)
		end
		Combat.addKill(killer)
		PlayerData.addKill(killer)
		grantXP(killer, def.xp)
		if def.passive then
			narrate("GoldenCaught", killer.DisplayName)
			R.CrewAction:FireAllClients(killer.UserId, "*Catches the golden keis*")
		elseif def.boss then
			R.Announce:FireAllClients("MASTER KEIS DESTROYED", killer.DisplayName .. " landed the final shot", "gold")
			for _, p in crew() do
				Combat.addCredits(p, 50)
			end
		end
	end
	if def.splitInto then
		local pos = k.root.Position
		for _ = 1, def.splitCount or 3 do
			local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			spawnKeis(def.splitInto, Vector3.new(pos.X, 3, pos.Z) + offset, currentHpScale)
		end
	end
end

Combat.hooks.canShoot = function(player: Player): boolean
	return crewStatus(player) == "alive"
end
Combat.hooks.repairReactor = function(player: Player): boolean
	if not running or reactorHp >= Config.REACTOR_MAX_HP then
		return false
	end
	reactorHp = math.min(Config.REACTOR_MAX_HP, reactorHp + Config.REPAIR_AMOUNT)
	setAttr("ReactorHP", reactorHp)
	if reactorHp >= Config.REACTOR_MAX_HP * 0.3 then
		reactorWarned = false
	end
	R.Notify:FireAllClients(`{player.DisplayName} repaired the reactor`, "cyan")
	return true
end
Combat.init(remotes)

PerkSystem.init(remotes)
PerkSystem.hooks.onChanged = function(player: Player)
	Combat.refresh(player)
end
PerkSystem.hooks.spendKey = function(player: Player): boolean
	return Loot.spendKeys(player, 1)
end
PerkSystem.hooks.onPicked = function(player: Player, perkId: string)
	local perk = Perks.byId[perkId]
	if perk then
		R.CrewAction:FireAllClients(player.UserId, `*{perk.name}*`)
		if perk.rarity == "Legendary" then
			R.Notify:FireAllClients(`{player.DisplayName} took {perk.name}`, "gold")
		end
	end
end

Loot.hooks.magnetRange = function(player: Player): number
	return 8 + 14 * PerkSystem.get(player, "KeyMagnet")
end
Loot.hooks.onCrateReward = function(player: Player, kind: string)
	if kind == "Credits" then
		local c = 30 + wave * 6
		Combat.addCredits(player, c)
		R.Notify:FireClient(player, `CRATE · +{c} CREDITS`, "gold")
	elseif kind == "Heal" then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = hum.MaxHealth
		end
		R.Notify:FireClient(player, "CRATE · SUIT REPAIRED (FULL HEALTH)", "green")
	elseif kind == "Perk" then
		PerkSystem.offer(player, wave)
		R.Notify:FireClient(player, "CRATE · EXTRA PERK CARD", "cyan")
	elseif kind == "Keys" then
		Loot.addKeys(player, 2)
		R.Notify:FireClient(player, "CRATE · +2 KEYS", "gold")
	elseif kind == "Legendary" then
		PerkSystem.offer(player, wave, "Legendary")
		R.Notify:FireAllClients(`{player.DisplayName} found a LEGENDARY card in a crate`, "gold")
	end
end

-- Global leaderboard on the bridge ---------------------------------------------------------------
local function renderBoard(entries: { { name: string, wave: number } })
	local frame = ship.leaderboard
	frame:ClearAllChildren()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 24)
	pad.PaddingRight = UDim.new(0, 24)
	pad.PaddingTop = UDim.new(0, 18)
	pad.Parent = frame
	local function row(text: string, color: Color3, size: number, font: Enum.Font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, size + 8)
		l.Font = font
		l.TextSize = size
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = color
		l.Text = text
		l.Parent = frame
	end
	row("TOP CREW · BEST WAVE", Color3.fromRGB(255, 138, 61), 30, Enum.Font.GothamBlack)
	if #entries == 0 then
		row("No records yet. Be the first.", Color3.fromRGB(150, 138, 128), 22, Enum.Font.GothamMedium)
	end
	for i, e in entries do
		local color = if i == 1 then Color3.fromRGB(255, 205, 64) else Color3.fromRGB(245, 236, 222)
		row(string.format("%2d.  %-18s  WAVE %d", i, e.name, e.wave), color, 22, Enum.Font.Code)
	end
end
task.spawn(function()
	while true do
		renderBoard(PlayerData.fetchTop(10))
		task.wait(90)
	end
end)

-- Waves ------------------------------------------------------------------------------------------
local function pickType(n: number): string
	local total, pool = 0, {}
	for id, def in Config.KeisTypes do
		if def.weight > 0 and def.unlockWave <= n then
			total += def.weight
			table.insert(pool, { id = id, w = def.weight })
		end
	end
	local roll = rng:NextNumber() * total
	for _, e in pool do
		roll -= e.w
		if roll <= 0 then
			return e.id
		end
	end
	return "Basic"
end

local function randomCrewName(): string?
	local names = {}
	for _, p in crew() do
		if crewStatus(p) == "alive" then
			table.insert(names, p.DisplayName)
		end
	end
	return if #names > 0 then names[rng:NextInteger(1, #names)] else nil
end

-- floor positions for mission objects and crates on the current stage
local function stagePoints(): { Vector3 }
	if stage.name ~= "Moon" then
		return stage.roomCenters
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { keisFolder }
	local out = {}
	for _, p in stage.roomCenters do
		local hit = workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -150, 0), params)
		table.insert(out, if hit then hit.Position else p)
	end
	return out
end

local function runWave(n: number): (boolean, string, string, boolean)
	local W = Config.Waves
	local kind = Missions.pick(n, rng, lastMission, W.BossEvery)
	lastMission = kind
	local def = Missions.Defs[kind]

	-- a wave modifier from wave 3
	activeMod = nil
	if n >= Config.MODIFIER_FROM_WAVE and kind ~= "GoldRush" and rng:NextNumber() < Config.MODIFIER_CHANCE then
		local ids = {}
		for id in Config.Modifiers do
			table.insert(ids, id)
		end
		table.sort(ids)
		activeMod = Config.Modifiers[ids[rng:NextInteger(1, #ids)]]
	end
	local mod = activeMod or {}

	local playerCount = math.max(1, #crew())
	local count = math.floor((W.BaseCount + W.CountPerWave * (n - 1)) * (1 + (playerCount - 1) * W.ExtraPlayerMultiplier) * (mod.count or 1))
	if kind == "Boss" then
		count = math.floor(count * 0.6)
	end
	currentHpScale = (1 + W.HealthScalePerWave * (n - 1)) * (mod.hp or 1)
	local interval = math.max(W.SpawnIntervalMin, W.SpawnIntervalStart - 0.06 * (n - 1)) / (mod.count or 1)
	modSpeed = mod.speed or 0
	Keis.hooks.speedBonus = modSpeed

	setPhase("Wave")
	setAttr("Wave", n)
	setAttr("Mission", def.name)
	setAttr("Modifier", if activeMod then `{activeMod.name} · {string.upper(activeMod.desc)}` else "")
	setAlarm(true)
	Loot.clearCrates()
	for _, p in crew() do
		p:SetAttribute("SecondWindUsed", false)
		PerkSystem.resolvePending(p)
	end

	local title = if kind == "Boss" then `BOSS WAVE {n}` else `WAVE {n} · {def.name}`
	local sub = def.desc .. (if activeMod then `   ·   {activeMod.name}` else "")
	R.Announce:FireAllClients(title, sub, if kind == "Boss" then "boss" else "wave")
	if mod.dark then
		setPower(false)
	end

	local ctx = {
		n = n,
		rng = rng,
		folder = keisFolder.Parent :: Instance,
		reactorPos = stage.reactor.Position,
		points = stagePoints(),
		count = count,
		spawnKeis = function(typeId: string, at: Vector3?, hpScale: number)
			return spawnKeis(typeId, at, hpScale)
		end,
		hpScale = currentHpScale,
		isAlive = function(p: Player): boolean
			return crewStatus(p) == "alive"
		end,
		setPower = setPower,
		narrate = narrate,
		notify = function(text: string, color: string)
			R.Notify:FireAllClients(text, color)
		end,
		setObjective = function(text: string, progress: number?)
			setAttr("Objective", text)
			setAttr("ObjectiveProgress", progress or -1)
		end,
		damageReactor = function(amount: number)
			reactorHp = math.max(0, reactorHp - amount)
			setAttr("ReactorHP", reactorHp)
		end,
	}
	local mission = Missions.create(kind, ctx :: any)
	mission:start()
	if kind == "Defend" then
		narrate("Vents", randomCrewName())
	end

	local spawned = 0
	local nextSpawn = os.clock() + 1.5
	local last = os.clock()
	local result, reason = true, ""
	while true do
		if reactorHp <= 0 then
			result, reason = false, "THE REACTOR WAS DESTROYED"
			break
		end
		if #crew() == 0 then
			result, reason = false, "THE SHIP WAS ABANDONED"
			break
		end
		if aliveCrew() == 0 then
			result, reason = false, "THE WHOLE CREW WENT DOWN"
			break
		end
		local now = os.clock()
		local dt = now - last
		last = now
		local hostile = Keis.countHostile()
		if mission.spawnMode == "count" then
			if spawned < count and now >= nextSpawn and hostile < W.MaxAlive then
				spawnKeis(pickType(n), nil, currentHpScale)
				spawned += 1
				nextSpawn = now + interval * rng:NextNumber(0.6, 1.4)
				if rng:NextNumber() < W.GoldenChance then
					spawnKeis("Golden", nil, 1)
					narrate("Golden")
				end
			end
		else
			-- timed missions: Keis keep coming until the objective is done
			local cap = math.min(W.MaxAlive, 6 + n * 2 + (playerCount - 1) * 3)
			if now >= nextSpawn and hostile < cap then
				spawnKeis(pickType(n), nil, currentHpScale)
				nextSpawn = now + interval * rng:NextNumber(1, 1.8)
			end
		end
		hostile = Keis.countHostile()
		local left = if mission.spawnMode == "count" then (count - spawned) + hostile else hostile
		setAttr("KeisLeft", left)
		local done = mission:tick(dt, left)
		if mission.spawnMode == "count" and spawned >= count and hostile == 0 then
			done = true
		end
		if done then
			break
		end
		task.wait(0.2)
	end
	mission:cleanup()
	if result and mission.spawnMode == "timed" then
		Keis.clearAll() -- the rest retreat into the vents
		narrate("Retreat")
	end
	setAttr("Objective", "")
	setAttr("ObjectiveProgress", -1)
	modSpeed = 0
	if ReplicatedStorage:GetAttribute("PowerOut") then
		setPower(true)
	end
	Keis.hooks.speedBonus = 0
	setAlarm(false)
	return result, reason, kind, mission.success
end

local function applyStage(newStage: Stage)
	stage = newStage
	setAttr("Stage", newStage.name)
	Keis.hooks.reactor = newStage.reactor
	Keis.hooks.reactorRadius = newStage.reactorRadius
	Keis.hooks.roomCenters = newStage.roomCenters
	ship.spawn.Enabled = newStage.name == "Ship"
	if moon then
		moon.spawn.Enabled = newStage.name == "Moon"
	end
	-- only one Jupiter in the sky at a time
	for _, m in ship.space do
		m.Parent = if newStage.name == "Ship" then ship.folder else ServerStorage
	end
	workspace.Gravity = if newStage.name == "Moon" then 196.2 * Config.MOON_GRAVITY else 196.2
	for _, p in crew() do
		local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.UseJumpPower = true
			humanoid.JumpPower = if newStage.name == "Moon" then Config.MOON_JUMP_POWER else 50
		end
	end
	collectRings()
end

local function landOnIo()
	R.Transition:FireAllClients("DESCENDING TO IO", 4)
	task.wait(1.2) -- screens are black now
	if not moon then
		moon = MoonBuilder.build()
	end
	applyStage({ name = "Moon", spawn = moon.spawn, reactor = moon.reactor, reactorRadius = moon.reactorRadius,
		vents = moon.vents, roomCenters = moon.roomCenters })
	reactorHp = Config.REACTOR_MAX_HP
	reactorWarned = false
	setAttr("ReactorHP", reactorHp)
	for _, p in crew() do
		local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			p.Character:PivotTo(moon.spawn.CFrame + Vector3.new(rng:NextNumber(-4, 4), 4, rng:NextNumber(-3, 3)))
		end
	end
	R.Announce:FireAllClients("IO", "JUPITER'S VOLCANIC MOON · LOW GRAVITY · DEFEND THE GENERATOR", "gold")
	narrate("Landing")
end

local function returnToShip()
	if stage.name ~= "Ship" then
		applyStage(shipStage)
	end
	if moon then
		MoonBuilder.clear()
		moon = nil
	end
end

local function respawnCrew()
	for _, p in crew() do
		local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if p:GetAttribute("Downed") then
			revive(p, nil)
		elseif not humanoid or humanoid.Health <= 0 then
			p:LoadCharacter()
		end
	end
end

local function gameOver(reason: string)
	Keis.clearAll()
	Loot.clearKeys()
	Loot.clearCrates()
	setAttr("Mission", "")
	setAttr("Modifier", "")
	setAlarm(false)
	setPower(true)
	local summary = { wave = wave, reason = reason, crew = {} :: { any }, mvp = 0 }
	local bestKills = -1
	for _, p in crew() do
		local kills, damage = Combat.getRunStats(p)
		table.insert(summary.crew, { userId = p.UserId, name = p.DisplayName, kills = kills, damage = damage,
			level = p:GetAttribute("Level") or 1 })
		if kills > bestKills then
			bestKills = kills
			summary.mvp = p.UserId
		end
		PlayerData.save(p)
	end
	R.GameOver:FireAllClients(summary)
	narrate("GameOver")
	setPhase("GameOver", Config.GAMEOVER_TIME)
	task.wait(Config.GAMEOVER_TIME)
	running = false
	returnToShip()
	reactorHp = Config.REACTOR_MAX_HP
	setAttr("ReactorHP", reactorHp)
	setAttr("Wave", 0)
	setAttr("KeisLeft", 0)
	for _, p in crew() do
		Combat.reset(p)
		p:LoadCharacter()
	end
end

local function startRun()
	running = true
	wave = 0
	reactorHp = Config.REACTOR_MAX_HP
	reactorWarned = false
	setAttr("ReactorHP", reactorHp)
	lastMission = nil
	for _, p in crew() do
		Combat.reset(p)
		PerkSystem.reset(p)
		Loot.resetKeys(p)
		PlayerData.addRun(p)
		p:LoadCharacter()
	end
	narrate("RunStart")
	task.wait(2)

	while true do
		wave += 1
		local cleared, reason, kind, success = runWave(wave)
		if not cleared then
			gameOver(reason)
			return
		end
		local bonus = Config.Waves.ClearBonusBase + Config.Waves.ClearBonusPerWave * wave
		local special = kind ~= "Defend" and success
		for _, p in crew() do
			Combat.addCredits(p, bonus)
			grantXP(p, Config.XP_PER_WAVE * wave)
			PlayerData.recordWave(p, wave)
			if special then
				Loot.addKeys(p, Config.MISSION_KEY_REWARD)
			end
			-- pick-1-of-3 perk card (bosses give a legendary choice)
			PerkSystem.offer(p, wave, if kind == "Boss" then "Legendary" else nil)
		end
		local missionName = Missions.Defs[kind].name
		R.Announce:FireAllClients(if success then `{missionName} COMPLETE` else `{missionName} FAILED`,
			`+{bonus} CREDITS{if special then ` · +{Config.MISSION_KEY_REWARD} KEYS` else ""} · PICK A PERK · OPEN CRATES`, if success then "clear" else "boss")
		narrate("WaveClear")
		-- supply crates around the map (open them with keys)
		local spots = {}
		for _, p in stagePoints() do
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(stage.reactor.Position.X, 0, stage.reactor.Position.Z)).Magnitude > 14 then
				table.insert(spots, p + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)))
			end
		end
		Loot.spawnCrates(spots, Config.CRATES_PER_BREAK)
		if wave == Config.LANDING_WAVE and stage.name == "Ship" then
			landOnIo()
		end
		respawnCrew()
		local breakTime = if wave % Config.Waves.BossEvery == 0 then Config.BOSS_BREAK_TIME else Config.BREAK_TIME
		for t = breakTime, 1, -1 do
			setPhase("Break", t)
			task.wait(1)
		end
	end
end

while true do
	setPhase("Lobby")
	while #crew() < Config.MIN_PLAYERS do
		task.wait(1)
	end
	local ready = true
	for t = Config.LOBBY_TIME, 1, -1 do
		setPhase("Lobby", t)
		task.wait(1)
		if #crew() < Config.MIN_PLAYERS then
			ready = false
			break
		end
	end
	if ready then
		local ok, err = pcall(startRun)
		if not ok then
			warn("[Jupiter2011] run crashed:", err)
			Keis.clearAll()
			running = false
			setAlarm(false)
			setPower(true)
			pcall(returnToShip)
		end
	end
end
