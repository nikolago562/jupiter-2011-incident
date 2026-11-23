--!strict
-- Client: the TikTok "Jupiter Incident (2011)" format.
--  * crew roster with each player's headshot and a live line ("*Entity approaches*", "*Deceased*", chat...)
--  * narrator caption bar at the bottom
--  * gun controls + ammo
--  * end card: "EVERYONE SADLY DYING TO KEIS:" / "THE TRUE SURVIVOR:"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local WHITE = Color3.fromRGB(235, 235, 235)
local RED = Color3.fromRGB(230, 30, 30)
local GREY = Color3.fromRGB(120, 120, 120)

local gui = Instance.new("ScreenGui")
gui.Name = "Jupiter2011Crew"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 11
gui.Parent = player:WaitForChild("PlayerGui")
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Arcade
	l.TextColor3 = WHITE
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local thumbCache: { [number]: string } = {}
local function headshot(userId: number): string
	if thumbCache[userId] then
		return thumbCache[userId]
	end
	local ok, url = pcall(function()
		return Players:GetUserThumbnailAsync(math.max(userId, 1), Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	end)
	thumbCache[userId] = if ok then url else ""
	return thumbCache[userId]
end

-- Crew roster ---------------------------------------------------------------
local roster = Instance.new("Frame")
roster.BackgroundTransparency = 1
roster.Position = UDim2.fromOffset(24, 88)
roster.Size = UDim2.fromOffset(340, 400)
roster.Visible = false
roster.Parent = gui
text(roster, {
	RichText = true,
	Text = 'JUPITER <font color="#E61E1E">INCIDENT</font> (2011)',
	TextSize = 24,
	Size = UDim2.new(1, 0, 0, 30),
	TextStrokeTransparency = 0.5,
})
local list = Instance.new("Frame")
list.BackgroundTransparency = 1
list.Position = UDim2.fromOffset(0, 36)
list.Size = UDim2.new(1, 0, 1, -36)
list.Parent = roster
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.Name
layout.Parent = list

type Row = { frame: Frame, img: ImageLabel, name: TextLabel, line: TextLabel, action: string, actionUntil: number }
local rows: { [number]: Row } = {}

local function makeRow(member: Player): Row
	local frame = Instance.new("Frame")
	frame.Name = member.DisplayName
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 58)
	frame.Parent = list
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromOffset(58, 58)
	img.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	img.BorderSizePixel = 0
	img.Parent = frame
	task.spawn(function()
		img.Image = headshot(member.UserId)
	end)
	local name = text(frame, { Text = member.DisplayName, TextSize = 18, Position = UDim2.fromOffset(66, 2), Size = UDim2.new(1, -66, 0, 20) })
	local line = text(frame, { Text = "", Font = Enum.Font.Code, TextSize = 16, Position = UDim2.fromOffset(76, 26),
		Size = UDim2.new(1, -76, 0, 28), TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd })
	return { frame = frame, img = img, name = name, line = line, action = "", actionUntil = 0 }
end

local function setAction(userId: number, msg: string, seconds: number?)
	local row = rows[userId]
	if row then
		row.action = msg
		row.actionUntil = os.clock() + (seconds or 3)
	end
end

Remotes:WaitForChild("CrewAction").OnClientEvent:Connect(function(userId: number, msg: string)
	setAction(userId, msg, 2.5)
end)

-- what crew members type in chat shows up in their row, like the videos' dialogue
TextChatService.MessageReceived:Connect(function(message: TextChatMessage)
	local source = message.TextSource
	if source then
		setAction(source.UserId, string.sub(message.Text, 1, 60), 4)
	end
end)

local function keisNear(character: Model?, range: number): boolean
	local folder = workspace:FindFirstChild("Keis")
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not folder or not hrp then
		return false
	end
	for _, model in folder:GetChildren() do
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - hrp.Position).Magnitude < range then
			return true
		end
	end
	return false
end

task.spawn(function()
	while true do
		local now = os.clock()
		local seen: { [number]: boolean } = {}
		for _, member in Players:GetPlayers() do
			local status = member:GetAttribute("CrewStatus")
			if status then
				seen[member.UserId] = true
				local row = rows[member.UserId] or makeRow(member)
				rows[member.UserId] = row
				if status == "dead" then
					row.img.ImageTransparency = 0.65
					row.name.TextColor3 = GREY
					row.line.Text = "*Deceased*"
					row.line.TextColor3 = GREY
				elseif status == "escaped" then
					row.img.ImageTransparency = 0
					row.name.TextColor3 = WHITE
					row.line.Text = "*Escaped*"
					row.line.TextColor3 = Color3.fromRGB(90, 255, 140)
				else
					row.img.ImageTransparency = 0
					row.name.TextColor3 = WHITE
					local near = keisNear(member.Character, 28)
					row.img.ImageColor3 = if near then Color3.fromRGB(255, 90, 90) else Color3.new(1, 1, 1)
					if now < row.actionUntil then
						row.line.Text = row.action
						row.line.TextColor3 = WHITE
					elseif near then
						row.line.Text = "*Key entity approaches*"
						row.line.TextColor3 = RED
					elseif ReplicatedStorage:GetAttribute("PowerOut") then
						row.line.Text = "*Silence*"
						row.line.TextColor3 = GREY
					else
						row.line.Text = ""
					end
				end
			end
		end
		for userId, row in rows do
			if not seen[userId] then
				row.frame:Destroy()
				rows[userId] = nil
			end
		end
		roster.Visible = next(rows) ~= nil
		uiScale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.55, 1)
		task.wait(0.2)
	end
end)

-- Narrator caption bar ---------------------------------------------------------
local narrator = Instance.new("Frame")
narrator.BackgroundTransparency = 1
narrator.AnchorPoint = Vector2.new(0.5, 1)
narrator.Position = UDim2.new(0.5, 0, 1, -24)
narrator.Size = UDim2.new(0.7, 0, 0, 60)
narrator.Visible = false
narrator.Parent = gui
local rule = Instance.new("Frame")
rule.BorderSizePixel = 0
rule.BackgroundColor3 = WHITE
rule.Size = UDim2.new(1, 0, 0, 2)
rule.Parent = narrator
local narration = text(narrator, { Font = Enum.Font.GothamMedium, TextSize = 20, Position = UDim2.fromOffset(0, 10),
	Size = UDim2.new(1, 0, 1, -10), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 0.5 })

local narrateToken = 0
Remotes:WaitForChild("Narrate").OnClientEvent:Connect(function(msg: string)
	narrateToken += 1
	local token = narrateToken
	narrator.Visible = true
	for i = 1, #msg do
		if token ~= narrateToken then
			return
		end
		narration.Text = string.sub(msg, 1, i)
		task.wait(0.02)
	end
	task.wait(5)
	if token == narrateToken then
		narrator.Visible = false
	end
end)

-- Gun ------------------------------------------------------------------------------
local Shoot = Remotes:WaitForChild("Shoot") :: RemoteEvent
local mouse = player:GetMouse()
local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local ammoLabel = text(gui, { Text = "", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -28, 1, -52), Size = UDim2.fromOffset(240, 26), TextColor3 = Color3.fromRGB(255, 220, 120) })

local function hookCharacter(character: Model)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == "KeisGun" and not hooked[child] then
			hooked[child] = true
			child.Activated:Connect(function()
				Shoot:FireServer(mouse.Hit.Position)
			end)
		end
	end)
end
if player.Character then
	hookCharacter(player.Character)
end
player.CharacterAdded:Connect(hookCharacter)

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local tool = character and character:FindFirstChild("KeisGun")
	if tool then
		local ammo = tool:GetAttribute("Ammo") or 0
		ammoLabel.Text = if ammo > 0 then `AMMO {ammo}/{Config.GUN_AMMO}` else "RELOADING!!"
	else
		ammoLabel.Text = ""
	end
end)

-- End card ----------------------------------------------------------------------------
local card = Instance.new("Frame")
card.Size = UDim2.fromScale(1, 1)
card.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
card.BorderSizePixel = 0
card.Visible = false
card.ZIndex = 30
card.Parent = gui
local cardTitle = text(card, { TextXAlignment = Enum.TextXAlignment.Center, TextSize = 40, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.12), Size = UDim2.new(0.9, 0, 0, 50), ZIndex = 31, TextStrokeTransparency = 0 })
local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.AnchorPoint = Vector2.new(0.5, 0)
grid.Position = UDim2.fromScale(0.5, 0.28)
grid.Size = UDim2.fromScale(0.85, 0.6)
grid.ZIndex = 31
grid.Parent = card
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(150, 190)
gridLayout.CellPadding = UDim2.fromOffset(16, 16)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.Parent = grid

Remotes:WaitForChild("RoundResults").OnClientEvent:Connect(function(results: { { userId: number, name: string, status: string } })
	for _, c in grid:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local survivors = {}
	for _, r in results do
		if r.status == "escaped" then
			table.insert(survivors, r)
		end
	end
	local shown = if #survivors > 0 then survivors else results
	if #survivors > 0 then
		cardTitle.Text = if #survivors == 1 then "THE TRUE SURVIVOR:" else "THE TRUE SURVIVORS:"
		cardTitle.TextColor3 = Color3.fromRGB(255, 210, 40)
	else
		cardTitle.Text = "EVERYONE SADLY DYING TO KEIS:"
		cardTitle.TextColor3 = WHITE
	end
	for _, r in shown do
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		cell.ZIndex = 31
		cell.Parent = grid
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromOffset(150, 150)
		img.BackgroundColor3 = Color3.new(0, 0, 0)
		img.ZIndex = 31
		img.ImageColor3 = if r.status == "escaped" then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150)
		img.Parent = cell
		task.spawn(function()
			img.Image = headshot(r.userId)
		end)
		text(cell, { Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Center, TextSize = 16, ZIndex = 31,
			Position = UDim2.fromOffset(0, 154), Size = UDim2.new(1, 0, 0, 34), TextWrapped = true,
			Text = string.upper(r.name) .. "\n" .. (if r.status == "escaped" then "SURVIVED" else "DECEASED") })
	end
	card.Visible = true
	task.wait(Config.RESULTS_TIME - 1)
	card.Visible = false
end)
