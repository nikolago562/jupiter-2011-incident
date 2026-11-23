--!strict
-- Semi-horror mood: light 2011 camcorder overlay, color grade, alarm pulse, power-outage dark, static when a Keis is close.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local C, F = Theme.Colors, Theme.Fonts
local make, text = Theme.make, Theme.text

local player = Players.LocalPlayer
local rng = Random.new()

-- Color grade ---------------------------------------------------------------------------------------
local cc = make("ColorCorrectionEffect", { Saturation = -0.25, Contrast = 0.18, TintColor = Color3.fromRGB(236, 246, 240), Parent = Lighting })
make("BlurEffect", { Size = 1.2, Parent = Lighting }) -- slightly soft, like a security camera
make("BloomEffect", { Intensity = 0.9, Threshold = 0.9, Size = 28, Parent = Lighting })
make("SunRaysEffect", { Intensity = 0.03, Spread = 0.6, Parent = Lighting })

local gui = make("ScreenGui", { Name = "Atmosphere", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1,
	Parent = player:WaitForChild("PlayerGui") })

-- vignette
for _, rot in { 0, 90 } do
	make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui }, {
		make("UIGradient", { Rotation = rot, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.18, 1),
			NumberSequenceKeypoint.new(0.82, 1), NumberSequenceKeypoint.new(1, 0.35) }) }),
	})
end
-- red alarm edge
local alarmEdge = {}
for _, rot in { 0, 90 } do
	local f = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Danger, BorderSizePixel = 0, BackgroundTransparency = 1, Parent = gui }, {
		make("UIGradient", { Rotation = rot, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.12, 1),
			NumberSequenceKeypoint.new(0.88, 1), NumberSequenceKeypoint.new(1, 0.2) }) }),
	})
	table.insert(alarmEdge, f)
end

-- faint scanlines
local scan = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
for i = 0, 89 do
	make("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, i / 90), BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.92, Parent = scan })
end

-- security camera overlay (like the footage): timestamp + camera of the room you're in
local stamp = text({ Font = Enum.Font.Code, TextSize = 22, TextColor3 = Color3.fromRGB(235, 235, 230), TextStrokeTransparency = 0.6,
	Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(400, 24), Parent = gui })
local camId = text({ Font = Enum.Font.Code, TextSize = 22, TextColor3 = Color3.fromRGB(235, 235, 230), TextStrokeTransparency = 0.6,
	Position = UDim2.fromOffset(16, 34), Size = UDim2.fromOffset(400, 24), Text = "CAM 01 (BRIDGE)", Parent = gui })
local rec = text({ Font = Enum.Font.Code, TextSize = 22, TextColor3 = Color3.fromRGB(235, 235, 230), TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 10), Size = UDim2.fromOffset(200, 24), RichText = true,
	Text = 'REC <font color="#F0463C">●</font>', Parent = gui })

-- which room is the local player in? (rooms carry Center/Size/Cam attributes)
local currentCam = "CAM 01 (BRIDGE)"
task.spawn(function()
	while true do
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local ship = workspace:FindFirstChild("Ship")
		if ReplicatedStorage:GetAttribute("Stage") == "Moon" then
			currentCam = "CAM EXT-1 (IO SURFACE)"
		elseif hrp and ship then
			for _, room in ship:GetChildren() do
				local center = room:GetAttribute("Center") :: Vector3?
				local size = room:GetAttribute("Size") :: Vector2?
				if center and size and math.abs(hrp.Position.X - center.X) <= size.X / 2 and math.abs(hrp.Position.Z - center.Z) <= size.Y / 2 then
					currentCam = (room:GetAttribute("Cam") :: string?) or currentCam
					break
				end
			end
		end
		task.wait(0.3)
	end
end)

-- static specks (only near Keis)
local specks = {}
for _ = 1, 70 do
	table.insert(specks, make("Frame", { BorderSizePixel = 0, Visible = false, Parent = gui }))
end

-- Sounds ---------------------------------------------------------------------------------------------
if Config.Sounds.Music ~= "" then
	local music = make("Sound", { SoundId = Config.Sounds.Music, Looped = true, Volume = 0.25, Parent = SoundService })
	music:Play()
end
local alarmSound: Sound? = nil
if Config.Sounds.Alarm ~= "" then
	alarmSound = make("Sound", { SoundId = Config.Sounds.Alarm, Looped = true, Volume = 0, Parent = SoundService })
	do
		local target = alarmSound :: Sound
		target:Play()
	end
end

-- Per frame --------------------------------------------------------------------------------------------
local start = os.clock()
local BASE = 23 * 3600 + 47 * 60 + 12 -- 23:47:12 (from the videos' timestamp)
local danger = 0

local function nearestKeis(): number
	local folder = workspace:FindFirstChild("Keis")
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not folder or not hrp then
		return math.huge
	end
	local best = math.huge
	for _, m in folder:GetChildren() do
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			best = math.min(best, (root.Position - hrp.Position).Magnitude)
		end
	end
	return best
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local secs = (BASE + math.floor(now - start)) % 86400
	stamp.Text = string.format("07/14/2011 %02d:%02d:%02d", secs // 3600, (secs // 60) % 60, secs % 60)
	rec.Visible = (now % 1.2) < 0.8

	local powerOut = ReplicatedStorage:GetAttribute("PowerOut") == true
	local alarm = ReplicatedStorage:GetAttribute("Alarm") == true

	-- static ramps up as a Keis closes in (light, this is semi-horror)
	local target = 0.12 + math.clamp(1 - (nearestKeis() - 6) / 30, 0, 1) * 0.5 -- constant light grain + more near a Keis
	danger += (target - danger) * math.min(dt * 5, 1)
	local count = math.floor(#specks * danger)
	for i, s in specks do
		if i <= count then
			s.Visible = true
			s.Size = UDim2.fromOffset(rng:NextInteger(3, 30), rng:NextInteger(1, 2))
			s.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
			local g = rng:NextNumber(0.7, 1)
			s.BackgroundColor3 = Color3.new(g, g, g)
			s.BackgroundTransparency = rng:NextNumber(0.3, 0.7)
		else
			s.Visible = false
		end
	end
	camId.Text = if danger > 0.4 and rng:NextNumber() < 0.03 then "CAM ?? (KEIS KEIS KEIS)" else currentCam

	-- grading
	local pulse = if alarm then (math.sin(now * 4) + 1) / 2 else 0
	for _, f in alarmEdge do
		f.BackgroundTransparency = 1 - pulse * 0.35
	end
	if alarmSound then
		alarmSound.Volume = if alarm then 0.15 else 0
	end
	cc.Brightness = if powerOut then -0.12 else 0
	cc.Saturation = if powerOut then -0.6 else -0.25 - danger * 0.3
	cc.TintColor = if powerOut then Color3.fromRGB(200, 215, 255) else Color3.fromRGB(236, 246 - math.floor(danger * 60), 240 - math.floor(danger * 80))
end)
