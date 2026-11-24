# Mount Olympus: Rise of the Gods

A Greek mythology RPG / temple tycoon for Roblox.

- **Status:** Phase 1 (Core Framework). Code complete, **not yet tested in Roblox Studio**.
- **Full design spec, decisions, and roadmap:** [`HANDOFF.md`](HANDOFF.md).

## Fastest way to try it (no tools needed)

1. On a Mac or Windows PC, download **`MountOlympus_Phase1.rbxlx`** from this folder.
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
| `src/server/Main.server.luau` | ServerScriptService › Main | Script |
| `src/server/Services/DataService.luau` | ServerScriptService › Services › DataService | ModuleScript |
| `src/server/Services/ProgressionService.luau` | ServerScriptService › Services › ProgressionService | ModuleScript |
| `src/server/Services/PlotService.luau` | ServerScriptService › Services › PlotService | ModuleScript |
| `src/server/Services/WorldBuilder.luau` | ServerScriptService › Services › WorldBuilder | ModuleScript |
| `src/client/HUDController.client.luau` | StarterPlayer › StarterPlayerScripts › HUDController | LocalScript |

`default.project.json` is the [Rojo](https://rojo.space) project file that defines this mapping.

## Developer workflow (optional, with Rojo)

Instead of re-opening the place file after every change, you can live-sync the code:

1. Install Rojo (`aftman`, `cargo install rojo`, or a release download) and the Rojo Studio plugin.
2. From this folder run `rojo serve`.
3. In Studio, open the Rojo plugin and click **Connect**. Script edits in this repo now appear in Studio instantly.

Rebuild the place file after changing code:

```sh
rojo build -o MountOlympus_Phase1.rbxlx
```

Lint (uses a minimal Roblox globals list in `roblox_min.yml`, since `selene`'s
full Roblox std needs internet access to generate):

```sh
selene src
```
