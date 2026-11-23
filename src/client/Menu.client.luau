--!strict
-- Start menu: a live 3D scene (Keis standing on rock, Jupiter behind them), title, PLAY.
-- Also plays full-screen transitions (e.g. the landing on Io).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local KeisModel = require(Shared:WaitForChild("KeisModel"))
local SpaceArt = require(Shared:WaitForChild("SpaceArt"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C, F = Theme.Colors, Theme.Fonts
local make, text = Theme.make, Theme.text

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Fader (also used for in-game transitions) ---------------------------------------------------
local fadeGui = make("ScreenGui", { Name = "Fader", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100,
	Parent = player:WaitForChild("PlayerGui") })
local fader = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
	BorderSizePixel = 0, Parent = fadeGui })
local fadeText = text({ Font = F.Title, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(900, 40), TextTransparency = 1, Parent = fadeGui })

local function fadeTo(alpha: number, seconds: number)
	Theme.tween(fader, seconds, { BackgroundTransparency = 1 - alpha })
	task.wait(seconds)
end

Remotes:WaitForChild("Transition").OnClientEvent:Connect(function(msg: string, seconds: number)
	fadeTo(1, 1)
	fadeText.Text = msg
	Theme.tween(fadeText, 0.5, { TextTransparency = 0 })
	task.wait(math.max(seconds - 1.5, 0.5))
	Theme.tween(fadeText, 0.5, { TextTransparency = 1 })
	fadeTo(0, 1.2)
end)

-- The scene ---------------------------------------------------------------------------------------
local P = Vector3.new(0, 400, 7000) -- far away from the ship and Io
local scene = Instance.new("Folder")
scene.Name = "MenuScene"
scene.Parent = workspace

local function rock(size: Vector3, cf: CFrame, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Basalt
	p.Parent = scene
end

local rng = Random.new(77)
rock(Vector3.new(140, 6, 70), CFrame.new(P + Vector3.new(0, -3, 6)), Color3.fromRGB(58, 48, 40))
for _ = 1, 26 do
	local s = rng:NextNumber(3, 12)
	rock(Vector3.new(s, s * rng:NextNumber(0.4, 0.9), s * rng:NextNumber(0.7, 1.3)),
		CFrame.new(P + Vector3.new(rng:NextNumber(-60, 60), rng:NextNumber(-1, 1), rng:NextNumber(-8, 38)))
			* CFrame.Angles(rng:NextNumber(0, 0.6), rng:NextNumber(0, 6), rng:NextNumber(0, 0.6)),
		Color3.fromRGB(rng:NextInteger(60, 100), rng:NextInteger(48, 70), rng:NextInteger(36, 50)))
end
-- glowing fissure behind the Keis
local crack = Instance.new("Part")
crack.Anchored = true
crack.CanCollide = false
crack.Size = Vector3.new(60, 0.3, 2)
crack.CFrame = CFrame.new(P + Vector3.new(0, 0.1, 10)) * CFrame.Angles(0, math.rad(4), 0)
crack.Material = Enum.Material.Neon
crack.Color = Color3.fromRGB(255, 60, 30)
crack.Parent = scene
local fl = Instance.new("PointLight")
fl.Color = Color3.fromRGB(255, 70, 40)
fl.Range = 40
fl.Brightness = 3
fl.Parent = crack

-- key light on the Keis' faces (from the camera side) + red rim lights from below
local key = Instance.new("Part")
key.Anchored = true
key.CanCollide = false
key.Transparency = 1
key.CFrame = CFrame.lookAt(P + Vector3.new(-12, 18, -30), P + Vector3.new(0, 6, 0))
key.Parent = scene
local spot = Instance.new("SpotLight")
spot.Face = Enum.NormalId.Front
spot.Range = 60
spot.Angle = 70
spot.Brightness = 2.2
spot.Color = Color3.fromRGB(200, 220, 255)
spot.Shadows = true
spot.Parent = key

-- the Keis lineup (boss in the middle)
local lineup = {
	{ "Master", Vector3.new(0, 0, 4) },
	{ "Basic", Vector3.new(-10, 0, 0) },
	{ "Basic", Vector3.new(10, 0, -1) },
	{ "Skeleton", Vector3.new(-19, 0, 5) },
	{ "Iron", Vector3.new(20, 0, 6) },
	{ "Keyring", Vector3.new(-30, 0, 12) },
}
local menuKeis = {}
for _, entry in lineup do
	local def = (Config.KeisTypes :: any)[entry[1]]
	local model, _, root, _, _, chant = KeisModel.build(def, P + entry[2])
	root.Anchored = true
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(rng:NextNumber(-12, 12)), 0)
	model.Parent = scene
	local motors = {}
	for _, m in root:GetChildren() do
		if m:IsA("Motor6D") then
			table.insert(motors, m)
		end
	end
	table.insert(menuKeis, { chant = chant, motors = motors, phase = rng:NextNumber(0, 6) })
end

-- Jupiter rising behind them + stars
local jc, jr = P + Vector3.new(-160, 210, 1000), 480
SpaceArt.jupiter(scene, jc, jr, P + Vector3.new(0, 6, -40), 1)
SpaceArt.stars(scene, P, 1600, 450, 3, jc, jr * 2.1)

-- UI ---------------------------------------------------------------------------------------------
local gui = make("ScreenGui", { Name = "Menu", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50,
	Parent = player:WaitForChild("PlayerGui") })
local uiScale = make("UIScale", { Parent = gui })
make("Frame", { Size = UDim2.fromScale(0.55, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui }, {
	make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }) }),
})
local column = make("Frame", { Position = UDim2.new(0, 70, 0.5, -230), Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 1, Parent = gui })
text({ Font = F.Mono, TextSize = 16, TextColor3 = C.Muted, Size = UDim2.new(1, 0, 0, 20), Text = "RECOVERED FOOTAGE · USS KEPLER · 07/14/2011", Parent = column })
local title = text({ Font = F.Title, TextSize = 92, Position = UDim2.fromOffset(-4, 22), Size = UDim2.new(1, 0, 0, 100), Text = "JUPITER",
	TextStrokeTransparency = 0.6, Parent = column })
text({ Font = F.Title, TextSize = 34, TextColor3 = C.Danger, Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, 0, 0, 40),
	Text = "2011 INCIDENT", Parent = column })
local chantLine = text({ Font = F.Mono, TextSize = 16, TextColor3 = C.Danger, Position = UDim2.fromOffset(0, 168), Size = UDim2.new(1, 0, 0, 20),
	Text = "keis keis keis o algo o algo", TextTransparency = 0.4, Parent = column })

local function button(label: string, y: number, primary: boolean): TextButton
	local b = make("TextButton", {
		Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(primary and 300 or 240, primary and 64 or 46),
		BackgroundColor3 = if primary then C.Accent else C.Panel, BackgroundTransparency = if primary then 0 else 0.2,
		Text = label, Font = F.Title, TextSize = primary and 24 or 15, TextColor3 = if primary then C.Bg else C.Text,
		AutoButtonColor = true, Parent = column,
	}, { Theme.corner(8), Theme.stroke(C.Accent, if primary then 1 else 0.5, 1.5) })
	b.MouseEnter:Connect(function()
		Theme.tween(b, 0.15, { Position = UDim2.fromOffset(10, y) })
	end)
	b.MouseLeave:Connect(function()
		Theme.tween(b, 0.15, { Position = UDim2.fromOffset(0, y) })
	end)
	return b
end
local playBtn = button("PLAY", 222, true)
local howBtn = button("HOW TO PLAY", 302, false)

-- saved stats card
local stats = Theme.panel({ Position = UDim2.fromOffset(0, 370), Size = UDim2.fromOffset(300, 92), Parent = column })
local statLevel = text({ Font = F.Title, TextSize = 18, TextColor3 = C.Accent, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 22), Parent = stats })
local statBest = text({ Font = F.Body, TextSize = 15, Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 18), Parent = stats })
local statXp = Theme.bar({ Position = UDim2.fromOffset(16, 66), Size = UDim2.new(1, -32, 0, 10), Parent = stats }, C.Accent)
local function refreshStats()
	statLevel.Text = `LV {player:GetAttribute("Level") or 1} · {player:GetAttribute("Title") or "CADET"}`
	statBest.Text = `BEST WAVE  {player:GetAttribute("BestWave") or 0}`
	statXp:set((player:GetAttribute("XP") or 0) / math.max(player:GetAttribute("XPNeeded") or 100, 1))
end
player.AttributeChanged:Connect(refreshStats)
refreshStats()

local how = Theme.panel({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -60, 0.5, 0), Size = UDim2.fromOffset(420, 330), Visible = false, Parent = gui })
text({ Font = F.Title, TextSize = 18, Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 24), Text = "HOW TO PLAY", Parent = how })
text({ Font = F.Body, TextSize = 15, Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 1, -60), TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = C.Cream, Parent = how,
	Text = "The Keis crawl out of the vents in waves. Keep them away from the reactor and keep your crew alive.\n\n"
		.. "• Hold click to fire · Shift to sprint · R to reload\n"
		.. "• Shoot a Keis in the mouth for a CRIT\n"
		.. "• Spend credits between waves: Q opens the Upgrade Terminal\n"
		.. "• Hold E on a downed crewmate to revive them\n"
		.. "• Survive wave 10 and the ship lands on Io, Jupiter's volcanic moon. Low gravity." })
howBtn.MouseButton1Click:Connect(function()
	how.Visible = not how.Visible
end)

-- Menu lifecycle ----------------------------------------------------------------------------------
local menuOpen = true
local HIDE = { "HUD", "Combat", "Shop", "Atmosphere" }
local function setGameGuis(enabled: boolean)
	for _, name in HIDE do
		local g = player.PlayerGui:FindFirstChild(name)
		if g and g:IsA("ScreenGui") then
			g.Enabled = enabled
		end
	end
end
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) -- we draw our own health bar
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local chantSound: Sound? = nil
if Config.Sounds.KeisChant ~= "" then
	chantSound = make("Sound", { SoundId = Config.Sounds.KeisChant, Volume = 0.6, PlaybackSpeed = 0.9, Parent = SoundService })
end

local start = os.clock()
local nextChant = os.clock() + 2
RunService:BindToRenderStep("JupiterMenu", Enum.RenderPriority.Camera.Value + 5, function()
	if not menuOpen then
		return
	end
	setGameGuis(false)
	uiScale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.2)
	local t = os.clock() - start
	camera.CameraType = Enum.CameraType.Scriptable
	local eye = P + Vector3.new(math.sin(t * 0.08) * 7, 6.5 + math.sin(t * 0.13) * 0.8, -40 + math.sin(t * 0.05) * 3)
	camera.CFrame = CFrame.lookAt(eye, P + Vector3.new(-4, 9, 30))
	camera.FieldOfView = 60
	for _, k in menuKeis do
		k.phase += 0.016
		for i, m in k.motors do
			m.Transform = CFrame.Angles(0, math.sin(k.phase * 2 + i) * 0.06, math.sin(k.phase * 3 + i * 2) * 0.05)
		end
	end
	title.TextTransparency = if math.random() < 0.015 then 0.5 else 0
	chantLine.TextTransparency = 0.3 + math.abs(math.sin(t * 1.5)) * 0.5
	if os.clock() >= nextChant then
		nextChant = os.clock() + 7
		for _, k in menuKeis do
			k.chant.Text = if math.random() < 0.6 then Config.KeisChatter[math.random(1, #Config.KeisChatter)] else ""
		end
		if chantSound then
			chantSound:Play()
		end
	end
end)

playBtn.MouseButton1Click:Connect(function()
	if not menuOpen then
		return
	end
	playBtn.Active = false
	fadeTo(1, 0.6)
	menuOpen = false
	RunService:UnbindFromRenderStep("JupiterMenu")
	gui:Destroy()
	scene:Destroy()
	if chantSound then
		chantSound:Destroy()
	end
	Remotes:WaitForChild("PlayRequest"):FireServer()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 10)
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid :: Humanoid
	end
	camera.FieldOfView = 70
	setGameGuis(true)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end)
	task.wait(0.3)
	fadeTo(0, 0.8)
end)
