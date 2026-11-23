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

local HULL = Color3.fromRGB(150, 154, 156)
local HULL_DARK = Color3.fromRGB(62, 66, 76)
local FLOOR = Color3.fromRGB(56, 58, 60)
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
type RoomDef = { name: string, code: string, cam: string, center: Vector3, size: Vector2, holes: { Hole } }

local HAZARD_Y = Color3.fromRGB(230, 180, 30)
local PIPE = Color3.fromRGB(96, 92, 86)
local GRATE = Color3.fromRGB(24, 25, 28)
local RIB = Color3.fromRGB(120, 124, 128)

local function hazardPost(parent: Instance, size: Vector3, cf: CFrame)
	-- yellow/black striped post (stacked bands)
	local bands = math.max(2, math.floor(size.Y / 1.2))
	local h = size.Y / bands
	for i = 0, bands - 1 do
		deco(parent, Vector3.new(size.X, h, size.Z), cf * CFrame.new(0, -size.Y / 2 + h * (i + 0.5), 0),
			if i % 2 == 0 then HAZARD_Y else Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
	end
end

local function sectorLabel(parent: Instance, cf: CFrame, code: string)
	local board = deco(parent, Vector3.new(7, 4.5, 0.05), cf, Color3.new(0, 0, 0))
	board.Transparency = 1
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(350, 225)
	sg.LightInfluence = 1
	sg.Parent = board
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(225, 222, 210)
	l.TextTransparency = 0.15
	l.Text = code
	l.Parent = sg
end

local function buildRoom(parent: Instance, def: RoomDef): Folder
	local folder = Instance.new("Folder")
	folder.Name = def.name
	folder:SetAttribute("Center", def.center)
	folder:SetAttribute("Size", def.size)
	folder:SetAttribute("Cam", def.cam)
	folder.Parent = parent
	local c, sx, sz = def.center, def.size.X, def.size.Y

	part(folder, Vector3.new(sx, 1, sz), CFrame.new(c + Vector3.new(0, -0.5, 0)), FLOOR, Enum.Material.DiamondPlate, "Floor")
	part(folder, Vector3.new(sx, 1, sz), CFrame.new(c + Vector3.new(0, H + 0.5, 0)), HULL_DARK, Enum.Material.Metal, "Ceiling")

	-- floor grate strip down the long axis (dark slats, like the corridor in the footage)
	local alongXFloor = sx >= sz
	local runLen = (if alongXFloor then sx else sz) - 4
	local slats = math.floor(runLen / 1.3)
	for i = 0, slats - 1 do
		local t = -runLen / 2 + (i + 0.5) * (runLen / slats)
		local size = if alongXFloor then Vector3.new(0.8, 0.06, 6) else Vector3.new(6, 0.06, 0.8)
		local pos = if alongXFloor then c + Vector3.new(t, 0.03, 0) else c + Vector3.new(0, 0.03, t)
		deco(folder, size, CFrame.new(pos), GRATE, Enum.Material.Metal)
	end
	for _, edge in { -3.4, 3.4 } do
		local size = if alongXFloor then Vector3.new(runLen, 0.08, 0.4) else Vector3.new(0.4, 0.08, runLen)
		local pos = if alongXFloor then c + Vector3.new(0, 0.04, edge) else c + Vector3.new(edge, 0.04, 0)
		deco(folder, size, CFrame.new(pos), HAZARD_Y, Enum.Material.SmoothPlastic)
	end

	local labelPlaced = false
	for _, side in { "N", "S", "E", "W" } do
		local alongX = side == "N" or side == "S"
		local length = if alongX then sx else sz
		local fixed = if side == "N" then c.Z - sz / 2 + 0.5
			elseif side == "S" then c.Z + sz / 2 - 0.5
			elseif side == "E" then c.X + sx / 2 - 0.5
			else c.X - sx / 2 + 0.5
		local inward = if side == "N" then Vector3.new(0, 0, 1) elseif side == "S" then Vector3.new(0, 0, -1)
			elseif side == "E" then Vector3.new(-1, 0, 0) else Vector3.new(1, 0, 0)

		local function at(t: number, y: number, depth: number): Vector3
			local base = if alongX then Vector3.new(c.X + t, c.Y + y, fixed) else Vector3.new(fixed, c.Y + y, c.Z + t)
			return base + inward * depth
		end
		local function slab(a: number, b: number, y0: number, y1: number, color: Color3, material: Enum.Material, transparency: number?)
			if b - a < 0.05 or y1 - y0 < 0.05 then
				return
			end
			local len, hgt = b - a, y1 - y0
			local size = if alongX then Vector3.new(len, hgt, 1) else Vector3.new(1, hgt, len)
			local p = part(folder, size, CFrame.new(at((a + b) / 2, y0 + hgt / 2, 0)), color, material)
			if transparency then
				p.Transparency = transparency
				p.CastShadow = false
				p.Name = "Window"
			end
		end
		local function rib(t: number, height: number, color: Color3)
			local size = if alongX then Vector3.new(0.9, height, 0.7) else Vector3.new(0.7, height, 0.9)
			deco(folder, size, CFrame.new(at(t, height / 2, 0.75)), color, Enum.Material.Metal)
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
				slab(h.a, h.b, h.bottom, h.top, GLASS, Enum.Material.Glass, 0.8)
				-- heavy window frame
				for _, t in { h.a, h.b } do
					rib(t, H, RIB)
				end
				local sill = if alongX then Vector3.new(h.b - h.a, 0.6, 1.2) else Vector3.new(1.2, 0.6, h.b - h.a)
				deco(folder, sill, CFrame.new(at((h.a + h.b) / 2, h.bottom - 0.3, 0.6)), RIB, Enum.Material.Metal)
				deco(folder, sill, CFrame.new(at((h.a + h.b) / 2, h.top + 0.3, 0.6)), RIB, Enum.Material.Metal)
			else
				-- door frame with hazard stripes + a lit header
				for _, t in { h.a - 0.45, h.b + 0.45 } do
					local size = if alongX then Vector3.new(0.9, h.top, 1.4) else Vector3.new(1.4, h.top, 0.9)
					hazardPost(folder, size, CFrame.new(at(t, h.top / 2, 0.7)))
				end
				local header = if alongX then Vector3.new(h.b - h.a + 1.8, 0.8, 1.4) else Vector3.new(1.4, 0.8, h.b - h.a + 1.8)
				deco(folder, header, CFrame.new(at((h.a + h.b) / 2, h.top + 0.4, 0.7)), RIB, Enum.Material.Metal)
				local lamp = if alongX then Vector3.new(2, 0.3, 0.2) else Vector3.new(0.2, 0.3, 2)
				local l = deco(folder, lamp, CFrame.new(at((h.a + h.b) / 2, h.top + 0.4, 1.45)), Color3.fromRGB(255, 70, 50), Enum.Material.Neon)
				light(l, Color3.fromRGB(255, 80, 60), 8, 0.6)
			end
			cursor = h.b
		end
		slab(cursor, length / 2, 0, H, HULL, Enum.Material.Metal)

		-- ribs every ~8 studs where the wall is solid, plus darker inset panels
		local t = -length / 2 + 4
		while t < length / 2 - 3 do
			local blocked = false
			for _, h in holes do
				if t > h.a - 1.5 and t < h.b + 1.5 then
					blocked = true
				end
			end
			local panelBlocked = t + 4 > length / 2 - 3
			for _, h in holes do
				if t + 4 > h.a - 3.5 and t + 4 < h.b + 3.5 then
					panelBlocked = true
				end
			end
			if not blocked then
				rib(t, H, RIB)
			end
			if not panelBlocked then
				local panel = if alongX then Vector3.new(5.5, 7, 0.15) else Vector3.new(0.15, 7, 5.5)
				deco(folder, panel, CFrame.new(at(t + 4, 6, 0.55)), Color3.fromRGB(128, 132, 136), Enum.Material.Metal)
			end
			t += 8
		end

		-- pipes along the top of every wall
		local pipeSize = Vector3.new(length - 2, 1, 1)
		local pipeCf = CFrame.new(at(0, H - 1, 1.1)) * (if alongX then CFrame.new() else CFrame.Angles(0, math.rad(90), 0))
		local pipe = deco(folder, pipeSize, pipeCf, PIPE, Enum.Material.Metal)
		pipe.Shape = Enum.PartType.Cylinder
		local pipe2 = deco(folder, Vector3.new(length - 2, 0.6, 0.6), pipeCf * CFrame.new(0, -1.1, 0), Color3.fromRGB(150, 70, 40), Enum.Material.Metal)
		pipe2.Shape = Enum.PartType.Cylinder

		-- sector label on the first wall with free space at its end
		if not labelPlaced then
			local freeFrom = -length / 2
			for _, h in holes do
				freeFrom = math.max(freeFrom, h.b)
			end
			if length / 2 - freeFrom >= 9 then
				labelPlaced = true
				local pos = at(length / 2 - 5, 8.5, 0.56)
				sectorLabel(folder, CFrame.lookAt(pos, pos + inward), def.code)
			end
		end
	end

	-- fluorescent tubes on a grid
	local stepX = math.max(1, math.floor(sx / 14))
	local stepZ = math.max(1, math.floor(sz / 14))
	for i = 1, stepX do
		for j = 1, stepZ do
			local px = c.X - sx / 2 + (i - 0.5) * sx / stepX
			local pz = c.Z - sz / 2 + (j - 0.5) * sz / stepZ
			deco(folder, Vector3.new(7, 0.5, 1.4), CFrame.new(px, c.Y + H - 0.25, pz), HULL_DARK, Enum.Material.Metal)
			local tube = deco(folder, Vector3.new(6, 0.25, 0.5), CFrame.new(px, c.Y + H - 0.55, pz), Color3.fromRGB(215, 235, 255), Enum.Material.Neon)
			light(tube, Color3.fromRGB(200, 222, 255), 24, 0.95, "ShipLight")
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
		{ name = "Bridge", code = "A-1", cam = "CAM 01 (BRIDGE)", center = Vector3.new(85, 0, 0), size = Vector2.new(40, 44), holes = {
			{ side = "W", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "E", offset = 0, width = 36, kind = "window", bottom = 2.5, top = 14 },
			{ side = "S", offset = 0, width = 26, kind = "window" },
			{ side = "N", offset = 0, width = 26, kind = "window" },
		} },
		{ name = "Corridor B", code = "C-3", cam = "CAM 04 (CORRIDOR)", center = Vector3.new(45, 0, 0), size = Vector2.new(40, 14), holes = {
			{ side = "E", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "W", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "S", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "N", offset = -10, width = 12, kind = "window" },
			{ side = "N", offset = 10, width = 12, kind = "window" },
		} },
		{ name = "Medbay", code = "M-2", cam = "CAM 05 (MEDBAY)", center = Vector3.new(45, 0, 24), size = Vector2.new(34, 34), holes = {
			{ side = "N", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "S", offset = 0, width = 26, kind = "window" },
			{ side = "E", offset = 0, width = 20, kind = "window" },
		} },
		{ name = "Reactor", code = "R-0", cam = "CAM 02 (REACTOR)", center = Vector3.new(0, 0, 0), size = Vector2.new(50, 50), holes = {
			{ side = "E", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "W", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "N", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "S", offset = 0, width = DOOR_W, kind = "door" },
		} },
		{ name = "Observation Deck", code = "O-6", cam = "CAM 07 (OBSERVATION)", center = Vector3.new(0, 0, 45), size = Vector2.new(40, 40), holes = {
			{ side = "N", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "S", offset = 0, width = 36, kind = "window", bottom = 1.5, top = 14.5 },
			{ side = "E", offset = 0, width = 30, kind = "window" },
			{ side = "W", offset = 0, width = 30, kind = "window" },
		} },
		{ name = "Engine Room", code = "E-5", cam = "CAM 06 (ENGINES)", center = Vector3.new(0, 0, -45), size = Vector2.new(40, 40), holes = {
			{ side = "S", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "N", offset = 0, width = 20, kind = "window" },
		} },
		{ name = "Corridor A", code = "C-2", cam = "CAM 03 (CORRIDOR)", center = Vector3.new(-45, 0, 0), size = Vector2.new(40, 14), holes = {
			{ side = "E", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "W", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "N", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "S", offset = -10, width = 12, kind = "window" },
			{ side = "S", offset = 10, width = 12, kind = "window" },
		} },
		{ name = "Crew Quarters", code = "Q-4", cam = "CAM 08 (QUARTERS)", center = Vector3.new(-45, 0, -24), size = Vector2.new(34, 34), holes = {
			{ side = "S", offset = 0, width = DOOR_W, kind = "door" },
			{ side = "N", offset = 0, width = 22, kind = "window" },
		} },
		{ name = "Cargo Bay", code = "K-9", cam = "CAM 09 (CARGO BAY)", center = Vector3.new(-90, 0, 0), size = Vector2.new(50, 50), holes = {
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

	local board = part(bf, Vector3.new(0.5, 9, 14), CFrame.new(67.3, 7, -14), Color3.fromRGB(10, 10, 14), Enum.Material.SmoothPlastic, "Leaderboard")
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
	Lighting.Ambient = Color3.fromRGB(30, 32, 36)
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
