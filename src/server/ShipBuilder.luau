--!strict
-- Builds the ship (USS KEPLER), the space outside it, and Jupiter. Parts only, no assets.
--
--   Top view (X →, Z ↓). Jupiter is off to +X/+Z, so the bridge, medbay and observation deck face it.
--
--                 [Crew Qtrs]   [Engine]
--   [Cargo Bay]==[Corridor A]==[REACTOR]==[Corridor B]==[Bridge] (spawn)
--                               [Observ.]   [Medbay]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local ShipBuilder = {}

local H = 16 -- ceiling height
local DOOR_W, DOOR_H = 10, 11

local HULL = Color3.fromRGB(205, 208, 214)
local HULL_DARK = Color3.fromRGB(62, 66, 76)
local FLOOR = Color3.fromRGB(48, 50, 58)
local TRIM = Color3.fromRGB(255, 138, 61)
local GLASS = Color3.fromRGB(150, 200, 255)

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, name: string?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if name then
		p.Name = name
	end
	p.Parent = parent
	return p
end

local function deco(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(parent, size, cf, color, material)
	p.CanCollide = false
	p.CanQuery = false -- decorations never block shots or the Keis' line of sight
	p.CastShadow = false
	return p
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number, tag: string?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	if tag then
		CollectionService:AddTag(parent, tag)
	end
	return l
end

type Hole = { side: string, offset: number, width: number, kind: string, bottom: number?, top: number? }
type RoomDef = { name: string, center: Vector3, size: Vector2, holes: { Hole } }

local function buildRoom(parent: Instance, def: RoomDef): Folder
	local folder = Instance.new("Folder")
	folder.Name = def.name
	folder.Parent = parent
	local c, sx, sz = def.center, def.size.X, def.size.Y

	part(folder, Vector3.new(sx, 1, sz), CFrame.new(c + Vector3.new(0, -0.5, 0)), FLOOR, Enum.Material.DiamondPlate, "Floor")
	part(folder, Vector3.new(sx, 1, sz), CFrame.new(c + Vector3.new(0, H + 0.5, 0)), HULL_DARK, Enum.Material.Metal, "Ceiling")

	for _, side in { "N", "S", "E", "W" } do
		local alongX = side == "N" or side == "S"
		local length = if alongX then sx else sz
		local fixed = if side == "N" then c.Z - sz / 2 + 0.5
			elseif side == "S" then c.Z + sz / 2 - 0.5
			elseif side == "E" then c.X + sx / 2 - 0.5
			else c.X - sx / 2 + 0.5

		local function slab(a: number, b: number, y0: number, y1: number, color: Color3, material: Enum.Material, transparency: number?)
			if b - a < 0.05 or y1 - y0 < 0.05 then
				return
			end
			local mid, len, hgt = (a + b) / 2, b - a, y1 - y0
			local size = if alongX then Vector3.new(len, hgt, 1) else Vector3.new(1, hgt, len)
			local pos = if alongX then Vector3.new(c.X + mid, c.Y + y0 + hgt / 2, fixed) else Vector3.new(fixed, c.Y + y0 + hgt / 2, c.Z + mid)
			local p = part(folder, size, CFrame.new(pos), color, material)
			if transparency then
				p.Transparency = transparency
				p.CastShadow = false
				p.Name = "Window"
			end
		end

		local holes = {}
		for _, h in def.holes do
			if h.side == side then
				local bottom = h.bottom or (if h.kind == "door" then 0 else 3)
				local top = h.top or (if h.kind == "door" then DOOR_H else 13)
				table.insert(holes, { a = h.offset - h.width / 2, b = h.offset + h.width / 2, bottom = bottom, top = top, kind = h.kind })
			end
		end
		table.sort(holes, function(x, y)
			return x.a < y.a
		end)

		local cursor = -length / 2
		for _, h in holes do
			slab(cursor, h.a, 0, H, HULL, Enum.Material.Metal)
			slab(h.a, h.b, 0, h.bottom, HULL, Enum.Material.Metal)
			slab(h.a, h.b, h.top, H, HULL, Enum.Material.Metal)
			if h.kind == "window" then
				slab(h.a, h.b, h.bottom, h.top, GLASS, Enum.Material.Glass, 0.75)
			else
				-- glowing door frame
				slab(h.a, h.b, h.top, h.top + 0.4, TRIM, Enum.Material.Neon)
			end
			cursor = h.b
		end
		slab(cursor, length / 2, 0, H, HULL, Enum.Material.Metal)

		-- orange floor trim along the wall
		local trimSize = if alongX then Vector3.new(length, 0.3, 0.2) else Vector3.new(0.2, 0.3, length)
		local inward = if side == "N" then Vector3.new(0, 0, 0.6) elseif side == "S" then Vector3.new(0, 0, -0.6)
			elseif side == "E" then Vector3.new(-0.6, 0, 0) else Vector3.new(0.6, 0, 0)
		local trimPos = if alongX then Vector3.new(c.X, c.Y + 0.4, fixed) else Vector3.new(fixed, c.Y + 0.4, c.Z)
		deco(folder, trimSize, CFrame.new(trimPos + inward), TRIM, Enum.Material.Neon)
	end

	-- ceiling light panels on a grid
	local stepX = math.max(1, math.floor(sx / 18))
	local stepZ = math.max(1, math.floor(sz / 18))
	for i = 1, stepX do
		for j = 1, stepZ do
			local px = c.X - sx / 2 + (i - 0.5) * sx / stepX
			local pz = c.Z - sz / 2 + (j - 0.5) * sz / stepZ
			local panel = deco(folder, Vector3.new(5, 0.3, 2), CFrame.new(px, c.Y + H - 0.15, pz), Color3.fromRGB(235, 245, 255), Enum.Material.Neon)
			light(panel, Color3.fromRGB(215, 230, 255), 28, 1.1, "ShipLight")
		end
	end

	-- red alarm beacon (on during waves)
	local alarm = deco(folder, Vector3.new(1.4, 0.6, 1.4), CFrame.new(c + Vector3.new(0, H - 0.3, 0)), Color3.fromRGB(90, 20, 20), Enum.Material.SmoothPlastic)
	local al = light(alarm, Color3.fromRGB(255, 40, 30), 40, 0, "AlarmLight")
	al.Enabled = false

	return folder
end

-- Jupiter, built from stacked discs so it has real color bands ----------------------------------
local BANDS = {
	Color3.fromRGB(238, 222, 196), Color3.fromRGB(214, 170, 120), Color3.fromRGB(180, 120, 80),
	Color3.fromRGB(232, 196, 150), Color3.fromRGB(200, 140, 95), Color3.fromRGB(245, 232, 210),
	Color3.fromRGB(165, 105, 72), Color3.fromRGB(226, 182, 132),
}

local function buildJupiter(parent: Instance, center: Vector3, R: number, shipPos: Vector3)
	local folder = Instance.new("Model")
	folder.Name = "Jupiter"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- always visible, even with streaming on
	folder.Parent = parent
	local slices = 44
	local t = 2 * R / slices
	local rng = Random.new(2011)
	local band = 1
	for i = 0, slices - 1 do
		local y = -R + (i + 0.5) * t
		local r = math.sqrt(math.max(R * R - y * y, 1))
		if rng:NextNumber() < 0.45 then
			band = rng:NextInteger(1, #BANDS)
		end
		local disc = deco(folder, Vector3.new(t + 0.2, 2 * r, 2 * r), CFrame.new(center + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)), BANDS[band])
		disc.Shape = Enum.PartType.Cylinder
		disc.Material = Enum.Material.SmoothPlastic
	end
	-- the Great Red Spot, facing the ship, south of the equator
	local toShip = shipPos - center
	local flat = Vector3.new(toShip.X, 0, toShip.Z).Unit
	local lat = math.rad(-22)
	local dir = (flat * math.cos(lat) + Vector3.new(0, math.sin(lat), 0)).Unit
	local spotPos = center + dir * (R * 0.985)
	local spot = deco(folder, Vector3.new(R * 0.03, R * 0.26, R * 0.26), CFrame.lookAt(spotPos, spotPos + dir) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(190, 75, 50))
	spot.Shape = Enum.PartType.Cylinder
	-- soft glow shell
	local glow = deco(folder, Vector3.new(R * 2.08, R * 2.08, R * 2.08), CFrame.new(center), Color3.fromRGB(255, 170, 110), Enum.Material.Neon)
	glow.Shape = Enum.PartType.Ball
	glow.Transparency = 0.93

	-- moons
	for _, m in { { offset = Vector3.new(-R * 1.6, R * 0.35, -R * 0.6), size = R * 0.09, color = Color3.fromRGB(235, 210, 120) },
		{ offset = Vector3.new(-R * 0.7, -R * 0.55, -R * 1.5), size = R * 0.07, color = Color3.fromRGB(225, 225, 235) } } do
		local moon = deco(folder, Vector3.one * m.size, CFrame.new(center + m.offset), m.color)
		moon.Shape = Enum.PartType.Ball
	end
end

export type ShipInfo = {
	folder: Folder,
	spawn: SpawnLocation,
	reactor: BasePart,
	reactorRadius: number,
	vents: { Vector3 },
	roomCenters: { Vector3 },
	leaderboard: Frame,
}

function ShipBuilder.build(): ShipInfo
	local old = workspace:FindFirstChild("Ship")
	if old then
		old:Destroy()
	end
	local ship = Instance.new("Folder")
	ship.Name = "Ship"
	ship.Parent = workspace

	local rooms: { RoomDef } = {
		{ name = "Bridge", center = Vector3.new(85, 0, 0), size = Vector2.new(40, 44), holes = {
			{ side = "W", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "E", offset = 0, width = 36, kind = "window", bottom = 2.5, top = 14 },
			{ side = "S", offset = 0, width = 26, kind = "window" },
			{ side = "N", offset = 0, width = 26, kind = "window" },
		} },
		{ name = "Corridor B", center = Vector3.new(45, 0, 0), size = Vector2.new(40, 14), holes = {
			{ side = "E", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "W", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "S", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "N", offset = -10, width = 12, kind = "window" },
			{ side = "N", offset = 10, width = 12, kind = "window" },
		} },
		{ name = "Medbay", center = Vector3.new(45, 0, 24), size = Vector2.new(34, 34), holes = {
			{ side = "N", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "S", offset = 0, width = 26, kind = "window" },
			{ side = "E", offset = 0, width = 20, kind = "window" },
		} },
		{ name = "Reactor", center = Vector3.new(0, 0, 0), size = Vector2.new(50, 50), holes = {
			{ side = "E", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "W", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "N", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "S", offset = 0, width = DOOR_W, kind = "door" },
		} },
		{ name = "Observation Deck", center = Vector3.new(0, 0, 45), size = Vector2.new(40, 40), holes = {
			{ side = "N", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "S", offset = 0, width = 36, kind = "window", bottom = 1.5, top = 14.5 },
			{ side = "E", offset = 0, width = 30, kind = "window" },
			{ side = "W", offset = 0, width = 30, kind = "window" },
		} },
		{ name = "Engine Room", center = Vector3.new(0, 0, -45), size = Vector2.new(40, 40), holes = {
			{ side = "S", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "N", offset = 0, width = 20, kind = "window" },
		} },
		{ name = "Corridor A", center = Vector3.new(-45, 0, 0), size = Vector2.new(40, 14), holes = {
			{ side = "E", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "W", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "N", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "S", offset = -10, width = 12, kind = "window" },
			{ side = "S", offset = 10, width = 12, kind = "window" },
		} },
		{ name = "Crew Quarters", center = Vector3.new(-45, 0, -24), size = Vector2.new(34, 34), holes = {
			{ side = "S", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "N", offset = 0, width = 22, kind = "window" },
		} },
		{ name = "Cargo Bay", center = Vector3.new(-90, 0, 0), size = Vector2.new(50, 50), holes = {
			{ side = "E", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "W", offset = 0, width = 30, kind = "window" },
			{ side = "S", offset = 0, width = 24, kind = "window" },
		} },
	}

	local roomCenters = {}
	local folders: { [string]: Folder } = {}
	for _, def in rooms do
		folders[def.name] = buildRoom(ship, def)
		table.insert(roomCenters, def.center)
	end

	-- Reactor core -------------------------------------------------------------------------
	local rf = folders["Reactor"]
	local base = part(rf, Vector3.new(3, 14, 14), CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), HULL_DARK, Enum.Material.Metal)
	base.Shape = Enum.PartType.Cylinder
	local core = part(rf, Vector3.new(12, 6, 6), CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(90, 220, 255), Enum.Material.Neon, "ReactorCore")
	core.Shape = Enum.PartType.Cylinder
	light(core, Color3.fromRGB(90, 220, 255), 40, 2.5)
	for k, y in { 5, 9, 13 } do
		local ring = deco(rf, Vector3.new(0.8, 10 + k, 10 + k), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), HULL, Enum.Material.Metal)
		ring.Shape = Enum.PartType.Cylinder
		ring.Name = "ReactorRing"
		ring.Transparency = 0.1
	end
	local cap = part(rf, Vector3.new(1, 10, 10), CFrame.new(0, H - 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), HULL_DARK, Enum.Material.Metal)
	cap.Shape = Enum.PartType.Cylinder

	-- Bridge: consoles + captain's chair + leaderboard ------------------------------------------
	local bf = folders["Bridge"]
	for _, z in { -12, -4, 4, 12 } do
		part(bf, Vector3.new(3, 3.5, 6), CFrame.new(98, 1.75, z), HULL_DARK, Enum.Material.Metal)
		deco(bf, Vector3.new(0.2, 2.5, 5), CFrame.new(96.4, 3.6, z) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(255, 160, 80), Enum.Material.Neon)
	end
	part(bf, Vector3.new(3, 1, 3), CFrame.new(84, 1.5, 0), HULL_DARK, Enum.Material.Metal)
	part(bf, Vector3.new(0.6, 4, 3), CFrame.new(82.8, 3.5, 0), Color3.fromRGB(150, 40, 30), Enum.Material.Fabric)

	local board = part(bf, Vector3.new(0.5, 9, 14), CFrame.new(66.4, 7, -14), Color3.fromRGB(10, 10, 14), Enum.Material.SmoothPlastic, "Leaderboard")
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Right
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Parent = board
	local boardFrame = Instance.new("Frame")
	boardFrame.Size = UDim2.fromScale(1, 1)
	boardFrame.BackgroundColor3 = Color3.fromRGB(14, 11, 18)
	boardFrame.Parent = sg

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(76, 0.2, 0)
	spawn.Color = TRIM
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.6
	spawn.Parent = bf

	-- Props -----------------------------------------------------------------------------------
	local cf = folders["Cargo Bay"]
	local rng = Random.new(14)
	for _ = 1, 10 do
		local s = rng:NextInteger(4, 7)
		part(cf, Vector3.new(s, s, s), CFrame.new(-90 + rng:NextNumber(-18, 18), s / 2, rng:NextNumber(-18, 18)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0),
			Color3.fromRGB(150, 110, 60), Enum.Material.WoodPlanks)
	end
	local mf = folders["Medbay"]
	for _, x in { 33, 57 } do
		for _, z in { 18, 32 } do
			part(mf, Vector3.new(4, 2, 7), CFrame.new(x, 1, z), Color3.fromRGB(230, 235, 240), Enum.Material.SmoothPlastic)
		end
	end
	local ef = folders["Engine Room"]
	for _, x in { -10, 10 } do
		local eng = part(ef, Vector3.new(14, 7, 7), CFrame.new(x, 7, -52) * CFrame.Angles(0, 0, math.rad(90)), HULL_DARK, Enum.Material.Metal)
		eng.Shape = Enum.PartType.Cylinder
		local glowRing = deco(ef, Vector3.new(1, 7.6, 7.6), CFrame.new(x, 10, -52) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 120, 50), Enum.Material.Neon)
		glowRing.Shape = Enum.PartType.Cylinder
	end
	local of = folders["Observation Deck"]
	for _, x in { -10, 0, 10 } do
		part(of, Vector3.new(6, 1.5, 2), CFrame.new(x, 0.75, 52), Color3.fromRGB(150, 40, 30), Enum.Material.Fabric)
	end
	local qf = folders["Crew Quarters"]
	for _, x in { -57, -33 } do
		for _, z in { -34, -18 } do
			part(qf, Vector3.new(7, 2.5, 4), CFrame.new(x, 1.25, z), Color3.fromRGB(80, 90, 120), Enum.Material.Fabric)
		end
	end

	-- Vents (where the Keis come from) ----------------------------------------------------------
	local vents = {}
	for _, pos in { Vector3.new(-105, 0, -18), Vector3.new(-105, 0, 18), Vector3.new(-15, 0, -60), Vector3.new(15, 0, -60),
		Vector3.new(-58, 0, -36), Vector3.new(14, 0, 58), Vector3.new(50, 0, 38) } do
		local grate = deco(ship, Vector3.new(5, 0.2, 5), CFrame.new(pos + Vector3.new(0, 0.05, 0)), Color3.fromRGB(20, 20, 24), Enum.Material.DiamondPlate)
		grate.Name = "Vent"
		local glowV = deco(ship, Vector3.new(4.4, 0.1, 4.4), CFrame.new(pos + Vector3.new(0, 0.02, 0)), Color3.fromRGB(255, 40, 30), Enum.Material.Neon)
		glowV.Transparency = 0.5
		table.insert(vents, pos + Vector3.new(0, 3, 0))
	end

	-- Space -------------------------------------------------------------------------------------
	buildJupiter(ship, Vector3.new(1000, 110, 720), 460, Vector3.new(40, 8, 0))

	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("Clouds") then
			child:Destroy()
		end
	end
	local sky = Instance.new("Sky")
	sky.StarCount = 5000
	sky.CelestialBodiesShown = false
	sky.Parent = Lighting
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(40, 40, 52)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 160, 150)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.FogEnd = 100000
	Lighting.GlobalShadows = true

	return {
		folder = ship,
		spawn = spawn,
		reactor = core,
		reactorRadius = 8,
		vents = vents,
		roomCenters = roomCenters,
		leaderboard = boardFrame,
	}
end

return ShipBuilder
