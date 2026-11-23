--!strict
-- Perk cards: after every wave each player picks 1 of 3. They stack and combine into a build for the run.

local Perks = {}

Perks.Rarity = {
	Common = { weight = 64, color = Color3.fromRGB(215, 215, 222), label = "COMMON" },
	Rare = { weight = 28, color = Color3.fromRGB(90, 200, 255), label = "RARE" },
	Legendary = { weight = 8, color = Color3.fromRGB(255, 200, 60), label = "LEGENDARY" },
}

export type Perk = { id: string, name: string, desc: string, rarity: string, max: number, icon: string }

Perks.List = {
	{ id = "HollowPoints", name = "HOLLOW POINTS", desc = "+15% damage", rarity = "Common", max = 5, icon = "✦" },
	{ id = "QuickHands", name = "QUICK HANDS", desc = "Reload 30% faster", rarity = "Common", max = 3, icon = "↻" },
	{ id = "SuitPadding", name = "SUIT PADDING", desc = "+20 max health", rarity = "Common", max = 5, icon = "✚" },
	{ id = "Scavenger", name = "SCAVENGER", desc = "+25% credits from kills", rarity = "Common", max = 4, icon = "◆" },
	{ id = "LightStep", name = "LIGHT STEP", desc = "+8% move speed", rarity = "Common", max = 3, icon = "➤" },
	{ id = "Vampire", name = "VAMPIRE SUIT", desc = "Heal 4 HP for every kill", rarity = "Rare", max = 3, icon = "♥" },
	{ id = "Ricochet", name = "RICOCHET", desc = "Killing shots bounce to the next Keis", rarity = "Rare", max = 2, icon = "⤳" },
	{ id = "ExtendedMag", name = "EXTENDED MAG", desc = "+50% magazine size", rarity = "Rare", max = 2, icon = "▤" },
	{ id = "CritLens", name = "CRIT LENS", desc = "+10% crit chance on any hit, crits +75% damage", rarity = "Rare", max = 3, icon = "◎" },
	{ id = "KeyMagnet", name = "KEY MAGNET", desc = "Pull keys from far away, +20% key drops", rarity = "Rare", max = 2, icon = "⊕" },
	{ id = "Adrenaline", name = "ADRENALINE", desc = "Each kill: +30% fire rate for 2 seconds", rarity = "Rare", max = 2, icon = "⚡" },
	{ id = "ChainLightning", name = "CHAIN LIGHTNING", desc = "Every 5th hit zaps nearby Keis", rarity = "Legendary", max = 2, icon = "ϟ" },
	{ id = "SecondWind", name = "SECOND WIND", desc = "Once per wave, get back up instantly when downed", rarity = "Legendary", max = 1, icon = "↑" },
	{ id = "ExplosiveCrits", name = "EXPLOSIVE CRITS", desc = "Crits explode and hit every Keis nearby", rarity = "Legendary", max = 2, icon = "✸" },
	{ id = "GoldenTouch", name = "GOLDEN TOUCH", desc = "Kills have an 8% chance to drop 3 keys + 15 credits", rarity = "Legendary", max = 1, icon = "♛" },
	{ id = "Overclock", name = "OVERCLOCK", desc = "+40% fire rate and +15% damage", rarity = "Legendary", max = 1, icon = "⚙" },
} :: { Perk }

Perks.byId = {} :: { [string]: Perk }
for _, p in Perks.List do
	Perks.byId[p.id] = p
end

-- Draw `count` different perks the player hasn't maxed. luck (0..1) makes rare/legendary cards likelier.
function Perks.roll(rng: Random, stacks: { [string]: number }, count: number, luck: number, onlyRarity: string?): { string }
	local pool = {}
	for _, p in Perks.List do
		if (stacks[p.id] or 0) < p.max and (onlyRarity == nil or p.rarity == onlyRarity) then
			local w = Perks.Rarity[p.rarity].weight
			if p.rarity == "Legendary" then
				w *= 1 + luck * 2
			elseif p.rarity == "Rare" then
				w *= 1 + luck
			end
			table.insert(pool, { id = p.id, w = w })
		end
	end
	local picked = {}
	for _ = 1, count do
		local total = 0
		for _, e in pool do
			total += e.w
		end
		if total <= 0 then
			break
		end
		local roll = rng:NextNumber() * total
		for i, e in pool do
			roll -= e.w
			if roll <= 0 then
				table.insert(picked, e.id)
				table.remove(pool, i)
				break
			end
		end
	end
	return picked
end

-- "Id:2,Other:1" <-> table (how the server publishes a player's perks as an attribute)
function Perks.encode(stacks: { [string]: number }): string
	local parts = {}
	for _, p in Perks.List do
		local n = stacks[p.id]
		if n and n > 0 then
			table.insert(parts, p.id .. ":" .. n)
		end
	end
	return table.concat(parts, ",")
end

function Perks.decode(s: string?): { [string]: number }
	local out = {}
	for id, n in string.gmatch(s or "", "(%w+):(%d+)") do
		out[id] = tonumber(n) or 0
	end
	return out
end

return Perks
