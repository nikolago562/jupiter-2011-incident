--!strict
-- Upgrade terminal: Q (or the button) opens it. Upgrades reset each run, so every run is a new build.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C, F = Theme.Colors, Theme.Fonts
local make, text = Theme.make, Theme.text

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Buy = Remotes:WaitForChild("BuyUpgrade") :: RemoteEvent
local Repair = Remotes:WaitForChild("RepairReactor") :: RemoteEvent

local gui = make("ScreenGui", { Name = "Shop", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 8,
	Parent = player:WaitForChild("PlayerGui") })
local scale = make("UIScale", { Parent = gui })
RunService.RenderStepped:Connect(function()
	scale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.15)
end)

-- open button (above the player card)
local openBtn = make("TextButton", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -120), Size = UDim2.fromOffset(170, 40),
	BackgroundColor3 = C.Accent, Text = "UPGRADES  [Q]", Font = F.Title, TextSize = 13, TextColor3 = C.Bg,
	AutoButtonColor = true, Parent = gui,
}, { Theme.corner(8) })

-- panel
local panel = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(720, 530),
	Visible = false, Parent = gui })
text({ Font = F.Title, TextSize = 24, Position = UDim2.fromOffset(22, 16), Size = UDim2.fromOffset(400, 30), Text = "UPGRADE TERMINAL", Parent = panel })
text({ Font = F.Meme, TextSize = 14, TextColor3 = C.Muted, Position = UDim2.fromOffset(22, 46), Size = UDim2.fromOffset(400, 18),
	Text = "USS KEPLER · ARMORY · JULY 14 2011", Parent = panel })
local credits = text({ Font = F.Heavy, TextSize = 24, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 18), Size = UDim2.fromOffset(200, 30), Parent = panel })
local close = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 16), Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = C.Bg, Text = "✕", TextColor3 = C.Text, Font = F.Heavy, TextSize = 18, Parent = panel }, { Theme.corner(8) })

local grid = make("Frame", { Position = UDim2.fromOffset(22, 80), Size = UDim2.new(1, -44, 0, 300), BackgroundTransparency = 1, Parent = panel })
make("UIGridLayout", { CellSize = UDim2.fromOffset(216, 140), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })

type Card = { def: any, level: TextLabel, pips: { Frame }, buy: TextButton }
local cards: { Card } = {}

for i, def in Config.Upgrades do
	local cell = make("Frame", { BackgroundColor3 = C.Bg, BackgroundTransparency = 0.2, LayoutOrder = i, Parent = grid },
		{ Theme.corner(10), Theme.stroke(C.Accent, 0.75, 1) })
	text({ Font = F.Heavy, TextSize = 26, TextColor3 = C.Accent, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(30, 30), Text = def.icon, Parent = cell })
	text({ Font = F.Title, TextSize = 12, Position = UDim2.fromOffset(46, 10), Size = UDim2.new(1, -56, 0, 16), Text = def.name, Parent = cell })
	text({ Font = F.Body, TextSize = 13, TextColor3 = C.Muted, Position = UDim2.fromOffset(46, 28), Size = UDim2.new(1, -56, 0, 16), Text = def.desc, Parent = cell })
	local pipRow = make("Frame", { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 8), BackgroundTransparency = 1, Parent = cell })
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = pipRow })
	local pips = {}
	for _ = 1, def.max do
		table.insert(pips, make("Frame", { Size = UDim2.new(1 / def.max, -4, 1, 0), BackgroundColor3 = Color3.fromRGB(50, 42, 56), BorderSizePixel = 0, Parent = pipRow }, { Theme.corner(3) }))
	end
	local level = text({ Font = F.Bold, TextSize = 12, TextColor3 = C.Cream, Position = UDim2.fromOffset(12, 70), Size = UDim2.new(1, -24, 0, 16), Parent = cell })
	local buy = make("TextButton", { Position = UDim2.new(0, 12, 1, -44), Size = UDim2.new(1, -24, 0, 34), BackgroundColor3 = C.Accent,
		Font = F.Heavy, TextSize = 15, TextColor3 = C.Bg, Text = "", Parent = cell }, { Theme.corner(8) })
	buy.MouseButton1Click:Connect(function()
		Buy:FireServer(def.id)
	end)
	table.insert(cards, { def = def, level = level, pips = pips, buy = buy })
end

local repairBtn = make("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(1, -44, 0, 44),
	BackgroundColor3 = C.Cyan, Font = F.Title, TextSize = 14, TextColor3 = C.Bg,
	Text = `REPAIR REACTOR  +{Config.REPAIR_AMOUNT} HP  ·  ◆ {Config.REPAIR_COST}`, Parent = panel }, { Theme.corner(8) })
repairBtn.MouseButton1Click:Connect(function()
	Repair:FireServer()
end)

local MINIGUN = Config.Weapons.Minigun
local minigunBtn = make("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -72), Size = UDim2.new(1, -44, 0, 44),
	BackgroundColor3 = C.Gold, Font = F.Title, TextSize = 14, TextColor3 = C.Bg, Text = "", Parent = panel }, { Theme.corner(8) })
minigunBtn.MouseButton1Click:Connect(function()
	Buy:FireServer("Minigun")
end)

local function refresh()
	local money = player:GetAttribute("Credits") or 0
	credits.Text = `◆ {money}`
	for _, card in cards do
		local lvl = player:GetAttribute("Up_" .. card.def.id) or 0
		for i, pip in card.pips do
			pip.BackgroundColor3 = if i <= lvl then C.Accent else Color3.fromRGB(50, 42, 56)
		end
		card.level.Text = `LEVEL {lvl} / {card.def.max}`
		if lvl >= card.def.max then
			card.buy.Text = "MAXED"
			card.buy.BackgroundColor3 = Color3.fromRGB(60, 52, 66)
			card.buy.TextColor3 = C.Muted
		else
			local cost = Config.upgradeCost(card.def, lvl)
			card.buy.Text = `BUY  ◆ {cost}`
			local afford = money >= cost
			card.buy.BackgroundColor3 = if afford then C.Accent else Color3.fromRGB(60, 52, 66)
			card.buy.TextColor3 = if afford then C.Bg else C.Muted
		end
	end
	if player:GetAttribute("Weapon") == "Minigun" then
		minigunBtn.Text = `{MINIGUN.name}  ·  EQUIPPED`
		minigunBtn.BackgroundColor3 = Color3.fromRGB(60, 52, 66)
		minigunBtn.TextColor3 = C.Muted
	else
		local afford = money >= MINIGUN.cost
		minigunBtn.Text = `UNLOCK {MINIGUN.name}  ·  ◆ {MINIGUN.cost}`
		minigunBtn.BackgroundColor3 = if afford then C.Gold else Color3.fromRGB(60, 52, 66)
		minigunBtn.TextColor3 = if afford then C.Bg else C.Muted
	end
	local hp = ReplicatedStorage:GetAttribute("ReactorHP") or 0
	local max = ReplicatedStorage:GetAttribute("ReactorMax") or 1
	local canRepair = money >= Config.REPAIR_COST and hp < max
	repairBtn.BackgroundColor3 = if canRepair then C.Cyan else Color3.fromRGB(60, 52, 66)
	repairBtn.TextColor3 = if canRepair then C.Bg else C.Muted
end
player.AttributeChanged:Connect(refresh)
ReplicatedStorage:GetAttributeChangedSignal("ReactorHP"):Connect(refresh)
refresh()

local function setOpen(open: boolean)
	if open == panel.Visible then
		return
	end
	panel.Visible = open
	player:SetAttribute("UIOpen", open)
	if open then
		panel.Size = UDim2.fromOffset(680, 500)
		Theme.tween(panel, 0.2, { Size = UDim2.fromOffset(720, 530) }, Enum.EasingStyle.Back)
		refresh()
	end
end
openBtn.MouseButton1Click:Connect(function()
	setOpen(not panel.Visible)
end)
close.MouseButton1Click:Connect(function()
	setOpen(false)
end)
ContextActionService:BindAction("JupiterShop", function(_, state)
	if state == Enum.UserInputState.Begin then
		setOpen(not panel.Visible)
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonY)

-- purchase feedback
Remotes:WaitForChild("Purchased").OnClientEvent:Connect(function(id: string)
	Theme.playSound(Config.Sounds.Buy, 0.6)
	for _, card in cards do
		if card.def.id == id then
			local b = card.buy
			b.Size = UDim2.new(1, -16, 0, 38)
			Theme.tween(b, 0.2, { Size = UDim2.new(1, -24, 0, 34) }, Enum.EasingStyle.Back)
		end
	end
end)

-- the button pulses during breaks if you can afford something
task.spawn(function()
	while true do
		local phase = ReplicatedStorage:GetAttribute("Phase")
		local money = player:GetAttribute("Credits") or 0
		local canAfford = false
		for _, card in cards do
			local lvl = player:GetAttribute("Up_" .. card.def.id) or 0
			if lvl < card.def.max and money >= Config.upgradeCost(card.def, lvl) then
				canAfford = true
			end
		end
		if phase == "Break" and canAfford and not panel.Visible then
			Theme.tween(openBtn, 0.4, { BackgroundColor3 = C.Gold })
			task.wait(0.45)
			Theme.tween(openBtn, 0.4, { BackgroundColor3 = C.Accent })
			task.wait(0.45)
		else
			openBtn.BackgroundColor3 = C.Accent
			task.wait(0.5)
		end
	end
end)
