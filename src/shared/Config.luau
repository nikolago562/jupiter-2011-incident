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
	Iron = { name = "IRON KEIS", hp = 220, speed = 9, damage = 22, reward = 15, xp = 5, scale = 1.45,
		color = Color3.fromRGB(70, 72, 80), unlockWave = 6, weight = 3 },
	Mini = { name = "MINI KEIS", hp = 18, speed = 19, damage = 4, reward = 2, xp = 1, scale = 0.55,
		color = Color3.fromRGB(200, 160, 80), unlockWave = 99, weight = 0 },
	Golden = { name = "GOLDEN KEIS", hp = 80, speed = 17, damage = 0, reward = 60, xp = 20, scale = 0.9,
		color = Color3.fromRGB(255, 200, 40), unlockWave = 1, weight = 0, passive = true, lifetime = 25 },
	Master = { name = "MASTER KEIS", hp = 1500, speed = 10, damage = 35, reward = 150, xp = 60, scale = 2.6,
		color = Color3.fromRGB(120, 20, 20), unlockWave = 99, weight = 0, boss = true,
		summon = "Mini", summonEvery = 8, summonCount = 3 },
}

-- Weapon ----------------------------------------------------------------------------------
Config.Weapon = {
	BaseDamage = 20,
	FireInterval = 0.2,
	MagSize = 15,
	ReloadTime = 1.5,
	Range = 220,
	Spread = 0.05, -- radians between Split Beam shots
	CritMultiplier = 2, -- hitting a Keis in the face
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
	KeisChant = "", -- "keis keis keis o algo o algo", loops on every Keis
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
}

return Config
