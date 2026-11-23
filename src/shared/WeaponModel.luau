--!strict
-- Detailed weapon models built from parts, with attachments (optic / laser / muzzle).
-- Used by the server (the tool other players see), the client viewmodel (first person) and the Armory preview.
-- Convention: the weapon points down -Z, +Y is up, the root part sits at the origin.

local WeaponModel = {}

export type Attachments = { Optic: string, Laser: string, Muzzle: string }
export type Built = {
	root: BasePart,
	muzzle: BasePart, -- invisible part at the barrel tip
	laser: BasePart?, -- invisible part at the laser lens
	sight: CFrame, -- where your eye goes when aiming down sights (relative to root)
	grip: CFrame, -- where the right hand holds it (relative to root)
	foregrip: CFrame, -- where the left hand holds it
	spin: Motor6D?, -- minigun barrel joint (clients spin it)
	parts: { BasePart },
}

local WHITE = Color3.fromRGB(226, 228, 232)
local DARK = Color3.fromRGB(46, 48, 54)
local GUNMETAL = Color3.fromRGB(70, 72, 78)
local BLACK = Color3.fromRGB(18, 18, 20)
local ORANGE = Color3.fromRGB(255, 138, 61)
local CYAN = Color3.fromRGB(90, 220, 255)
local OLIVE = Color3.fromRGB(88, 94, 60)
local BRASS = Color3.fromRGB(200, 160, 70)
local GLASS = Color3.fromRGB(150, 200, 230)

local function axisZ(): CFrame
	return CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder's X axis to point along Z
end

function WeaponModel.build(weaponId: string, att: Attachments, parent: Instance, rootName: string?): Built
	local parts: { BasePart } = {}
	local root = Instance.new("Part")
	root.Name = rootName or "Root"
	root.CFrame = CFrame.new()
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Material = Enum.Material.SmoothPlastic

	local function add(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?, attachTo: BasePart?): Part
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.CFrame = (attachTo or root).CFrame * cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		local w = Instance.new("WeldConstraint")
		w.Part0 = attachTo or root
		w.Part1 = p
		w.Parent = p
		table.insert(parts, p)
		return p
	end
	local function marker(name: string, cf: CFrame): Part
		local p = add(name, Vector3.new(0.05, 0.05, 0.05), cf, BLACK)
		p.Transparency = 1
		return p
	end

	local mountY: number -- top of the rail where optics sit
	local mountZ = 0 -- optic center along the gun
	local laserAt: CFrame
	local muzzleZ: number
	local barrelY: number
	local ironSight: CFrame
	local grip: CFrame
	local foregrip: CFrame
	local spin: Motor6D? = nil

	if weaponId == "Minigun" then
		root.Size = Vector3.new(0.8, 0.75, 1.3)
		root.Color = GUNMETAL
		root.Material = Enum.Material.Metal
		root.Parent = parent
		table.insert(parts, root)
		add("Motor", Vector3.new(0.62, 0.6, 0.6), CFrame.new(0, 0, 0.95), DARK, Enum.Material.Metal)
		for i = 0, 3 do
			add("Fin", Vector3.new(0.66, 0.04, 0.5), CFrame.new(0, -0.22 + i * 0.15, 0.95), BLACK, Enum.Material.Metal)
		end
		add("StripeL", Vector3.new(0.02, 0.1, 1.1), CFrame.new(-0.41, 0.12, 0), ORANGE)
		add("StripeR", Vector3.new(0.02, 0.1, 1.1), CFrame.new(0.41, 0.12, 0), ORANGE)
		add("FrontPlate", Vector3.new(0.86, 0.8, 0.1), CFrame.new(0, 0, -0.7), DARK, Enum.Material.Metal)
		-- carry handle with a rail on top
		for _, z in { -0.4, 0.4 } do
			add("HandlePost", Vector3.new(0.08, 0.3, 0.08), CFrame.new(0, 0.52, z), DARK, Enum.Material.Metal)
		end
		add("HandleBar", Vector3.new(0.1, 0.1, 0.92), CFrame.new(0, 0.7, 0), DARK, Enum.Material.Metal)
		add("Rail", Vector3.new(0.22, 0.05, 0.7), CFrame.new(0, 0.77, 0), BLACK, Enum.Material.Metal)
		mountY, mountZ = 0.8, 0
		-- spade grips at the back
		for _, x in { -0.25, 0.25 } do
			add("Spade", Vector3.new(0.1, 0.55, 0.1), CFrame.new(x, -0.05, 1.4), BLACK, Enum.Material.Fabric)
		end
		add("SpadeBar", Vector3.new(0.6, 0.08, 0.08), CFrame.new(0, 0.22, 1.4), DARK, Enum.Material.Metal)
		add("Trigger", Vector3.new(0.08, 0.08, 0.06), CFrame.new(0.25, 0.25, 1.4), Color3.fromRGB(255, 50, 40), Enum.Material.Neon)
		-- ammo box + belt
		add("AmmoBox", Vector3.new(0.6, 0.65, 0.85), CFrame.new(0.75, -0.25, 0.1), OLIVE, Enum.Material.Metal)
		add("AmmoLid", Vector3.new(0.62, 0.06, 0.87), CFrame.new(0.75, 0.1, 0.1), Color3.fromRGB(70, 75, 48), Enum.Material.Metal)
		add("Stencil", Vector3.new(0.02, 0.2, 0.5), CFrame.new(1.06, -0.25, 0.1), Color3.fromRGB(220, 210, 160))
		for i = 0, 4 do
			add("Belt", Vector3.new(0.12, 0.12, 0.14), CFrame.new(0.62 - i * 0.05, 0.18 + i * 0.05, 0.05 - i * 0.12) * CFrame.Angles(0, 0, math.rad(20)), BRASS, Enum.Material.Metal)
		end
		-- rotating barrel cluster on a Motor6D
		local hub = add("Hub", Vector3.new(0.3, 0.56, 0.56), CFrame.new(0, 0, -0.9) * axisZ(), GUNMETAL, Enum.Material.Metal, Enum.PartType.Cylinder)
		hub:FindFirstChildOfClass("WeldConstraint"):Destroy()
		local motor = Instance.new("Motor6D")
		motor.Name = "Spin"
		motor.Part0 = root
		motor.Part1 = hub
		motor.C0 = CFrame.new(0, 0, -0.9) * axisZ()
		motor.Parent = root
		spin = motor
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			add("Barrel", Vector3.new(2.6, 0.17, 0.17), CFrame.new(0, math.cos(a) * 0.2, math.sin(a) * 0.2) * CFrame.new(1.3, 0, 0), -- hub local +X points forward
				Color3.fromRGB(60, 60, 64), Enum.Material.Metal, Enum.PartType.Cylinder, hub)
		end
		for _, x in { 0.7, 2.0, 2.55 } do
			add("Clamp", Vector3.new(0.12, 0.62, 0.62), CFrame.new(x, 0, 0), DARK, Enum.Material.Metal, Enum.PartType.Cylinder, hub)
		end
		barrelY, muzzleZ = 0, -3.55
		laserAt = CFrame.new(-0.48, 0.12, -0.55)
		ironSight = CFrame.new(0, 0.86, 0.9)
		add("IronRing", Vector3.new(0.04, 0.12, 0.12), CFrame.new(0, 0.86, -0.35) * axisZ(), BLACK, Enum.Material.Metal, Enum.PartType.Cylinder)
		grip = CFrame.new(0.25, -0.05, 1.4)
		foregrip = CFrame.new(-0.25, 0.65, 0)
	else
		-- BLASTER: sci-fi carbine
		root.Size = Vector3.new(0.5, 0.55, 1.6)
		root.Color = WHITE
		root.Parent = parent
		table.insert(parts, root)
		add("UpperReceiver", Vector3.new(0.46, 0.18, 1.5), CFrame.new(0, 0.36, -0.05), DARK, Enum.Material.Metal)
		add("Rail", Vector3.new(0.3, 0.06, 1.3), CFrame.new(0, 0.48, -0.05), BLACK, Enum.Material.Metal)
		for i = 0, 5 do
			add("RailNotch", Vector3.new(0.32, 0.04, 0.06), CFrame.new(0, 0.52, -0.6 + i * 0.22), BLACK, Enum.Material.Metal)
		end
		mountY, mountZ = 0.52, 0.05
		for _, x in { -0.26, 0.26 } do
			add("Stripe", Vector3.new(0.02, 0.08, 1.1), CFrame.new(x, 0.05, 0), ORANGE)
			for _, z in { -0.55, 0.45 } do
				add("Bolt", Vector3.new(0.04, 0.07, 0.07), CFrame.new(x + (if x > 0 then 0.01 else -0.01), -0.15, z), GUNMETAL, Enum.Material.Metal, Enum.PartType.Cylinder)
			end
		end
		add("EjectionPort", Vector3.new(0.02, 0.14, 0.35), CFrame.new(0.26, 0.18, -0.2), BLACK)
		add("ChargingHandle", Vector3.new(0.12, 0.07, 0.22), CFrame.new(0.31, 0.3, 0.45), DARK, Enum.Material.Metal)
		add("StatusLED", Vector3.new(0.05, 0.05, 0.05), CFrame.new(-0.26, 0.28, 0.55), Color3.fromRGB(80, 255, 120), Enum.Material.Neon)
		-- shroud with cooling vents
		add("Shroud", Vector3.new(0.4, 0.4, 1.3), CFrame.new(0, 0.12, -1.45), DARK, Enum.Material.Metal)
		add("ShroudRail", Vector3.new(0.26, 0.05, 0.9), CFrame.new(0, 0.345, -1.45), BLACK, Enum.Material.Metal)
		for k = 0, 2 do
			for _, x in { -0.205, 0.205 } do
				add("Vent", Vector3.new(0.02, 0.09, 0.22), CFrame.new(x, 0.14, -1.05 - k * 0.35), BLACK)
			end
		end
		add("CoilGlow", Vector3.new(0.41, 0.05, 0.9), CFrame.new(0, -0.06, -1.45), CYAN, Enum.Material.Neon)
		local long = att.Muzzle == "LongBarrel"
		local barrelLen = if long then 1.25 else 0.65
		add("Barrel", Vector3.new(barrelLen, 0.2, 0.2), CFrame.new(0, 0.12, -2.1 - barrelLen / 2) * axisZ(), GUNMETAL, Enum.Material.Metal, Enum.PartType.Cylinder)
		barrelY, muzzleZ = 0.12, -2.1 - barrelLen
		-- energy cell (magazine)
		add("Cell", Vector3.new(0.28, 0.62, 0.4), CFrame.new(0, -0.48, -0.35) * CFrame.Angles(math.rad(-8), 0, 0), DARK, Enum.Material.Metal)
		add("CellWindow", Vector3.new(0.3, 0.36, 0.1), CFrame.new(0, -0.45, -0.52) * CFrame.Angles(math.rad(-8), 0, 0), CYAN, Enum.Material.Neon)
		add("CellCap", Vector3.new(0.3, 0.08, 0.42), CFrame.new(0, -0.79, -0.31) * CFrame.Angles(math.rad(-8), 0, 0), BLACK, Enum.Material.Metal)
		add("TriggerGuard", Vector3.new(0.06, 0.06, 0.42), CFrame.new(0, -0.36, 0.12), DARK, Enum.Material.Metal)
		add("Trigger", Vector3.new(0.04, 0.16, 0.04), CFrame.new(0, -0.28, 0.06), BLACK, Enum.Material.Metal)
		add("Grip", Vector3.new(0.26, 0.62, 0.34), CFrame.new(0, -0.5, 0.42) * CFrame.Angles(math.rad(18), 0, 0), BLACK, Enum.Material.Fabric)
		add("StockTube", Vector3.new(0.7, 0.18, 0.18), CFrame.new(0, 0.05, 1.12) * axisZ(), GUNMETAL, Enum.Material.Metal, Enum.PartType.Cylinder)
		add("Stock", Vector3.new(0.24, 0.42, 0.55), CFrame.new(0, -0.08, 1.45), WHITE)
		add("ButtPad", Vector3.new(0.26, 0.5, 0.08), CFrame.new(0, -0.08, 1.76), BLACK, Enum.Material.Fabric)
		add("Foregrip", Vector3.new(0.2, 0.38, 0.24), CFrame.new(0, -0.24, -1.3), BLACK, Enum.Material.Fabric)
		laserAt = CFrame.new(0.25, 0.02, -1.5)
		ironSight = CFrame.new(0, 0.6, 0.95)
		grip = CFrame.new(0, -0.45, 0.42)
		foregrip = CFrame.new(0, -0.3, -1.3)
	end

	-- Muzzle device --------------------------------------------------------------------------------
	if weaponId ~= "Minigun" then
		if att.Muzzle == "Compensator" then
			add("Compensator", Vector3.new(0.3, 0.3, 0.42), CFrame.new(0, barrelY, muzzleZ - 0.2), DARK, Enum.Material.Metal)
			for k = 0, 2 do
				add("Port", Vector3.new(0.18, 0.02, 0.06), CFrame.new(0, barrelY + 0.15, muzzleZ - 0.08 - k * 0.12), BLACK)
			end
			muzzleZ -= 0.42
		else
			add("MuzzleBrake", Vector3.new(0.26, 0.26, 0.18), CFrame.new(0, barrelY, muzzleZ - 0.09), BLACK, Enum.Material.Metal)
			muzzleZ -= 0.18
		end
	end
	local muzzle = marker("Muzzle", CFrame.new(0, barrelY, muzzleZ - 0.05))

	-- Optic -------------------------------------------------------------------------------------------
	local sightY = ironSight.Y
	local optic = att.Optic or "Iron"
	local my, mz = mountY, mountZ
	if optic == "Iron" then
		if weaponId ~= "Minigun" then
			add("FrontSightBase", Vector3.new(0.12, 0.1, 0.12), CFrame.new(0, 0.42, -1.95), BLACK, Enum.Material.Metal)
			add("FrontSightPost", Vector3.new(0.03, 0.14, 0.03), CFrame.new(0, 0.53, -1.95), BLACK, Enum.Material.Metal)
			add("RearSightL", Vector3.new(0.05, 0.14, 0.08), CFrame.new(-0.07, 0.6, 0.55), BLACK, Enum.Material.Metal)
			add("RearSightR", Vector3.new(0.05, 0.14, 0.08), CFrame.new(0.07, 0.6, 0.55), BLACK, Enum.Material.Metal)
			sightY = 0.58
		end
	elseif optic == "RedDot" then
		add("OpticBase", Vector3.new(0.2, 0.06, 0.32), CFrame.new(0, my + 0.03, mz), BLACK, Enum.Material.Metal)
		for _, x in { -0.12, 0.12 } do
			add("OpticPost", Vector3.new(0.04, 0.26, 0.3), CFrame.new(x, my + 0.18, mz), DARK, Enum.Material.Metal)
		end
		add("OpticTop", Vector3.new(0.28, 0.04, 0.3), CFrame.new(0, my + 0.32, mz), DARK, Enum.Material.Metal)
		local glass = add("OpticGlass", Vector3.new(0.2, 0.22, 0.02), CFrame.new(0, my + 0.18, mz - 0.1), GLASS, Enum.Material.Glass)
		glass.Transparency = 0.7
		add("RedDot", Vector3.new(0.018, 0.018, 0.01), CFrame.new(0, my + 0.18, mz - 0.11), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
		sightY = my + 0.18
	elseif optic == "Holo" then
		add("OpticBase", Vector3.new(0.26, 0.06, 0.46), CFrame.new(0, my + 0.03, mz), BLACK, Enum.Material.Metal)
		add("HoloBody", Vector3.new(0.3, 0.1, 0.46), CFrame.new(0, my + 0.1, mz), DARK, Enum.Material.Metal)
		for _, x in { -0.15, 0.15 } do
			add("HoloPost", Vector3.new(0.04, 0.24, 0.4), CFrame.new(x, my + 0.26, mz - 0.03), DARK, Enum.Material.Metal)
		end
		add("HoloTop", Vector3.new(0.34, 0.05, 0.42), CFrame.new(0, my + 0.4, mz - 0.03), DARK, Enum.Material.Metal)
		local glass = add("OpticGlass", Vector3.new(0.26, 0.22, 0.02), CFrame.new(0, my + 0.26, mz - 0.18), GLASS, Enum.Material.Glass)
		glass.Transparency = 0.7
		local c = Color3.fromRGB(255, 60, 50)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			add("Reticle", Vector3.new(0.014, 0.014, 0.01), CFrame.new(math.cos(a) * 0.05, my + 0.26 + math.sin(a) * 0.05, mz - 0.19), c, Enum.Material.Neon)
		end
		add("Reticle", Vector3.new(0.012, 0.012, 0.01), CFrame.new(0, my + 0.26, mz - 0.19), c, Enum.Material.Neon)
		sightY = my + 0.26
	elseif optic == "ACOG" or optic == "Sniper" then
		local sniper = optic == "Sniper"
		local len = if sniper then 1.25 else 0.72
		local r = if sniper then 0.3 else 0.27
		local h = if sniper then 0.3 else 0.24
		for _, z in { -len * 0.3, len * 0.3 } do
			add("ScopeMount", Vector3.new(0.16, h - 0.04, 0.1), CFrame.new(0, my + (h - 0.04) / 2, mz + z), BLACK, Enum.Material.Metal)
			add("ScopeRing", Vector3.new(0.1, r + 0.06, r + 0.06), CFrame.new(0, my + h, mz + z) * axisZ(), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		add("ScopeTube", Vector3.new(len, r, r), CFrame.new(0, my + h, mz) * axisZ(), BLACK, Enum.Material.Metal, Enum.PartType.Cylinder)
		add("ScopeBellFront", Vector3.new(if sniper then 0.3 else 0.12, r + 0.12, r + 0.12), CFrame.new(0, my + h, mz - len / 2) * axisZ(), BLACK, Enum.Material.Metal, Enum.PartType.Cylinder)
		add("ScopeBellRear", Vector3.new(0.16, r + 0.06, r + 0.06), CFrame.new(0, my + h, mz + len / 2) * axisZ(), BLACK, Enum.Material.Metal, Enum.PartType.Cylinder)
		local lens = add("Lens", Vector3.new(0.02, r + 0.08, r + 0.08), CFrame.new(0, my + h, mz - len / 2 - (if sniper then 0.16 else 0.07)) * axisZ(),
			Color3.fromRGB(120, 170, 255), Enum.Material.Glass, Enum.PartType.Cylinder)
		lens.Transparency = 0.35
		if sniper then
			add("TurretTop", Vector3.new(0.14, 0.14, 0.14), CFrame.new(0, my + h + 0.2, mz) * CFrame.Angles(0, 0, math.rad(90)), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
			add("TurretSide", Vector3.new(0.14, 0.14, 0.14), CFrame.new(0.2, my + h, mz), DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
		else
			add("AcogFin", Vector3.new(0.04, 0.08, 0.3), CFrame.new(0, my + h + 0.17, mz), Color3.fromRGB(255, 60, 40), Enum.Material.Neon)
		end
		sightY = my + h
	end

	-- Laser ---------------------------------------------------------------------------------------------
	local laserPart: BasePart? = nil
	if att.Laser and att.Laser ~= "None" then
		local color = if att.Laser == "Green" then Color3.fromRGB(60, 255, 90) else Color3.fromRGB(255, 40, 40)
		add("LaserBox", Vector3.new(0.16, 0.16, 0.42), laserAt, DARK, Enum.Material.Metal)
		add("LaserLens", Vector3.new(0.08, 0.08, 0.03), laserAt * CFrame.new(0, 0, -0.22), color, Enum.Material.Neon)
		add("LaserSwitch", Vector3.new(0.04, 0.05, 0.08), laserAt * CFrame.new(0, 0.09, 0.1), color, Enum.Material.Neon)
		laserPart = marker("LaserEmitter", laserAt * CFrame.new(0, 0, -0.25))
		laserPart:SetAttribute("Color", color)
	end

	return {
		root = root,
		muzzle = muzzle,
		laser = laserPart,
		sight = CFrame.new(0, sightY, ironSight.Z),
		grip = grip,
		foregrip = foregrip,
		spin = spin,
		parts = parts,
	}
end

-- "Optic=RedDot;Laser=Red;Muzzle=None" <-> table
function WeaponModel.decode(s: string?): Attachments
	local out = { Optic = "Iron", Laser = "None", Muzzle = "None" }
	for k, v in string.gmatch(s or "", "(%w+)=(%w+)") do
		(out :: any)[k] = v
	end
	return out
end

function WeaponModel.encode(a: Attachments): string
	return `Optic={a.Optic};Laser={a.Laser};Muzzle={a.Muzzle}`
end

return WeaponModel
