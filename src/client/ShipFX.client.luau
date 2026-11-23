--!strict
-- Local ship effects: sliding doors (with sound), console flicker, fans, LEDs, gauges, background ambience.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local TweenService = game:GetService("TweenService")

local OPEN_RANGE = 12
local TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Door = { leaves: { BasePart }, center: Vector3, open: boolean }
local doors: { [string]: Door } = {}

local function addLeaf(p: Instance)
	if not p:IsA("BasePart") then
		return
	end
	local center = p:GetAttribute("DoorCenter") :: Vector3?
	if not center then
		return
	end
	local key = string.format("%.1f|%.1f|%.1f", center.X, center.Y, center.Z)
	local d = doors[key]
	if not d then
		d = { leaves = {}, center = center, open = false }
		doors[key] = d
	end
	table.insert(d.leaves, p)
end
for _, p in CollectionService:GetTagged("DoorLeaf") do
	addLeaf(p)
end
CollectionService:GetInstanceAddedSignal("DoorLeaf"):Connect(addLeaf)

local function positions(): { Vector3 }
	local list = {}
	for _, pl in Players:GetPlayers() do
		local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			table.insert(list, hrp.Position)
		end
	end
	local keis = workspace:FindFirstChild("Keis")
	if keis then
		for _, m in keis:GetChildren() do
			local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				table.insert(list, root.Position)
			end
		end
	end
	return list
end

task.spawn(function()
	while true do
		local pos = positions()
		for _, d in doors do
			local near = false
			for _, p in pos do
				if (p - d.center).Magnitude < OPEN_RANGE then
					near = true
					break
				end
			end
			if near ~= d.open then
				d.open = near
				if Config.Sounds.Door ~= "" and d.leaves[1] and d.leaves[1].Parent then
					local snd = Instance.new("Sound")
					snd.SoundId = Config.Sounds.Door
					snd.Volume = 0.5
					snd.RollOffMaxDistance = 40
					snd.Parent = d.leaves[1]
					snd:Play()
					snd.Ended:Connect(function()
						snd:Destroy()
					end)
				end
				for _, leaf in d.leaves do
					if leaf.Parent then
						local closed = leaf:GetAttribute("ClosedCF") :: CFrame
						local offset = leaf:GetAttribute("OpenOffset") :: Vector3
						TweenService:Create(leaf, TWEEN, { CFrame = if near then closed + offset else closed }):Play()
					end
				end
			end
		end
		task.wait(0.1)
	end
end)

-- console screens: occasional flicker
task.spawn(function()
	while true do
		local screens = CollectionService:GetTagged("ConsoleScreen")
		if #screens > 0 then
			local s = screens[math.random(1, #screens)]
			local gui = s:FindFirstChildOfClass("SurfaceGui")
			if gui then
				gui.Enabled = false
				task.wait(0.06)
				gui.Enabled = true
			end
		end
		task.wait(math.random() * 0.8 + 0.2)
	end
end)

-- spinning wall fans, blinking LEDs, twitching gauge needles ---------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for _, fan in CollectionService:GetTagged("Fan") do
		if fan:IsA("Model") and fan.PrimaryPart then
			fan:PivotTo(fan:GetPivot() * CFrame.Angles(dt * 8, 0, 0))
		end
	end
	for _, led in CollectionService:GetTagged("BlinkLED") do
		if led:IsA("BasePart") then
			local rate = (led:GetAttribute("BlinkRate") :: number?) or 1
			led.Transparency = if (now * rate) % 1 < 0.5 then 0 else 0.85
		end
	end
end)
task.spawn(function()
	while true do
		for _, face in CollectionService:GetTagged("Gauge") do
			local needle = face:FindFirstChild("Needle", true) :: Frame?
			if needle then
				needle.Rotation = math.clamp(needle.Rotation + math.random(-6, 6), -75, 75)
			end
		end
		task.wait(0.15)
	end
end)

-- constant background ambience: ship hum, or the wind on Io
local function loop(id: string, volume: number): Sound?
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	return s
end
local hum = loop(Config.Sounds.ShipHum, 0.35)
local wind = loop(Config.Sounds.IoWind, 0.45)
RunService.Heartbeat:Connect(function(dt)
	local onMoon = ReplicatedStorage:GetAttribute("Stage") == "Moon"
	local inGame = workspace.CurrentCamera.CameraType == Enum.CameraType.Custom
	if hum then
		hum.Volume += ((if inGame and not onMoon then 0.35 else 0) - hum.Volume) * math.min(dt * 2, 1)
	end
	if wind then
		wind.Volume += ((if inGame and onMoon then 0.45 else 0) - wind.Volume) * math.min(dt * 2, 1)
	end
end)
