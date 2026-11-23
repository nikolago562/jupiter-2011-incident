--!strict
-- Shared UI style: dark glass panels, Jupiter-orange accents, sci-fi headings.

local TweenService = game:GetService("TweenService")

local Theme = {}

Theme.Colors = {
	Bg = Color3.fromRGB(12, 10, 16),
	Panel = Color3.fromRGB(20, 16, 26),
	Accent = Color3.fromRGB(255, 138, 61), -- Jupiter orange
	Cream = Color3.fromRGB(242, 214, 170), -- Jupiter cloud band
	Text = Color3.fromRGB(245, 236, 222),
	Muted = Color3.fromRGB(150, 138, 128),
	Danger = Color3.fromRGB(240, 70, 60),
	Good = Color3.fromRGB(110, 230, 150),
	Gold = Color3.fromRGB(255, 205, 64),
	Cyan = Color3.fromRGB(90, 220, 255),
}

local function font(name: string, fallback: Enum.Font): Enum.Font
	local ok, f = pcall(function()
		return (Enum.Font :: any)[name]
	end)
	return if ok and f then f else fallback
end

Theme.Fonts = {
	Title = font("Michroma", Enum.Font.GothamBlack),
	Heavy = Enum.Font.GothamBlack,
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Meme = Enum.Font.Arcade,
	Mono = Enum.Font.Code,
}

-- Theme.make("Frame", {props}, {children})
function Theme.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Theme.corner(radius: number?): UICorner
	return Theme.make("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function Theme.stroke(color: Color3?, transparency: number?, thickness: number?): UIStroke
	return Theme.make("UIStroke", {
		Color = color or Theme.Colors.Accent,
		Transparency = transparency or 0.55,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Theme.panel(props: { [string]: any }): Frame
	local p = Theme.make("Frame", {
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	}, { Theme.corner(10), Theme.stroke() })
	Theme.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 160, 175)),
		Parent = p,
	})
	for k, v in props do
		if k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	if props.Parent then
		p.Parent = props.Parent
	end
	return p
end

function Theme.text(props: { [string]: any }): TextLabel
	local l = Theme.make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local parent = props.Parent
	for k, v in props do
		if k ~= "Parent" then
			(l :: any)[k] = v
		end
	end
	if parent then
		l.Parent = parent
	end
	return l
end

export type Bar = { frame: Frame, fill: Frame, label: TextLabel, set: (self: Bar, fraction: number, text: string?) -> () }

function Theme.bar(props: { [string]: any }, fillColor: Color3): Bar
	local frame = Theme.make("Frame", {
		BackgroundColor3 = Color3.fromRGB(30, 24, 34),
		BorderSizePixel = 0,
	}, { Theme.corner(6), Theme.stroke(Color3.new(0, 0, 0), 0.4, 1) })
	local fill = Theme.make("Frame", {
		BackgroundColor3 = fillColor,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	}, { Theme.corner(6) })
	Theme.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
		Parent = fill,
	})
	local label = Theme.text({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Bold,
		TextSize = 13,
		TextStrokeTransparency = 0.5,
		ZIndex = 3,
		Parent = frame,
	})
	for k, v in props do
		if k ~= "Parent" then
			(frame :: any)[k] = v
		end
	end
	if props.Parent then
		frame.Parent = props.Parent
	end
	local bar = { frame = frame, fill = fill, label = label } :: any
	function bar:set(fraction: number, text: string?)
		TweenService:Create(self.fill, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) }):Play()
		if text then
			self.label.Text = text
		end
	end
	return bar
end

function Theme.tween(obj: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- plays a configured sound id once (if set)
function Theme.playSound(id: string, volume: number?, speed: number?)
	if id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = speed or 1
	s.Parent = game:GetService("SoundService")
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	task.delay(10, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

return Theme
