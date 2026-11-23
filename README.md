# JUPITER 2011 INCIDENT (Roblox)

A co-op **wave survival** game with a light horror mood, based on the TikTok "Jupiter 2011 incident" meme.

July 14, 2011. Your crew is aboard the **USS KEPLER** in orbit around Jupiter. The **Keis** crawl out of the vents, chanting
*"keis keis keis o algo o algo"*. They're key-shaped and have faces. Defend the reactor, keep your crew alive, and see how many waves you can survive.

## The loop
1. **Lobby:** the crew spawns on the bridge. Through the windows you can see Jupiter, with its bands, the Great Red Spot and two moons.
2. **Waves:** the Keis pour out of the vents and go for the **reactor**, or for any crew member who gets close.
3. **Break:** spend the credits from your kills in the **Upgrade Terminal** (Q). Dead crew respawn.
4. **Boss every 5 waves:** the **MASTER KEIS** is huge, has a health bar, and summons Mini Keis.
5. **Game over** when the reactor is destroyed or the whole crew is down. The end card shows the stats and names the **TRUE SURVIVOR** (the MVP).

### What makes it addictive
- **Every run is a new build.** Upgrades reset each run: damage, fire rate, Split Beam, health, speed, magazine size.
- **Permanent progress (saved):** your level and title (CADET → KEY HUNTER → … → THE TRUE SURVIVOR), +1% damage per level, best wave, and a **global Top 10** board on the bridge.
- **Feels good to shoot:** hitmarkers, floating damage numbers, **CRITs** for shooting a Keis in the face, kill pops showing credits, and combo names (TRIPLE KEIS → … → O ALGO O ALGO).
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

### The meme, built in
- **Crew roster** in the top left, in the "JUPITER INCIDENT (2011)" style: headshots, chat lines, `*Key entity approaches*`, `*Silence*`, `*Deceased*`, "Reloading!!".
- **Narrator captions** at the bottom ("The keys board the ship and chase {you} algo"…), a 2011 camcorder timestamp, and "THE TRUE SURVIVOR" on the end card.

## Files
| File | What it does |
|---|---|
| `src/shared/Config.luau` | **All the tuning:** waves, Keis types, weapon, upgrade prices, XP and titles, sound ids, narrator lines |
| `src/server/GameManager.server.luau` | Run/wave loop, boss waves, downed/revive, outages, alarm, reactor, game over |
| `src/server/ShipBuilder.luau` | The ship (9 rooms, windows), reactor, vents, props, Jupiter and space |
| `src/server/KeisAI.luau` | Keis models (with faces), health bars, AI, death effect |
| `src/server/Combat.luau` | Server-checked shooting, crits, Split Beam, reload, credits, upgrade shop |
| `src/server/PlayerData.luau` | Saved level/XP/best wave plus the global leaderboard |
| `src/client/Theme.luau` | UI style (colors, fonts, panels, bars) |
| `src/client/HUD.client.luau` | Wave + reactor panel, crew roster, player card, banners, narrator, toasts, downed and game-over screens |
| `src/client/Combat.client.luau` | Firing, crosshair, tracers, damage numbers, combos, ammo |
| `src/client/Shop.client.luau` | Upgrade terminal (Q) |
| `src/client/Atmosphere.client.luau` | Color grade, camcorder overlay, alarm pulse, outage, static, music |

## Running it
1. Run `rojo serve` in this folder, then connect from the Rojo plugin in a new Baseplate place.
2. To test saving in Studio: **Game Settings → Security → Enable Studio Access to API Services**. The place must be published first.
3. Press Play. It works solo.

**Controls:** hold click to fire · **R** reload · **Q** upgrades · hold **E** on a downed crewmate to revive them.

## Sounds
Every slot is in `Config.Sounds`. The most important one is `KeisChant` ("keis keis keis o algo o algo"), which loops on every Keis in 3D.
Upload audio you have the rights to, then paste the `rbxassetid://` ids.
⚠️ Don't use real streamers' clips, names or faces. Roblox moderates them, and the game could lose its audio or get taken down.
