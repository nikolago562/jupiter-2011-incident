--!strict
-- Jupiter 2011 Incident — every tunable value lives here.

local Config = {}

-- Round flow
Config.MIN_PLAYERS = 1
Config.INTERMISSION_TIME = 20
Config.ROUND_TIME = 300
Config.RESULTS_TIME = 8
Config.KEIS_GRACE_TIME = 8 -- seconds before the Keis wake up

-- Station layout (procedurally generated every round)
Config.MAP_ORIGIN = Vector3.new(0, 0, 0)
Config.LOBBY_POSITION = Vector3.new(0, 0, -450)
Config.GRID_SIZE = 6 -- 6x6 rooms
Config.CELL_SIZE = 36
Config.WALL_HEIGHT = 16
Config.DOOR_WIDTH = 8
Config.DOOR_HEIGHT = 11
Config.OPEN_WALL_CHANCE = 0.25 -- chance a wall is removed entirely

-- Objectives
Config.FUEL_CELLS_SPAWNED = 7
Config.FUEL_CELLS_REQUIRED = 5
Config.AUDIO_LOGS_SPAWNED = 6

-- Keis entities
Config.KEIS_BASE_COUNT = 2
Config.KEIS_EXTRA_EVERY_N_PLAYERS = 3 -- +1 Keis for every N players
Config.KEIS_BASE_SPEED = 12
Config.KEIS_SPEED_PER_CELL = 1.3 -- they get faster ("angrier") per fuel cell taken
Config.KEIS_HEARING_RANGE = 95 -- they hunt anyone within this range
Config.KEIS_DIRECT_CHASE_RANGE = 35 -- inside this + line of sight they run straight at you
Config.KEIS_KILL_RANGE = 4.5

-- Sound asset ids ("rbxassetid://123..."). Leave "" to skip a sound.
-- Upload your own audio in the Creator Hub, then paste the ids here.
Config.Sounds = {
	KeisChant = "", -- looping "keis keis keis" chant on each entity
	Ambience = "", -- looping station hum
	Jumpscare = "",
	Static = "", -- looping static, volume follows Keis distance
	Pickup = "",
}

-- The "filter" applied to every audio log (the meme's creepy voice effect)
Config.LogFilter = {
	Pitch = 0.78,
	Distortion = 0.55,
	ReverbDecay = 3.5,
}

-- Audio logs: the last recordings of the 2011 crew.
-- soundId = your recorded voice line; text = subtitle shown while it plays.
Config.AudioLogs = {
	{ speaker = "CREW // NOVA — LOG 01", soundId = "", duration = 6,
		text = "okay chat we're live from JUPITER. no, actually Jupiter. signal's kinda bad but we are SO back." },
	{ speaker = "CREW // DEX — LOG 02", soundId = "", duration = 6,
		text = "guys something is tapping on the hull. tap. tap. tap. no... no that's not the ship." },
	{ speaker = "CREW // NOVA — LOG 03", soundId = "", duration = 6,
		text = "it said something. it literally said 'keis'. what does that even MEAN bro" },
	{ speaker = "CREW // MARLO — LOG 04", soundId = "", duration = 6,
		text = "do NOT open cargo bay C. there's like a hundred of them in there and they're all... keys?" },
	{ speaker = "CREW // DEX — LOG 05", soundId = "", duration = 7,
		text = "keis keis keis o algo... it keeps saying it. chat why is it saying it. chat??" },
	{ speaker = "CREW // MARLO — LOG 06", soundId = "", duration = 7,
		text = "if anyone finds this: get the fuel cells, get to the pod. don't stop moving. they get faster when they're angry." },
	{ speaker = "CREW // ??? — LOG 07", soundId = "", duration = 6,
		text = "[unintelligible] ...it's in the stream. it's IN the stream. end it. END THE STR—" },
	{ speaker = "FINAL LOG — 07.14.2011", soundId = "", duration = 8,
		text = "this is the last recording. the keis took everyone. if you can hear this... you're already on Jupiter." },
}

-- Image shown as the face on each Keis ("rbxassetid://..."). "" = a drawn creepy face.
-- Use a face you made or have rights to: Roblox moderates images of real people.
Config.KeisFaceImage = ""

-- The gun ("I GOT A GUN" / "Reloading!!" from the videos). One spawns per round.
Config.GUN_AMMO = 6
Config.GUN_RELOAD_TIME = 2.5
Config.GUN_FIRE_COOLDOWN = 0.35
Config.GUN_RANGE = 120
Config.GUN_STUN_TIME = 4

-- Power outage: "the keis shut the ship's power off"
Config.OUTAGE_AT_FRACTION = { 0.35, 0.6 } -- happens randomly between 35% and 60% of the round
Config.OUTAGE_DURATION = 20
Config.OUTAGE_KEIS_SPEED_BONUS = 4

-- Narrator captions (bottom of the screen). {name} = a player's display name.
Config.Narration = {
	KeisBoard = "The keis board the ship and chase {name} algo",
	Taunt = "They begin to taunt {name}",
	Kill = "The keis find {name}. {name} is deceased",
	FuelCell = "{name} grabs a fuel cell. the keis heard that",
	Outage = "The keis shut the ship's power off. The crew is separated",
	PowerBack = "Emergency power restored... for now",
	GunPickup = "{name} gets the gun and begins to shoot the keis",
	PodOnline = "The escape pod is online. Someone has to make it",
	Escape = "{name} reaches the pod and escapes Jupiter",
	TimeUp = "The station goes dark. The incident was never reported",
}

-- Random lines the Keis "say" above their heads
Config.KeisChatter = {
	"KEIS KEIS KEIS",
	"keis keis keis o algo",
	"KEIS",
	"k e i s",
	"keis... keis...",
	"KEIS KEIS KEIS KEIS KEIS",
	"o algo",
}

return Config
