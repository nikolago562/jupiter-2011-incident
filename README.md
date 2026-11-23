# JUPITER 2011 INCIDENT (Roblox)

A co-op **sci-fi wave survival** game with a light horror mood, inspired by the "Jupiter 2011 incident" trend.
Everything is shown like recovered **security-camera footage**: `07/14/2011 23:47:52 · CAM 04 (CORRIDOR)`.

July 14, 2011. Your crew is aboard the **USS KEPLER** in orbit around Jupiter. The **Keis** crawl out of the vents, chanting
*"keis keis keis o algo o algo"*. They're giant brass keys walking on **spider legs**, with a **ring of teeth** inside the key's head. Defend the reactor, keep your crew alive, and see how many waves you can survive.

## What's in it
- **Start menu:** a live 3D scene with the Keis standing on volcanic rock and Jupiter rising behind them. PLAY, how to play, and your saved stats.
- **The USS KEPLER:** 9 detailed rooms with ceiling arches, sliding doors that open when anyone gets close, consoles with live screens,
  warning signs, steam leaks, sparking panels, cables, lockers, pipes, floor grates and Future lighting with real shadows.
- **Jupiter:** 110 color bands following its real cloud belts, the layered Great Red Spot, white ovals, haze, a soft night side,
  Io, Europa and Ganymede, a full starfield with the Milky Way and nebulas.
- **First person:** detailed weapon viewmodel with suit arms, sway, bob, recoil, reload/sprint poses, aim down sights,
  scope overlay for 4x/8x, Q/E lean, laser beam, spinning minigun barrels.
- **Armory bench:** buy and swap optics (iron, red dot, holo, 4x ACOG, 8x scope), lasers (red, green) and muzzles
  (compensator, long barrel) with a live 3D preview, plus upgrades and the minigun.
- **Map detail:** pipes with elbows, flanges and valve wheels, junction boxes with blinking LEDs, pressure gauges,
  spinning wall fans, sagging wire bundles, cable trays, conduits, steam, sparks.
- **Io (after wave 10):** the ship lands on Jupiter's volcanic moon. Terrain with craters, lava lakes, a smoking volcano,
  sulfur fields, the landed ship, floodlights, and **25% gravity** (long floaty jumps, dust when you land).

## Why it's addictive: every run is different
- **Every wave is a random mission:** HOLD THE LINE (destroy all), BLACKOUT (find 3 fuses in the dark and carry them to the fuse box),
  TRANSMIT (hold the beacon zone), KEYMASTER HUNT (kill the elite before it escapes), GOLD RUSH (golden Keis everywhere), and a BOSS every 5th wave.
- **Wave modifiers** from wave 3: SWARM, ARMORED, FRENZY, DARKNESS, DOUBLE KEYS, BOUNTY.
- **Perk cards:** after every wave, pick 1 of 3 (Common / Rare / Legendary). They stack into a build:
  Ricochet + Chain Lightning + Explosive Crits, Vampire Suit + Overclock, Key Magnet + Golden Touch… Bosses offer a Legendary choice.
- **Keys:** the Keis drop keys. Spend them on **supply crates** that appear between waves (credits, heal, extra perk card, keys, or a Legendary card)
  or on **rerolling** your perk cards.

## The loop
1. **Lobby:** the crew spawns on the bridge. Through the windows you can see Jupiter, with its bands, the Great Red Spot and two moons.
2. **Waves:** the Keis pour out of the vents and go for the **reactor**, or for any crew member who gets close.
3. **Break:** spend the credits from your kills in the **Upgrade Terminal** (Q). Dead crew respawn.
4. **Boss every 5 waves:** the **MASTER KEIS** is huge, has a health bar, and summons Mini Keis.
5. **Game over** when the reactor is destroyed or the whole crew is down. The end card shows the stats and names the **TRUE SURVIVOR** (the MVP).

### What makes it addictive
- **Every run is a new build.** Upgrades reset each run: damage, fire rate, Split Beam, health, speed, magazine size,
  plus the **M-2011 MINIGUN** (◆450).
- **Permanent progress (saved):** your level and title (CADET → KEY HUNTER → … → THE TRUE SURVIVOR), +1% damage per level, best wave, and a **global Top 10** board on the bridge.
- **Feels good to shoot:** hitmarkers, floating damage numbers, **CRITs** for shooting a Keis in the mouth, kill pops showing credits, and combo names (TRIPLE KEIS → … → O ALGO O ALGO).
- **Surprises:** **Golden Keis** (catch it for a big payout before it escapes), **power outages** (lights die, the Keis get faster, flashlights turn on), and Keyrings that split into 3 minis.
- **Co-op:** downed players can be **revived** by teammates (+credits for the reviver). More players means more Keis.

### Keis types
| Type | From wave | Notes |
|---|---|---|
| Keis | 1 | basic |
| Skeleton Keis | 3 | fast and fragile |
| Keyring | 4 | splits into 3 Mini Keis |
| Iron Keis | 6 | slow tank, hits hard |
| Golden Keis | random | doesn't attack, worth 60 credits |
| MASTER KEIS | every 5th wave | boss, summons minis |

### Look
- An industrial ship: floor grates, pipes, wall ribs, hazard-striped doors, sector labels (C-3, R-0…), fluorescent tubes.
- Every crew member wears a white **spacesuit** with a glass helmet and life-support pack (`Config.SPACESUITS`).
- A security-camera overlay with the timestamp and the camera of the room you're in, light grain, and a colder grade.

### Nods to the trend
- **Crew manifest** with headshots, chat lines and status lines (KEY ENTITY APPROACHING, NO SIGNAL, DECEASED, "Reloading!!").
- **Narrator captions** at the bottom ("The keys board the ship and chase {you} algo"…), a 2011 camcorder timestamp, and "THE TRUE SURVIVOR" on the end card.

## Files
| File | What it does |
|---|---|
| `src/shared/Config.luau` | **All the tuning:** waves, Keis types, weapon, upgrade prices, XP and titles, sound ids, narrator lines |
| `src/server/GameManager.server.luau` | Run/wave loop, boss waves, downed/revive, outages, alarm, reactor, game over |
| `src/server/ShipBuilder.luau` | The ship (9 detailed rooms, sliding doors, consoles, steam, sparks), reactor, vents |
| `src/server/MoonBuilder.luau` | Io: terrain, craters, lava, volcano, landed ship, generator, fissures |
| `src/shared/SpaceArt.luau` | Jupiter (bands, Great Red Spot, moons) and the starfield |
| `src/shared/KeisModel.luau` | The Keis model (used by the server and the menu) |
| `src/client/Menu.client.luau` | Start menu scene + PLAY, and full-screen transitions |
| `src/client/Movement.client.luau` | Shoulder camera, sprint, camera bob, hit shake, moon dust |
| `src/client/ShipFX.client.luau` | Sliding doors and console screen flicker |
| `src/server/KeisAI.luau` | Keis models (spider legs, toothy mouth), health bars, AI, chant, death effect |
| `src/server/Suit.luau` | Spacesuits: suit colors, glass helmet, life-support pack |
| `src/server/Combat.luau` | Server-checked shooting, Blaster + Minigun, crits, Split Beam, reload, credits, upgrade shop |
| `src/server/PlayerData.luau` | Saved level/XP/best wave plus the global leaderboard |
| `src/client/Theme.luau` | UI style (colors, fonts, panels, bars) |
| `src/client/HUD.client.luau` | Wave + reactor panel, crew roster, player card, banners, narrator, toasts, downed and game-over screens |
| `src/client/Combat.client.luau` | Firing, crosshair, tracers, damage numbers, combos, ammo |
| `src/client/Shop.client.luau` | Upgrade terminal (Q) |
| `src/client/Atmosphere.client.luau` | Security-camera overlay (per-room CAM names), grade, alarm pulse, outage, grain, music |
| `src/client/KeisAnimator.client.luau` | Walks the Keis' spider legs (tripod gait) |

## Running it
**Easiest (no Rojo):** download `Jupiter2011Incident.rbxlx` from this repo and open it in Roblox Studio (File → Open from File). Press Play.
After code changes, rebuild it with `python3 tools/build_place.py`.

**With Rojo (live sync):**
1. Run `rojo serve` in this folder, then connect from the Rojo plugin in a new Baseplate place.
2. To test saving in Studio: **Game Settings → Security → Enable Studio Access to API Services**. The place must be published first.
3. Press Play. It works solo.

**Controls (first person):** hold click to fire · **right-click** aim down sights · **R** reload · **Shift** sprint · **Q / E** lean ·
walk up to the **ARMORY** bench and press **E** to upgrade · hold **E** on a downed crewmate to revive them.

## Sounds
Roblox only plays audio uploaded to Roblox, so every sound has a ready file in this repo. Upload each one
(Creator Hub → Creations → Development Items → Audio), then paste its id (`rbxassetid://123…`) into `Config.Sounds`:

| Config key | File | Where you hear it |
|---|---|---|
| `KeisChant` | `assets/audio/keis_chant.ogg` | every Keis, with the floating chant text |
| `BossChant` | `assets/audio/keis_chant_boss.ogg` | the Master Keis (optional) |
| `ShipHum` | `assets/audio/sfx/ship_hum.ogg` | constant background on the ship |
| `ReactorHum` | `sfx/reactor_hum.ogg` | 3D, the reactor and Io's generator |
| `EngineRumble` | `sfx/engine_rumble.ogg` | 3D, engine room |
| `Steam` | `sfx/steam_hiss.ogg` | 3D, every steam leak |
| `Sparks` | `sfx/sparks.ogg` | 3D, every sparking panel |
| `Alarm` | `sfx/alarm.ogg` | during waves |
| `IoWind` | `sfx/io_wind.ogg` | constant background on Io |
| `Shoot` / `MinigunShoot` | `sfx/blaster_shot.ogg` / `sfx/minigun_shot.ogg` | firing |
| `Reload` | `sfx/reload.ogg` | reloading |
| `Door` | `sfx/door_slide.ogg` | 3D, sliding doors |
| `KeyPickup` | `sfx/key_pickup.ogg` | picking up keys |
| `Hit` / `Kill` | `sfx/hit_marker.ogg` / `sfx/keis_death.ogg` | hits and kills |
| `WaveStart`, `LevelUp`, `Buy`, `UIClick`, `CrateOpen` | matching files in `sfx/` | UI |
| `Footstep` | `sfx/footstep_metal.ogg` | (spare) |

All the `sfx/` sounds were generated for this game, so you own them. Don't use real streamers' clips, names or faces:
Roblox moderates them.
