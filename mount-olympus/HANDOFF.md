# Mount Olympus: Rise of the Gods — Project Handoff

This is the source of truth for continuing development. The Phase 1 code that
was originally pasted as "Part D" now lives in `src/` (see `README.md` for the
file → Roblox Explorer mapping).

---

## 0. Instructions for the AI continuing this project

You are continuing development of a Roblox game with a **beginner** developer.
Follow the master specification in **Part C** exactly, including its section 19
("How to work with me").

- The developer currently has only an **iPad** (Roblox Studio does not run on
  iPad). They test by playing the published game in the Roblox app. Builds are
  published from the cloud session with Open Cloud (see "Publishing without
  Studio" below), and server logic is checked with the Luau Execution API using
  a fake player before going live.
- Phases 1–3 are **confirmed**. Phase 4 is split: **4A (core combat)** is
  built and server-tested; **4B (god abilities Q/E/R/Dash/Form, hotbar with
  cooldowns)** comes next. Do not start Phase 5 until the developer replies
  **"Phase 4 confirmed"** after 4B.
- Luau Execution sessions do **not** simulate physics (parts don't fall,
  Humanoids don't walk), so movement/chasing must be play-tested by the developer. Build each
  phase on top of the existing code; do not rewrite earlier phases unless a bug
  requires it.
- When delivering a phase, give: complete scripts, exact Explorer placement, an
  updated `.rbxlx` place file (built with `rojo build`), step-by-step tests,
  likely errors and fixes, and a completion checklist.
- Never claim code works without the developer testing it in Studio.

---

## Part A — Current status

| Phase | Status |
|---|---|
| 1. Core Framework | **Confirmed** by the developer |
| 2. Temple Tycoon | **Confirmed** by the developer |
| 3. God Selection | **Confirmed** by the developer |
| 4A. Combat core | **Built and server-tested**, live in the game, awaiting play-testing |
| 4B. God abilities | Next |
| 5–8 | Not started |

### How to set up Phase 1 on a Mac (or Windows PC)
1. Install Roblox Studio from create.roblox.com and sign in.
2. Open the place file `MountOlympus.rbxlx` (**File → Open from File**).
   (Alternative: sync live from this repo with Rojo — see `README.md`.)
3. **File → Publish to Roblox As…** → create a new experience.
4. **Home → Game Settings → Security** → turn on **Enable Studio Access to API Services**.
5. **Game Settings → Places** → **Max Players = 8**.
6. If you built by hand from the **Baseplate** template, delete `Workspace > SpawnLocation`.
7. Open **View → Output**, press **Play**, and run the tests in Part B.

### Explorer hierarchy
```
ReplicatedStorage
└── Shared                      (Folder)
    ├── GameConfig              (ModuleScript)
    ├── Progression             (ModuleScript)
    ├── TempleConfig            (ModuleScript)   Phase 2
    ├── GodConfig               (ModuleScript)   Phase 3
    ├── CombatConfig            (ModuleScript)   Phase 4
    └── Gods                    (Folder)         Phase 3
        ├── Zeus, Ares          (ModuleScript, playable)
        └── Poseidon, Hades, Athena, Apollo  (ModuleScript, Available = false until Phase 7)

ServerScriptService
├── Main                        (Script)
└── Services                    (Folder)
    ├── DataService             (ModuleScript)
    ├── ProgressionService      (ModuleScript)
    ├── PlotService             (ModuleScript)
    ├── WorldBuilder            (ModuleScript)
    ├── TempleService           (ModuleScript)   Phase 2
    ├── TempleModels            (ModuleScript)   Phase 2
    ├── GodService              (ModuleScript)   Phase 3
    ├── EnemyService            (ModuleScript)   Phase 4
    └── CombatService           (ModuleScript)   Phase 4

StarterPlayer
└── StarterPlayerScripts
    ├── HUDController           (LocalScript)
    ├── TempleUI                (LocalScript)    Phase 2
    ├── GodUI                   (LocalScript)    Phase 3
    └── CombatController        (LocalScript)    Phase 4
StarterPlayer
└── StarterCharacterScripts
    └── Health                  (Script, empty)  Phase 4: disables Roblox's default regen
```
Created automatically at runtime: `ReplicatedStorage > Remotes` (RemoteEvents
`Notify`, `RequestTeleport`, `RequestUpgrade`, `GodAction`, `CombatAttack`,
`CombatBlock`, `CombatDash`, `CombatFX`), `Workspace > Hub` (including
`HallOfTheGods`, `PracticeField`, `PracticePath`, `PracticeSpawn`),
`Workspace > Enemies`,
`Workspace > TemplePlots` (Plot1–Plot8, each a Model with `Base`, `Sign`,
`Buildings` folder, `Pads` folder; attribute `OwnerUserId`, 0 = free).

### Design decisions made in Phase 1 (developer asked to confirm)
1. **Level cap per rank:** players stop levelling at the top of their rank's
   range (Mortal stops at 10) until they pass the ascension trial. Toggle:
   `GameConfig.Progression.LevelCappedByRank`.
2. **8 players / 8 plots per server.**
3. **Starting currencies:** 100 Gold, 0 Divine Favor, 0 Ambrosia.
4. **Placeholder XP curve:** XP to next level = `floor(100 × level^1.5)`. That's
   100 at level 1, 3,162 at 10, 100,000 at 100, about 22.5M total to level 200.
   To be balanced in Phase 8.
5. **Debug chat commands** work in Studio: `!xp N`, `!gold N`, `!favor N`,
   `!ambrosia N`, `!spend N`, `!rank`, `!save`, `!data`, `!reset`.
   **Changed (approved by the developer):** they also work in the live game for
   the game's owner only, so Phase 1 can be tested on an iPad without Studio.
   Toggle: `GameConfig.Debug.ChatCommandsForOwnerInLiveGame` — **must be set to
   false before public release.**

### Publishing without Studio
The experience is Universe `6686565007`, start place `73663368596582`. A Roblox
Open Cloud API key is saved as a network secret on this repo's Claude cloud
environment, so a session can `rojo build` and publish via
`POST https://apis.roblox.com/universes/v1/<universe>/places/<place>/versions?versionType=Published`
(Content-Type `application/xml`, body = the `.rbxlx`).

### Design decisions made in Phase 2 (developer asked to confirm)
1. **Temple tier = 1 + Temple Core level.** Core has 5 levels, so tiers 1–6
   (up to Celestial Palace) are reachable now; tier 7 Divine Citadel comes in
   Phase 7 ("full temple progression").
2. **Requirements:** a building's level N needs temple tier ≥ N. Temple Core
   level N needs character level 5 / 10 / 25 / 45 / 70.
3. **Buying:** glowing pads with a short hold-to-buy prompt (hold E, tap on
   mobile, X on controller) instead of step-on pads, to stop accidental buys.
   The Temple Upgrades menu buys the same things. Only the plot owner can buy.
4. **Income:** paid automatically every 5 s while the player is in the game.
   Treasury 30/75/180/420/900 Gold per minute; Altar 5/12/25/50/100 Favor per minute.
5. **Effects stored now, used later:** Fountain (regen %), Training Grounds
   (combat %), Statue Hall (worship %) are in `TempleConfig` and readable via
   `TempleService.GetEffect`, but take effect in Phases 3–4.
6. **Costs** (Gold, levels 1–5): Treasury 100/600/3K/15K/75K, Altar
   250/1.5K/7.5K/35K/150K, Fountain 300/2K/10K/45K/180K, Training
   400/2.5K/12K/50K/200K, Statue Hall 500/3K/15K/60K/250K, Core
   1K/8K/40K/160K/600K. Placeholders, balanced in Phase 8.
7. No save-layout change (uses the reserved `Temple.Tier` / `Temple.Buildings`),
   so `SchemaVersion` stays 1.

### Design decisions made in Phase 3 (developer asked to confirm)
1. **Blessing tree:** each god has 5 blessings, one per tier, each up to level 3.
   They map to the spec's 5 abilities (Q, Dash, E, R, Form). The abilities
   themselves are built in Phase 4; **for now each blessing gives a passive
   bonus** that works immediately for the active god only (Zeus: attack/speed,
   Ares: attack/health). Abilities of inactive gods will be blocked in Phase 4.
2. **Tier requirements:** Main Altar level 0/1/2/3/4, loyalty 0/25/100/300/800,
   rank Mortal/Mortal/Warrior/Champion/Hero. Favor costs per level: tier 1
   free/40/120, tier 2 60/150/400, tier 3 200/500/1.2K, tier 4 600/1.5K/3.5K,
   tier 5 1.5K/4K/10K.
3. **First blessing:** tier 1 level 1 is free when you choose (or switch to) a god.
4. **Loyalty** (per god, kept forever): earned by worshipping at your god's
   statue in the Hall of the Gods: +10 Favor and +10 loyalty every 30 s,
   boosted by the Statue Hall's worship bonus (so that bonus is live now).
5. **Changing god:** pick the new god in the menu (or at the Shrine of Change),
   then pray 3 times at the Shrine (20 s apart). Can be cancelled. Keeps
   levels, currencies, temple, and every god's blessings and loyalty.
6. **Temple colours:** trims, glowing parts, banner and flames use the god's
   colours (Zeus gold + blue lightning, Ares bronze + red fire). Treasury
   gold stays gold.
7. **New save fields:** `NextWorshipAt`, `GodChange { Target, Prayers,
   NextPrayerAt }` (added to defaults, filled in for old saves; `SchemaVersion`
   stays 1).
8. New test command: `!loyalty N`.

### Design decisions made in Phase 4A (developer asked to confirm)
1. **Practice Field** behind the plaza spawn (new "Practice" travel button): 3
   wooden Training Dummies (500 HP, wobble when hit, never die — a knockout
   pops them straight back up — heal after 3 s, no rewards), 3 Bandits
   (respawn 6 s), 2 Skeletons (respawn 7 s). Enemy bodies are built once per
   type and cloned, so spawns are instant. Arenas replace this in Phase 5.
2. **Controls:** attack = left click / R2 / on-screen Attack; block = hold F /
   L2 / hold on-screen Block (70% less damage, half speed, can't attack);
   dash = Left Shift / B / on-screen Dash (2 s cooldown, 0.3 s where you can't
   be hit). Q/E/R stay free for the god abilities (Phase 4B).
3. **Damage** = BaseAttack (level + blessings) × (1 + Training Grounds
   combat bonus), ±10%. Swing every 0.45 s, hits up to 3 enemies in front.
4. **Enemies:** Bandit 60 HP / 8 dmg / 25 XP / 10 Gold; Skeleton 45 HP / 10
   dmg / 35 XP / 14 Gold. They glow red with a red ring for 0.6–0.7 s before
   each hit, chase within 22 studs, give up and heal if pulled 55 studs from
   spawn, and heal only after 4 s without being hit. Every player who damaged
   an enemy gets the full reward once.
5. **Regeneration:** Roblox's default is replaced: 1% max HP per second after
   5 s without damage, × (1 + Divine Fountain bonus) — so the Fountain is live.
6. **Death:** respawn after 4 s at the plaza; nothing is lost.
7. **Animations and sword (revised after developer feedback: "no sword,
   rough animation, laggy, dummies don't react"):**
   - The sword (`Shared/SwordBuilder`) is welded into the right hand (no Tool:
     disabling the Backpack UI auto-unequips tools, which hid the first sword).
     Gem, glowing fuller and swing trail use the god colour.
   - Our own animations (`Shared/SwordPoses`, joint angles) are played by
     `Shared/SwordAnimator` on every device every frame (PreSimulation, after
     Roblox's animations): ready stance while holding a weapon, guard while
     `Blocking`, and a Slash1 → Slash2 → Lunge combo. Other players' swings
     arrive as `CombatFX("Swing", player, moveName)`; enemies raise and swing
     their weapon via `CombatFX("EnemyAttack", pos, model, windup)`.
     Preview: `docs/sword-poses-preview.png` (rendered from the real rig).
   - Lag fixes: no `Highlight` on attacking enemies (weapon turns neon red
     instead); dummy wobble moved from the server to each device.
   - Hit reactions: enemies flash white (a 0.18 s client Highlight), get
     knocked back (a 0.15 s LinearVelocity push) and stagger 0.3 s; dummies
     wobble. Your own hits react instantly (predicted locally).
   - Second fix round: real avatars replace their body parts when their
     appearance loads, which destroyed the hand the sword was welded to. The
     server now (re)attaches the sword on `CharacterAppearanceLoaded` and
     checks every second that it is still held. Enemies no longer snap their
     rotation while waiting to attack (looked jerky / laggy).

### Build label and update restarts
- `GameConfig.BuildLabel` (e.g. "v13") is shown bottom-left. **Bump it to the
  Roblox version number with every publish.**
- Servers listen on the MessagingService topic `OlympusUpdate`; a message whose
  data is a version number newer than the server's `game.PlaceVersion` kicks
  everyone with "please rejoin". Send it after publishing:
  `POST https://apis.roblox.com/messaging-service/v1/universes/6686565007/topics/OlympusUpdate`
  body `{"message":"<new version>"}` (needs the API key permission
  `universe-messaging-service` → publish).

### Ideas from the developer for later (not built yet)
- **Rank outfits and physique (Phase 6, Ascension):** each ascension rank gets
  its own outfit, and the character gets bigger with a more powerful physique
  as they rank up. The spec already gives each ascension "a visual
  transformation or aura", so this belongs there. Ask the developer then:
  whether outfits replace or layer over the player's own avatar, and how much
  bigger (Roblox body scales: `BodyHeightScale`, `BodyWidthScale`,
  `BodyDepthScale`, `HeadScale` via `HumanoidDescription`). Use original
  models/clothing, not unverified Toolbox assets.

---

## Part B4A — Phase 4A tests
- **Practice button** takes you to the Practice Field; enemies have name + health bars.
- **Attack** a Training Dummy: yellow damage numbers, sparks, a glowing swing; it heals after 3 s.
- **Bandit:** walks to you, glows red with a red ring, then hits you (red numbers, health bar drops).
- **Block** (hold): blue bubble, blue "(blocked)" numbers, smaller hits, slower walking.
- **Dash** through an attack: "Dodged!".
- **Kill** a bandit: "+25 XP +10 Gold" floats up; it respawns after ~10 s.
- **Run away** ~55 studs: enemies give up and go home.
- **Die:** respawn at the plaza after 4 s with everything kept.
- **Regen:** after 5 s without damage your health refills slowly (faster with the Divine Fountain).
- **iPad:** round Attack (left of Jump, hold to keep swinging), Block (above Attack, hold) and Dash (above Jump) buttons, none overlapping Jump; health bar bottom centre.

## Part B3 — Phase 3 tests
- **Intro:** joining without a god shows "Choose Your God" with 6 cards; only Zeus and Ares can be picked.
- **Choice:** picking Zeus closes the screen, shows a Zeus badge (top right), and your temple turns blue/gold.
- **Menu:** tapping the badge opens Gods & Blessings: Lightning Strike Lv 1, bonus +3% attack.
- **Locks:** Thunder Dash says "Needs Main Altar level 1", then "Needs 25 loyalty".
- **Worship:** at Zeus's statue in the Hall of the Gods (left of spawn): +10 Favor, +10 Loyalty; again too soon says "wait".
- **Upgrade:** `!loyalty 50`, `!favor 500`, build the Main Altar, then unlock Thunder Dash: you walk a bit faster.
- **Change god:** start switching to Ares, pray 3 times at the purple Shrine of Change (20 s apart): Ares badge, red/bronze temple, Zeus progress kept.
- **Saving:** leave and rejoin: god, blessings, loyalty and worship timer are kept.

---

## Part B2 — Phase 2 tests
- **Start:** your plot shows the Ruined Shrine and 6 glowing pads with labels. Gold Treasury pad is green ("Build Gold Treasury / 100 Gold").
- **Build:** hold the prompt on the Treasury pad: Gold drops to 0 and the Treasury rises out of the ground with gold sparkles.
- **Income:** Gold goes up by about 2–3 every 5 seconds (30/min).
- **Locks:** Treasury level 2 says "Needs temple tier 2"; Temple Core says "Reach character level 5".
- **Tier up:** `!xp 2000`, `!gold 1000`, buy Temple Core: the shrine is replaced by the Sacred Sanctuary.
- **Menu:** "Temple Upgrades" button opens the menu; levels, effects and costs match the pads; buttons buy.
- **Saving:** leave and rejoin: everything you built is rebuilt (possibly on a different plot).
- **Others:** another player cannot buy on your plot ("This is not your temple").

---

## Part B — Phase 1 tests (abbreviated)
- **A Startup:** no red errors. A loading screen, then the marble plaza; HUD shows Lv. 1, Mortal, 0/100 XP, 100 Gold.
- **B Travel:** "My Temple" and "Plaza" buttons teleport; spamming them is rate-limited.
- **C XP:** `!xp 100` levels you up with a pop-up and MaxHealth 110; `!xp 999999` caps you at level 10 with "trial ready".
- **D Ranks:** `!rank` at level 10 makes you a Warrior at level 11; below the cap it is refused.
- **E Currency:** `!gold`, `!spend` work; overspending is refused; negative or garbage values are ignored.
- **F Saving (most important):** Stop → Play restores progress, with and without `!save`.
- **G Multiplayer:** Test → Clients and Servers → 2 players. Separate plots and currencies; a plot frees when its player leaves.
- **H Load failure:** with API access off you're kicked and nothing is wiped; turn it back on and the data is still there.
- **I Mobile:** the Device emulator on a phone shows a readable HUD that doesn't overlap the controls.

---

## Part C-1 — How the existing code works (for building later phases)

**Rule:** all gameplay changes happen on the server. Clients only send requests;
the server validates them.

**DataService** (server) — session-locked DataStore saving.
- `GetData(player)` → the live data table, or **nil if not safely loaded** (always check for nil).
- `SaveNow(player)`, `ReleasePlayer(player)`, `ResetData(player)`, `LoadPlayer(player)`.
- To change the save layout: add a step to `Migrations` and increase
  `GameConfig.Data.SchemaVersion`. New fields added to `makeDefaultData()` are
  filled in automatically for old saves.
- Save layout already reserves: `SelectedGod`, `GodLoyalty`, `Blessings`,
  `Temple.Tier`, `Temple.Buildings`, `Inventory.Items`, `Inventory.EquippedWeapon`,
  `Quests.Active/Completed/LastDailyReset`, `CompletedTrials`, `Stats`, `Settings`.

**ProgressionService** (server) — the only place XP, levels, ranks and currencies change.
- `AddXP(player, amount, source)`
- `AddCurrency(player, "Gold" | "DivineFavor" | "Ambrosia", amount, source)`
- `CanAfford(player, currency, amount)`, `SpendCurrency(player, currency, amount)`
  → true/false (check and subtract happen with no yield in between).
- `AdvanceRank(player, trialId)` → true/false, message. Phase 6 calls this when a trial is won.
- `Refresh(player)` pushes values to Player Attributes: `Level, XP, XPToNext,
  RankIndex, RankName, LevelCap, TrialReady, BaseAttack, Gold, DivineFavor,
  Ambrosia, DataLoaded, PlotName`.

**PlotService** (server) — `AssignPlot`, `ReleasePlot`, `GetPlot(player)`,
`TeleportPlayer(player, "Temple" | "Plaza")`. Release clears the plot's
`Buildings` and `Pads` (visual only; saved data is untouched).

**TempleService** (server, Phase 2) — `SetupPlayer(player, plot)` rebuilds the
temple from `data.Temple` and creates pads; `ReleasePlayer`, `Rebuild` (after
`!reset`), `RequestUpgrade(player, buildingId)` (all validation lives here),
`GetEffect(player, effectName)`, `PayIncome(seconds)`. Publishes attributes
`TempleTier, TempleTierName, Temple_<BuildingId>, GoldPerMinute, FavorPerMinute`.
Phase 3 should colour the temple by god by passing a palette into `TempleModels`.

**TempleModels** (server, Phase 2) — placeholder models: `Temple(tier, origin)`,
`Building(id, level, origin)`, `AnimateIn(model)`.

**GodService** (server, Phase 3) — `ChooseFirstGod`, `UpgradeBlessing`,
`Worship`, `StartGodChange`, `CancelGodChange`, `Pray`, `GetBonuses(player)`
(→ `{AttackPercent, HealthPercent, SpeedPercent}` for the active god),
`GetColors(player)`, `BuildHall()`. It registers itself with
`ProgressionService.SetBonusProvider` (health/speed/attack are applied there)
and `TempleService.SetColorProvider`. Attributes: `SelectedGod, Loyalty,
Blessing_<Id>, GodChangeTarget, GodChangePrayers, NextPrayerAt, NextWorshipAt,
BonusAttackPercent, BonusHealthPercent, BonusSpeedPercent`.
**Phase 4:** abilities should check `data.SelectedGod` and the blessing level
(`data.Blessings[god][blessingId]`); each blessing's `Ability` field says
which control it uses.

**CombatService** (server, Phase 4) — `BasicAttack`, `Dash`,
`DamagePlayer(player, amount, sourcePos)` (applies block / dash
invulnerability), regen loop. State per player: attack/dash cooldowns,
`Blocking` (also a player attribute).

**EnemyService** (server, Phase 4) — `Spawn(type, cframe, {HealthMultiplier,
DamageMultiplier, RewardMultiplier, OnDeath})`, `DamageEnemy(model, amount,
player)`, `GetEnemiesInRange(pos, range)`, `SpawnPracticeField()`. Rewards go
to all contributors once. **Phase 4B abilities** should damage via
`EnemyService.DamageEnemy` and find targets with `GetEnemiesInRange`.
**Phase 5 arenas** should spawn waves with `Spawn(..., {OnDeath = ...})`.

**CombatFX remote** (server → clients): `("Damage", pos, amount, style)`,
`("Hit", pos)`, `("Death", pos)`, `("Reward", pos, text)`.

**GodConfig + Gods/** (shared, Phase 3) — one module per god (colours,
blessings with `Tier`, `Ability`, `Passive`); `GodConfig` holds tier rules,
worship and god-change settings and `GetBlessingUpgradeInfo`.

**TempleConfig** (shared, Phase 2) — buildings, costs, effects, slots, tiers,
and `GetUpgradeInfo` (the purchase rules, shared by server and menu).

**Notify remote** (server → client): `FireClient(player, "LevelUp" | "RankUp" | "Message", value)` shows a pop-up.

**GameConfig** holds all tunable values. Later phases should add their config
tables here (or in new config modules in `ReplicatedStorage > Shared`).

---

## Part C-2 — Plan for the remaining phases

**Phase 2 — Temple Tycoon**
- Glowing purchase pads on the owner's plot (only the owner can buy; validated by plot `OwnerUserId`).
- Config table of buildings (Main Altar, Gold Treasury, Training Grounds, Statue
  Hall, Divine Fountain, Temple Core): 5 levels each, cost, required temple
  tier, effects, placeholder models.
- Automatic construction with a simple rise/fade animation.
- Server-side passive income: Treasury → Gold, Altar → Divine Favor, only while
  the player is in the game. Passive income must not replace combat.
- Temple Core raises the temple tier (7 tiers: Ruined Shrine → Divine Citadel)
  and changes the temple's appearance.
- Saved in `data.Temple`; the temple rebuilds when the player joins any server.
- Temple upgrade UI.

**Phase 3 — God Selection**
- Hall of the Gods interface; first god chosen in the intro.
- Zeus and Ares functional first; the other 4 come in Phase 7. The system must
  be modular (god config modules).
- God loyalty, Divine Favor costs, a blessing tree per god, altar-tier gating,
  a god-change shrine and quest (keeps levels, resources and temple).
- Temple colours adapt to the chosen god.

**Phase 4 — Combat**
- Third-person combat: LMB basic attack, Q/E abilities, R ultimate, dash, block.
  Mobile on-screen buttons and controller support.
- Server-validated damage, cooldowns and rewards; client handles input, animation and VFX.
- Enemy AI (chase, attack, telegraphs), health, damage numbers, hit effects, death and respawn.

**Phase 5 — Arenas**
- Arena Gate menu; solo or party entry; 5 waves plus a boss; remaining-enemy tracker.
- Party-size scaling; victory screen; reduced rewards on failure; return to hub.
- Config-driven arenas and enemies. First arena: Mortal Training Pit (levels
  1–15) with the Training Champion boss.

**Phase 6 — Ascension**
- Ascension Chamber UI; trials per rank (Training Champion, Spartan Arena,
  Minotaur, God's Divine Trial, Cerberus, Olympian Gauntlet, Titan King).
- Calls `ProgressionService.AdvanceRank`; rank auras and transformations; area unlock restrictions.
- **Developer request:** an outfit per rank, and the character grows bigger
  with a better physique each rank (see "Ideas from the developer" above).

**Phase 7 — Content Expansion** (may be split into sub-phases)
- Poseidon, Hades, Athena and Apollo; arenas 2–6; bosses Minotaur, Medusa, Cerberus and Titan King.
- Full temple progression to Divine Citadel.
- Weapons (Common → Divine), a persistent duplicate-proof inventory, the Divine Forge.
- Quest system (combat, temple, worship, boss, god, daily, ascension).
- Endgame: Divine Mastery, Temple Prestige, Olympian Challenges, Divine Incarnations.

**Phase 8 — Polish and Release**
- Final UI, VFX, sound, animations, mobile optimisation, multiplayer testing,
  economy balancing (including the XP curve), bug fixing, performance.

---

## Part C — Original master specification (verbatim)

```text
MOUNT OLYMPUS: RISE OF THE GODS

MASTER ROBLOX GAME DEVELOPMENT PROMPT

1. YOUR ROLE

You are an expert Roblox game development AI with extensive experience in Roblox Studio, Luau programming, multiplayer architecture, tycoon systems, RPG progression, PvE combat, enemy artificial intelligence, game environments, UI design, animation, and persistent player data.

Your task is to help me develop a complete, playable, polished Roblox game called Mount Olympus: Rise of the Gods.

I am a beginner at Roblox development. You must guide me through the entire development process, including writing scripts, constructing environments, creating interfaces, organizing Roblox Studio, and testing features.

The game should eventually be fully playable, multiplayer-compatible, mobile-friendly, visually appealing, and suitable for public release on Roblox.

Important instructions:

* Follow the design specifications below.
* Do not add major new gameplay systems without asking.
* Build the game in manageable development stages.
* Provide complete scripts rather than incomplete code snippets.
* Explain exactly where each script and object belongs.
* Avoid unnecessary complexity.
* Prioritize working gameplay and reliable systems.
* Clearly identify anything that requires manual work in Roblox Studio.
* Never assume code or a feature works without testing.
* Do not move to the next development stage until the current one has been implemented and tested.

⸻

2. GAME OVERVIEW

Title: Mount Olympus: Rise of the Gods

Genre: Greek Mythology RPG / Temple Tycoon / PvE Adventure

Platform: Roblox

Primary gameplay: PvE combat, temple construction, character progression, divine blessings, boss battles, and ascension.

Target progression time: Approximately 10–20 hours of active gameplay to reach godhood.

Visual style: Stylized, colorful, polished 3D Greek mythology with white marble architecture, golden decorations, magical effects, glowing weapons, and Mount Olympus environments.

Main concept

Every player begins as an ordinary Mortal arriving at Mount Olympus.

Players choose a Greek god to worship, receive their first divine blessing, and claim a ruined temple.

Through battles, quests, offerings, and temple upgrades, they become progressively more powerful.

Players unlock divine abilities, construct increasingly impressive temples, defeat mythological monsters, and advance through eight ascension ranks.

Their ultimate objective is to become an Elder God, construct a Divine Citadel, and dominate challenging endgame PvE encounters.

⸻

3. CORE GAMEPLAY LOOP

The fundamental gameplay loop is:

1. Claim a temple and choose a god.
2. Earn Gold and Divine Favor.
3. Purchase temple upgrades.
4. Unlock and improve divine blessings.
5. Enter PvE combat arenas.
6. Defeat enemies and bosses.
7. Earn experience, equipment, and rewards.
8. Complete ascension trials.
9. Unlock additional arenas and temple upgrades.
10. Repeat until achieving godhood.

Players should constantly have meaningful short-term and long-term objectives.

⸻

4. CENTRAL HUB AND WORLD DESIGN

The game takes place around a large central hub called The Olympus Sanctuary.

The world should feature:

* Ancient Greek architecture.
* White marble buildings.
* Gold decorations.
* Statues of Greek gods.
* Mountains and clouds.
* Magical portals.
* Temple plots belonging to players.
* Mythological atmosphere and environmental effects.

Main areas

Olympus Plaza: Main spawn area with tutorial NPCs, quest boards, and information.

Temple District: Contains private player temple plots, each assigned to one player per server.

Hall of the Gods: Players select or change their chosen god.

Arena Gate: Allows players to enter PvE combat arenas.

Titan Gate: Allows players to challenge powerful bosses.

Divine Forge: Players obtain and upgrade weapons.

Ascension Chamber: Players complete trials to advance their ascension rank.

Olympus Market: Contains cosmetics and basic supplies.

All regions should initially exist within one Roblox place, using designated areas and teleportation between them rather than separate servers.

Players must never be able to permanently modify another player’s temple.

⸻

5. GREEK GOD SELECTION SYSTEM

Players choose one of six Greek gods.

Each god has distinct abilities, visual effects, and combat specialties.

Zeus — God of Thunder

Specialty: Lightning and burst damage.

Abilities:

* Lightning Strike
* Thunder Dash
* Chain Lightning
* Wrath of Olympus
* Ascended Thunder Form

Theme: Gold, blue lightning, glowing electricity.

Poseidon — God of the Sea

Specialty: Water damage and crowd control.

Abilities:

* Water Blast
* Tidal Dash
* Whirlpool
* Divine Tsunami
* Oceanic Ascension

Theme: Blue, aqua, water effects.

Hades — God of the Underworld

Specialty: Shadow damage, life stealing, and summoning.

Abilities:

* Shadow Strike
* Soul Drain
* Summon Undead
* Army of the Dead
* Underworld Ascension

Theme: Black, purple, spectral flames.

Ares — God of War

Specialty: Melee combat and aggressive damage.

Abilities:

* War Slash
* Battle Charge
* Berserker Rage
* God of War
* Divine Warlord Form

Theme: Red, bronze, fire.

Athena — Goddess of Wisdom

Specialty: Defense, precision, and counterattacks.

Abilities:

* Spear Strike
* Divine Shield
* Counterattack
* Aegis of Olympus
* Divine Guardian Form

Theme: White, gold, silver.

Apollo — God of the Sun

Specialty: Ranged damage and healing.

Abilities:

* Solar Arrow
* Radiant Dash
* Healing Light
* Solar Judgment
* Sun God Form

Theme: Gold, yellow, radiant light.

God system rules

* Players select their first god during the introduction.
* Only one god can be actively worshipped at a time.
* Each god has a separate blessing progression tree.
* God loyalty determines blessing eligibility.
* Divine Favor is spent to unlock and upgrade blessings.
* Temple altar upgrades unlock additional blessing tiers.
* Advanced blessings also require specific ascension ranks.
* Players may change gods through a special shrine and quest.
* Changing gods preserves character levels, resources, and temple upgrades.
* Abilities belonging to inactive gods cannot be used.
* Combat power should be balanced between gods.

The system must be modular so additional gods can be introduced later.

⸻

6. TEMPLE TYCOON SYSTEM

Every player receives a private temple plot when joining.

Initially, the temple is a small ruined shrine.

Players purchase glowing upgrade pads that automatically construct buildings, add decorations, and improve their temple.

Temple progression

Tier	Name	Visual progression
1	Ruined Shrine	Small broken altar
2	Sacred Sanctuary	Basic restored columns
3	Temple of Devotion	Marble temple
4	Blessed Temple	Larger temple with divine decorations
5	Grand Pantheon	Monumental temple with glowing statues
6	Celestial Palace	Floating structures and golden architecture
7	Divine Citadel	Massive god-tier palace

Temple structures

Main Altar

* Generates Divine Favor through worship.
* Unlocks higher blessing tiers.
* Improves offering rewards.

Gold Treasury

* Generates Gold passively while the player is active.
* Produces more Gold as upgraded.

Training Grounds

* Unlocks combat-related upgrades.
* Improves equipment progression.

Statue Hall

* Displays mythological statues and achievements.
* Improves worship rewards.

Divine Fountain

* Improves health and energy regeneration.

Temple Core

* Upgrades the overall temple tier.
* Unlocks more construction options.
* Changes the temple’s appearance.

Temple mechanics

* Buildings have five upgrade levels.
* Upgrades require Gold and sometimes additional progression requirements.
* Higher temple tiers unlock stronger buildings.
* Building upgrades are saved permanently.
* Buildings automatically construct after purchase.
* Construction should include basic visual animations.
* Temple colors and decorations adapt to the selected god.
* Income must be calculated securely on the server.
* Players cannot purchase upgrades they cannot afford.
* Temple plots reset visually when a player leaves but their purchased upgrades remain saved.
* Their temple reconstructs when they return to another server.

The temple system should be easy to expand using configuration tables containing costs, requirements, models, and effects.

⸻

7. CHARACTER LEVELS AND ASCENSION

Players begin at level 1.

The maximum character level is 200.

Players earn experience from combat, quests, bosses, and other activities.

Leveling automatically increases maximum health and base attack strength.

Ascension ranks

Rank	Level range
Mortal	1–10
Warrior	11–25
Champion	26–45
Hero	46–70
Demigod	71–100
Lesser God	101–140
Olympian	141–180
Elder God	181–200

Ranks are not awarded automatically.

Players must reach the required level and complete an ascension trial.

Required trials

* Warrior: Defeat the Training Champion.
* Champion: Complete the Spartan Arena trial.
* Hero: Defeat the Minotaur.
* Demigod: Complete a divine trial for the player’s selected god.
* Lesser God: Defeat Cerberus.
* Olympian: Complete the Olympian Gauntlet.
* Elder God: Defeat the Titan King.

Each ascension grants:

* A new rank title.
* Access to higher-level areas.
* New blessing opportunities.
* A visual transformation or aura.
* Improved character power.

Players should not lose progress when changing servers or dying.

The experience curve should support reaching godhood in approximately 10–20 hours of active gameplay, subject to balancing and testing.

⸻

8. COMBAT SYSTEM

Combat is primarily PvE.

The game uses third-person action combat.

Basic controls

* Left mouse button: Basic attack.
* Q: Divine Ability 1.
* E: Divine Ability 2.
* R: Ultimate ability.
* Additional controls: Dash, block, jump, and weapon switching.

Provide equivalent on-screen controls for mobile players and reasonable controller support.

Combat features

* Melee weapons.
* Ranged attacks.
* Divine abilities.
* Ability cooldowns.
* Health and damage systems.
* Enemy attack animations.
* Damage indicators.
* Basic hit effects.
* Blocking and dodging.
* Enemy death and respawn systems.

All damage, cooldowns, and rewards must be validated by the server.

Client scripts should handle input, UI, animations, and visual effects.

The combat system must work in multiplayer and prevent players from awarding themselves damage, rewards, or abilities.

⸻

9. PvE ARENA SYSTEM

Players enter arenas through the central hub.

Arenas contain five waves of enemies with a final miniboss or boss.

A typical completed arena run should take around 3–6 minutes.

Arena progression

Arena 1: Mortal Training Pit
Levels 1–15.
Enemies: Bandits and skeletons.

Arena 2: Spartan Battleground
Levels 16–35.
Enemies: Armored soldiers and beasts.

Arena 3: Labyrinth of Crete
Levels 36–60.
Enemies: Minotaurs and guardians.

Arena 4: Cursed Temple
Levels 61–90.
Enemies: Gorgons and cursed warriors.

Arena 5: Gates of the Underworld
Levels 91–135.
Enemies: Undead and underworld monsters.

Arena 6: Titan’s Colosseum
Levels 136–200.
Enemies: Titan warriors and divine monsters.

Arena requirements

* Players can enter alone or in cooperative groups.
* Enemy waves spawn automatically.
* Players can track remaining enemies.
* Bosses spawn during final waves.
* Completing an arena awards Gold, XP, and possible equipment.
* Higher-level arenas provide better rewards.
* Arena difficulty adjusts moderately for party size.
* A victory screen displays rewards.
* Players return to the central hub after completion.
* Failed runs provide reduced rewards where appropriate.

The arena system must be configurable so new arenas and enemies can be added without rewriting the core system.

⸻

10. BOSSES AND MYTHOLOGICAL ENEMIES

Include bosses based on Greek mythology.

Initial major bosses:

* Training Champion
* Minotaur
* Medusa
* Cerberus
* Titan King, inspired by Cronus

Bosses should have:

* Unique health values.
* Distinct attacks and cooldowns.
* Clear attack warnings.
* Multiple attacks or phases.
* Boss health bars.
* Unique rewards.
* Death animations and effects.

Higher-level bosses should feel substantially more difficult without relying solely on enormous health pools.

Some bosses may be fought cooperatively.

⸻

11. CURRENCIES AND ECONOMY

Implement three currencies.

Gold

Earned from combat, quests, arena completion, and the Gold Treasury.

Used for temple upgrades, equipment, and construction.

Divine Favor

Earned from worship, god quests, offerings, and the Main Altar.

Used for unlocking and upgrading divine abilities.

Ambrosia

Earned through difficult bosses and ascension challenges.

Used for rare crafting and high-level upgrades.

Economy requirements

* Currency balances must save between sessions.
* Purchases are validated on the server.
* Rewards must not be granted multiple times through exploits.
* Upgrade prices should scale with progression.
* Passive Gold production should not eliminate the need to fight enemies.
* The economy should support fast but meaningful progression.
* Prices and reward amounts should be controlled through configuration modules.

⸻

12. QUEST SYSTEM

Implement a quest system with multiple objective types.

Quest categories:

* Combat quests.
* Temple upgrade quests.
* Worship and offering quests.
* Boss quests.
* God-specific divine quests.
* Daily quests.
* Ascension quests.

The UI should show active objectives, progress, and completion rewards.

Completed quests should be claimable through the interface when appropriate.

Quest rewards may include experience, Gold, Divine Favor, equipment, and other progression items.

Quest progress must be validated by the server.

⸻

13. WEAPON AND INVENTORY SYSTEM

Players can obtain weapons through quests, bosses, and crafting.

Weapons have rarity levels:

* Common
* Uncommon
* Rare
* Epic
* Legendary
* Divine

Each weapon can have configurable damage, attack speed, visual effects, and special attributes.

Weapon designs should reflect Greek mythology.

Examples include swords, spears, tridents, bows, and divine weapons.

Players have a persistent inventory, can equip compatible weapons, and cannot duplicate items.

The initial weapon system should be simple, with more advanced effects added in later development stages.

⸻

14. USER INTERFACE

Design a polished, readable Roblox interface.

Required elements:

* Health bar.
* Experience bar.
* Level and ascension rank.
* Gold and Divine Favor counters.
* Equipped god indicator.
* Ability hotbar and cooldown displays.
* Quest tracker.
* Temple upgrade interface.
* Blessing menu.
* Inventory.
* Arena selection menu.
* Boss health bar.
* Ascension trial interface.
* Settings menu.

The visual theme should match Greek mythology, using stone, marble, bronze, gold, and colors corresponding to the gods.

The interface must adapt to PC and mobile screen sizes.

Important information should remain visible without obstructing gameplay.

⸻

15. ENDGAME CONTENT

After reaching Elder God, players can continue progression through:

Divine Mastery: Earn mastery experience for the selected god and unlock cosmetics, visual effects, and limited additional bonuses.

Temple Prestige: Continue improving the appearance and prestige of the temple without resetting character levels.

Olympian Challenges: Replay difficult boss encounters and participate in challenging PvE encounters.

Divine Incarnations: Unlock spectacular temporary divine transformations.

Endgame content should reward skilled play and continued participation without making lower-level players irrelevant.

⸻

16. MULTIPLAYER AND DATA SAVING

The game must support multiple players per server.

Each player requires:

* A unique active temple plot.
* Individual saved progress.
* Independent currencies and inventory.
* Their own selected god.
* Their own blessing progression.
* Their own ascension rank.

Use Roblox DataStoreService for persistent data.

Include:

* Safe loading and saving.
* Periodic autosaving.
* Saving when players leave.
* Appropriate shutdown handling.
* Error handling and retry behavior.
* Schema versioning for future updates.
* Protection against duplicated rewards and race conditions.
* Appropriate handling when player data cannot load safely.

Do not allow destructive overwrites with empty default data when a save fails to load.

Combat, purchases, temple upgrades, and rewards must be server-authoritative.

⸻

17. VISUAL AND AUDIO DIRECTION

The game should feel like a colorful, magical interpretation of ancient Greece.

Visual priorities:

* Strong Greek architecture.
* Beautiful central hub.
* Visible temple progression.
* Distinct god colors and effects.
* Readable enemy attacks.
* Impressive transformations.
* Satisfying construction animations.
* Clear visual feedback when receiving rewards.

Use optimized Roblox parts, meshes, materials, particles, and lighting.

Prefer original or properly licensed assets, and do not depend on unverified third-party toolbox models.

Maintain good performance on typical mobile devices.

⸻

18. DEVELOPMENT ROADMAP

Build the game in eight phases.

Phase 1 — Core Framework

* Roblox Studio project structure.
* Player data schema.
* Saving and loading.
* Experience and leveling.
* Gold and Divine Favor.
* Basic central hub placeholder.
* Player temple plot assignment.

Phase 2 — Temple Tycoon

* Upgrade purchase pads.
* Automatic building construction.
* Temple income systems.
* Temple tier progression.
* Saved building upgrades.

Phase 3 — God Selection

* God selection interface.
* Zeus and Ares as initial functional gods.
* Divine Favor requirements.
* Basic blessing progression.

Phase 4 — Combat

* Basic attacks.
* Divine abilities.
* Enemy AI.
* Health and damage.
* Combat rewards.

Phase 5 — Arenas

* Arena entry.
* Enemy waves.
* Wave progression.
* Arena completion rewards.
* First boss.

Phase 6 — Ascension

* Ascension ranks.
* Level and trial requirements.
* Rank progression.
* Transformation effects.
* Unlock restrictions.

Phase 7 — Content Expansion

* Remaining gods.
* Additional enemies.
* Remaining arenas.
* Full temple progression.
* Weapons and inventory.
* Quests.
* Endgame systems.

Phase 8 — Polish and Release

* Final UI improvements.
* Visual effects.
* Sound effects.
* Animations.
* Mobile optimization.
* Multiplayer testing.
* Economy balancing.
* Bug fixing.
* Performance optimization.

⸻

19. HOW TO WORK WITH ME

I am a beginner, so I need detailed but straightforward instructions.

For each development phase:

1. Explain the objective.
2. List the Roblox Studio objects that must be created.
3. Provide the exact Explorer hierarchy.
4. Write complete Luau scripts.
5. Identify each script’s exact name and placement.
6. Explain any required properties or settings.
7. Explain what should happen when the game runs.
8. Provide step-by-step testing instructions.
9. Describe likely errors and how to fix them.
10. Give a completion checklist before proceeding.

When creating or modifying code, keep scripts organized and reusable.

When changing existing scripts, provide the complete updated script or clearly identified changes, and explain what should be replaced.

Do not silently change existing design decisions.

Use placeholder buildings, UI, and effects where appropriate during early development. Replace them with polished assets later.

Prioritize a working and testable project over excessive complexity.

⸻

20. FINAL OBJECTIVE

The final result should be a complete Roblox game in which a player can:

* Join Mount Olympus.
* Choose a Greek god.
* Claim and upgrade a temple.
* Generate and earn resources.
* Unlock powerful blessings.
* Fight mythological enemies.
* Enter PvE arenas.
* Defeat bosses.
* Earn weapons and rewards.
* Progress through 200 character levels.
* Complete eight ascension ranks.
* Become an Elder God.
* Build a Divine Citadel.
* Participate in challenging endgame activities.
* Leave and return without losing progress.

The game should feel exciting, rewarding, responsive, and visually impressive.

BEGIN DEVELOPMENT:

First, review the complete specification and produce a practical Phase 1 implementation plan.

Then begin implementing the foundational systems using complete Luau scripts and step-by-step Roblox Studio instructions.

Do not begin developing later phases until Phase 1 is tested and confirmed operational.
```
