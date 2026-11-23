--!strict
-- The Armory: opened at the weapon bench. Attachments (with live 3D preview), upgrades, supplies.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local WeaponModel = require(Shared:WaitForChild("WeaponModel"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C, F = Theme.Colors, Theme.Fonts
local make, text = Theme.make, Theme.text

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Attachment = Remotes:WaitForChild("Attachment") :: RemoteEvent
local Buy = Remotes:WaitForChild("BuyUpgrade") :: RemoteEvent
local Repair = Remotes:WaitForChild("RepairReactor") :: RemoteEvent

local gui = make("ScreenGui", { Name = "Armory", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 15, Enabled = false,
	Parent = player:WaitForChild("PlayerGui") })
local scale = make("UIScale", { Parent = gui })
RunService.RenderStepped:Connect(function()
	scale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.55, 1.1)
end)
-- a Modal button frees the mouse while in first person
make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Text = "",
	AutoButtonColor = false, Modal = true, Parent = gui })

local panel = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1060, 640), Parent = gui })
text({ Font = F.Title, TextSize = 26, Position = UDim2.fromOffset(26, 18), Size = UDim2.fromOffset(500, 32), Text = "ARMORY", Parent = panel })
text({ Font = F.Mono, TextSize = 14, TextColor3 = C.Muted, Position = UDim2.fromOffset(26, 50), Size = UDim2.fromOffset(500, 18),
	Text = "USS KEPLER · WEAPON SYSTEMS · 07/14/2011", Parent = panel })
local creditsText = text({ Font = F.Heavy, TextSize = 24, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -70, 0, 20), Size = UDim2.fromOffset(260, 30), Parent = panel })
local closeBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = C.Bg, Text = "✕", Font = F.Heavy, TextSize = 18, TextColor3 = C.Text, Parent = panel }, { Theme.corner(8) })

-- Preview (left) ---------------------------------------------------------------------------------------
local previewBox = make("Frame", { Position = UDim2.fromOffset(26, 84), Size = UDim2.fromOffset(400, 530), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.1,
	Parent = panel }, { Theme.corner(10), Theme.stroke(C.Accent, 0.7, 1) })
local viewport = make("ViewportFrame", { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 330), BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(150, 150, 160), LightColor = Color3.fromRGB(255, 245, 230), LightDirection = Vector3.new(-1, -1, -0.6), Parent = previewBox })
local vpCam = Instance.new("Camera")
vpCam.FieldOfView = 30
vpCam.Parent = viewport
viewport.CurrentCamera = vpCam
local weaponName = text({ Font = F.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 346),
	Size = UDim2.new(1, 0, 0, 26), Parent = previewBox })
local statsText = text({ Font = F.Mono, TextSize = 15, TextColor3 = C.Cream, Position = UDim2.fromOffset(24, 384), Size = UDim2.new(1, -48, 0, 130),
	TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Parent = previewBox })

local previewModel: Model? = nil
local previewKey = ""
local hoverAtt: { slot: string, id: string }? = nil

local function currentAtt(): WeaponModel.Attachments
	local att = WeaponModel.decode(player:GetAttribute("Attachments") :: string?)
	if hoverAtt then
		(att :: any)[hoverAtt.slot] = hoverAtt.id
	end
	return att
end

local function refreshPreview()
	local weaponId = (player:GetAttribute("Weapon") :: string?) or "Blaster"
	local att = currentAtt()
	local key = weaponId .. WeaponModel.encode(att)
	if key == previewKey then
		return
	end
	previewKey = key
	if previewModel then
		previewModel:Destroy()
	end
	local m = Instance.new("Model")
	WeaponModel.build(weaponId, att, m, "Root")
	m.Parent = viewport
	previewModel = m
	local w = Config.Weapons[weaponId]
	weaponName.Text = if w then w.name else weaponId
	local optic = Config.attachment("Optic", att.Optic)
	local laser = Config.attachment("Laser", att.Laser)
	local muzzle = Config.attachment("Muzzle", att.Muzzle)
	statsText.Text = string.format("FIRE RATE   %.1f /s\nMAGAZINE    %d\nOPTIC       %s (%.1fx)\nLASER       %s\nMUZZLE      %s",
		1 / ((player:GetAttribute("FireInterval") :: number?) or 0.2), (player:GetAttribute("MagSize") :: number?) or 0,
		if optic then optic.name else "-", if optic then optic.zoom else 1, if laser then laser.name else "-", if muzzle then muzzle.name else "-")
end

-- Tabs (right) ---------------------------------------------------------------------------------------------
local content = make("Frame", { Position = UDim2.fromOffset(450, 136), Size = UDim2.fromOffset(584, 478), BackgroundTransparency = 1, Parent = panel })
local tabs: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}
local function showTab(name: string)
	for n, f in tabs do
		f.Visible = n == name
		tabButtons[n].BackgroundColor3 = if n == name then C.Accent else C.Bg
		tabButtons[n].TextColor3 = if n == name then C.Bg else C.Text
	end
	Theme.playSound(Config.Sounds.UIClick, 0.4)
end
for i, name in { "ATTACHMENTS", "UPGRADES", "SUPPLIES" } do
	local b = make("TextButton", { Position = UDim2.fromOffset(450 + (i - 1) * 196, 84), Size = UDim2.fromOffset(186, 38), BackgroundColor3 = C.Bg,
		Text = name, Font = F.Title, TextSize = 13, TextColor3 = C.Text, Parent = panel }, { Theme.corner(8), Theme.stroke(C.Accent, 0.5, 1) })
	tabButtons[name] = b
	tabs[name] = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = content })
	b.MouseButton1Click:Connect(function()
		showTab(name)
	end)
end

local function owned(): { [string]: boolean }
	local set = {}
	for k in string.gmatch((player:GetAttribute("OwnedAttachments") :: string?) or "", "[^,]+") do
		set[k] = true
	end
	return set
end

-- ATTACHMENTS
type Option = { button: TextButton, slot: string, def: any, status: TextLabel }
local options: { Option } = {}
do
	local y = 0
	for _, slot in { "Optic", "Laser", "Muzzle" } do
		text({ Font = F.Title, TextSize = 13, TextColor3 = C.Accent, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(300, 18),
			Text = string.upper(slot), Parent = tabs.ATTACHMENTS })
		local row = make("Frame", { Position = UDim2.fromOffset(0, y + 22), Size = UDim2.new(1, 0, 0, 112), BackgroundTransparency = 1, Parent = tabs.ATTACHMENTS })
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = row })
		local defs = (Config.Attachments :: any)[slot]
		local w = math.floor((584 - 8 * (#defs - 1)) / #defs)
		for _, def in defs do
			local b = make("TextButton", { Size = UDim2.fromOffset(w, 112), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.1, Text = "", AutoButtonColor = false,
				Parent = row }, { Theme.corner(8), Theme.stroke(C.Muted, 0.6, 1) })
			text({ Font = F.Title, TextSize = 11, Position = UDim2.fromOffset(8, 10), Size = UDim2.new(1, -16, 0, 28), TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center, Text = def.name, Parent = b })
			text({ Font = F.Body, TextSize = 11, TextColor3 = C.Muted, Position = UDim2.fromOffset(6, 40), Size = UDim2.new(1, -12, 0, 36), TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Text = def.desc or "", Parent = b })
			local status = text({ Font = F.Heavy, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -28),
				Size = UDim2.new(1, 0, 0, 20), Parent = b })
			b.MouseEnter:Connect(function()
				hoverAtt = { slot = slot, id = def.id }
				refreshPreview()
			end)
			b.MouseLeave:Connect(function()
				if hoverAtt and hoverAtt.id == def.id then
					hoverAtt = nil
					refreshPreview()
				end
			end)
			b.MouseButton1Click:Connect(function()
				Attachment:FireServer(slot, def.id)
				Theme.playSound(Config.Sounds.UIClick, 0.5)
			end)
			table.insert(options, { button = b, slot = slot, def = def, status = status })
		end
		y += 150
	end
end

-- UPGRADES
type Card = { def: any, level: TextLabel, pips: { Frame }, buy: TextButton }
local cards: { Card } = {}
do
	local grid = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = tabs.UPGRADES })
	make("UIGridLayout", { CellSize = UDim2.fromOffset(186, 150), CellPadding = UDim2.fromOffset(13, 13), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for i, def in Config.Upgrades do
		local cell = make("Frame", { BackgroundColor3 = C.Bg, BackgroundTransparency = 0.1, LayoutOrder = i, Parent = grid },
			{ Theme.corner(10), Theme.stroke(C.Accent, 0.75, 1) })
		text({ Font = F.Heavy, TextSize = 24, TextColor3 = C.Accent, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(30, 30), Text = def.icon, Parent = cell })
		text({ Font = F.Title, TextSize = 11, Position = UDim2.fromOffset(44, 10), Size = UDim2.new(1, -52, 0, 16), Text = def.name, Parent = cell })
		text({ Font = F.Body, TextSize = 12, TextColor3 = C.Muted, Position = UDim2.fromOffset(44, 28), Size = UDim2.new(1, -52, 0, 16), Text = def.desc, Parent = cell })
		local pipRow = make("Frame", { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 8), BackgroundTransparency = 1, Parent = cell })
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = pipRow })
		local pips = {}
		for _ = 1, def.max do
			table.insert(pips, make("Frame", { Size = UDim2.new(1 / def.max, -4, 1, 0), BackgroundColor3 = Color3.fromRGB(50, 42, 56), BorderSizePixel = 0, Parent = pipRow }, { Theme.corner(3) }))
		end
		local level = text({ Font = F.Bold, TextSize = 12, TextColor3 = C.Cream, Position = UDim2.fromOffset(12, 70), Size = UDim2.new(1, -24, 0, 16), Parent = cell })
		local buy = make("TextButton", { Position = UDim2.new(0, 12, 1, -44), Size = UDim2.new(1, -24, 0, 34), BackgroundColor3 = C.Accent, Font = F.Heavy,
			TextSize = 14, TextColor3 = C.Bg, Text = "", Parent = cell }, { Theme.corner(8) })
		buy.MouseButton1Click:Connect(function()
			Buy:FireServer(def.id)
		end)
		table.insert(cards, { def = def, level = level, pips = pips, buy = buy })
	end
end

-- SUPPLIES
local MINIGUN = Config.Weapons.Minigun
local minigunBtn = make("TextButton", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = C.Gold, Font = F.Title, TextSize = 15, TextColor3 = C.Bg,
	Text = "", Parent = tabs.SUPPLIES }, { Theme.corner(10) })
minigunBtn.MouseButton1Click:Connect(function()
	Buy:FireServer("Minigun")
end)
minigunBtn.MouseEnter:Connect(function()
	if player:GetAttribute("Weapon") ~= "Minigun" then
		previewKey = ""
		local m = Instance.new("Model")
		WeaponModel.build("Minigun", currentAtt(), m, "Root")
		if previewModel then
			previewModel:Destroy()
		end
		m.Parent = viewport
		previewModel = m
		weaponName.Text = MINIGUN.name
	end
end)
minigunBtn.MouseLeave:Connect(function()
	previewKey = ""
	refreshPreview()
end)
local repairBtn = make("TextButton", { Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = C.Cyan, Font = F.Title, TextSize = 15,
	TextColor3 = C.Bg, Text = `REPAIR REACTOR  +{Config.REPAIR_AMOUNT} HP  ·  ◆ {Config.REPAIR_COST}`, Parent = tabs.SUPPLIES }, { Theme.corner(10) })
repairBtn.MouseButton1Click:Connect(function()
	Repair:FireServer()
end)

-- Refresh --------------------------------------------------------------------------------------------------
local GREY = Color3.fromRGB(60, 52, 66)
local function refresh()
	local money = (player:GetAttribute("Credits") :: number?) or 0
	creditsText.Text = `◆ {money}`
	local att = WeaponModel.decode(player:GetAttribute("Attachments") :: string?)
	local have = owned()
	for _, o in options do
		local equipped = (att :: any)[o.slot] == o.def.id
		local isOwned = o.def.price == 0 or have[o.slot .. "." .. o.def.id]
		local stroke = o.button:FindFirstChildOfClass("UIStroke")
		if equipped then
			o.status.Text, o.status.TextColor3 = "EQUIPPED", C.Good
		elseif isOwned then
			o.status.Text, o.status.TextColor3 = "EQUIP", C.Text
		else
			o.status.Text = `◆ {o.def.price}`
			o.status.TextColor3 = if money >= o.def.price then C.Gold else C.Muted
		end
		if stroke then
			stroke.Color = if equipped then C.Good else C.Muted
			stroke.Transparency = if equipped then 0 else 0.6
		end
	end
	for _, card in cards do
		local lvl = (player:GetAttribute("Up_" .. card.def.id) :: number?) or 0
		for i, pip in card.pips do
			pip.BackgroundColor3 = if i <= lvl then C.Accent else GREY
		end
		card.level.Text = `LEVEL {lvl} / {card.def.max}`
		if lvl >= card.def.max then
			card.buy.Text, card.buy.BackgroundColor3, card.buy.TextColor3 = "MAXED", GREY, C.Muted
		else
			local cost = Config.upgradeCost(card.def, lvl)
			local afford = money >= cost
			card.buy.Text = `BUY  ◆ {cost}`
			card.buy.BackgroundColor3 = if afford then C.Accent else GREY
			card.buy.TextColor3 = if afford then C.Bg else C.Muted
		end
	end
	if player:GetAttribute("Weapon") == "Minigun" then
		minigunBtn.Text, minigunBtn.BackgroundColor3, minigunBtn.TextColor3 = `{MINIGUN.name}  ·  EQUIPPED`, GREY, C.Muted
	else
		local afford = money >= MINIGUN.cost
		minigunBtn.Text = `UNLOCK {MINIGUN.name}  ·  ◆ {MINIGUN.cost}`
		minigunBtn.BackgroundColor3 = if afford then C.Gold else GREY
		minigunBtn.TextColor3 = if afford then C.Bg else C.Muted
	end
	local hp = (ReplicatedStorage:GetAttribute("ReactorHP") :: number?) or 0
	local max = (ReplicatedStorage:GetAttribute("ReactorMax") :: number?) or 1
	local canRepair = money >= Config.REPAIR_COST and hp < max
	repairBtn.BackgroundColor3 = if canRepair then C.Cyan else GREY
	repairBtn.TextColor3 = if canRepair then C.Bg else C.Muted
	previewKey = ""
	refreshPreview()
end
player.AttributeChanged:Connect(function()
	if gui.Enabled then
		refresh()
	end
end)

-- Open / close ----------------------------------------------------------------------------------------------
local openedAt: Vector3? = nil
local function setOpen(open: boolean)
	gui.Enabled = open
	player:SetAttribute("UIOpen", open)
	if open then
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		openedAt = if hrp then hrp.Position else nil
		hoverAtt = nil
		refresh()
		showTab("ATTACHMENTS")
		panel.Size = UDim2.fromOffset(1000, 600)
		Theme.tween(panel, 0.2, { Size = UDim2.fromOffset(1060, 640) }, Enum.EasingStyle.Back)
	end
end
Remotes:WaitForChild("OpenArmory").OnClientEvent:Connect(function()
	setOpen(true)
end)
closeBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)
Remotes:WaitForChild("Purchased").OnClientEvent:Connect(function()
	Theme.playSound(Config.Sounds.Buy, 0.6)
end)

RunService.RenderStepped:Connect(function()
	if not gui.Enabled then
		return
	end
	-- orbit the preview camera around the weapon
	local t = os.clock() * 0.6
	vpCam.CFrame = CFrame.lookAt(Vector3.new(math.sin(t) * 9, 1.6, math.cos(t) * 9) + Vector3.new(0, 0, -0.6), Vector3.new(0, 0.2, -0.6))
	-- walking away closes it
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if openedAt and hrp and (hrp.Position - openedAt).Magnitude > 14 then
		setOpen(false)
	end
end)
