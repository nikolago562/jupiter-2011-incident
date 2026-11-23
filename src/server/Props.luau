--!strict
-- Detailed set pieces. Right now: the Armory bench where players upgrade weapons and change attachments.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponModel = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponModel"))

local Props = {}

local DARK = Color3.fromRGB(52, 55, 62)
local STEEL = Color3.fromRGB(120, 124, 130)
local ORANGE = Color3.fromRGB(255, 138, 61)
local HAZARD = Color3.fromRGB(230, 180, 30)

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function displayWeapon(parent: Instance, weaponId: string, att: any, cf: CFrame)
	local holder = Instance.new("Model")
	holder.Name = "Display" .. weaponId
	holder.Parent = parent
	local built = WeaponModel.build(weaponId, att, holder, "Root")
	built.root.Anchored = true
	built.root.Transparency = 0
	built.root.CFrame = cf
	if built.spin then
		built.spin.Parent = nil -- displays don't spin
	end
end

-- cf: floor point at the front-center of the bench; the bench faces -Z (players stand at -Z)
function Props.armoryBench(parent: Instance, cf: CFrame): ProximityPrompt
	local m = Instance.new("Model")
	m.Name = "ArmoryBench"
	m.Parent = parent
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	-- floor marking
	for i = 0, 9 do
		part(m, Vector3.new(1, 0.05, 0.4), at(-4.5 + i, 0.03, -2.3) * CFrame.Angles(0, math.rad(45), 0), if i % 2 == 0 then HAZARD else Color3.fromRGB(20, 20, 20))
	end
	-- table
	local top = part(m, Vector3.new(9, 0.4, 3.4), at(0, 3.4, 0), DARK, Enum.Material.DiamondPlate, nil, true)
	top.Name = "BenchTop"
	part(m, Vector3.new(9.05, 0.12, 0.12), at(0, 3.55, -1.72), ORANGE, Enum.Material.Neon)
	for _, x in { -4.2, 4.2 } do
		for _, z in { -1.4, 1.4 } do
			part(m, Vector3.new(0.4, 3.2, 0.4), at(x, 1.6, z), STEEL, Enum.Material.Metal, nil, true)
		end
	end
	part(m, Vector3.new(8.6, 0.2, 3), at(0, 1, 0), STEEL, Enum.Material.Metal)
	-- stuff on the shelf
	part(m, Vector3.new(1.6, 0.9, 1.2), at(-2.8, 1.55, 0.2), Color3.fromRGB(88, 94, 60), Enum.Material.Metal)
	part(m, Vector3.new(1.2, 0.7, 1), at(-1.2, 1.45, 0.4), Color3.fromRGB(150, 40, 35), Enum.Material.Metal)
	for i = 0, 3 do
		part(m, Vector3.new(0.35, 0.6, 0.35), at(1.2 + i * 0.45, 1.4, -0.4), Color3.fromRGB(200, 160, 70), Enum.Material.Metal, Enum.PartType.Cylinder)
	end

	-- pegboard wall with tools
	part(m, Vector3.new(9, 6.4, 0.3), at(0, 6.8, 1.75), Color3.fromRGB(70, 74, 80), Enum.Material.Metal, nil, true)
	for row = 0, 4 do
		part(m, Vector3.new(8.8, 0.08, 0.05), at(0, 4.4 + row * 1.2, 1.58), Color3.fromRGB(40, 42, 46), Enum.Material.Metal)
	end
	-- wrench
	part(m, Vector3.new(0.2, 1.6, 0.08), at(3.4, 7.6, 1.55) * CFrame.Angles(0, 0, math.rad(10)), STEEL, Enum.Material.Metal)
	part(m, Vector3.new(0.55, 0.35, 0.08), at(3.27, 8.4, 1.55), STEEL, Enum.Material.Metal)
	-- screwdrivers
	for i = 0, 2 do
		part(m, Vector3.new(0.12, 0.9, 0.12), at(2.3 + i * 0.35, 7.2, 1.55), STEEL, Enum.Material.Metal)
		part(m, Vector3.new(0.2, 0.45, 0.2), at(2.3 + i * 0.35, 7.8, 1.55), if i == 1 then ORANGE else Color3.fromRGB(40, 90, 180))
	end
	-- spare scopes on a shelf
	part(m, Vector3.new(2.4, 0.12, 0.6), at(-3, 5.4, 1.35), STEEL, Enum.Material.Metal)
	for i = 0, 1 do
		part(m, Vector3.new(0.9, 0.3, 0.3), at(-3.6 + i * 1.1, 5.65, 1.35) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(20, 20, 22), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	-- a spare rifle hanging on the wall + one lying on the table
	displayWeapon(m, "Blaster", { Optic = "ACOG", Laser = "Red", Muzzle = "Compensator" }, at(-0.6, 8.3, 1.4) * CFrame.Angles(0, math.rad(90), 0))
	displayWeapon(m, "Blaster", { Optic = "RedDot", Laser = "None", Muzzle = "None" }, at(0.4, 4.0, -0.2) * CFrame.Angles(0, math.rad(80), math.rad(90)))
	-- vise
	part(m, Vector3.new(0.8, 0.6, 0.8), at(3.7, 3.9, -0.9), Color3.fromRGB(40, 90, 160), Enum.Material.Metal)
	part(m, Vector3.new(0.9, 0.3, 0.2), at(3.7, 4.3, -1.25), STEEL, Enum.Material.Metal)

	-- monitor
	part(m, Vector3.new(0.3, 1, 0.3), at(-3, 4.1, 0.7), DARK, Enum.Material.Metal)
	local screen = part(m, Vector3.new(2.6, 1.6, 0.15), at(-3, 5, 0.65) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(10, 14, 18))
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(260, 160)
	sg.LightInfluence = 0
	sg.Brightness = 1.6
	sg.Parent = screen
	for i, line in { "ARMORY // WEAPON SYSTEMS", "OPTICS ....... READY", "LASER MODULES  READY", "BARREL KITS .. READY", "> PRESS E TO MODIFY" } do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(10, 6 + (i - 1) * 30)
		l.Size = UDim2.new(1, -20, 0, 26)
		l.Font = Enum.Font.Code
		l.TextSize = 17
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = if i == 5 then ORANGE else Color3.fromRGB(110, 255, 160)
		l.Text = line
		l.Parent = sg
	end

	-- desk lamp shining on the table
	part(m, Vector3.new(0.5, 0.15, 0.5), at(2.2, 3.68, 0.9), DARK, Enum.Material.Metal)
	part(m, Vector3.new(0.12, 1.8, 0.12), at(2.2, 4.5, 0.9) * CFrame.Angles(math.rad(-20), 0, 0), DARK, Enum.Material.Metal)
	local lampHead = part(m, Vector3.new(0.7, 0.35, 0.5), at(2.2, 5.35, 0.45) * CFrame.Angles(math.rad(-50), 0, 0), Color3.fromRGB(255, 236, 200), Enum.Material.Neon)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Range = 10
	spot.Angle = 80
	spot.Brightness = 2
	spot.Shadows = true
	spot.Color = Color3.fromRGB(255, 236, 200)
	spot.Parent = lampHead

	-- sign
	local sign = part(m, Vector3.new(5, 1.2, 0.1), at(0, 10.4, 1.55), Color3.new(0, 0, 0))
	sign.Transparency = 1
	local sg2 = Instance.new("SurfaceGui")
	sg2.Face = Enum.NormalId.Front
	sg2.CanvasSize = Vector2.new(500, 120)
	sg2.LightInfluence = 0
	sg2.Brightness = 2
	sg2.Parent = sign
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = ORANGE
	t.Text = "ARMORY"
	t.Parent = sg2
	local signLight = Instance.new("PointLight")
	signLight.Color = ORANGE
	signLight.Range = 10
	signLight.Brightness = 1
	signLight.Parent = sign

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Armory"
	prompt.ObjectText = "WEAPON BENCH"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = top
	return prompt
end

return Props
