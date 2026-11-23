--!strict
-- Permanent progress: level, XP, best wave, total Keis destroyed. Saved with DataStores.
-- In Studio, enable Game Settings → Security → "Enable Studio Access to API Services" to test saving.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerData = {}

export type Data = { Level: number, XP: number, BestWave: number, TotalKeis: number, Runs: number }

local store: DataStore? = nil
local bestWaveStore: OrderedDataStore? = nil
do
	local ok, err = pcall(function()
		store = DataStoreService:GetDataStore(Config.DATASTORE_NAME)
		bestWaveStore = DataStoreService:GetOrderedDataStore(Config.DATASTORE_NAME .. "_BestWave")
	end)
	if not ok then
		warn("[PlayerData] DataStores unavailable, progress won't save:", err)
	end
end

local cache: { [Player]: Data } = {}

local function defaults(): Data
	return { Level = 1, XP = 0, BestWave = 0, TotalKeis = 0, Runs = 0 }
end

local function publish(player: Player, data: Data)
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("XPNeeded", Config.xpForLevel(data.Level))
	player:SetAttribute("BestWave", data.BestWave)
	player:SetAttribute("Title", Config.titleFor(data.Level))
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats:FindFirstChild("Level") :: IntValue).Value = data.Level;
		(stats:FindFirstChild("Best Wave") :: IntValue).Value = data.BestWave
	end
end

function PlayerData.load(player: Player): Data
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, name in { "Level", "Best Wave" } do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = stats
	end
	stats.Parent = player

	local data = defaults()
	if store then
		local ok, saved = pcall(function()
			return (store :: DataStore):GetAsync("u" .. player.UserId)
		end)
		if ok and type(saved) == "table" then
			for k, v in saved do
				if (data :: any)[k] ~= nil and type(v) == "number" then
					(data :: any)[k] = v
				end
			end
		end
	end
	cache[player] = data
	publish(player, data)
	return data
end

function PlayerData.get(player: Player): Data?
	return cache[player]
end

-- returns the number of levels gained
function PlayerData.addXP(player: Player, amount: number): number
	local data = cache[player]
	if not data then
		return 0
	end
	data.XP += math.floor(amount)
	local gained = 0
	while data.XP >= Config.xpForLevel(data.Level) do
		data.XP -= Config.xpForLevel(data.Level)
		data.Level += 1
		gained += 1
	end
	publish(player, data)
	return gained
end

function PlayerData.addKill(player: Player)
	local data = cache[player]
	if data then
		data.TotalKeis += 1
	end
end

function PlayerData.recordWave(player: Player, wave: number)
	local data = cache[player]
	if data and wave > data.BestWave then
		data.BestWave = wave
		publish(player, data)
	end
end

function PlayerData.addRun(player: Player)
	local data = cache[player]
	if data then
		data.Runs += 1
	end
end

function PlayerData.save(player: Player)
	local data = cache[player]
	if not data or not store then
		return
	end
	pcall(function()
		(store :: DataStore):SetAsync("u" .. player.UserId, data)
	end)
	if bestWaveStore and data.BestWave > 0 then
		pcall(function()
			(bestWaveStore :: OrderedDataStore):SetAsync(tostring(player.UserId), data.BestWave)
		end)
	end
end

function PlayerData.release(player: Player)
	PlayerData.save(player)
	cache[player] = nil
end

local nameCache: { [number]: string } = {}
function PlayerData.fetchTop(count: number): { { name: string, wave: number } }
	local results = {}
	if not bestWaveStore then
		return results
	end
	local ok, pages = pcall(function()
		return (bestWaveStore :: OrderedDataStore):GetSortedAsync(false, count)
	end)
	if not ok then
		return results
	end
	for _, entry in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(entry.key) or 0
		local name = nameCache[userId]
		if not name then
			local okName, n = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			name = if okName then n else "???"
			nameCache[userId] = name
		end
		table.insert(results, { name = name :: string, wave = entry.value })
	end
	return results
end

return PlayerData
