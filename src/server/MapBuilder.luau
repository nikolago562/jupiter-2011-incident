--!strict
-- Builds the lobby and a fresh, randomized Jupiter station each round, using only Parts.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local MapBuilder = {}

local WALL_COLOR = Color3.fromRGB(58, 60, 66)
local FLOOR_COLOR = Color3.fromRGB(40, 40, 44)
local HAZARD_COLOR = Color3.fromRGB(170, 120, 30)

local function makePart(parent: Instance, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A wall segment centered at `center` (y = floor), running along X if alongX else along Z,
-- with an optional doorway in the middle.
local function buildWall(parent: Instance, center: Vector3, alongX: boolean, length: number, withDoor: boolean)
	local H = Config.WALL_HEIGHT
	local function seg(offset: number, len: number, height: number, yBase: number)
		local size = if alongX then Vector3.new(len, height, 1) else Vector3.new(1, height, len)
		local shift = if alongX then Vector3.new(offset, 0, 0) else Vector3.new(0, 0, offset)
		makePart(parent, size, CFrame.new(center + shift + Vector3.new(0, yBase + height / 2, 0)), WALL_COLOR, Enum.Material.DiamondPlate)
	end

	if not withDoor then
		seg(0, length, H, 0)
		return
	end

	local door = Config.DOOR_WIDTH
	local side = (length - door) / 2
	seg(-(door / 2 + side / 2), side, H, 0)
	seg(door / 2 + side / 2, side, H, 0)
	seg(0, door, H - Config.DOOR_HEIGHT, Config.DOOR_HEIGHT) -- lintel

	-- hazard stripe over the doorway
	local stripeSize = if alongX then Vector3.new(door, 0.6, 1.2) else Vector3.new(1.2, 0.6, door)
	local stripe = makePart(parent, stripeSize, CFrame.new(center + Vector3.new(0, Config.DOOR_HEIGHT + 0.3, 0)), HAZARD_COLOR, Enum.Material.Neon)
	stripe.CanCollide = false
end

export type StationInfo = {
	folder: Folder,
	cells: { Vector3 },
	cellAt: (i: number, j: number) -> Vector3,
	playerSpawn: Vector3,
	podPosition: Vector3,
	keisSpawns: { Vector3 },
	itemSpots: { Vector3 },
}

function MapBuilder.buildStation(rng: Random): StationInfo
	local old = workspace:FindFirstChild("Station")
	if old then
		old:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Station"

	local N, S, H = Config.GRID_SIZE, Config.CELL_SIZE, Config.WALL_HEIGHT
	local origin = Config.MAP_ORIGIN
	local total = N * S
	local half = total / 2

	local function cellAt(i: number, j: number): Vector3
		return origin + Vector3.new(-half + (i - 0.5) * S, 0, -half + (j - 0.5) * S)
	end

	-- floor + ceiling
	makePart(folder, Vector3.new(total, 1, total), CFrame.new(origin + Vector3.new(0, -0.5, 0)), FLOOR_COLOR, Enum.Material.DiamondPlate)
	makePart(folder, Vector3.new(total, 1, total), CFrame.new(origin + Vector3.new(0, H + 0.5, 0)), Color3.fromRGB(25, 25, 28), Enum.Material.Metal)

	-- outer walls
	buildWall(folder, origin + Vector3.new(0, 0, -half), true, total, false)
	buildWall(folder, origin + Vector3.new(0, 0, half), true, total, false)
	buildWall(folder, origin + Vector3.new(-half, 0, 0), false, total, false)
	buildWall(folder, origin + Vector3.new(half, 0, 0), false, total, false)

	-- interior walls: every wall has a doorway, so the station is always fully connected
	for i = 1, N - 1 do
		for j = 1, N do
			if rng:NextNumber() > Config.OPEN_WALL_CHANCE then
				local c = cellAt(i, j)
				buildWall(folder, Vector3.new(c.X + S / 2, origin.Y, c.Z), false, S, true)
			end
		end
	end
	for i = 1, N do
		for j = 1, N - 1 do
			if rng:NextNumber() > Config.OPEN_WALL_CHANCE then
				local c = cellAt(i, j)
				buildWall(folder, Vector3.new(c.X, origin.Y, c.Z + S / 2), true, S, true)
			end
		end
	end

	-- ceiling lights: some work, some flicker, some are dead
	local cells = {}
	for i = 1, N do
		for j = 1, N do
			local c = cellAt(i, j)
			table.insert(cells, c)
			local roll = rng:NextNumber()
			if roll > 0.2 then
				local fixture = makePart(folder, Vector3.new(6, 0.4, 1.5), CFrame.new(c + Vector3.new(0, H - 0.2, 0)), Color3.fromRGB(255, 214, 160), Enum.Material.Neon)
				fixture.CanCollide = false
				local light = Instance.new("PointLight")
				light.Range = 26
				light.Brightness = 1.4
				light.Color = Color3.fromRGB(255, 200, 150)
				light.Shadows = true
				light.Parent = fixture
				if roll < 0.55 then
					CollectionService:AddTag(fixture, "FlickerLight")
				end
			end

			-- random clutter: crates
			if rng:NextNumber() < 0.45 then
				local size = Vector3.new(rng:NextInteger(3, 5), rng:NextInteger(3, 5), rng:NextInteger(3, 5))
				local offset = Vector3.new(rng:NextNumber(-S / 3, S / 3), size.Y / 2, rng:NextNumber(-S / 3, S / 3))
				makePart(folder, size, CFrame.new(c + offset) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), Color3.fromRGB(80, 70, 55), Enum.Material.WoodPlanks)
			end
		end
	end

	-- escape pod in the far corner
	local podPos = cellAt(N, N)
	local playerSpawn = cellAt(1, 1)

	local keisSpawns = {}
	local itemSpots = {}
	for i = 1, N do
		for j = 1, N do
			local farFromPlayers = (i + j) >= N + 1
			if not (i == 1 and j == 1) and not (i == N and j == N) then
				local jitter = Vector3.new(rng:NextNumber(-S / 4, S / 4), 0, rng:NextNumber(-S / 4, S / 4))
				table.insert(itemSpots, cellAt(i, j) + jitter)
			end
			if farFromPlayers and not (i == N and j == N) then
				table.insert(keisSpawns, cellAt(i, j))
			end
		end
	end
	-- shuffle item spots
	for k = #itemSpots, 2, -1 do
		local r = rng:NextInteger(1, k)
		itemSpots[k], itemSpots[r] = itemSpots[r], itemSpots[k]
	end

	folder.Parent = workspace

	return {
		folder = folder,
		cells = cells,
		cellAt = cellAt,
		playerSpawn = playerSpawn,
		podPosition = podPos,
		keisSpawns = keisSpawns,
		itemSpots = itemSpots,
	}
end

local function addPrompt(parent: BasePart, action: string, object: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

function MapBuilder.spawnFuelCell(parent: Instance, position: Vector3): (Part, ProximityPrompt)
	local cell = makePart(parent, Vector3.new(1.4, 2.6, 1.4), CFrame.new(position + Vector3.new(0, 1.3, 0)), Color3.fromRGB(80, 255, 140), Enum.Material.Neon)
	cell.Name = "FuelCell"
	cell.Shape = Enum.PartType.Cylinder
	cell.Size = Vector3.new(2.6, 1.4, 1.4)
	cell.CFrame = CFrame.new(position + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(80, 255, 140)
	glow.Range = 10
	glow.Brightness = 2
	glow.Parent = cell
	return cell, addPrompt(cell, "Take", "Fuel Cell", 1.2)
end

function MapBuilder.spawnAudioLog(parent: Instance, position: Vector3): (Part, ProximityPrompt)
	local recorder = makePart(parent, Vector3.new(1.6, 0.6, 1), CFrame.new(position + Vector3.new(0, 0.3, 0)), Color3.fromRGB(30, 30, 30), Enum.Material.Plastic)
	recorder.Name = "AudioLog"
	local led = makePart(parent, Vector3.new(0.2, 0.2, 0.2), CFrame.new(position + Vector3.new(0.6, 0.65, 0)), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
	led.CanCollide = false
	led.Parent = recorder
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = recorder
	weld.Part1 = led
	weld.Parent = recorder
	return recorder, addPrompt(recorder, "Play", "Tape Recorder", 0)
end

function MapBuilder.spawnEscapePod(parent: Instance, position: Vector3): (Part, ProximityPrompt)
	local base = makePart(parent, Vector3.new(10, 1, 10), CFrame.new(position + Vector3.new(0, 0.5, 0)), Color3.fromRGB(90, 90, 100), Enum.Material.DiamondPlate)
	local pod = makePart(parent, Vector3.new(6, 9, 6), CFrame.new(position + Vector3.new(0, 5.5, 0)), Color3.fromRGB(140, 30, 30), Enum.Material.Neon)
	pod.Name = "EscapePod"
	pod.Shape = Enum.PartType.Ball
	pod.Size = Vector3.new(8, 8, 8)
	pod.Transparency = 0.2
	base.Name = "PodBase"
	local light = Instance.new("PointLight")
	light.Color = pod.Color
	light.Range = 20
	light.Brightness = 2
	light.Parent = pod
	return pod, addPrompt(pod, "Launch", "Escape Pod (OFFLINE)", 2)
end

-- The one gun on the station: walk over it to pick it up.
function MapBuilder.spawnGun(parent: Instance, position: Vector3): Tool
	local tool = Instance.new("Tool")
	tool.Name = "KeisGun"
	tool.ToolTip = "Stuns the keis"
	tool.CanBeDropped = false
	tool.Grip = CFrame.new(0, -0.3, 0.6)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.9, 0.6)
	handle.Color = Color3.fromRGB(30, 30, 30)
	handle.Material = Enum.Material.Metal
	handle.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))
	handle.Parent = tool

	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Size = Vector3.new(0.35, 0.35, 1.8)
	barrel.Color = Color3.fromRGB(45, 45, 45)
	barrel.Material = Enum.Material.Metal
	barrel.CanCollide = false
	barrel.Massless = true
	barrel.CFrame = handle.CFrame * CFrame.new(0, 0.45, -0.7)
	barrel.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = barrel
	weld.Parent = handle

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 220, 120)
	glow.Range = 8
	glow.Parent = handle

	tool:SetAttribute("Ammo", Config.GUN_AMMO)
	tool.Parent = parent
	return tool
end

function MapBuilder.buildLobby(): SpawnLocation
	local existing = workspace:FindFirstChild("Lobby")
	if existing then
		existing:Destroy()
	end
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"
	local pos = Config.LOBBY_POSITION

	makePart(lobby, Vector3.new(70, 1, 70), CFrame.new(pos + Vector3.new(0, -0.5, 0)), Color3.fromRGB(35, 35, 40), Enum.Material.DiamondPlate)
	for _, offset in { Vector3.new(0, 0, -35), Vector3.new(0, 0, 35) } do
		makePart(lobby, Vector3.new(70, 14, 1), CFrame.new(pos + offset + Vector3.new(0, 7, 0)), WALL_COLOR, Enum.Material.Metal)
	end
	for _, offset in { Vector3.new(-35, 0, 0), Vector3.new(35, 0, 0) } do
		makePart(lobby, Vector3.new(1, 14, 70), CFrame.new(pos + offset + Vector3.new(0, 7, 0)), WALL_COLOR, Enum.Material.Metal)
	end

	-- a big "window" showing Jupiter
	local jupiter = makePart(lobby, Vector3.new(60, 60, 60), CFrame.new(pos + Vector3.new(0, 40, -140)), Color3.fromRGB(200, 140, 90), Enum.Material.SmoothPlastic)
	jupiter.Shape = Enum.PartType.Ball
	jupiter.CanCollide = false

	local sign = makePart(lobby, Vector3.new(30, 6, 1), CFrame.new(pos + Vector3.new(0, 10, -34)), Color3.fromRGB(10, 10, 10), Enum.Material.SmoothPlastic)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back
	surface.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "JUPITER 2011 INCIDENT"
	label.TextColor3 = Color3.fromRGB(255, 60, 60)
	label.TextScaled = true
	label.Font = Enum.Font.Arcade
	label.Parent = surface

	for _, offset in { Vector3.new(-18, 13, -18), Vector3.new(18, 13, 18), Vector3.new(-18, 13, 18), Vector3.new(18, 13, -18) } do
		local lamp = makePart(lobby, Vector3.new(2, 0.5, 2), CFrame.new(pos + offset), Color3.fromRGB(255, 220, 180), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 30
		light.Brightness = 1.5
		light.Parent = lamp
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0))
	spawn.Color = Color3.fromRGB(60, 60, 70)
	spawn.Material = Enum.Material.Metal
	spawn.Duration = 0
	spawn.Parent = lobby

	lobby.Parent = workspace
	return spawn
end

return MapBuilder
