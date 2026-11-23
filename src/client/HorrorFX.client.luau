--!strict
-- Client: found-footage "2011 camcorder" filter, HUD, distorted audio logs, Keis static and jumpscares.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local rng = Random.new()

-- Post-processing (local only) -------------------------------------------
local cc = Instance.new("ColorCorrectionEffect")
cc.Saturation = -0.55
cc.Contrast = 0.25
cc.TintColor = Color3.fromRGB(255, 228, 195)
cc.Parent = Lighting
local blur = Instance.new("BlurEffect")
blur.Size = 1.5
blur.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.8
bloom.Threshold = 0.85
bloom.Size = 30
bloom.Parent = Lighting

-- GUI --------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "Jupiter2011"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Code
	l.TextColor3 = Color3.fromRGB(235, 235, 235)
	l.TextStrokeTransparency = 0.4
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = gui
	return l
end

-- vignette (two linear gradients)
for _, rotation in { 0, 90 } do
	local v = Instance.new("Frame")
	v.Size = UDim2.fromScale(1, 1)
	v.BackgroundColor3 = Color3.new(0, 0, 0)
	v.BorderSizePixel = 0
	v.ZIndex = 1
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.22, 1),
		NumberSequenceKeypoint.new(0.78, 1),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	g.Parent = v
	v.Parent = gui
end

-- scanlines
local scan = Instance.new("Frame")
scan.Size = UDim2.fromScale(1, 1)
scan.BackgroundTransparency = 1
scan.ZIndex = 2
scan.Parent = gui
local LINES = 110
for i = 0, LINES - 1 do
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.BackgroundColor3 = Color3.new(0, 0, 0)
	line.BackgroundTransparency = 0.82
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.fromScale(0, i / LINES)
	line.ZIndex = 2
	line.Parent = scan
end
-- rolling VHS band
local band = Instance.new("Frame")
band.BorderSizePixel = 0
band.BackgroundColor3 = Color3.new(1, 1, 1)
band.BackgroundTransparency = 0.93
band.Size = UDim2.new(1, 0, 0.06, 0)
band.ZIndex = 2
band.Parent = gui

-- static noise
local noise = Instance.new("Frame")
noise.Size = UDim2.fromScale(1, 1)
noise.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
noise.BackgroundTransparency = 1
noise.BorderSizePixel = 0
noise.ZIndex = 3
noise.Parent = gui
local specks = {}
for _ = 1, 160 do
	local s = Instance.new("Frame")
	s.BorderSizePixel = 0
	s.ZIndex = 3
	s.Visible = false
	s.Parent = gui
	table.insert(specks, s)
end

-- camcorder overlay
local rec = label({ Text = "● REC", TextColor3 = Color3.fromRGB(255, 50, 50), Font = Enum.Font.Code,
	TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 28, 0, 22), Size = UDim2.fromOffset(200, 30), ZIndex = 5 })
local stamp = label({ Text = "", Font = Enum.Font.Arcade, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 22), Size = UDim2.fromOffset(420, 30), ZIndex = 5 })
local camLabel = label({ Text = "JUPITER ORBITAL STATION // CAM 03", Font = Enum.Font.Arcade, TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 28, 0, 52), Size = UDim2.fromOffset(500, 24), ZIndex = 5 })
local battery = label({ Text = "▮▮▮▯", Font = Enum.Font.Code, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -22), Size = UDim2.fromOffset(200, 24), ZIndex = 5 })

-- status, notifications, subtitles
local status = label({ Text = "", TextSize = 22, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.new(0.8, 0, 0, 30), ZIndex = 6 })
local notify = label({ Text = "", TextSize = 24, Font = Enum.Font.Arcade, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(0.9, 0, 0, 40), TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 6, TextWrapped = true })
local subSpeaker = label({ Text = "", TextSize = 18, TextColor3 = Color3.fromRGB(255, 200, 80), AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -175), Size = UDim2.new(0.8, 0, 0, 22), ZIndex = 6 })
local subText = label({ Text = "", TextSize = 22, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -125),
	Size = UDim2.new(0.8, 0, 0, 50), TextWrapped = true, ZIndex = 6 })

-- jumpscare
local scare = Instance.new("Frame")
scare.Size = UDim2.fromScale(1, 1)
scare.BackgroundColor3 = Color3.new(0, 0, 0)
scare.BorderSizePixel = 0
scare.Visible = false
scare.ZIndex = 20
scare.Parent = gui
local scareText = Instance.new("TextLabel")
scareText.BackgroundTransparency = 1
scareText.AnchorPoint = Vector2.new(0.5, 0.5)
scareText.Position = UDim2.fromScale(0.5, 0.5)
scareText.Size = UDim2.fromScale(1.1, 0.5)
scareText.Font = Enum.Font.Arcade
scareText.TextScaled = true
scareText.TextColor3 = Color3.fromRGB(255, 0, 0)
scareText.Text = "KEIS KEIS KEIS"
scareText.ZIndex = 21
scareText.Parent = scare

-- Sounds -----------------------------------------------------------------
local function makeSound(id: string, looped: boolean, volume: number): Sound?
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Looped = looped
	s.Volume = volume
	s.Parent = SoundService
	return s
end
local ambience = makeSound(Config.Sounds.Ambience, true, 0.4)
if ambience then
	ambience:Play()
end
local staticSound = makeSound(Config.Sounds.Static, true, 0)
if staticSound then
	staticSound:Play()
end
local scareSound = makeSound(Config.Sounds.Jumpscare, false, 2)

-- the meme filter: slowed, crunchy, echoing
local function applyLogFilter(sound: Sound)
	local f = Config.LogFilter
	local pitch = Instance.new("PitchShiftSoundEffect")
	pitch.Octave = f.Pitch
	pitch.Parent = sound
	local dist = Instance.new("DistortionSoundEffect")
	dist.Level = f.Distortion
	dist.Parent = sound
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = -12
	eq.MidGain = 4
	eq.HighGain = -6
	eq.Parent = sound
	local reverb = Instance.new("ReverbSoundEffect")
	reverb.DecayTime = f.ReverbDecay
	reverb.WetLevel = -2
	reverb.Parent = sound
end

-- Notifications ------------------------------------------------------------
local COLORS = {
	red = Color3.fromRGB(255, 70, 70),
	green = Color3.fromRGB(90, 255, 140),
	yellow = Color3.fromRGB(255, 210, 90),
	white = Color3.fromRGB(240, 240, 240),
}
local notifyToken = 0
Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(text: string, color: string?)
	notifyToken += 1
	local token = notifyToken
	notify.Text = text
	notify.TextColor3 = COLORS[color or "white"] or COLORS.white
	notify.TextTransparency = 0
	notify.TextStrokeTransparency = 0.4
	task.delay(3.5, function()
		if token == notifyToken then
			TweenService:Create(notify, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)

-- Audio logs -----------------------------------------------------------------
local GLITCH = { "#", "%", "&", "@", "?", "▓", "░" }
local logToken = 0
local currentLog: Sound? = nil
Remotes:WaitForChild("PlayLog").OnClientEvent:Connect(function(index: number)
	local log = Config.AudioLogs[index]
	if not log then
		return
	end
	logToken += 1
	local token = logToken
	if currentLog then
		currentLog:Destroy()
		currentLog = nil
	end
	local sound = makeSound(log.soundId, false, 1.5)
	if sound then
		applyLogFilter(sound)
		sound:Play()
		currentLog = sound
	end

	subSpeaker.Text = "[ " .. log.speaker .. " ]"
	-- typewriter with glitchy characters
	local full = log.text
	local perChar = math.clamp((log.duration * 0.7) / #full, 0.02, 0.08)
	for i = 1, #full do
		if token ~= logToken then
			return
		end
		local shown = string.sub(full, 1, i)
		if rng:NextNumber() < 0.25 then
			shown ..= GLITCH[rng:NextInteger(1, #GLITCH)]
		end
		subText.Text = shown
		task.wait(perChar)
	end
	subText.Text = full
	task.wait(log.duration * 0.4 + 1.5)
	if token == logToken then
		subSpeaker.Text = ""
		subText.Text = ""
	end
end)

-- Jumpscare -------------------------------------------------------------------
local scareUntil = 0
Remotes:WaitForChild("Jumpscare").OnClientEvent:Connect(function()
	scareUntil = os.clock() + 1.8
	scare.Visible = true
	if scareSound then
		scareSound:Play()
	end
	task.delay(1.8, function()
		scare.Visible = false
	end)
end)

-- Status line ---------------------------------------------------------------
local function formatTime(t: number): string
	return string.format("%d:%02d", t // 60, t % 60)
end
local function refreshStatus()
	local phase = ReplicatedStorage:GetAttribute("Phase")
	local t = ReplicatedStorage:GetAttribute("TimeLeft") or 0
	local cells = ReplicatedStorage:GetAttribute("Cells") or 0
	local req = ReplicatedStorage:GetAttribute("CellsRequired") or 0
	if phase == "Waiting" then
		status.Text = "WAITING FOR CREW..."
	elseif phase == "Intermission" then
		status.Text = `SHUTTLE DOCKING WITH JUPITER STATION IN {t}`
	elseif phase == "Round" then
		local goal = if cells >= req then "GET TO THE ESCAPE POD" else "FIND FUEL CELLS · DON'T LET THEM HEAR YOU"
		status.Text = `FUEL {cells}/{req}  ·  {formatTime(t)}  ·  {goal}`
	elseif phase == "Results" then
		status.Text = "RECORDING ENDED"
	end
end
for _, attr in { "Phase", "TimeLeft", "Cells", "CellsRequired" } do
	ReplicatedStorage:GetAttributeChangedSignal(attr):Connect(refreshStatus)
end
refreshStatus()

-- Per-frame effects ------------------------------------------------------------
local startClock = os.clock()
local BASE_SECONDS = 3 * 3600 + 12 * 60 + 44 -- 03:12:44 AM

local function nearestKeisDistance(): number
	local folder = workspace:FindFirstChild("Keis")
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not folder or not hrp then
		return math.huge
	end
	local best = math.huge
	for _, model in folder:GetChildren() do
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			best = math.min(best, (root.Position - hrp.Position).Magnitude)
		end
	end
	return best
end

local danger = 0
RunService:BindToRenderStep("Jupiter2011FX", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local now = os.clock()
	-- timestamp + REC blink
	local secs = BASE_SECONDS + math.floor(now - startClock)
	stamp.Text = string.format("JUL 14 2011  %02d:%02d:%02d AM", (secs // 3600) % 12, (secs // 60) % 60, secs % 60)
	rec.Visible = (now % 1.2) < 0.75
	band.Position = UDim2.fromScale(0, ((now * 0.12) % 1.1) - 0.06)

	-- danger level from nearest Keis
	local d = nearestKeisDistance()
	local target = math.clamp(1 - (d - 8) / 55, 0, 1)
	if now < scareUntil then
		target = 1
	end
	danger += (target - danger) * math.min(dt * 4, 1)

	-- static
	noise.BackgroundTransparency = 1 - danger * 0.25
	local visible = math.floor(#specks * danger)
	for i, s in specks do
		if i <= visible then
			s.Visible = true
			local w = rng:NextInteger(2, 40)
			s.Size = UDim2.fromOffset(w, rng:NextInteger(1, 3))
			s.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
			local g = rng:NextNumber(0.6, 1)
			s.BackgroundColor3 = Color3.new(g, g, g)
			s.BackgroundTransparency = rng:NextNumber(0.1, 0.6)
		else
			s.Visible = false
		end
	end
	if staticSound then
		staticSound.Volume = danger * 1.2
	end

	-- color + blur get worse as they get closer
	cc.Saturation = -0.55 - danger * 0.4
	cc.TintColor = Color3.fromRGB(255, math.floor(228 - danger * 120), math.floor(195 - danger * 140))
	blur.Size = 1.5 + danger * 4

	-- camera shake + glitchy HUD
	if danger > 0.05 then
		local a = danger * 0.012
		camera.CFrame *= CFrame.Angles(rng:NextNumber(-a, a), rng:NextNumber(-a, a), rng:NextNumber(-a, a) * 0.5)
		stamp.Position = UDim2.new(1, -28 + rng:NextInteger(-3, 3) * danger, 0, 22)
		if rng:NextNumber() < danger * 0.05 then
			camLabel.Text = "JUPITER ORBITAL STATION // KEIS KEIS KEIS"
		else
			camLabel.Text = "JUPITER ORBITAL STATION // CAM 03"
		end
	end

	-- jumpscare shake
	if scare.Visible then
		scare.BackgroundColor3 = if rng:NextNumber() < 0.5 then Color3.new(0, 0, 0) else Color3.fromRGB(90, 0, 0)
		scareText.Position = UDim2.fromScale(0.5 + rng:NextNumber(-0.03, 0.03), 0.5 + rng:NextNumber(-0.03, 0.03))
		scareText.Rotation = rng:NextNumber(-8, 8)
	end

	battery.Text = if (now % 4) < 3.6 then "▮▮▮▯" else "▮▯▯▯"
end)
