# Jupiter 2011 Incident (Roblox)

A co-op found-footage horror game based on the TikTok "Jupiter 2011 incident" meme.
In July 2011 a crew livestreamed from a station on Jupiter, and the **Keis** took all of them.
The Keis are key-shaped entities that chant *"keis keis keis o algo"*.

## The game loop
1. **Lobby** → 20s intermission → the crew lands on a station that's **randomly generated every round**.
2. Find **5 of the 7 fuel cells** (green glow). Every cell you take makes the Keis **faster**.
3. Pick up **tape recorders** to hear the lost crew's last streams, played through the meme's slowed, crunchy, echoing filter, with glitchy subtitles.
4. Once the fuel is in, the **escape pod** in the far corner turns green. Reach it to escape.
5. If time runs out, the station goes dark and anyone left gets a jumpscare.

### The meme's format, built into the game (from the TikToks)
- **Crew roster** (top left), styled like the "JUPITER INCIDENT (2011)" videos: each player's avatar headshot and name, plus a live line.
  The line shows what you type in chat, `*Key entity approaches*` when a Keis is near, `*Silence*`, and finally a greyed-out `*Deceased*`.
  The players *are* the doomed crew, so every round becomes a clip people want to post.
- **Narrator captions** (bottom): "The keis board the ship and chase {you} algo", "They begin to taunt {you}", "{you} gets the gun and begins to shoot the keis"…
- **Power outage** mid-round: "The keis shut the ship's power off". The lights die and the Keis get faster.
- **The gun:** one per round. "I GOT A GUN", `*Shooting*`, "Reloading!!". Shots stun a Keis for a few seconds but never kill it.
- **The Keis have faces** on the key's head (drawn by default; set `Config.KeisFaceImage` to use your own image).
- **End card:** "THE TRUE SURVIVOR:" with the winners' headshots, or "EVERYONE SADLY DYING TO KEIS:".

The Keis hunt by sound (you're heard within 95 studs), use pathfinding through the rooms, and run straight at you once they can see you.
As they get closer, your camcorder filter degrades: static, shake, a red tint, blur, and glitched HUD text.

## Files
| File | What it does |
|---|---|
| `src/shared/Config.luau` | **All the tuning:** timers, Keis speed and count, map size, sound ids, the voice filter, audio log text |
| `src/server/GameManager.server.luau` | Round loop, objectives, leaderstats (Escapes, Tapes), lighting, flashlights |
| `src/server/MapBuilder.luau` | Lobby and procedural station (rooms, doorways, flickering lights, crates, items) |
| `src/server/KeisAI.luau` | The Keis model (built from parts) and its hunting AI |
| `src/client/HorrorFX.client.luau` | 2011 camcorder overlay, static, audio-log filter, subtitles, jumpscares, HUD |
| `src/client/CrewRoster.client.luau` | Crew roster, narrator bar, gun controls and ammo, survivor end card |

## Running it
**With Rojo (recommended):** install Rojo, run `rojo serve` in this folder, and connect from the Rojo plugin in a new Baseplate place.

**Without Rojo, by copy-paste in Studio:**
- `ReplicatedStorage` → Folder `Shared` → ModuleScript `Config`
- `ServerScriptService` → Folder `Server` → Script `GameManager`, ModuleScripts `MapBuilder` and `KeisAI`
- `StarterPlayer/StarterPlayerScripts` → Folder `Client` → LocalScripts `HorrorFX` and `CrewRoster`

Turn on **Game Settings → Security → Allow HTTP Requests** only if you add web features later. Nothing here needs it.
Player headshots only load in a real server or a published place; in a local Studio test the portraits may be blank.

Press Play. It works with 1 player. No models or assets are required.

## Adding the voices (this is what will make it go viral)
Record the audio log lines, upload them in the Creator Hub, and paste the ids into `Config.AudioLogs[n].soundId`.
The game applies the creepy filter itself (pitch, distortion, EQ, reverb), so upload clean recordings.
Also fill in `Config.Sounds.KeisChant`, the looping "keis keis keis" on each entity, which is the most important sound.

⚠️ **Don't put real streamers' names, faces or clips in the game.** The TikToks use real people (CaseOh and others), but Roblox moderates real people's likenesses. That's why the crew here is the *players themselves*.
⚠️ **Don't upload real streamers' clips.** Roblox removes audio you don't own the rights to. A game built on stolen clips can lose its audio overnight, or get taken down just as it starts trending. Record the lines yourself, have friends do streamer-style impressions, or get the streamers' permission. The log text in `Config` is original writing in that style, so you can edit it freely.

## Ideas for the next update
- A "found tapes" collection book; finding all 8 unlocks a secret ending.
- A cargo bay room full of dormant Keis that wake up if you sprint.
- Let dead players spectate through security cameras.
- A lore post at launch: "recovered footage, July 14 2011".
