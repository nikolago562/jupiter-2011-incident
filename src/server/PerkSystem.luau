--!strict
-- Server side of the perk cards: offers, picks, rerolls (cost 1 key), stacks per player for the current run.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Perks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Perks"))

local PerkSystem = {}

type Offer = { id: number, cards: { string }, rarity: string?, wave: number }
local stacks: { [Player]: { [string]: number } } = {}
local queues: { [Player]: { Offer } } = {}
local seq = 0
local rng = Random.new()
local remotes: Folder

PerkSystem.hooks = {
	onChanged = function(_player: Player) end, -- refresh health/speed/ammo after a pick
	spendKey = function(_player: Player): boolean
		return false
	end,
	onPicked = function(_player: Player, _perkId: string) end,
}

local function publish(player: Player)
	player:SetAttribute("Perks", Perks.encode(stacks[player] or {}))
end

local function send(player: Player)
	local q = queues[player]
	local offer = q and q[1]
	if offer then
		(remotes:FindFirstChild("PerkOffer") :: RemoteEvent):FireClient(player, offer.id, offer.cards, offer.rarity)
	end
end

function PerkSystem.get(player: Player, id: string): number
	local s = stacks[player]
	return if s then s[id] or 0 else 0
end

function PerkSystem.reset(player: Player)
	stacks[player] = {}
	queues[player] = {}
	publish(player)
	do
		local target = remotes:FindFirstChild("PerkOffer") :: RemoteEvent
		target:FireClient(player, 0, {}, nil) -- closes any open picker
	end
end

function PerkSystem.remove(player: Player)
	stacks[player] = nil
	queues[player] = nil
end

-- queue a pick-1-of-3 for this player. onlyRarity forces e.g. "Legendary" (boss reward).
function PerkSystem.offer(player: Player, wave: number, onlyRarity: string?)
	stacks[player] = stacks[player] or {}
	queues[player] = queues[player] or {}
	local luck = math.clamp(wave / 20, 0, 1)
	local cards = Perks.roll(rng, stacks[player], 3, luck, onlyRarity)
	if #cards == 0 then
		cards = Perks.roll(rng, stacks[player], 3, luck, nil)
	end
	if #cards == 0 then
		return -- everything maxed
	end
	seq += 1
	table.insert(queues[player], { id = seq, cards = cards, rarity = onlyRarity, wave = wave })
	if #queues[player] == 1 then
		send(player)
	end
end

local function pick(player: Player, offerId: any, index: any)
	local q = queues[player]
	local offer = q and q[1]
	if not offer or offer.id ~= offerId or type(index) ~= "number" then
		return
	end
	local id = offer.cards[math.clamp(math.floor(index), 1, #offer.cards)]
	table.remove(q, 1)
	stacks[player][id] = (stacks[player][id] or 0) + 1
	publish(player)
	PerkSystem.hooks.onChanged(player)
	PerkSystem.hooks.onPicked(player, id)
	send(player)
end

-- any offers still open when the next wave starts get a random pick
function PerkSystem.resolvePending(player: Player)
	local q = queues[player]
	while q and q[1] do
		pick(player, q[1].id, rng:NextInteger(1, #q[1].cards))
	end
end

function PerkSystem.init(remoteFolder: Folder)
	remotes = remoteFolder
	do
		local target = remotes:FindFirstChild("PickPerk") :: RemoteEvent
		target.OnServerEvent:Connect(pick)
	end
	do
		local target = remotes:FindFirstChild("RerollPerk") :: RemoteEvent
		target.OnServerEvent:Connect(function(player, offerId)
		local q = queues[player]
		local offer = q and q[1]
		if not offer or offer.id ~= offerId then
			return
		end
		if not PerkSystem.hooks.spendKey(player) then
			return
		end
		local cards = Perks.roll(rng, stacks[player], 3, math.clamp(offer.wave / 20, 0, 1), offer.rarity)
		if #cards > 0 then
			offer.cards = cards
		end
		send(player)
	end)
	end
end

return PerkSystem
