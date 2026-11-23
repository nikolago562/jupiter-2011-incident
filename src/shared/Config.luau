--!strict
-- JUPITER 2011 INCIDENT — every tunable value lives here.

local Config = {}

-- Flow ------------------------------------------------------------------------
Config.MIN_PLAYERS = 1
Config.LOBBY_TIME = 15 -- countdown before a run starts
Config.BREAK_TIME = 15 -- shop time between waves
Config.BOSS_BREAK_TIME = 25 -- longer break after a boss wave
Config.GAMEOVER_TIME = 12

-- Crew ------------------------------------------------------------------------
Config.BASE_HEALTH = 100
Config.BASE_WALKSPEED = 16
Config.DOWNED_BLEEDOUT = 25 -- seconds a downed player has to be revived
Config.REVIVE_TIME = 2.5 -- hold time to revive a crewmate
Config.REVIVE_HEALTH = 0.4 -- revived with 40% health

Config.SPACESUITS = true -- dress everyone in white spacesuits with helmets

-- Io (the moon landing) ---------------------------------------------------------------
Config.LANDING_WAVE = 10 -- after clearing this wave the ship lands on Io
Config.MOON_GRAVITY = 0.25 -- fraction of normal gravity (Io is 0.18g; 0.25 keeps it playable)
Config.MOON_JUMP_POWER = 32 -- with low gravity this is a long, floaty jump

-- Reactor (the thing the Keis want) ---------------------------------------------
Config.REACTOR_MAX_HP = 1000
Config.REPAIR_COST = 60
Config.REPAIR_AMOUNT = 250

-- Waves ---------------------------------------------------------------------------
Config.Waves = {
	BaseCount = 6,
	CountPerWave = 3,
	ExtraPlayerMultiplier = 0.5, -- +50% Keis per extra player
	HealthScalePerWave = 0.12, -- +12% Keis HP per wave
	SpawnIntervalStart = 1.2,
	SpawnIntervalMin = 0.35,
	BossEvery = 5,
	MaxAlive = 35,
	GoldenChance = 0.04, -- chance each spawn is a Golden Keis
	OutageFromWave = 3,
	OutageChance = 0.35, -- chance a wave has a power outage
	OutageDuration = 18,
	OutageSpeedBonus = 3,
	ClearBonusBase = 20, -- credits for everyone when a wave is cleared
	ClearBonusPerWave = 5,
}

-- Keis types -------------------------------------------------------------------------
-- weight = how often it spawns once unlockWave is reached (0 = never spawned by waves)
Config.KeisTypes = {
	Basic = { name = "KEIS", hp = 60, speed = 13, damage = 10, reward = 5, xp = 2, scale = 1,
		color = Color3.fromRGB(176, 142, 66), unlockWave = 1, weight = 10 },
	Skeleton = { name = "SKELETON KEIS", hp = 35, speed = 20, damage = 6, reward = 6, xp = 2, scale = 0.8,
		color = Color3.fromRGB(225, 220, 200), unlockWave = 3, weight = 6 },
	Keyring = { name = "KEYRING", hp = 90, speed = 11, damage = 10, reward = 8, xp = 3, scale = 1.1,
		color = Color3.fromRGB(150, 160, 175), unlockWave = 4, weight = 4, splitInto = "Mini", splitCount = 3 },
	Iron = { name = "IRON KEIS", hp = 220, speed = 9, damage = 22, reward = 15, xp = 5, scale = 1.25,
		color = Color3.fromRGB(70, 72, 80), unlockWave = 6, weight = 3 },
	Mini = { name = "MINI KEIS", hp = 18, speed = 19, damage = 4, reward = 2, xp = 1, scale = 0.55,
		color = Color3.fromRGB(200, 160, 80), unlockWave = 99, weight = 0 },
	Golden = { name = "GOLDEN KEIS", hp = 80, speed = 17, damage = 0, reward = 60, xp = 20, scale = 0.9,
		color = Color3.fromRGB(255, 200, 40), unlockWave = 1, weight = 0, passive = true, lifetime = 25 },
	Keymaster = { name = "KEYMASTER", hp = 700, speed = 17, damage = 18, reward = 120, xp = 40, scale = 1.15,
		color = Color3.fromRGB(255, 190, 50), unlockWave = 99, weight = 0, keys = 5 },
	Master = { name = "MASTER KEIS", hp = 1500, speed = 10, damage = 35, reward = 150, xp = 60, scale = 1.3,
		color = Color3.fromRGB(120, 20, 20), unlockWave = 99, weight = 0, boss = true,
		summon = "Mini", summonEvery = 8, summonCount = 3 },
}

-- Wave modifiers (one may roll from wave 3) -----------------------------------------------
Config.MODIFIER_FROM_WAVE = 3
Config.MODIFIER_CHANCE = 0.6
Config.Modifiers = {
	Swarm = { name = "SWARM", desc = "+60% Keis, -30% health", count = 1.6, hp = 0.7 },
	Armored = { name = "ARMORED", desc = "Keis have +50% health", hp = 1.5 },
	Frenzy = { name = "FRENZY", desc = "Keis are much faster", speed = 4 },
	Darkness = { name = "DARKNESS", desc = "The lights are out", dark = true },
	DoubleKeys = { name = "DOUBLE KEYS", desc = "Keis drop twice the keys", keys = 2 },
	Bounty = { name = "BOUNTY", desc = "+75% credits from kills", credits = 1.75 },
}

-- Keys & crates ------------------------------------------------------------------------------------
Config.KEY_DROP_CHANCE = 0.22 -- per kill (bosses and the Keymaster always drop several)
Config.CRATES_PER_BREAK = 3
Config.MISSION_KEY_REWARD = 2 -- keys for each crew member when a special mission succeeds

-- Weapons ----------------------------------------------------------------------------------
-- Shared settings
Config.Weapon = {
	Range = 220,
	Spread = 0.05, -- radians between Split Beam shots
	CritMultiplier = 2, -- hitting a Keis in the mouth
	FireInterval = 0.2, -- fallback for the client before stats arrive
}
-- Everyone starts with the Blaster. The minigun is unlocked in the Upgrade Terminal.
Config.Weapons = {
	Blaster = { name = "BLASTER", damage = 20, interval = 0.2, mag = 15, magPerLevel = 5, reload = 1.5, jitter = 0,
		tracer = Color3.fromRGB(90, 220, 255) },
	Minigun = { name = "M-2011 MINIGUN", damage = 11, interval = 0.065, mag = 100, magPerLevel = 25, reload = 3.2, jitter = 0.035,
		tracer = Color3.fromRGB(255, 170, 60), cost = 450 },
}

-- Upgrades (bought with credits; reset every run) ------------------------------------------------
Config.Upgrades = {
	{ id = "Damage", name = "PLASMA DAMAGE", desc = "+20% damage", baseCost = 30, growth = 1.55, max = 8, icon = "✦" },
	{ id = "FireRate", name = "TRIGGER CYCLER", desc = "+12% fire rate", baseCost = 35, growth = 1.6, max = 6, icon = "⟫" },
	{ id = "MaxHealth", name = "SUIT PLATING", desc = "+25 max health", baseCost = 25, growth = 1.5, max = 6, icon = "✚" },
	{ id = "Speed", name = "MAG BOOTS", desc = "+1.5 walk speed", baseCost = 25, growth = 1.6, max = 5, icon = "➤" },
	{ id = "Mag", name = "BIGGER MAG", desc = "+5 magazine size", baseCost = 20, growth = 1.5, max = 4, icon = "▤" },
	{ id = "Multishot", name = "SPLIT BEAM", desc = "+1 beam per shot", baseCost = 150, growth = 2.2, max = 3, icon = "⋔" },
}

function Config.upgradeCost(def: { baseCost: number, growth: number }, level: number): number
	return math.floor(def.baseCost * def.growth ^ level)
end

-- Permanent progression (saved) ---------------------------------------------------------------------
Config.DATASTORE_NAME = "Jupiter2011_v1"
Config.XP_PER_WAVE = 15 -- times the wave number
Config.LEVEL_DAMAGE_BONUS = 0.01 -- +1% damage per level
function Config.xpForLevel(level: number): number
	return math.floor(100 * level ^ 1.35)
end
Config.Titles = {
	{ level = 1, title = "CADET" },
	{ level = 5, title = "KEY HUNTER" },
	{ level = 10, title = "LOCKSMITH" },
	{ level = 20, title = "VENT WARDEN" },
	{ level = 35, title = "JUPITER VETERAN" },
	{ level = 50, title = "THE TRUE SURVIVOR" },
}
function Config.titleFor(level: number): string
	local title = Config.Titles[1].title
	for _, t in Config.Titles do
		if level >= t.level then
			title = t.title
		end
	end
	return title
end

-- Look & sound -----------------------------------------------------------------------------------
-- Image shown as the face on each Keis ("rbxassetid://..."). "" = a drawn face.
Config.KeisFaceImage = ""

-- Sound ids ("rbxassetid://123..."). "" = silent until you add one.
Config.Sounds = {
	-- "keis keis keis o algo o algo": upload assets/audio/keis_chant.ogg (or keis_chant_filtered.ogg)
	KeisChant = "",
	-- optional: upload assets/audio/keis_chant_boss.ogg. If empty, the boss plays KeisChant slowed down.
	BossChant = "",
	Music = "", -- background loop
	WaveStart = "",
	Alarm = "",
	Shoot = "",
	Hit = "",
	Kill = "",
	LevelUp = "",
	Buy = "",
}

Config.KEIS_CHANT_CHANCE = 0.5 -- chance a Keis chants each cycle (text + sound)
Config.MAX_SIMULTANEOUS_CHANTS = 6 -- cap on chant sounds playing at once

Config.KeisChatter = {
	"keis keis keis o algo o algo",
	"KEIS KEIS KEIS",
	"keis keis keis o algo",
	"o algo o algo",
	"KEIS",
	"k e i s",
}

Config.WaveSubtitles = {
	"THEY'RE IN THE VENTS",
	"KEIS KEIS KEIS O ALGO O ALGO",
	"PROTECT THE REACTOR",
	"THE KEYS BOARD THE SHIP",
	"DON'T LET THEM TAUNT YOU",
	"SIGNAL LOST · JULY 14, 2011",
}

-- Narrator captions. {name} = a player's display name.
Config.Narration = {
	RunStart = "July 14, 2011. The crew reaches Jupiter orbit. Something is in the vents",
	Vents = "The keys board the ship and chase {name} algo",
	Boss = "The Master Keis has boarded the ship",
	Outage = "The keis shut the ship's power off. The crew is separated",
	PowerBack = "Emergency power restored",
	ReactorLow = "The reactor is failing. The keis are getting in",
	Downed = "{name} is down. Someone revive them",
	Revived = "{name} was revived",
	Deceased = "{name} is deceased",
	Golden = "A GOLDEN KEIS appeared. Catch it before it escapes",
	GoldenCaught = "{name} caught the golden keis",
	GoldenEscaped = "The golden keis got away",
	WaveClear = "Wave cleared. The keis are regrouping",
	GameOver = "The incident was never reported",
	Retreat = "The keis retreat into the vents. For now",
	Landing = "The USS Kepler lands on Io. The keis followed the ship down",
}

return Config
