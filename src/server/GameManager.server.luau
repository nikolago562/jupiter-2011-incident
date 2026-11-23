--!strict
-- Jupiter 2011 Incident — round loop.
-- Lobby -> intermission -> station round (fuel cells, tapes, the gun, a power outage, the pod) -> results.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MapBuilder = require(script.Parent:WaitForChild("MapBuilder"))
local Keis = require(script.Parent:WaitForChild("KeisAI"))

-- Remotes ---------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local function remote(name: string): RemoteEvent
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end
local Notify = remote("Notify") -- (text, colorName): big center text
local Narrate = remote("Narrate") -- (text): narrator caption bar, like the videos
local CrewAction = remote("CrewAction") -- (userId, text): a line in that player's crew-roster row
local PlayLog = remote("PlayLog") -- (logIndex)
local Jumpscare = remote("Jumpscare") -- ()
local RoundResults = remote("RoundResults") -- ({ {userId, name, status} })
local Shoot = remote("Shoot") -- client -> server (aimPosition)
remotes.Parent = ReplicatedStorage

local function setState(phase: string, timeLeft: number?)
	ReplicatedStorage:SetAttribute("Phase", phase)
	ReplicatedStorage:SetAttribute("TimeLeft", timeLeft or 0)
end
ReplicatedStorage:SetAttribute("Cells", 0)
ReplicatedStorage:SetAttribute("CellsRequired", Config.FUEL_CELLS_REQUIRED)
ReplicatedStorage:SetAttribute("PowerOut", false)
setState("Waiting")

local function narrate(key: string, name: string?)
	local template = (Config.Narration :: any)[key] or key
	Narrate:FireAllClients((string.gsub(template, "{name}", name or "someone")))
end

-- Atmosphere ------------------------------------------------------------
Lighting.ClockTime = 0
Lighting.Brightness = 0
Lighting.Ambient = Color3.fromRGB(12, 10, 14)
Lighting.OutdoorAmbient = Color3.fromRGB(10, 8, 12)
Lighting.FogColor = Color3.fromRGB(8, 6, 10)
Lighting.FogStart = 10
Lighting.FogEnd = 110
Lighting.GlobalShadows = true

local defaultBaseplate = workspace:FindFirstChild("Baseplate")
if defaultBaseplate then
	defaultBaseplate:Destroy()
end
MapBuilder.buildLobby()
Players.RespawnTime = 4

-- Players ---------------------------------------------------------------
local function giveFlashlight(character: Model)
	local head = character:WaitForChild("Head", 5) :: BasePart?
	if not head then
		return
	end
	local light = Instance.new("SpotLight")
	light.Name = "Flashlight"
	light.Range = 45
	light.Angle = 55
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 240, 210)
	light.Shadows = true
	light.Face = Enum.NormalId.Front
	light.Parent = head
end

Players.PlayerAdded:Connect(function(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local escapes = Instance.new("IntValue")
	escapes.Name = "Escapes"
	escapes.Parent = stats
	local tapes = Instance.new("IntValue")
	tapes.Name = "Tapes"
	tapes.Parent = stats
	stats.Parent = player

	player.CharacterAdded:Connect(giveFlashlight)
end)

-- Lights: flicker normally, all dead during a power outage ----------------
task.spawn(function()
	local rng = Random.new()
	while true do
		local out = ReplicatedStorage:GetAttribute("PowerOut") == true
		for _, fixture in CollectionService:GetTagged("FlickerLight") do
			if fixture:IsA("BasePart") and (out or rng:NextNumber() < 0.35) then
				local light = fixture:FindFirstChildOfClass("PointLight")
				local on = (not out) and rng:NextNumber() > 0.4
				if light then
					light.Enabled = on
				end
				fixture.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end
		task.wait(rng:NextNumber(0.05, 0.4))
	end
end)

local function setPower(on: boolean)
	ReplicatedStorage:SetAttribute("PowerOut", not on)
	local station = workspace:FindFirstChild("Station")
	if not station then
		return
	end
	for _, d in station:GetDescendants() do
		if d:IsA("PointLight") and d.Parent and d.Parent.Name ~= "FuelCell" and not CollectionService:HasTag(d.Parent, "FlickerLight") then
			d.Enabled = on
			local fixture = d.Parent :: BasePart
			fixture.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

-- Round -----------------------------------------------------------------
type Status = "alive" | "dead" | "escaped"

local function addStat(player: Player, stat: string)
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(stat) :: IntValue?
	if value then
		value.Value += 1
	end
end

local function runRound()
	local rng = Random.new()
	local station = MapBuilder.buildStation(rng)
	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = station.folder
	local keisFolder = Instance.new("Folder")
	keisFolder.Name = "Keis"
	keisFolder.Parent = workspace

	local participants: { [Player]: Status } = {}
	local connections: { RBXScriptConnection } = {}
	local keisList = {}
	local cells = 0
	local required = Config.FUEL_CELLS_REQUIRED
	ReplicatedStorage:SetAttribute("Cells", 0)
	ReplicatedStorage:SetAttribute("CellsRequired", required)
	setPower(true)

	local function setStatus(player: Player, status: Status)
		participants[player] = status
		player:SetAttribute("CrewStatus", status) -- clients build the crew roster from this
	end

	local function aliveCount(): number
		local n = 0
		for _, s in participants do
			if s == "alive" then
				n += 1
			end
		end
		return n
	end

	local function randomAliveName(): string?
		local names = {}
		for player, s in participants do
			if s == "alive" then
				table.insert(names, player.DisplayName)
			end
		end
		return if #names > 0 then names[rng:NextInteger(1, #names)] else nil
	end

	-- Escape pod
	local pod, podPrompt = MapBuilder.spawnEscapePod(items, station.podPosition)
	local function activatePod()
		pod.Color = Color3.fromRGB(60, 255, 120)
		local l = pod:FindFirstChildOfClass("PointLight")
		if l then
			l.Color = pod.Color
		end
		podPrompt.ObjectText = "Escape Pod (ONLINE)"
	end
	table.insert(connections, podPrompt.Triggered:Connect(function(player)
		if participants[player] ~= "alive" then
			return
		end
		if cells < required then
			Notify:FireClient(player, `THE POD NEEDS {required - cells} MORE FUEL CELL(S)`, "red")
			return
		end
		setStatus(player, "escaped")
		addStat(player, "Escapes")
		if player.Character then
			player.Character:PivotTo(CFrame.new(Config.LOBBY_POSITION + Vector3.new(0, 4, 0)))
		end
		CrewAction:FireAllClients(player.UserId, "*Escaped*")
		narrate("Escape", player.DisplayName)
	end))

	-- Fuel cells
	local spot = 1
	for _ = 1, Config.FUEL_CELLS_SPAWNED do
		local pos = station.itemSpots[spot]
		spot += 1
		if not pos then
			break
		end
		local part, prompt = MapBuilder.spawnFuelCell(items, pos)
		table.insert(connections, prompt.Triggered:Connect(function(player)
			if participants[player] ~= "alive" or not part.Parent then
				return
			end
			part:Destroy()
			cells += 1
			ReplicatedStorage:SetAttribute("Cells", cells)
			if cells == required then
				activatePod()
				Notify:FireAllClients("ESCAPE POD ONLINE. GET TO THE FAR CORNER.", "green")
				narrate("PodOnline")
			elseif cells < required then
				narrate("FuelCell", player.DisplayName)
			end
		end))
	end

	-- Audio logs (tapes), shuffled
	local order = {}
	for i = 1, #Config.AudioLogs do
		table.insert(order, i)
	end
	for k = #order, 2, -1 do
		local r = rng:NextInteger(1, k)
		order[k], order[r] = order[r], order[k]
	end
	for n = 1, math.min(Config.AUDIO_LOGS_SPAWNED, #order) do
		local pos = station.itemSpots[spot]
		spot += 1
		if not pos then
			break
		end
		local logIndex = order[n]
		local heardBy: { [Player]: boolean } = {}
		local _, prompt = MapBuilder.spawnAudioLog(items, pos)
		table.insert(connections, prompt.Triggered:Connect(function(player)
			PlayLog:FireClient(player, logIndex)
			if not heardBy[player] then
				heardBy[player] = true
				addStat(player, "Tapes")
			end
		end))
	end

	-- The gun ------------------------------------------------------------
	local gun = MapBuilder.spawnGun(workspace, station.itemSpots[spot] or station.playerSpawn)
	spot += 1
	local gunAnnounced = false
	local reloading = false
	local lastShot = 0

	local function holderOf(tool: Tool): Player?
		local parent = tool.Parent
		if parent and parent:IsA("Model") then
			return Players:GetPlayerFromCharacter(parent)
		end
		return nil
	end

	table.insert(connections, gun.AncestryChanged:Connect(function()
		local holder = holderOf(gun)
		if holder and participants[holder] ~= "alive" then
			-- only the crew on the station may hold it
			gun.Parent = workspace
			return
		end
		if holder and not gunAnnounced then
			gunAnnounced = true
			CrewAction:FireAllClients(holder.UserId, "I GOT A GUN")
			narrate("GunPickup", holder.DisplayName)
		end
	end))

	local function startReload(player: Player)
		reloading = true
		CrewAction:FireAllClients(player.UserId, "Reloading!!")
		task.delay(Config.GUN_RELOAD_TIME, function()
			if gun.Parent then
				gun:SetAttribute("Ammo", Config.GUN_AMMO)
			end
			reloading = false
		end)
	end

	table.insert(connections, Shoot.OnServerEvent:Connect(function(player, aimPos)
		if typeof(aimPos) ~= "Vector3" or participants[player] ~= "alive" then
			return
		end
		if holderOf(gun) ~= player or reloading or os.clock() - lastShot < Config.GUN_FIRE_COOLDOWN then
			return
		end
		local character = player.Character :: Model
		local head = character:FindFirstChild("Head") :: BasePart?
		if not head then
			return
		end
		lastShot = os.clock()
		local ammo = (gun:GetAttribute("Ammo") :: number?) or 0
		if ammo <= 0 then
			startReload(player)
			return
		end
		gun:SetAttribute("Ammo", ammo - 1)

		local origin = head.Position
		local direction = (aimPos - origin).Unit * Config.GUN_RANGE
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local result = workspace:Raycast(origin, direction, params)
		local hitPos = if result then result.Position else origin + direction

		if result then
			for _, k in keisList do
				if result.Instance:IsDescendantOf(k.model) then
					k:stun(Config.GUN_STUN_TIME)
					break
				end
			end
		end

		-- tracer
		local length = (hitPos - origin).Magnitude
		local tracer = Instance.new("Part")
		tracer.Anchored = true
		tracer.CanCollide = false
		tracer.CanQuery = false
		tracer.Material = Enum.Material.Neon
		tracer.Color = Color3.fromRGB(255, 220, 120)
		tracer.Size = Vector3.new(0.12, 0.12, length)
		tracer.CFrame = CFrame.lookAt(origin, hitPos) * CFrame.new(0, 0, -length / 2)
		tracer.Parent = workspace
		Debris:AddItem(tracer, 0.08)

		CrewAction:FireAllClients(player.UserId, "*Shooting*")
		if ammo - 1 <= 0 then
			startReload(player)
		end
	end))

	-- Teleport the crew in
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid and humanoid.Health > 0 then
			setStatus(player, "alive")
			local offset = Vector3.new(rng:NextNumber(-6, 6), 3, rng:NextNumber(-6, 6))
			character:PivotTo(CFrame.new(station.playerSpawn + offset))
			table.insert(connections, humanoid.Died:Connect(function()
				-- drop the gun where they died
				if holderOf(gun) == player or gun.Parent == player:FindFirstChild("Backpack") then
					local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
					gun.Parent = workspace
					if root then
						(gun:FindFirstChild("Handle") :: BasePart).CFrame = root.CFrame
					end
				end
				if participants[player] == "alive" then
					setStatus(player, "dead")
					narrate("Kill", player.DisplayName)
				end
			end))
		end
	end
	table.insert(connections, Players.PlayerRemoving:Connect(function(player)
		participants[player] = nil
	end))

	local function getTargets(): { Model }
		local list = {}
		for player, status in participants do
			if status == "alive" and player.Character then
				table.insert(list, player.Character)
			end
		end
		return list
	end
	local function getSpeed(): number
		local bonus = if ReplicatedStorage:GetAttribute("PowerOut") then Config.OUTAGE_KEIS_SPEED_BONUS else 0
		return Config.KEIS_BASE_SPEED + cells * Config.KEIS_SPEED_PER_CELL + bonus
	end
	local function onKill(character: Model)
		local player = Players:GetPlayerFromCharacter(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if player then
			Jumpscare:FireClient(player)
		end
		if humanoid then
			humanoid.Health = 0
		end
	end

	local crewSize = 0
	for _ in participants do
		crewSize += 1
	end
	local keisCount = Config.KEIS_BASE_COUNT + math.floor((crewSize - 1) / Config.KEIS_EXTRA_EVERY_N_PLAYERS)

	Notify:FireAllClients("SIGNAL LOST... YOU ARE ON JUPITER. JULY 14, 2011.", "white")

	local function spawnKeis()
		local where = station.keisSpawns[rng:NextInteger(1, #station.keisSpawns)]
		table.insert(keisList, Keis.new({
			position = where,
			cells = station.cells,
			parent = keisFolder,
			getSpeed = getSpeed,
			getTargets = getTargets,
			onKill = onKill,
		}))
	end

	local outageAt = math.floor(Config.ROUND_TIME * (1 - rng:NextNumber(Config.OUTAGE_AT_FRACTION[1], Config.OUTAGE_AT_FRACTION[2])))
	local outageEnd = -1

	local timeLeft = Config.ROUND_TIME
	local keisAwake = false
	while timeLeft > 0 do
		setState("Round", timeLeft)
		if not keisAwake and Config.ROUND_TIME - timeLeft >= Config.KEIS_GRACE_TIME then
			keisAwake = true
			for _ = 1, keisCount do
				spawnKeis()
			end
			local victim = randomAliveName()
			narrate("KeisBoard", victim)
			task.delay(6, function()
				if victim then
					narrate("Taunt", victim)
				end
			end)
		end
		if timeLeft == outageAt then
			setPower(false)
			narrate("Outage")
			outageEnd = timeLeft - Config.OUTAGE_DURATION
		elseif timeLeft == outageEnd then
			setPower(true)
			narrate("PowerBack")
		end
		if aliveCount() == 0 then
			break
		end
		task.wait(1)
		timeLeft -= 1
	end

	-- Time ran out: the station goes dark and takes whoever is left
	if timeLeft <= 0 then
		narrate("TimeUp")
		for player, status in participants do
			if status == "alive" then
				Jumpscare:FireClient(player)
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = 0
				end
			end
		end
	end

	-- Results: "EVERYONE SADLY DYING TO KEIS:" / "THE TRUE SURVIVOR:"
	local results = {}
	for player, status in participants do
		table.insert(results, { userId = player.UserId, name = player.DisplayName, status = status })
	end
	RoundResults:FireAllClients(results)

	for _, c in connections do
		c:Disconnect()
	end
	for _, k in keisList do
		k:destroy()
	end
	gun:Destroy()
	keisFolder:Destroy()
	station.folder:Destroy()
	setPower(true)
	task.delay(Config.RESULTS_TIME, function()
		for _, player in Players:GetPlayers() do
			player:SetAttribute("CrewStatus", nil)
		end
	end)
end

while true do
	while #Players:GetPlayers() < Config.MIN_PLAYERS do
		setState("Waiting")
		task.wait(1)
	end
	for t = Config.INTERMISSION_TIME, 1, -1 do
		setState("Intermission", t)
		task.wait(1)
	end
	local ok, err = pcall(runRound)
	if not ok then
		warn("[Jupiter2011] round crashed:", err)
		for _, name in { "Keis", "Station", "KeisGun" } do
			local leftover = workspace:FindFirstChild(name)
			if leftover then
				leftover:Destroy()
			end
		end
		ReplicatedStorage:SetAttribute("PowerOut", false)
	end
	setState("Results", Config.RESULTS_TIME)
	task.wait(Config.RESULTS_TIME)
end
