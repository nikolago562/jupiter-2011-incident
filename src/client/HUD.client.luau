--!strict
-- Main HUD: wave + reactor, crew roster (meme format), player card, banners, narrator, toasts, downed + game over screens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C, F = Theme.Colors, Theme.Fonts
local make, text = Theme.make, Theme.text

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local gui = make("ScreenGui", { Name = "HUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
local scale = make("UIScale", { Parent = gui })
RunService.RenderStepped:Connect(function()
	scale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.6, 1.15)
end)

local thumbs: { [number]: string } = {}
local function headshot(userId: number): string
	if thumbs[userId] == nil then
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(math.max(userId, 1), Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		thumbs[userId] = if ok then url else ""
	end
	return thumbs[userId]
end

-- Wave panel (top center) -------------------------------------------------------------------------
local wavePanel = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(340, 92), Parent = gui })
local waveTitle = text({ Font = F.Title, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 8),
	Size = UDim2.new(1, 0, 0, 32), Text = "USS KEPLER", Parent = wavePanel })
local waveSub = text({ Font = F.Bold, TextSize = 14, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 18), Text = "", Parent = wavePanel })
local reactorBar = Theme.bar({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.new(1, -28, 0, 16), Parent = wavePanel }, C.Cyan)

local function formatTime(t: number): string
	return string.format("%d:%02d", t // 60, t % 60)
end
local function refreshWave()
	local phase = ReplicatedStorage:GetAttribute("Phase")
	local t = ReplicatedStorage:GetAttribute("TimeLeft") or 0
	local w = ReplicatedStorage:GetAttribute("Wave") or 0
	if phase == "Lobby" then
		waveTitle.Text = "USS KEPLER"
		waveSub.Text = if t > 0 then `JUPITER ORBIT IN {t}` else "WAITING FOR CREW"
	elseif phase == "Wave" then
		local boss = w % Config.Waves.BossEvery == 0
		waveTitle.Text = string.format(if boss then "BOSS %02d" else "WAVE %02d", w)
		waveSub.Text = `KEIS LEFT  {ReplicatedStorage:GetAttribute("KeisLeft") or 0}`
	elseif phase == "Break" then
		waveTitle.Text = string.format("WAVE %02d", w + 1)
		waveSub.Text = `INCOMING IN {formatTime(t)}  ·  UPGRADE [Q]`
	elseif phase == "GameOver" then
		waveTitle.Text = "SIGNAL LOST"
		waveSub.Text = `REACHED WAVE {w}`
	end
	waveTitle.TextColor3 = if phase == "Wave" and w % Config.Waves.BossEvery == 0 then C.Danger else C.Text
	local hp = ReplicatedStorage:GetAttribute("ReactorHP") or 0
	local max = ReplicatedStorage:GetAttribute("ReactorMax") or 1
	reactorBar:set(hp / max, `REACTOR  {math.floor(hp)} / {max}`)
	reactorBar.fill.BackgroundColor3 = if hp / max < 0.3 then C.Danger else C.Cyan
end
for _, a in { "Phase", "TimeLeft", "Wave", "KeisLeft", "ReactorHP", "ReactorMax" } do
	ReplicatedStorage:GetAttributeChangedSignal(a):Connect(refreshWave)
end
refreshWave()

-- Crew roster (top left) — the TikTok "JUPITER INCIDENT (2011)" format --------------------------------
local roster = Theme.panel({ Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(300, 60), AutomaticSize = Enum.AutomaticSize.Y, Parent = gui })
make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = roster })
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = roster })
text({ RichText = true, Font = F.Meme, TextSize = 22, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0,
	Text = 'JUPITER <font color="#F0463C">INCIDENT</font> (2011)', Parent = roster })

type Row = { frame: Frame, img: ImageLabel, name: TextLabel, line: TextLabel, action: string, until_: number }
local rows: { [number]: Row } = {}

local function makeRow(member: Player): Row
	local frame = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1, Parent = roster })
	local img = make("ImageLabel", { Size = UDim2.fromOffset(44, 44), BackgroundColor3 = C.Bg, Parent = frame }, { Theme.corner(8), Theme.stroke(C.Accent, 0.6, 1) })
	task.spawn(function()
		img.Image = headshot(member.UserId)
	end)
	local name = text({ Font = F.Bold, TextSize = 15, Position = UDim2.fromOffset(54, 2), Size = UDim2.new(1, -54, 0, 18),
		Text = member.DisplayName, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
	local line = text({ Font = F.Meme, TextSize = 14, Position = UDim2.fromOffset(54, 22), Size = UDim2.new(1, -54, 0, 18),
		Text = "", TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
	return { frame = frame, img = img, name = name, line = line, action = "", until_ = 0 }
end

local function setAction(userId: number, msg: string, seconds: number)
	local row = rows[userId]
	if row then
		row.action = msg
		row.until_ = os.clock() + seconds
	end
end
Remotes:WaitForChild("CrewAction").OnClientEvent:Connect(function(userId: number, msg: string)
	setAction(userId, msg, 2.5)
end)
TextChatService.MessageReceived:Connect(function(message: TextChatMessage)
	if message.TextSource then
		setAction(message.TextSource.UserId, string.sub(message.Text, 1, 50), 4)
	end
end)

local function keisNear(character: Model?, range: number): boolean
	local folder = workspace:FindFirstChild("Keis")
	local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not folder or not hrp then
		return false
	end
	for _, m in folder:GetChildren() do
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - hrp.Position).Magnitude < range then
			return true
		end
	end
	return false
end

task.spawn(function()
	while true do
		local now = os.clock()
		local seen = {}
		for _, member in Players:GetPlayers() do
			seen[member.UserId] = true
			local row = rows[member.UserId] or makeRow(member)
			rows[member.UserId] = row
			local status = member:GetAttribute("CrewStatus")
			row.img.ImageTransparency = 0
			row.img.ImageColor3 = Color3.new(1, 1, 1)
			row.name.TextColor3 = C.Text
			if status == "dead" then
				row.img.ImageTransparency = 0.6
				row.name.TextColor3 = C.Muted
				row.line.Text, row.line.TextColor3 = "*Deceased*", C.Muted
			elseif status == "downed" then
				row.img.ImageColor3 = Color3.fromRGB(255, 110, 100)
				row.line.Text, row.line.TextColor3 = "*Down · needs a revive*", C.Danger
			elseif now < row.until_ then
				row.line.Text, row.line.TextColor3 = row.action, C.Text
			elseif keisNear(member.Character, 25) then
				row.img.ImageColor3 = Color3.fromRGB(255, 150, 140)
				row.line.Text, row.line.TextColor3 = "*Key entity approaches*", C.Danger
			elseif ReplicatedStorage:GetAttribute("PowerOut") then
				row.line.Text, row.line.TextColor3 = "*Silence*", C.Muted
			else
				row.line.Text, row.line.TextColor3 = `LV {member:GetAttribute("Level") or 1} · {member:GetAttribute("Title") or "CADET"}`, C.Accent
			end
		end
		for id, row in rows do
			if not seen[id] then
				row.frame:Destroy()
				rows[id] = nil
			end
		end
		task.wait(0.2)
	end
end)

-- Player card (bottom left) ------------------------------------------------------------------------------
local card = Theme.panel({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.fromOffset(300, 96), Parent = gui })
local levelBadge = make("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = C.Accent, Parent = card }, { Theme.corner(23) })
local levelText = text({ Font = F.Heavy, TextSize = 20, TextColor3 = C.Bg, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = levelBadge })
local titleText = text({ Font = F.Title, TextSize = 13, TextColor3 = C.Accent, Position = UDim2.fromOffset(68, 12), Size = UDim2.new(1, -80, 0, 16), Parent = card })
local creditsText = text({ Font = F.Heavy, TextSize = 20, TextColor3 = C.Gold, Position = UDim2.fromOffset(68, 32), Size = UDim2.new(1, -80, 0, 24), Parent = card })
local healthBar = Theme.bar({ Position = UDim2.fromOffset(12, 66), Size = UDim2.new(1, -24, 0, 18), Parent = card }, C.Good)

local function refreshCard()
	local lvl = player:GetAttribute("Level") or 1
	levelText.Text = tostring(lvl)
	titleText.Text = player:GetAttribute("Title") or "CADET"
	creditsText.Text = `◆ {player:GetAttribute("Credits") or 0}`
end
for _, a in { "Level", "Title", "Credits" } do
	player:GetAttributeChangedSignal(a):Connect(refreshCard)
end
refreshCard()

-- XP bar (bottom center)
local xpBar = Theme.bar({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(420, 12), Parent = gui }, C.Accent)
local function refreshXP()
	local xp = player:GetAttribute("XP") or 0
	local need = player:GetAttribute("XPNeeded") or 100
	xpBar:set(xp / need, `XP {xp} / {need}`)
end
player:GetAttributeChangedSignal("XP"):Connect(refreshXP)
player:GetAttributeChangedSignal("XPNeeded"):Connect(refreshXP)
refreshXP()

RunService.Heartbeat:Connect(function()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local frac = humanoid.Health / math.max(humanoid.MaxHealth, 1)
		healthBar.fill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
		healthBar.label.Text = `{math.ceil(humanoid.Health)} / {math.floor(humanoid.MaxHealth)}`
		healthBar.fill.BackgroundColor3 = if frac < 0.3 then C.Danger elseif frac < 0.6 then C.Gold else C.Good
	end
end)

-- Center banner -------------------------------------------------------------------------------------------
local banner = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(700, 120),
	BackgroundTransparency = 1, Visible = false, Parent = gui })
local bannerTitle = text({ Font = F.Title, TextSize = 56, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 70),
	TextStrokeTransparency = 0.2, Parent = banner })
local bannerLine = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.fromOffset(0, 3),
	BorderSizePixel = 0, BackgroundColor3 = C.Accent, Parent = banner })
local bannerSub = text({ Font = F.Meme, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 84),
	Size = UDim2.new(1, 0, 0, 28), TextColor3 = C.Cream, TextStrokeTransparency = 0.4, Parent = banner })
local STYLE = { wave = C.Accent, boss = C.Danger, clear = C.Good, outage = C.Muted, gold = C.Gold }
local bannerToken = 0
Remotes:WaitForChild("Announce").OnClientEvent:Connect(function(title: string, sub: string, style: string)
	bannerToken += 1
	local token = bannerToken
	local color = STYLE[style] or C.Accent
	bannerTitle.Text = title
	bannerTitle.TextColor3 = if style == "boss" then C.Danger else C.Text
	bannerSub.Text = sub
	bannerLine.BackgroundColor3 = color
	banner.Visible = true
	bannerTitle.TextTransparency = 1
	bannerSub.TextTransparency = 1
	banner.Position = UDim2.fromScale(0.5, 0.29)
	bannerLine.Size = UDim2.fromOffset(0, 3)
	Theme.tween(banner, 0.35, { Position = UDim2.fromScale(0.5, 0.32) }, Enum.EasingStyle.Back)
	Theme.tween(bannerTitle, 0.25, { TextTransparency = 0 })
	Theme.tween(bannerLine, 0.5, { Size = UDim2.fromOffset(420, 3) })
	task.delay(0.15, function()
		Theme.tween(bannerSub, 0.3, { TextTransparency = 0 })
	end)
	Theme.playSound(Config.Sounds.WaveStart, 0.7)
	task.delay(3.2, function()
		if token == bannerToken then
			Theme.tween(bannerTitle, 0.4, { TextTransparency = 1 })
			Theme.tween(bannerSub, 0.4, { TextTransparency = 1 })
			Theme.tween(bannerLine, 0.4, { Size = UDim2.fromOffset(0, 3) })
			task.wait(0.45)
			if token == bannerToken then
				banner.Visible = false
			end
		end
	end)
end)

-- Narrator bar (bottom center) ---------------------------------------------------------------------------------
local narrator = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -34), Size = UDim2.fromOffset(620, 50),
	BackgroundTransparency = 1, Visible = false, Parent = gui })
make("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.Text, BorderSizePixel = 0, Parent = narrator })
local narration = text({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 1, -8), TextSize = 18, TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 0.5, Parent = narrator })
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
		task.wait(0.018)
	end
	task.wait(4.5)
	if token == narrateToken then
		narrator.Visible = false
	end
end)

-- Toasts (right side) ---------------------------------------------------------------------------------------------
local toasts = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 120), Size = UDim2.fromOffset(320, 300),
	BackgroundTransparency = 1, Parent = gui })
make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = toasts })
local TOAST = { red = C.Danger, green = C.Good, gold = C.Gold, cyan = C.Cyan, white = C.Text, yellow = C.Gold }
Remotes:WaitForChild("Notify").OnClientEvent:Connect(function(msg: string, color: string?)
	local col = TOAST[color or "white"] or C.Text
	local t = Theme.panel({ Size = UDim2.fromOffset(300, 34), Parent = toasts })
	make("Frame", { Size = UDim2.new(0, 4, 1, -12), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = col, BorderSizePixel = 0, Parent = t }, { Theme.corner(2) })
	text({ Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -24, 1, 0), TextSize = 14, Font = F.Bold, Text = msg,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = t })
	local kids = toasts:GetChildren()
	if #kids > 5 then
		for _, k in kids do
			if k:IsA("Frame") then
				k:Destroy()
				break
			end
		end
	end
	task.delay(4, function()
		if t.Parent then
			Theme.tween(t, 0.3, { BackgroundTransparency = 1 })
			task.wait(0.3)
			t:Destroy()
		end
	end)
end)

-- Level up -------------------------------------------------------------------------------------------------------------
Remotes:WaitForChild("LevelUp").OnClientEvent:Connect(function(level: number, title: string)
	local f = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(0, 70), Parent = gui })
	f.ClipsDescendants = true
	text({ Font = F.Title, TextSize = 26, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 4), Text = `LEVEL {level}`, Parent = f })
	text({ Font = F.Bold, TextSize = 14, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 42), Text = title .. "  ·  +1% DAMAGE", Parent = f })
	Theme.tween(f, 0.35, { Size = UDim2.fromOffset(340, 70) }, Enum.EasingStyle.Back)
	Theme.playSound(Config.Sounds.LevelUp, 0.8)
	task.delay(2.6, function()
		Theme.tween(f, 0.25, { Size = UDim2.fromOffset(0, 70) })
		task.wait(0.3)
		f:Destroy()
	end)
end)

-- Hurt flash + downed screen ------------------------------------------------------------------------------------------
local hurt = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Danger, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Parent = gui })
Remotes:WaitForChild("PlayerHurt").OnClientEvent:Connect(function(_damage: number)
	hurt.BackgroundTransparency = 0.75
	Theme.tween(hurt, 0.4, { BackgroundTransparency = 1 })
end)

local downed = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(60, 0, 0), BackgroundTransparency = 0.55,
	BorderSizePixel = 0, Visible = false, ZIndex = 20, Parent = gui })
text({ Font = F.Meme, TextSize = 64, TextColor3 = C.Danger, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(800, 70), Text = "*KEY ENTITY APPROACHES*", ZIndex = 21, Parent = downed })
local downedSub = text({ Font = F.Title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(800, 30), ZIndex = 21, Parent = downed })
RunService.Heartbeat:Connect(function()
	local isDown = player:GetAttribute("Downed") == true
	downed.Visible = isDown
	if isDown then
		local untilT = player:GetAttribute("DownedUntil") or 0
		local left = math.max(0, math.ceil(untilT - workspace:GetServerTimeNow()))
		downedSub.Text = `YOU'RE DOWN · A CREWMATE CAN REVIVE YOU · {left}s`
	end
end)

-- hide the revive prompt on your own body
local function hideOwnPrompt(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		hrp.ChildAdded:Connect(function(c)
			if c:IsA("ProximityPrompt") then
				c.Enabled = false
			end
		end)
	end
end
if player.Character then
	task.spawn(hideOwnPrompt, player.Character)
end
player.CharacterAdded:Connect(hideOwnPrompt)

-- Game over ------------------------------------------------------------------------------------------------------------
local over = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 4, 10), BackgroundTransparency = 0.1,
	BorderSizePixel = 0, Visible = false, ZIndex = 30, Parent = gui })
local overTitle = text({ Font = F.Meme, TextSize = 30, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromScale(0, 0.1), Size = UDim2.new(1, 0, 0, 34), ZIndex = 31, Text = "THE INCIDENT WAS NEVER REPORTED", Parent = over })
local overWave = text({ Font = F.Title, TextSize = 64, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromScale(0, 0.16), Size = UDim2.new(1, 0, 0, 76), ZIndex = 31, Parent = over })
local overReason = text({ Font = F.Bold, TextSize = 18, TextColor3 = C.Danger, TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromScale(0, 0.27), Size = UDim2.new(1, 0, 0, 24), ZIndex = 31, Parent = over })
local overGrid = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.9, 0.5),
	BackgroundTransparency = 1, ZIndex = 31, Parent = over })
make("UIGridLayout", { CellSize = UDim2.fromOffset(170, 230), CellPadding = UDim2.fromOffset(16, 16),
	HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = overGrid })

Remotes:WaitForChild("GameOver").OnClientEvent:Connect(function(summary: any)
	for _, c in overGrid:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	overWave.Text = `WAVE {summary.wave}`
	overReason.Text = summary.reason
	for _, m in summary.crew do
		local isMvp = m.userId == summary.mvp and m.kills > 0
		local cell = Theme.panel({ ZIndex = 31, Parent = overGrid })
		local stroke = cell:FindFirstChildOfClass("UIStroke")
		if stroke and isMvp then
			stroke.Color = C.Gold
			stroke.Transparency = 0
			stroke.Thickness = 2.5
		end
		local img = make("ImageLabel", { Position = UDim2.fromOffset(25, 14), Size = UDim2.fromOffset(120, 120), BackgroundColor3 = C.Bg,
			ImageColor3 = if isMvp then Color3.new(1, 1, 1) else Color3.fromRGB(170, 170, 170), ZIndex = 32, Parent = cell }, { Theme.corner(10) })
		task.spawn(function()
			img.Image = headshot(m.userId)
		end)
		text({ Font = F.Bold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 0, 18),
			Text = string.upper(m.name), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 32, Parent = cell })
		text({ Font = F.Mono, TextSize = 14, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 162),
			Size = UDim2.new(1, 0, 0, 36), Text = `{m.kills} KEIS\n{m.damage} DMG`, ZIndex = 32, Parent = cell })
		text({ Font = F.Meme, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 202), Size = UDim2.new(1, 0, 0, 18),
			TextColor3 = if isMvp then C.Gold else C.Muted, Text = if isMvp then "THE TRUE SURVIVOR" else "*Deceased*", ZIndex = 32, Parent = cell })
	end
	over.Visible = true
	over.BackgroundTransparency = 1
	Theme.tween(over, 0.6, { BackgroundTransparency = 0.1 })
	task.wait(Config.GAMEOVER_TIME - 0.5)
	over.Visible = false
end)
