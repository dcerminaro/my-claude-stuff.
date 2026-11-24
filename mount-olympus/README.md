# Mount Olympus: Rise of the Gods

A Greek mythology RPG / temple tycoon for Roblox.

- **Status:** Phases 1–3 and 4A confirmed by the developer. Phase 4B (god abilities) built, server-tested on Roblox, awaiting play-testing.
- **Full design spec, decisions, and roadmap:** [`HANDOFF.md`](HANDOFF.md).

## Fastest way to try it (no tools needed)

1. On a Mac or Windows PC, download **`MountOlympus.rbxlx`** from this folder.
2. In Roblox Studio: **File → Open from File** → choose it.
3. **File → Publish to Roblox As…** → create a new experience.
4. **Home → Game Settings → Security** → turn on **Enable Studio Access to API Services**.
5. **Game Settings → Places** → **Max Players = 8**.
6. **View → Output**, press **Play**, and run the tests in `HANDOFF.md` Part B.

## Where each file goes in Roblox Studio

| File in this repo | Roblox Explorer location | Type |
|---|---|---|
| `src/shared/GameConfig.luau` | ReplicatedStorage › Shared › GameConfig | ModuleScript |
| `src/shared/Progression.luau` | ReplicatedStorage › Shared › Progression | ModuleScript |
| `src/shared/TempleConfig.luau` | ReplicatedStorage › Shared › TempleConfig | ModuleScript |
| `src/shared/AbilityConfig.luau` | ReplicatedStorage › Shared › AbilityConfig | ModuleScript |
| `src/shared/SwordBuilder.luau`, `SwordPoses.luau`, `SwordAnimator.luau` | ReplicatedStorage › Shared › (same names) | ModuleScript |
| `src/shared/CombatConfig.luau` | ReplicatedStorage › Shared › CombatConfig | ModuleScript |
| `src/shared/GodConfig.luau` | ReplicatedStorage › Shared › GodConfig | ModuleScript |
| `src/shared/Gods/*.luau` (Zeus, Ares, Poseidon, Hades, Athena, Apollo) | ReplicatedStorage › Shared › Gods › *(one per god)* | ModuleScript |
| `src/server/Main.server.luau` | ServerScriptService › Main | Script |
| `src/server/Services/DataService.luau` | ServerScriptService › Services › DataService | ModuleScript |
| `src/server/Services/ProgressionService.luau` | ServerScriptService › Services › ProgressionService | ModuleScript |
| `src/server/Services/PlotService.luau` | ServerScriptService › Services › PlotService | ModuleScript |
| `src/server/Services/WorldBuilder.luau` | ServerScriptService › Services › WorldBuilder | ModuleScript |
| `src/server/Services/TempleService.luau` | ServerScriptService › Services › TempleService | ModuleScript |
| `src/server/Services/TempleModels.luau` | ServerScriptService › Services › TempleModels | ModuleScript |
| `src/server/Services/GodService.luau` | ServerScriptService › Services › GodService | ModuleScript |
| `src/server/Services/EnemyService.luau` | ServerScriptService › Services › EnemyService | ModuleScript |
| `src/server/Services/CombatService.luau` | ServerScriptService › Services › CombatService | ModuleScript |
| `src/server/Services/AbilityService.luau` | ServerScriptService › Services › AbilityService | ModuleScript |
| `src/server/Services/DiagnosticsService.luau` | ServerScriptService › Services › DiagnosticsService | ModuleScript |
| `src/client/HUDController.client.luau` | StarterPlayer › StarterPlayerScripts › HUDController | LocalScript |
| `src/client/TempleUI.client.luau` | StarterPlayer › StarterPlayerScripts › TempleUI | LocalScript |
| `src/client/GodUI.client.luau` | StarterPlayer › StarterPlayerScripts › GodUI | LocalScript |
| `src/client/CombatController.client.luau` | StarterPlayer › StarterPlayerScripts › CombatController | LocalScript |
| `src/client/AbilityController.client.luau` | StarterPlayer › StarterPlayerScripts › AbilityController | LocalScript |
| `src/client/Diagnostics.client.luau` | StarterPlayer › StarterPlayerScripts › Diagnostics | LocalScript |
| `src/character/Health.server.luau` | StarterPlayer › StarterCharacterScripts › Health (empty: disables default regen) | Script |

`default.project.json` is the [Rojo](https://rojo.space) project file that defines this mapping.

## Developer workflow (optional, with Rojo)

Instead of re-opening the place file after every change, you can live-sync the code:

1. Install Rojo (`aftman`, `cargo install rojo`, or a release download) and the Rojo Studio plugin.
2. From this folder run `rojo serve`.
3. In Studio, open the Rojo plugin and click **Connect**. Script edits in this repo now appear in Studio instantly.

Rebuild the place file after changing code:

```sh
rojo build -o MountOlympus.rbxlx
```

The place file is also kept up to date in this folder, and each tested build is
published straight to the experience with Open Cloud (see `HANDOFF.md`).

Cloud test note: Roblox's Luau Execution sessions do **not** run physics, so
walking/chasing can't be tested there; everything else (damage, rewards,
saving, telegraphs) can.

Lint (uses a minimal Roblox globals list in `roblox_min.yml`, since `selene`'s
full Roblox std needs internet access to generate):

```sh
selene src
```
