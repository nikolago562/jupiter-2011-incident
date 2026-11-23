--!strict
-- Shooting feel: hold-to-fire, crosshair, tracers, hitmarkers, floating damage numbers, kill pops, combo counter, ammo.

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C, F = Theme.Colors, Theme.Fonts
local make, text = Theme.make, Theme.text

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()
local Shoot = Remotes:WaitForChild("Shoot") :: RemoteEvent
local Reload = Remotes:WaitForChild("Reload") :: RemoteEvent

local gui = make("ScreenGui", { Name = "Combat", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6,
	Parent = player:WaitForChild("PlayerGui") })

-- Crosshair -----------------------------------------------------------------------------------------
local cross = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1, Visible = false, Parent = gui })
for _, d in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, d[1] * 10, 0.5, d[2] * 10),
		Size = if d[1] == 0 then UDim2.fromOffset(2, 8) else UDim2.fromOffset(8, 2),
		BackgroundColor3 = C.Text,
		BorderSizePixel = 0,
		Parent = cross,
	})
end
make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 3),
	BackgroundColor3 = C.Accent, BorderSizePixel = 0, Parent = cross })
local hitmarker = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40),
	BackgroundTransparency = 1, Text = "✕", TextSize = 30, Font = F.Heavy, TextColor3 = C.Text, TextTransparency = 1, Parent = cross })

-- Ammo panel (bottom right) ----------------------------------------------------------------------------
local ammoPanel = Theme.panel({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(200, 70), Parent = gui })
local ammoText = text({ Font = F.Title, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(0, 6),
	Size = UDim2.new(1, -14, 0, 36), Parent = ammoPanel })
local ammoSub = text({ Font = F.Bold, TextSize = 12, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, -14, 0, 16), Text = "BLASTER · [R] RELOAD", Parent = ammoPanel })

-- Combo counter ----------------------------------------------------------------------------------------
local comboLabel = text({ Font = F.Title, TextSize = 26, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -96), Size = UDim2.fromOffset(300, 34),
	TextStrokeTransparency = 0.3, TextTransparency = 1, Parent = gui })
local combo, comboUntil = 0, 0
local COMBO_NAMES = { [3] = "TRIPLE KEIS", [5] = "KEY SMASHER", [8] = "LOCKSMITH RAMPAGE", [12] = "O ALGO O ALGO", [20] = "THE TRUE SURVIVOR" }

-- Firing -------------------------------------------------------------------------------------------------
local firing = false
local lastFire = 0
local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function equippedBlaster(): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChild("Blaster")
	return if tool and tool:IsA("Tool") then tool else nil
end

local function muzzlePos(): Vector3?
	local tool = equippedBlaster()
	local muzzle = tool and tool:FindFirstChild("Muzzle") :: BasePart?
	return if muzzle then muzzle.Position else nil
end

local tracerFolder = make("Folder", { Name = "LocalTracers", Parent = workspace })
mouse.TargetFilter = tracerFolder
local function tracer(from: Vector3, to: Vector3, color: Color3)
	local len = (to - from).Magnitude
	if len < 0.5 then
		return
	end
	local p = make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Material = Enum.Material.Neon, Color = color, Size = Vector3.new(0.14, 0.14, len),
		CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2), Parent = tracerFolder,
	})
	Theme.tween(p, 0.09, { Transparency = 1, Size = Vector3.new(0.02, 0.02, len) })
	Debris:AddItem(p, 0.12)
	local spark = make("Part", {
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon, Color = color, Size = Vector3.one * 0.8, CFrame = CFrame.new(to), Parent = tracerFolder,
	})
	Theme.tween(spark, 0.15, { Transparency = 1, Size = Vector3.one * 2 })
	Debris:AddItem(spark, 0.2)
end

local function tryFire()
	local tool = equippedBlaster()
	if not tool or player:GetAttribute("Reloading") or player:GetAttribute("CrewStatus") ~= "alive" then
		return
	end
	local interval = player:GetAttribute("FireInterval") or Config.Weapon.FireInterval
	local now = os.clock()
	if now - lastFire < interval then
		return
	end
	lastFire = now
	if (player:GetAttribute("Ammo") or 0) <= 0 then
		Reload:FireServer()
		return
	end
	local aim = mouse.Hit.Position
	Shoot:FireServer(aim)
	-- local tracer for instant feedback
	local from = muzzlePos()
	if from then
		tracer(from, aim, C.Cyan)
	end
	Theme.playSound(Config.Sounds.Shoot, 0.35, 0.95 + math.random() * 0.1)
	-- tiny recoil
	camera.CFrame *= CFrame.Angles(math.rad(0.35), 0, 0)
end

local function hookTool(tool: Tool)
	if hooked[tool] then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		firing = true
		tryFire()
	end)
	tool.Deactivated:Connect(function()
		firing = false
	end)
	tool.Unequipped:Connect(function()
		firing = false
	end)
end

local function hookCharacter(character: Model)
	character.ChildAdded:Connect(function(c)
		if c:IsA("Tool") and c.Name == "Blaster" then
			hookTool(c)
		end
	end)
	local existing = character:FindFirstChild("Blaster")
	if existing and existing:IsA("Tool") then
		hookTool(existing)
	end
end
if player.Character then
	hookCharacter(player.Character)
end
player.CharacterAdded:Connect(hookCharacter)

ContextActionService:BindAction("JupiterReload", function(_, state)
	if state == Enum.UserInputState.Begin then
		Reload:FireServer()
	end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("JupiterReload", "R")

RunService.RenderStepped:Connect(function()
	local tool = equippedBlaster()
	local armed = tool ~= nil
	cross.Visible = armed
	UserInputService.MouseIconEnabled = not armed
	if armed then
		local m = UserInputService:GetMouseLocation()
		cross.Position = UDim2.fromOffset(m.X, m.Y)
		if firing then
			tryFire()
		end
	end
	ammoPanel.Visible = armed or player:GetAttribute("Downed") == true
	if player:GetAttribute("Reloading") then
		ammoText.Text = "RELOADING"
		ammoText.TextColor3 = C.Accent
	else
		local ammo = player:GetAttribute("Ammo") or 0
		ammoText.Text = `{ammo} / {player:GetAttribute("MagSize") or 0}`
		ammoText.TextColor3 = if ammo <= 3 then C.Danger else C.Text
	end
	if os.clock() > comboUntil and combo > 0 then
		combo = 0
		Theme.tween(comboLabel, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end
end)

-- Other players' shots -------------------------------------------------------------------------------------
Remotes:WaitForChild("ShotFx").OnClientEvent:Connect(function(shooter: Player, origin: Vector3, hits: { Vector3 })
	if shooter == player then
		-- our extra Split Beam pellets (the first one was drawn locally already)
		local from = muzzlePos() or origin
		for i = 2, #hits do
			tracer(from, hits[i], C.Cyan)
		end
		return
	end
	local character = shooter.Character
	local tool = character and character:FindFirstChild("Blaster")
	local muzzle = tool and tool:FindFirstChild("Muzzle") :: BasePart?
	local from = if muzzle then muzzle.Position else origin
	for _, h in hits do
		tracer(from, h, C.Accent)
	end
end)

-- Hit feedback ---------------------------------------------------------------------------------------------
local function popup(worldPos: Vector3, msg: string, color: Color3, size: number)
	local anchor = make("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1,
		Size = Vector3.one * 0.1, CFrame = CFrame.new(worldPos), Parent = tracerFolder })
	local bb = make("BillboardGui", { Size = UDim2.fromOffset(160, 50), AlwaysOnTop = true, LightInfluence = 0, Adornee = anchor, Parent = anchor })
	local l = make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = F.Heavy, TextSize = size,
		TextColor3 = color, TextStrokeTransparency = 0.2, Text = msg, Parent = bb })
	local dx = (math.random() - 0.5) * 2
	Theme.tween(bb, 0.7, { StudsOffsetWorldSpace = Vector3.new(dx, 3, 0) })
	task.delay(0.35, function()
		Theme.tween(l, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(anchor, 0.8)
end

Remotes:WaitForChild("HitConfirm").OnClientEvent:Connect(function(pos: Vector3, dmg: number, crit: boolean, killed: boolean, reward: number, golden: boolean)
	hitmarker.TextColor3 = if killed then C.Danger elseif crit then C.Gold else C.Text
	hitmarker.TextTransparency = 0
	hitmarker.Size = UDim2.fromOffset(if killed then 56 else 40, if killed then 56 else 40)
	Theme.tween(hitmarker, 0.18, { TextTransparency = 1 })
	popup(pos, if crit then `{dmg} CRIT!` else tostring(dmg), if crit then C.Gold else C.Text, if crit then 26 else 20)
	Theme.playSound(Config.Sounds.Hit, 0.3, if crit then 1.3 else 1)
	if killed then
		popup(pos + Vector3.new(0, 2, 0), `+{reward} ◆`, if golden then C.Gold else C.Good, if golden then 34 else 24)
		Theme.playSound(Config.Sounds.Kill, 0.5)
		combo += 1
		comboUntil = os.clock() + 2.5
		if combo >= 2 then
			local name, best = "", 0
			for n, label in COMBO_NAMES do
				if combo >= n and n > best then
					best, name = n, label
				end
			end
			comboLabel.Text = `x{combo}  {name}`
			comboLabel.TextTransparency = 0
			comboLabel.TextStrokeTransparency = 0.3
			comboLabel.TextSize = 34
			Theme.tween(comboLabel, 0.2, { TextSize = 26 })
		end
	end
end)
