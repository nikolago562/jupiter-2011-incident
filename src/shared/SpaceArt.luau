--!strict
-- Jupiter, its moons and the starfield, built from parts (no assets). Shared by the ship, the moon and the menu.

local SpaceArt = {}

local function deco(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
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

-- Jupiter's real band layout, from south pole (-1) to north pole (+1): {latitude, color}
local PROFILE = {
	{ -1.00, Color3.fromRGB(120, 118, 125) }, -- south polar region (blue-grey)
	{ -0.80, Color3.fromRGB(150, 140, 135) },
	{ -0.62, Color3.fromRGB(196, 170, 140) }, -- south temperate zone
	{ -0.50, Color3.fromRGB(160, 112, 80) }, -- south temperate belt
	{ -0.38, Color3.fromRGB(226, 205, 176) }, -- south tropical zone
	{ -0.25, Color3.fromRGB(168, 104, 66) }, -- south equatorial belt
	{ -0.15, Color3.fromRGB(196, 136, 92) },
	{ -0.05, Color3.fromRGB(242, 228, 205) }, -- equatorial zone
	{ 0.08, Color3.fromRGB(236, 214, 182) },
	{ 0.18, Color3.fromRGB(150, 92, 60) }, -- north equatorial belt
	{ 0.28, Color3.fromRGB(182, 120, 80) },
	{ 0.38, Color3.fromRGB(230, 210, 180) }, -- north tropical zone
	{ 0.48, Color3.fromRGB(170, 126, 92) }, -- north temperate belt
	{ 0.60, Color3.fromRGB(205, 184, 156) },
	{ 0.78, Color3.fromRGB(150, 140, 136) },
	{ 1.00, Color3.fromRGB(118, 116, 124) }, -- north polar region
}

local function bandColor(lat: number): Color3
	for i = 1, #PROFILE - 1 do
		local a, b = PROFILE[i], PROFILE[i + 1]
		if lat >= a[1] and lat <= b[1] then
			local t = (lat - a[1]) / (b[1] - a[1])
			t = t * t * (3 - 2 * t) -- smooth edges between bands
			return a[2]:Lerp(b[2], t)
		end
	end
	return PROFILE[#PROFILE][2]
end

-- Builds Jupiter facing `viewer`. sunSide = 1 lights the right side (from the viewer), -1 the left.
function SpaceArt.jupiter(parent: Instance, center: Vector3, R: number, viewer: Vector3, sunSide: number?): Model
	local model = Instance.new("Model")
	model.Name = "Jupiter"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	local rng = Random.new(2011)

	-- 1) banded body: thin discs stacked pole to pole, colors follow the real band profile + turbulence
	local slices = 110
	local t = 2 * R / slices
	for i = 0, slices - 1 do
		local y = -R + (i + 0.5) * t
		local r = math.sqrt(math.max(R * R - y * y, 1))
		local lat = y / R
		local color = bandColor(lat + rng:NextNumber(-0.012, 0.012))
		local shade = rng:NextNumber(0.94, 1.05)
		color = Color3.new(math.clamp(color.R * shade, 0, 1), math.clamp(color.G * shade, 0, 1), math.clamp(color.B * shade, 0, 1))
		deco(model, Vector3.new(t + 0.3, 2 * r, 2 * r), CFrame.new(center + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end

	-- surface helpers on the visible hemisphere
	local toViewer = viewer - center
	local flat = Vector3.new(toViewer.X, 0, toViewer.Z).Unit
	local right = flat:Cross(Vector3.yAxis).Unit
	local function surfaceDir(latDeg: number, lonDeg: number): Vector3
		local lat, lon = math.rad(latDeg), math.rad(lonDeg)
		return ((flat * math.cos(lon) + right * math.sin(lon)) * math.cos(lat) + Vector3.yAxis * math.sin(lat)).Unit
	end
	local function spot(latDeg: number, lonDeg: number, radius: number, color: Color3, lift: number?)
		local dir = surfaceDir(latDeg, lonDeg)
		local pos = center + dir * (R * (1 + (lift or 0.002)))
		deco(model, Vector3.new(R * 0.008, radius * 2, radius * 2), CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0),
			color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end

	-- 2) the Great Red Spot (layered) in the south tropical zone
	spot(-22, -18, R * 0.15, Color3.fromRGB(226, 196, 160), 0.002)
	spot(-22, -18, R * 0.12, Color3.fromRGB(205, 110, 70), 0.004)
	spot(-22, -18, R * 0.085, Color3.fromRGB(180, 75, 50), 0.006)
	spot(-22, -18, R * 0.04, Color3.fromRGB(150, 60, 45), 0.008)

	-- 3) white ovals and dark festoons along the belts
	for _ = 1, 14 do
		spot(rng:NextNumber(-42, -32), rng:NextNumber(-60, 60), R * rng:NextNumber(0.02, 0.045), Color3.fromRGB(240, 232, 220))
	end
	for _ = 1, 16 do
		spot(rng:NextNumber(8, 14), rng:NextNumber(-65, 65), R * rng:NextNumber(0.012, 0.03), Color3.fromRGB(110, 70, 55))
	end
	for _ = 1, 10 do
		spot(rng:NextNumber(26, 34), rng:NextNumber(-60, 60), R * rng:NextNumber(0.015, 0.03), Color3.fromRGB(236, 222, 200))
	end

	-- 4) atmosphere haze
	for i, a in { { 1.02, 0.9 }, { 1.05, 0.95 }, { 1.1, 0.975 } } do
		local glow = deco(model, Vector3.one * R * 2 * a[1], CFrame.new(center), Color3.fromRGB(255, 196 - i * 10, 150 - i * 15),
			Enum.Material.Neon, Enum.PartType.Ball)
		glow.Transparency = a[2]
	end

	-- 5) night side: dark spheres offset sideways make a soft terminator (shadow on the side away from the sun)
	local side = -(sunSide or 1)
	for _, layer in { { 0.62, 0.55 }, { 0.78, 0.3 }, { 0.92, 0.08 } } do
		local shadow = deco(model, Vector3.one * R * 2.02, CFrame.new(center + right * side * R * layer[1] + flat * R * 0.05),
			Color3.fromRGB(4, 4, 8), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		shadow.Transparency = layer[2]
	end

	-- 6) moons: Io, Europa, Ganymede
	for _, m in {
		{ offset = -right * R * 1.7 + Vector3.new(0, R * 0.3, 0), size = R * 0.07, color = Color3.fromRGB(230, 200, 110) },
		{ offset = right * R * 1.55 - Vector3.new(0, R * 0.45, 0) - flat * R * 0.4, size = R * 0.06, color = Color3.fromRGB(225, 222, 215) },
		{ offset = -right * R * 1.2 - Vector3.new(0, R * 0.7, 0) - flat * R * 0.8, size = R * 0.09, color = Color3.fromRGB(150, 140, 130) },
	} do
		local moonPos = center + m.offset
		deco(model, Vector3.one * m.size, CFrame.new(moonPos), m.color, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		local ms = deco(model, Vector3.one * m.size * 1.01, CFrame.new(moonPos + right * side * m.size * 0.35), Color3.fromRGB(4, 4, 8),
			Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		ms.Transparency = 0.2
	end
	return model
end

-- A starfield on a sphere around `center`, skipping the patch of sky covered by Jupiter (if given).
function SpaceArt.stars(parent: Instance, center: Vector3, radius: number, count: number, seed: number?, avoidCenter: Vector3?, avoidRadius: number?): Model
	local model = Instance.new("Model")
	model.Name = "Stars"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	local rng = Random.new(seed or 7)
	local avoidDir, avoidAngle = nil, 0
	if avoidCenter and avoidRadius then
		local d = avoidCenter - center
		avoidDir = d.Unit
		avoidAngle = math.asin(math.clamp(avoidRadius / d.Magnitude, 0, 1)) + 0.06
	end
	local TINTS = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 220, 255), Color3.fromRGB(255, 240, 210), Color3.fromRGB(255, 210, 190) }
	local galacticPole = Vector3.new(0.3, 0.8, 0.5).Unit

	local function place(dir: Vector3, size: number, transparency: number)
		if avoidDir and math.acos(math.clamp(dir:Dot(avoidDir), -1, 1)) < avoidAngle then
			return
		end
		local s = deco(model, Vector3.one * size, CFrame.new(center + dir * radius), TINTS[rng:NextInteger(1, #TINTS)], Enum.Material.Neon, Enum.PartType.Ball)
		s.Transparency = transparency
	end

	for _ = 1, count do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		if dir.Magnitude > 0.05 then
			local bright = rng:NextNumber() ^ 3 -- mostly small, a few bright ones
			place(dir.Unit, radius * (0.0014 + bright * 0.004), rng:NextNumber(0, 0.35))
		end
	end
	-- the Milky Way: a dense band of faint stars around a great circle
	for _ = 1, math.floor(count * 0.7) do
		local v = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
		local inPlane = (v - galacticPole * v:Dot(galacticPole))
		if inPlane.Magnitude > 0.05 then
			local dir = (inPlane.Unit + galacticPole * rng:NextNumber(-0.12, 0.12)).Unit
			place(dir, radius * rng:NextNumber(0.0009, 0.0018), rng:NextNumber(0.35, 0.7))
		end
	end
	-- faint nebula clouds
	for _, n in { { Color3.fromRGB(120, 80, 200), 0.6 }, { Color3.fromRGB(60, 120, 220), -0.4 }, { Color3.fromRGB(200, 80, 120), 0.1 } } do
		local dir = (galacticPole:Cross(Vector3.xAxis).Unit * math.cos(n[2] * 3) + galacticPole:Cross(Vector3.zAxis).Unit * math.sin(n[2] * 3)).Unit
		if not (avoidDir and dir:Dot(avoidDir) > 0.85) then
			local cloud = deco(model, Vector3.one * math.min(radius * 0.5, 2000), CFrame.new(center + dir * radius * 1.05), n[1], Enum.Material.Neon, Enum.PartType.Ball)
			cloud.Transparency = 0.965
		end
	end
	return model
end

return SpaceArt
