--!strict
-- Local ship effects: sliding doors open when anyone (crew or Keis) comes close; console screens flicker.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local OPEN_RANGE = 12
local TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Door = { leaves: { BasePart }, center: Vector3, open: boolean }
local doors: { [string]: Door } = {}

local function addLeaf(p: Instance)
	if not p:IsA("BasePart") then
		return
	end
	local center = p:GetAttribute("DoorCenter") :: Vector3?
	if not center then
		return
	end
	local key = string.format("%.1f|%.1f|%.1f", center.X, center.Y, center.Z)
	local d = doors[key]
	if not d then
		d = { leaves = {}, center = center, open = false }
		doors[key] = d
	end
	table.insert(d.leaves, p)
end
for _, p in CollectionService:GetTagged("DoorLeaf") do
	addLeaf(p)
end
CollectionService:GetInstanceAddedSignal("DoorLeaf"):Connect(addLeaf)

local function positions(): { Vector3 }
	local list = {}
	for _, pl in Players:GetPlayers() do
		local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			table.insert(list, hrp.Position)
		end
	end
	local keis = workspace:FindFirstChild("Keis")
	if keis then
		for _, m in keis:GetChildren() do
			local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				table.insert(list, root.Position)
			end
		end
	end
	return list
end

task.spawn(function()
	while true do
		local pos = positions()
		for _, d in doors do
			local near = false
			for _, p in pos do
				if (p - d.center).Magnitude < OPEN_RANGE then
					near = true
					break
				end
			end
			if near ~= d.open then
				d.open = near
				for _, leaf in d.leaves do
					if leaf.Parent then
						local closed = leaf:GetAttribute("ClosedCF") :: CFrame
						local offset = leaf:GetAttribute("OpenOffset") :: Vector3
						TweenService:Create(leaf, TWEEN, { CFrame = if near then closed + offset else closed }):Play()
					end
				end
			end
		end
		task.wait(0.1)
	end
end)

-- console screens: occasional flicker
task.spawn(function()
	while true do
		local screens = CollectionService:GetTagged("ConsoleScreen")
		if #screens > 0 then
			local s = screens[math.random(1, #screens)]
			local gui = s:FindFirstChildOfClass("SurfaceGui")
			if gui then
				gui.Enabled = false
				task.wait(0.06)
				gui.Enabled = true
			end
		end
		task.wait(math.random() * 0.8 + 0.2)
	end
end)
