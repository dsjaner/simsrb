# Bahay Buhay 🏠🇵🇭

A Filipino-themed life-simulation game for Roblox. Gameplay works like a Sims-style life sim, set in a Philippine barangay.

You get your own **bahay kubo**. Look after your needs, earn pesos from local jobs, make friends with the *kapitbahay*, and furnish your home.

Everything (world, buildings, furniture, UI) is made in code from parts, so you don't need to upload any meshes, decals or sounds to start.

---

## Phase 0 — Three cities, one shared world

Everyone plays in the same map, with three cities connected by road (no teleports between cities):

| City | Feel | Cost of living | Pay | Houses |
|---|---|---|---|---|
| 🌊 **Baybay Alon** | Coastal town: fishing, beach, pier | ×1.0 | ×1.0 | Bahay kubo |
| 🏙️ **Metro Dakila** | Metro Manila-style city: BPO, hospital, university, mall | ×1.4 | ×1.35 | Concrete bungalow |
| 🌾 **San Bukid** | Upland farming town on a plateau: rice paddies, kalabaw | ×0.85 | ×0.9 | Bahay kubo |

- **Ikot ng Kapalaran.** The first time you join, a wheel decides your **hometown**, **Yaman** (wealth), **Swerte** (luck) and **DNA** (talent), each with 3 tiers. It also picks a natural talent skill and your parents' jobs. The odds are shown on screen. The server rolls it once and saves it, so rejoining doesn't re-roll it.
  - **Yaman:** starting pesos and the daily *padala* from your parents. Mahirap players get slower Pakikisama decay ("matibay ang samahan").
  - **Swerte:** the good/bad mix of trip events. Malas players get +10% skill XP ("natututo sa hirap").
  - **DNA:** skill XP speed, plus +25% XP in your talent skill.
- **Parents are never shown as characters.** They show up through 📱 text messages and story notifications.
- **Only your age is visible to other players.** You can see the rest of your identity in the private 🪪 **Ako** panel.
- **Aging:** 1 year for every 3 in-game days you play. Everyone starts at 18 for now; playable childhood comes in Phase 1.
- **PESO Office:** one in every city. Pick from 10 professions: Mangingisda, Magsasaka, Tindero, Drayber, Karpintero, Guro, Nars, Call Center Agent, Seaman, Doktor. Education locks some of them; college and medicine unlock in Phase 1. Each job can only be done in certain cities, so you choose between commuting and moving.
- **Provincial buses:**
  - Routes: Baybay Alon ⇄ Metro Dakila (₱60, ~90s) and Metro Dakila ⇄ San Bukid (₱80, ~110s).
  - Press **E** to board and **Space** to get off. The fare is paid when the bus leaves.
  - **Trip events** happen along the way, weighted by Swerte: finding coins, Ninong Boy's pocket money, a lost wallet with a reward, a pickpocket, a flat tire, traffic, and more.
- **Prices, pay and bills scale by city.**
- **StreamingEnabled** is on (set in the place file and in `default.project.json`), so phones only load the area around the player.

## Features

| System | What it does |
|---|---|
| **Needs (Pangangailangan)** | Six needs decay over time: Kabusugan (hunger), Lakas (energy), Kalinisan (hygiene), Saya (fun), Pakikisama (social), Banyo (bladder). If a need runs out, something happens: you pass out on the floor, have an "accident", or walk slower. |
| **Mood + Parol** | Your average need sets your mood (*Masayang-masaya → Pagod at stressed*). A floating **parol star** over your head shows it, and mood changes your job pay. |
| **Actions** | Use objects through ProximityPrompts (key **E**). Each action is timed and puts your character in position (stand, sit or lie down). An emoji thought bubble shows over your head and a progress bar shows on screen. Moving or jumping cancels the action. |
| **Jobs (Trabaho)** | Drive a **jeepney** (5AM–10PM), sell at the **palengke** (4AM–6PM), or go fishing in a **bangka**. Pay comes in while you work. |
| **Skills (Kasanayan)** | Pagluluto, Pagkanta, Basketball, Pangingisda, Pagmamaneho, Pagtitinda. Higher levels make cooking more filling and raise job pay. |
| **Relationships (Relasyon)** | Talk to Aling Nena, Mang Tonyo, Lola Remedios and Kuya Jun: *Makipagkwentuhan*, *Makichismis*, *Magmano*. Levels go from *Hindi pa Kilala* up to *Parang Kapamilya*. Relationships fade a little each day. |
| **Build mode (Gawa)** | Press **B**. Buy furniture from a catalog, preview it as a ghost (green/red), rotate with **R**, place with a click, and sell back with **X** (60% refund). |
| **Day/night + bills** | 14 real minutes is one in-game day. Lamps and parols light up at night. Every 6AM, *kuryente at tubig* (electricity and water) bills are charged based on how much furniture you have. |
| **Saving** | DataStore saves pesos, needs, skills, relationships and your full furniture layout. |
| **Multiplayer** | 6 lots, one per player. Videoke and basketball give extra Pakikisama when another player is nearby. |

### The barangay
- **Plaza:** basketball court, Aling Nena's sari-sari store (with hanging *tingi* sachets), karinderya (*turo-turo*), videoke pavilion with monobloc chairs, poso (water pump), monument, and banderitas strung between lamp posts.
- **East:** jeepney terminal (2 jeepneys), palengke (3 stalls), simbahan with a bell tower, barangay hall.
- **West:** beach with coconut trees, a cottage, and bangkas with *katig* (outriggers).
- **Residential:** 6 lots, each with a bahay kubo on stilts (nipa roof, sawali walls, window shutters propped open with *tukod*), a bamboo fence, a name sign, and coconut trees.

### Things to buy and do
| Furniture | Price | Action |
|---|---|---|
| Banig / Kamang Kawayan | ₱150 / ₱650 | Matulog, Umidlip |
| Kalan | ₱400 | Sinangag, Adobo, Pancit Bihon, Sinigang |
| Hapag-Kainan | ₱350 | Mag-merienda |
| Timba at Tabo / Inidoro | ₱120 / ₱300 | Maligo / CR |
| TV (de-kahon) | ₱900 | Teleserye, Balita |
| Videoke | ₱1,500 | Kumanta (with a random score!) |
| Duyan, Bentilador, Aparador, Altar, Sampaguita, Parol | ₱80–₱450 | Rest, cool off, change clothes, pray, water plants, decor |

Public places: sari-sari store (pandesal, turon, balut, kakanin, palamig), karinderya (tapsilog, lugaw, halo-halo), simbahan (*Magsimba*), poso (*Maghilamos*).

---

## Setup

### Easiest — open the ready-made place file
Open `release/BahayBuhay.rbxlx` in Roblox Studio (File → Open from File), then press **Play**.
If you change the code, rebuild it with `python3 tools/build_place.py`.

### Option A — Rojo (recommended)
1. Install [Rojo](https://rojo.space/) (CLI 7.x) and the Rojo plugin in Roblox Studio.
2. In this folder, run:
   ```bash
   rojo serve
   ```
3. In Studio, open a new **Baseplate** place, click **Rojo → Connect**, then press **Play**.

To make a place file without Studio syncing:
```bash
rojo build -o BahayBuhay.rbxl
```

### Option B — Copy and paste into Studio
Make these objects and paste each file's contents in:

| Studio location | Type | File |
|---|---|---|
| `ReplicatedStorage › Shared` (Folder) | ModuleScript `Config`, `Util`, `Models` | `src/shared/*.luau` |
| `ServerScriptService › Server` (Folder) | Script `Main` | `src/server/Main.server.luau` |
| `ServerScriptService › Server › Services` (Folder) | ModuleScripts (one per file) | `src/server/Services/*.luau` |
| `StarterPlayer › StarterPlayerScripts › Client` (Folder) | LocalScript `Main` | `src/client/Main.client.luau` |
| `… › Client` | ModuleScript `BuildMode` | `src/client/BuildMode.luau` |
| `… › Client › UI` (Folder) | ModuleScripts `Theme`, `HUD`, `Menus` | `src/client/UI/*.luau` |

### Studio settings
- **Saving in Studio:** Game Settings → Security → turn on *Enable Studio Access to API Services*. Without it the game still runs, but progress isn't saved.
- **Max players:** set this to **6** (one per lot) under Game Settings → Places.
- The default Baseplate is removed automatically when the server starts.

---

## Controls
| Key | Action |
|---|---|
| **E** | Interact with the object or person in front of you |
| **W/A/S/D**, **Space** | Moving or jumping cancels the current action |
| **B** | Enter/exit build mode |
| **R** / **X** / **Q** | Rotate / sell / deselect (in build mode) |
| **Esc** | Close menus |
| Side buttons | 🏠 Bahay (go home) · 🔨 Gawa · 📊 Kasanayan · ❤️ Relasyon |

---

## Code layout
```
src/
  shared/                 (ReplicatedStorage.Shared)
    Config.luau           all tunables: needs, actions, stations, furniture, NPCs, skills
    Models.luau           procedural builders for every 3D object
    Util.luau             helpers (part factory, peso/clock formatting, hours)
  server/                 (ServerScriptService.Server)
    Main.server.luau      bootstrap, player join/leave, autosave, daily bills
    Services/
      WorldBuilder        lighting, terrain, roads, plaza, landmarks
      LotService          6 lots, assignment, signs
      BuildService        place/sell furniture (server-validated), (de)serialize layout
      StationService      ProximityPrompts → actions or choice menus
      ActionService       timed actions: positioning, effects, pay, skills, relationships
      NeedsService        decay, mood, warnings, consequences
      NPCService          neighbours: rigs, wandering, speech bubbles
      TimeService         day/night cycle, night lights, morning callbacks
      DataService         DataStore load/save
      Overhead            parol mood star + thought bubble
      Remotes             RemoteEvents/Functions
  client/                 (StarterPlayerScripts.Client)
    Main.client.luau      HUD bootstrap, side buttons, cancel-on-move
    BuildMode.luau        ghost preview, catalog, place/rotate/sell
    UI/Theme, HUD, Menus  UI building blocks, HUD, station menu, skill/relationship panels
```

State replicates through **player attributes** (`Pesos`, `Need_*`, `Skill_*`, `Rel_*`, `CurrentAction`, `ActionProgress`, `Mood`), so the UI just listens for changes. The server is authoritative for money, needs and placement.

---

## Extending it

**Add a food or activity.** Add an entry to `Config.Actions`, then add its id to a station's `actions` list in `Config.Stations`. No other code changes are needed.

**Add furniture.**
1. Write `Builders.MyThing()` in `Models.luau`. The pivot goes at floor centre, +Z is the front, and you add a `UsePoint` part (or a Seat named `UsePoint`).
2. Add a `Config.Stations.MyThing` entry.
3. Add a `Config.Furniture` entry.

**Tune balance.** Need decay rates, prices, pay, day length, bills and starting pesos are all in `Config.luau`.

### Ideas for next steps
- Custom animations (sleeping, cooking, singing): put animation asset ids into the action defs and play them in `ActionService.positionCharacter`.
- Sound: rooster at sunrise, videoke music, jeepney horn, rain on a nipa roof.
- Fiesta events (banderitas plus a lechon feast) and Pasko season (more parols, Noche Buena).
- More jobs: tricycle driver, sari-sari store owner, call-center agent at night.
- Weather: typhoon days and *tag-ulan* (rainy season).
- Wall and floor painting, and second-floor building.
- Family/household: live together with friends on one lot.
- Use real meshes for the jeepney, people and furniture once you have art.

---

## Notes and limitations
- The code has **not yet been run in Roblox Studio**. Play-test it there first, and check the Output window for errors from small API mismatches.
- NPCs use Roblox's default R15 walk and idle animations. If those animation ids fail to load in your place, the NPCs will just slide (a warning is printed).
- Player actions use positioning (standing, lying, sitting on Seats) but no custom animations yet.
- Placement checks bounds and money but not overlap between furniture.
- Build mode is designed for mouse and keyboard. Touch placement works but is basic.
