--!strict
-- IO: Jupiter's volcanic moon. Built with Terrain + parts after the crew survives wave 10.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpaceArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpaceArt"))
local Props = require(script.Parent:WaitForChild("Props"))

local MoonBuilder = {}

MoonBuilder.ORIGIN = Vector3.new(0, 0, -3200)
local SIZE = 420
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
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

local function deco(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = part(parent, size, cf, color, material, shape)
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

local function emitter(parent: Instance, props: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
end

export type MoonInfo = {
	folder: Folder,
	spawn: SpawnLocation,
	reactor: BasePart,
	reactorRadius: number,
	vents: { Vector3 },
	roomCenters: { Vector3 },
	space: { Instance },
	armoryPrompt: ProximityPrompt,
}

function MoonBuilder.clear()
	local old = workspace:FindFirstChild("Io")
	if old then
		old:Destroy()
	end
	local M = MoonBuilder.ORIGIN
	workspace.Terrain:FillBlock(CFrame.new(M + Vector3.new(0, 20, 0)), Vector3.new(SIZE + 120, 200, SIZE + 120), Enum.Material.Air)
end

function MoonBuilder.build(): MoonInfo
	MoonBuilder.clear()
	local M = MoonBuilder.ORIGIN
	local T = workspace.Terrain
	local rng = Random.new(1610) -- Io was discovered in 1610

	T:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(62, 50, 40))
	T:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 108, 58))
	T:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(222, 196, 88)) -- sulfur
	T:SetMaterialColor(Enum.Material.Salt, Color3.fromRGB(238, 232, 196)) -- sulfur dioxide frost
	T:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(176, 92, 42))
	T:SetMaterialColor(Enum.Material.CrackedLava, Color3.fromRGB(70, 40, 30))

	local folder = Instance.new("Folder")
	folder.Name = "Io"
	folder.Parent = workspace

	-- base ground
	T:FillBlock(CFrame.new(M + Vector3.new(0, -12, 0)), Vector3.new(SIZE, 24, SIZE), Enum.Material.Basalt)
	-- rolling mounds
	local mats = { Enum.Material.Rock, Enum.Material.Sand, Enum.Material.Ground, Enum.Material.Basalt }
	for _ = 1, 70 do
		local r = rng:NextNumber(8, 28)
		local p = M + Vector3.new(rng:NextNumber(-190, 190), -r * rng:NextNumber(0.55, 0.85), rng:NextNumber(-190, 190))
		T:FillBall(p, r, mats[rng:NextInteger(1, #mats)])
	end
	-- sulfur / frost patches on the surface
	for _ = 1, 26 do
		local p = M + Vector3.new(rng:NextNumber(-190, 190), -0.6, rng:NextNumber(-190, 190))
		T:FillCylinder(CFrame.new(p), 2, rng:NextNumber(8, 22), if rng:NextNumber() < 0.6 then Enum.Material.Sand else Enum.Material.Salt)
	end
	-- impact craters with raised rims
	for _ = 1, 12 do
		local r = rng:NextNumber(10, 26)
		local c = M + Vector3.new(rng:NextNumber(-170, 170), 0, rng:NextNumber(-170, -40) * (if rng:NextNumber() < 0.5 then 1 else -1))
		T:FillBall(c + Vector3.new(0, r * 0.45, 0), r, Enum.Material.Air)
		for k = 1, 12 do
			local a = k / 12 * math.pi * 2
			T:FillBall(c + Vector3.new(math.cos(a) * r * 1.05, -1, math.sin(a) * r * 1.05), r * 0.3, Enum.Material.Rock)
		end
	end
	-- lava lakes
	for _ = 1, 3 do
		local c = M + Vector3.new(rng:NextNumber(-150, 150), 0, rng:NextNumber(-170, -80))
		local r = rng:NextNumber(10, 16)
		T:FillCylinder(CFrame.new(c + Vector3.new(0, 2, 0)), 8, r, Enum.Material.Air)
		T:FillCylinder(CFrame.new(c + Vector3.new(0, -2.5, 0)), 3, r, Enum.Material.CrackedLava)
		local glow = deco(folder, Vector3.new(0.2, r * 1.8, r * 1.8), CFrame.new(c + Vector3.new(0, -0.9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(255, 110, 30), Enum.Material.Neon, Enum.PartType.Cylinder)
		glow.Transparency = 0.35
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 120, 40)
		l.Range = 40
		l.Brightness = 2
		l.Parent = glow
	end
	-- the volcano (Loki-style), with a glowing crater and a smoke plume
	local V = M + Vector3.new(-120, 0, -150)
	for i = 0, 7 do
		T:FillCylinder(CFrame.new(V + Vector3.new(0, i * 6 + 3, 0)), 6, 62 - i * 7, Enum.Material.Basalt)
	end
	T:FillBall(V + Vector3.new(0, 52, 0), 12, Enum.Material.Air)
	T:FillCylinder(CFrame.new(V + Vector3.new(0, 42, 0)), 3, 9, Enum.Material.CrackedLava)
	local vent = deco(folder, Vector3.new(14, 1, 14), CFrame.new(V + Vector3.new(0, 44, 0)), Color3.fromRGB(255, 120, 30), Enum.Material.Neon)
	vent.Transparency = 0.2
	local vl = Instance.new("PointLight")
	vl.Color = Color3.fromRGB(255, 120, 40)
	vl.Range = 60
	vl.Brightness = 3
	vl.Parent = vent
	emitter(vent, { Texture = FIRE, Rate = 25, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(10, 20), SpreadAngle = Vector2.new(20, 20),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 1) }), LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 60, 20)), EmissionDirection = Enum.NormalId.Top })
	emitter(vent, { Texture = SMOKE, Rate = 10, Lifetime = NumberRange.new(8, 12), Speed = NumberRange.new(14, 22), SpreadAngle = Vector2.new(15, 15),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 40) }), RotSpeed = NumberRange.new(-20, 20),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(200, 180, 140)), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(4, 2, 0) })

	-- flat landing zone (cleared last so nothing pokes through)
	local LZ = M + Vector3.new(0, 0, 40)
	T:FillCylinder(CFrame.new(LZ + Vector3.new(0, 20, 0)), 40, 62, Enum.Material.Air)
	T:FillCylinder(CFrame.new(LZ + Vector3.new(0, -2, 0)), 4, 62, Enum.Material.Basalt)
	T:FillCylinder(CFrame.new(LZ + Vector3.new(0, -0.4, 0)), 0.8, 30, Enum.Material.Ground)

	-- boulders + sulfur crystals
	for _ = 1, 55 do
		local p = M + Vector3.new(rng:NextNumber(-195, 195), 0, rng:NextNumber(-195, 195))
		if (p - LZ).Magnitude > 70 then
			local s = rng:NextNumber(2, 8)
			part(folder, Vector3.new(s, s * rng:NextNumber(0.5, 1), s * rng:NextNumber(0.7, 1.3)),
				CFrame.new(p + Vector3.new(0, s * 0.2, 0)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), rng:NextNumber(0, 1)),
				Color3.fromRGB(rng:NextInteger(70, 110), rng:NextInteger(55, 80), rng:NextInteger(40, 55)), Enum.Material.Basalt)
		end
	end
	for _ = 1, 30 do
		local p = M + Vector3.new(rng:NextNumber(-190, 190), 0, rng:NextNumber(-190, 190))
		if (p - LZ).Magnitude > 70 then
			for k = 1, 3 do
				deco(folder, Vector3.new(0.6, rng:NextNumber(1.5, 3.5), 0.6), CFrame.new(p + Vector3.new(k * 0.6, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-25, 25))),
					Color3.fromRGB(240, 220, 90), Enum.Material.Glass)
			end
		end
	end

	-- the landed ship (USS KEPLER) --------------------------------------------------------------------
	local S = M + Vector3.new(0, 0, 82)
	local hullW = Color3.fromRGB(205, 208, 212)
	local hullD = Color3.fromRGB(70, 74, 82)
	part(folder, Vector3.new(44, 12, 22), CFrame.new(S + Vector3.new(0, 11, 0)), hullW, Enum.Material.Metal)
	part(folder, Vector3.new(44, 4, 16), CFrame.new(S + Vector3.new(0, 19, 0)), hullW, Enum.Material.Metal)
	local nose = Instance.new("WedgePart")
	nose.Anchored = true
	nose.Size = Vector3.new(22, 12, 14)
	nose.CFrame = CFrame.new(S + Vector3.new(29, 11, 0)) * CFrame.Angles(0, math.rad(-90), 0)
	nose.Color = hullW
	nose.Material = Enum.Material.Metal
	nose.Parent = folder
	deco(folder, Vector3.new(6, 2.5, 14), CFrame.new(S + Vector3.new(24, 15, 0)), Color3.fromRGB(120, 200, 255), Enum.Material.Neon).Transparency = 0.35
	for _, z in { -6, 6 } do
		local eng = part(folder, Vector3.new(10, 8, 8), CFrame.new(S + Vector3.new(-26, 11, z)) * CFrame.Angles(0, 0, 0), hullD, Enum.Material.Metal, Enum.PartType.Cylinder)
		eng.Size = Vector3.new(10, 8, 8)
		local glow = deco(folder, Vector3.new(0.5, 6.5, 6.5), CFrame.new(S + Vector3.new(-31.3, 11, z)), Color3.fromRGB(90, 200, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
		local gl = Instance.new("PointLight")
		gl.Color = Color3.fromRGB(90, 200, 255)
		gl.Range = 20
		gl.Parent = glow
	end
	for _, x in { -16, 16 } do
		for _, z in { -12, 12 } do
			part(folder, Vector3.new(1.4, 6, 1.4), CFrame.new(S + Vector3.new(x, 3, z)) * CFrame.Angles(math.rad(z > 0 and 15 or -15), 0, 0), hullD, Enum.Material.Metal)
			part(folder, Vector3.new(4, 0.6, 4), CFrame.new(S + Vector3.new(x, 0.3, z + (z > 0 and 0.8 or -0.8))), hullD, Enum.Material.Metal)
		end
	end
	-- ramp down toward the defense area
	local ramp = part(folder, Vector3.new(10, 0.8, 16), CFrame.new(S + Vector3.new(0, 2.6, -17)) * CFrame.Angles(math.rad(-18), 0, 0), hullD, Enum.Material.DiamondPlate)
	ramp.Name = "Ramp"
	deco(folder, Vector3.new(0.3, 30, 0.3), CFrame.new(S + Vector3.new(-12, 36, 4)), hullD, Enum.Material.Metal)
	local beacon = deco(folder, Vector3.new(0.8, 0.8, 0.8), CFrame.new(S + Vector3.new(-12, 51.4, 4)), Color3.fromRGB(255, 40, 30), Enum.Material.Neon, Enum.PartType.Ball)
	local bl = Instance.new("PointLight")
	bl.Color = Color3.fromRGB(255, 40, 30)
	bl.Range = 25
	bl.Parent = beacon
	-- hull lettering
	local plate = deco(folder, Vector3.new(16, 3, 0.1), CFrame.new(S + Vector3.new(-6, 13, -11.06)) * CFrame.Angles(0, math.rad(180), 0), hullW)
	plate.Transparency = 1
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.CanvasSize = Vector2.new(480, 90)
	sg.Parent = plate
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 1
	txt.Font = Enum.Font.GothamBlack
	txt.TextScaled = true
	txt.TextColor3 = Color3.fromRGB(40, 42, 48)
	txt.Text = "USS KEPLER  ·  K-2011"
	txt.Parent = sg

	-- field generator: what the Keis attack here ---------------------------------------------------------
	local G = M + Vector3.new(0, 0, 32)
	local gbase = part(folder, Vector3.new(3, 14, 14), CFrame.new(G + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), hullD, Enum.Material.Metal, Enum.PartType.Cylinder)
	gbase.Name = "GeneratorBase"
	local core = part(folder, Vector3.new(12, 6, 6), CFrame.new(G + Vector3.new(0, 9, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(90, 220, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	core.Name = "ReactorCore"
	local cl = Instance.new("PointLight")
	cl.Color = core.Color
	cl.Range = 45
	cl.Brightness = 3
	cl.Shadows = true
	cl.Parent = core
	for k, y in { 5, 9, 13 } do
		local ring = deco(folder, Vector3.new(0.8, 10 + k, 10 + k), CFrame.new(G + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)), hullW, Enum.Material.Metal, Enum.PartType.Cylinder)
		ring.Name = "ReactorRing"
	end
	part(folder, Vector3.new(1, 10, 10), CFrame.new(G + Vector3.new(0, 15.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), hullD, Enum.Material.Metal, Enum.PartType.Cylinder)

	-- floodlights around the defense area
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local p = G + Vector3.new(math.cos(a) * 34, 0, math.sin(a) * 34)
		part(folder, Vector3.new(0.8, 10, 0.8), CFrame.new(p + Vector3.new(0, 5, 0)), hullD, Enum.Material.Metal)
		local head = deco(folder, Vector3.new(2, 1.2, 1.2), CFrame.lookAt(p + Vector3.new(0, 10.5, 0), p + Vector3.new(math.cos(a) * 30, 0, math.sin(a) * 30)),
			Color3.fromRGB(255, 245, 220), Enum.Material.Neon)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Range = 60
		spot.Angle = 70
		spot.Brightness = 2.5
		spot.Shadows = true
		spot.Color = Color3.fromRGB(255, 240, 215)
		spot.Parent = head
	end

	-- armory bench next to the ramp
	local armoryPrompt = Props.armoryBench(folder, CFrame.new(S + Vector3.new(16, 0, -24)))

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = false
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 0.4, 8)
	spawn.CFrame = CFrame.new(S + Vector3.new(0, 0.2, -30))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = folder

	-- glowing fissures: where the Keis crawl out
	local vents = {}
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local d = rng:NextNumber(130, 175)
		local p = G + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		T:FillBlock(CFrame.new(p + Vector3.new(0, 1, 0)) * CFrame.Angles(0, a, 0), Vector3.new(4, 6, 14), Enum.Material.Air)
		local crack = deco(folder, Vector3.new(2, 0.3, 12), CFrame.new(p + Vector3.new(0, -1.8, 0)) * CFrame.Angles(0, a, 0), Color3.fromRGB(255, 50, 30), Enum.Material.Neon)
		emitter(crack, { Texture = SMOKE, Rate = 3, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(2, 4),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(Color3.fromRGB(255, 140, 100)), EmissionDirection = Enum.NormalId.Top })
		local cl2 = Instance.new("PointLight")
		cl2.Color = Color3.fromRGB(255, 60, 30)
		cl2.Range = 18
		cl2.Brightness = 1.5
		cl2.Parent = crack
		table.insert(vents, p + Vector3.new(0, 6, 0))
	end

	local roomCenters = {}
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		table.insert(roomCenters, G + Vector3.new(math.cos(a) * 60, 3, math.sin(a) * 60))
	end

	-- keep everyone inside the map
	for _, w in { { Vector3.new(SIZE, 300, 2), Vector3.new(0, 150, SIZE / 2) }, { Vector3.new(SIZE, 300, 2), Vector3.new(0, 150, -SIZE / 2) },
		{ Vector3.new(2, 300, SIZE), Vector3.new(SIZE / 2, 150, 0) }, { Vector3.new(2, 300, SIZE), Vector3.new(-SIZE / 2, 150, 0) } } do
		local wall = part(folder, w[1], CFrame.new(M + w[2]), Color3.new(0, 0, 0))
		wall.Transparency = 1
		wall.CanQuery = false
	end

	-- sky: Jupiter hangs huge over the horizon
	local jc, jr = M + Vector3.new(420, 520, -1050), 620
	local space = {
		SpaceArt.jupiter(folder, jc, jr, M, 1),
		SpaceArt.stars(folder, M, 1700, 450, 9, jc, jr * 2.1),
	}

	return {
		folder = folder,
		spawn = spawn,
		reactor = core,
		reactorRadius = 8,
		vents = vents,
		roomCenters = roomCenters,
		space = space,
		armoryPrompt = armoryPrompt,
	}
end

return MoonBuilder
