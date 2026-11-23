--!strict
-- Pick-1-of-3 perk cards after each wave (and from crates). Keys 1/2/3 to pick, reroll costs 1 key.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Perks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Perks"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C, F = Theme.Colors, Theme.Fonts
local make, text = Theme.make, Theme.text

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local PickPerk = Remotes:WaitForChild("PickPerk") :: RemoteEvent
local RerollPerk = Remotes:WaitForChild("RerollPerk") :: RemoteEvent

local gui = make("ScreenGui", { Name = "PerkPicker", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Enabled = false,
	Parent = player:WaitForChild("PlayerGui") })
local scale = make("UIScale", { Parent = gui })
RunService.RenderStepped:Connect(function()
	scale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.1)
end)
-- a Modal button frees the mouse while in first person
make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0,
	Text = "", AutoButtonColor = false, Modal = true, Parent = gui })
local header = text({ Font = F.Title, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromOffset(900, 44), Text = "CHOOSE A PERK", Parent = gui })
local subheader = text({ Font = F.Mono, TextSize = 16, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromOffset(900, 20), Text = "PRESS 1 · 2 · 3", Parent = gui })
local row = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(780, 330),
	BackgroundTransparency = 1, Parent = gui })
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 24), Parent = row })
local reroll = make("TextButton", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.78), Size = UDim2.fromOffset(240, 44),
	BackgroundColor3 = C.Panel, Text = "REROLL · 1 KEY", Font = F.Title, TextSize = 14, TextColor3 = C.Gold, Parent = gui },
	{ Theme.corner(8), Theme.stroke(C.Gold, 0.4, 1.5) })

local currentId = 0
local currentCards: { string } = {}
local shimmer: { UIGradient } = {}

local function close()
	gui.Enabled = false
	player:SetAttribute("UIOpen", false)
	currentId = 0
end

local function choose(index: number)
	if currentId == 0 or not currentCards[index] then
		return
	end
	PickPerk:FireServer(currentId, index)
	close()
end

local function build(cards: { string }, rarityOnly: string?)
	for _, c in row:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	shimmer = {}
	header.Text = if rarityOnly == "Legendary" then "LEGENDARY CHOICE" else "CHOOSE A PERK"
	header.TextColor3 = if rarityOnly == "Legendary" then C.Gold else C.Text
	local owned = Perks.decode(player:GetAttribute("Perks") :: string?)
	for i, id in cards do
		local perk = Perks.byId[id]
		local rarity = Perks.Rarity[perk.rarity]
		local card = make("TextButton", { Size = UDim2.fromOffset(240, 320), BackgroundColor3 = C.Panel, AutoButtonColor = false, Text = "",
			LayoutOrder = i, Parent = row }, { Theme.corner(14) })
		local stroke = Theme.stroke(rarity.color, 0, if perk.rarity == "Legendary" then 3 else 2)
		stroke.Parent = card
		if perk.rarity == "Legendary" then
			local g = make("UIGradient", { Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, rarity.color), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, rarity.color) }),
				Parent = stroke })
			table.insert(shimmer, g)
		end
		make("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = rarity.color, BorderSizePixel = 0, Parent = card }, { Theme.corner(3) })
		text({ Font = F.Mono, TextSize = 14, TextColor3 = rarity.color, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 16),
			Size = UDim2.new(1, 0, 0, 18), Text = rarity.label, Parent = card })
		text({ Font = F.Heavy, TextSize = 64, TextColor3 = rarity.color, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 44),
			Size = UDim2.new(1, 0, 0, 80), Text = perk.icon, Parent = card })
		text({ Font = F.Title, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 136),
			Size = UDim2.new(1, -20, 0, 40), TextWrapped = true, Text = perk.name, Parent = card })
		text({ Font = F.Body, TextSize = 15, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(16, 184), Size = UDim2.new(1, -32, 0, 70), TextWrapped = true, Text = perk.desc, Parent = card })
		text({ Font = F.Mono, TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -50),
			Size = UDim2.new(1, 0, 0, 18), Text = `STACK {(owned[id] or 0) + 1} / {perk.max}`, Parent = card })
		text({ Font = F.Title, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -28),
			Size = UDim2.new(1, 0, 0, 18), Text = `[{i}]`, Parent = card })
		card.MouseEnter:Connect(function()
			Theme.tween(card, 0.12, { Size = UDim2.fromOffset(252, 336) })
		end)
		card.MouseLeave:Connect(function()
			Theme.tween(card, 0.12, { Size = UDim2.fromOffset(240, 320) })
		end)
		card.MouseButton1Click:Connect(function()
			choose(i)
		end)
		-- deal the cards in
		card.Position = UDim2.fromOffset(0, 60)
		card.BackgroundTransparency = 1
		task.delay((i - 1) * 0.08, function()
			Theme.tween(card, 0.3, { BackgroundTransparency = 0.05 }, Enum.EasingStyle.Back)
		end)
	end
end

Remotes:WaitForChild("PerkOffer").OnClientEvent:Connect(function(offerId: number, cards: { string }, rarityOnly: string?)
	if offerId == 0 or #cards == 0 then
		close()
		return
	end
	currentId = offerId
	currentCards = cards
	build(cards, rarityOnly)
	gui.Enabled = true
	player:SetAttribute("UIOpen", true) -- Movement.client frees the mouse while this is open
end)

reroll.MouseButton1Click:Connect(function()
	if currentId ~= 0 and ((player:GetAttribute("Keys") :: number?) or 0) >= 1 then
		RerollPerk:FireServer(currentId)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not gui.Enabled then
		return
	end
	local map = { [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 }
	local idx = map[input.KeyCode]
	if idx then
		choose(idx)
	end
end)

RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		return
	end
	local keys = (player:GetAttribute("Keys") :: number?) or 0
	reroll.Text = `REROLL · 1 KEY  (YOU HAVE {keys})`
	reroll.TextTransparency = if keys >= 1 then 0 else 0.5
	for _, g in shimmer do
		g.Rotation = (os.clock() * 120) % 360
	end
	subheader.Text = "PRESS 1 · 2 · 3   ·   THE KEIS DON'T WAIT"
end)
