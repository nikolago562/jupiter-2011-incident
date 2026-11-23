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
	"Shoot", "Reload", "BuyUpgrade", "RepairReactor", -- client → server
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
local rings = {}
for _, d in ship.reactor.Parent:GetChildren() do
	if d.Name == "ReactorRing" then
		table.insert(rings, { part = d :: BasePart, base = (d :: BasePart).CFrame, speed = (#rings + 1) * 0.6 * (if #rings % 2 == 0 then 1 else -1) })
	end
end
task.spawn(function()
	local angle = 0
	while true do
		angle += 0.05
		for _, r in rings do
			r.part.CFrame = r.base * CFrame.Angles(0, math.sin(angle * r.speed) * 0.45, 0) -- gyroscope wobble
		end
		local frac = reactorHp / Config.REACTOR_MAX_HP
		ship.reactor.Color = Color3.fromRGB(90, 220, 255):Lerp(Color3.fromRGB(255, 50, 40), 1 - frac)
		local l = ship.reactor:FindFirstChildOfClass("PointLight")
		if l then
			l.Color = ship.reactor.Color
		end
		task.wait(0.05)
	end
end)

-- Lights: power outage + alarm -------------------------------------------------------------
local function setPower(on: boolean)
	setAttr("PowerOut", not on)
	Keis.hooks.speedBonus = if on then 0 else Config.Waves.OutageSpeedBonus
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
	for _, p in Players:GetPlayers() do
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
	local tool = backpack and backpack:FindFirstChild("Blaster") :: Tool?
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
		humanoid.Died:Connect(function()
			player:SetAttribute("Downed", false)
			if running then
				player:SetAttribute("CrewStatus", "dead")
				narrate("Deceased", player.DisplayName)
				-- comes back at the next break
			else
				task.delay(3, function()
					if player.Parent and not running then
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
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	player:LoadCharacter()
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end
Players.PlayerRemoving:Connect(function(player)
	PlayerData.release(player)
	Combat.remove(player)
end)
game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		PlayerData.save(p)
	end
end)

-- Keis wiring ----------------------------------------------------------------------------------
local function spawnKeis(typeId: string, at: Vector3?, hpScale: number)
	local pos = at or ship.vents[rng:NextInteger(1, #ship.vents)]
	pos += Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
	return Keis.new(typeId, pos, hpScale)
end

local currentHpScale = 1
Keis.hooks.folder = keisFolder
Keis.hooks.reactor = ship.reactor
Keis.hooks.reactorRadius = ship.reactorRadius
Keis.hooks.roomCenters = ship.roomCenters
Keis.hooks.getTargets = function(): { Model }
	local list = {}
	for _, p in Players:GetPlayers() do
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
	if killer then
		Combat.addCredits(killer, def.reward)
		Combat.addKill(killer)
		PlayerData.addKill(killer)
		grantXP(killer, def.xp)
		if def.passive then
			narrate("GoldenCaught", killer.DisplayName)
			R.CrewAction:FireAllClients(killer.UserId, "*Catches the golden keis*")
		elseif def.boss then
			R.Announce:FireAllClients("MASTER KEIS DESTROYED", killer.DisplayName .. " landed the final shot", "gold")
			for _, p in Players:GetPlayers() do
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
	for _, p in Players:GetPlayers() do
		if crewStatus(p) == "alive" then
			table.insert(names, p.DisplayName)
		end
	end
	return if #names > 0 then names[rng:NextInteger(1, #names)] else nil
end

local function runWave(n: number): (boolean, string)
	local W = Config.Waves
	local isBoss = n % W.BossEvery == 0
	local playerCount = math.max(1, #Players:GetPlayers())
	local count = math.floor((W.BaseCount + W.CountPerWave * (n - 1)) * (1 + (playerCount - 1) * W.ExtraPlayerMultiplier))
	if isBoss then
		count = math.floor(count * 0.6)
	end
	currentHpScale = 1 + W.HealthScalePerWave * (n - 1)
	local interval = math.max(W.SpawnIntervalMin, W.SpawnIntervalStart - 0.06 * (n - 1))

	setPhase("Wave")
	setAttr("Wave", n)
	setAlarm(true)
	if isBoss then
		R.Announce:FireAllClients("BOSS WAVE " .. n, "THE MASTER KEIS HAS BOARDED", "boss")
		spawnKeis("Master", nil, currentHpScale * (1 + 0.35 * (playerCount - 1)))
		narrate("Boss")
	else
		R.Announce:FireAllClients("WAVE " .. n, Config.WaveSubtitles[rng:NextInteger(1, #Config.WaveSubtitles)], "wave")
		narrate("Vents", randomCrewName())
	end

	local outageAt: number? = nil
	if n >= W.OutageFromWave and rng:NextNumber() < W.OutageChance then
		outageAt = os.clock() + rng:NextNumber(8, 20)
	end
	local outageEndAt = 0
	local outageOn = false

	local spawned = 0
	local nextSpawn = os.clock() + 1.5
	local result, reason = true, ""
	while true do
		if reactorHp <= 0 then
			result, reason = false, "THE REACTOR WAS DESTROYED"
			break
		end
		if #Players:GetPlayers() == 0 then
			result, reason = false, "THE SHIP WAS ABANDONED"
			break
		end
		if aliveCrew() == 0 then
			result, reason = false, "THE WHOLE CREW WENT DOWN"
			break
		end
		local now = os.clock()
		if outageAt and not outageOn and now >= outageAt then
			outageOn = true
			outageEndAt = now + W.OutageDuration
			setPower(false)
			narrate("Outage")
			R.Announce:FireAllClients("POWER FAILURE", "THE KEIS ARE FASTER IN THE DARK", "outage")
		elseif outageOn and now >= outageEndAt then
			outageOn = false
			outageAt = nil
			setPower(true)
			narrate("PowerBack")
		end
		if spawned < count and now >= nextSpawn and Keis.countHostile() < W.MaxAlive then
			spawnKeis(pickType(n), nil, currentHpScale)
			spawned += 1
			nextSpawn = now + interval * rng:NextNumber(0.6, 1.4)
			if rng:NextNumber() < W.GoldenChance then
				spawnKeis("Golden", nil, 1)
				narrate("Golden")
			end
		end
		local hostile = Keis.countHostile()
		setAttr("KeisLeft", (count - spawned) + hostile)
		if spawned >= count and hostile == 0 then
			break
		end
		task.wait(0.2)
	end
	if outageOn then
		setPower(true)
	end
	setAlarm(false)
	return result, reason
end

local function respawnCrew()
	for _, p in Players:GetPlayers() do
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
	setAlarm(false)
	setPower(true)
	local summary = { wave = wave, reason = reason, crew = {} :: { any }, mvp = 0 }
	local bestKills = -1
	for _, p in Players:GetPlayers() do
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
	reactorHp = Config.REACTOR_MAX_HP
	setAttr("ReactorHP", reactorHp)
	setAttr("Wave", 0)
	setAttr("KeisLeft", 0)
	for _, p in Players:GetPlayers() do
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
	for _, p in Players:GetPlayers() do
		Combat.reset(p)
		PlayerData.addRun(p)
		p:LoadCharacter()
	end
	narrate("RunStart")
	task.wait(2)

	while true do
		wave += 1
		local cleared, reason = runWave(wave)
		if not cleared then
			gameOver(reason)
			return
		end
		local bonus = Config.Waves.ClearBonusBase + Config.Waves.ClearBonusPerWave * wave
		for _, p in Players:GetPlayers() do
			Combat.addCredits(p, bonus)
			grantXP(p, Config.XP_PER_WAVE * wave)
			PlayerData.recordWave(p, wave)
		end
		R.Announce:FireAllClients("WAVE " .. wave .. " CLEARED", `+{bonus} CREDITS · UPGRADE NOW [Q]`, "clear")
		narrate("WaveClear")
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
	while #Players:GetPlayers() < Config.MIN_PLAYERS do
		task.wait(1)
	end
	local ready = true
	for t = Config.LOBBY_TIME, 1, -1 do
		setPhase("Lobby", t)
		task.wait(1)
		if #Players:GetPlayers() < Config.MIN_PLAYERS then
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
		end
	end
end
