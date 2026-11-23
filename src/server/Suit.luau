--!strict
-- Dresses every crew member in a white spacesuit: suit colors, glass helmet, life-support pack, mission patch.
-- Turn off with Config.SPACESUITS = false.

local Suit = {}

local SUIT_WHITE = Color3.fromRGB(232, 232, 228)
local SUIT_GREY = Color3.fromRGB(150, 152, 156)
local PATCH = Color3.fromRGB(255, 138, 61)

local function attach(character: Model, anchor: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3,
	material: Enum.Material, shape: Enum.PartType?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = transparency == nil
	p.CFrame = anchor.CFrame * offset
	p.Parent = character
	local w = Instance.new("WeldConstraint")
	w.Part0 = anchor
	w.Part1 = p
	w.Parent = p
	return p
end

function Suit.apply(character: Model)
	if character:FindFirstChild("SuitHelmet") then
		return
	end
	-- strip clothing + hats/hair (they would poke through the helmet)
	for _, d in character:GetChildren() do
		if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
	-- suit colors on every body part except the head
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.TorsoColor3 = SUIT_WHITE
		bodyColors.LeftArmColor3 = SUIT_WHITE
		bodyColors.RightArmColor3 = SUIT_WHITE
		bodyColors.LeftLegColor3 = SUIT_WHITE
		bodyColors.RightLegColor3 = SUIT_WHITE
	end
	for _, d in character:GetChildren() do
		if d:IsA("BasePart") and d.Name ~= "Head" and d.Name ~= "HumanoidRootPart" then
			d.Color = if string.find(d.Name, "Hand") or string.find(d.Name, "Foot") then SUIT_GREY else SUIT_WHITE
			d.Material = Enum.Material.Fabric
		end
	end

	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if head then
		local d = math.max(head.Size.Y, head.Size.Z, head.Size.X * 0.6) * 1.75 -- works for R6 (2x1x1 head) and R15
		attach(character, head, "SuitHelmet", Vector3.one * d, CFrame.new(0, 0.1, 0), Color3.fromRGB(190, 215, 240),
			Enum.Material.Glass, Enum.PartType.Ball, 0.72)
		attach(character, head, "SuitCollar", Vector3.new(0.35, d * 0.85, d * 0.85), CFrame.new(0, -d * 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)),
			SUIT_GREY, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	if torso then
		local back = torso.Size.Z / 2
		attach(character, torso, "SuitPack", Vector3.new(torso.Size.X * 0.8, torso.Size.Y * 1.05, 0.7), CFrame.new(0, 0.1, back + 0.35),
			SUIT_WHITE, Enum.Material.SmoothPlastic)
		attach(character, torso, "SuitPackLight", Vector3.new(0.3, 0.3, 0.1), CFrame.new(torso.Size.X * 0.25, torso.Size.Y * 0.35, back + 0.72),
			Color3.fromRGB(90, 220, 255), Enum.Material.Neon)
		attach(character, torso, "SuitPatch", Vector3.new(0.45, 0.35, 0.05), CFrame.new(-torso.Size.X * 0.25, torso.Size.Y * 0.2, -torso.Size.Z / 2 - 0.03),
			PATCH, Enum.Material.SmoothPlastic)
	end
end

return Suit
