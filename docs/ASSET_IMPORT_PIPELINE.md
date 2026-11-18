# Asset import pipeline — reproducible blockout + lighting

## Source of truth
Downloaded packs live in the Termux vault copy `~/ObsidianVault/second_brain/assets/downloads/` (mtime 2026-11-17). Heavy files are NEVER copied into the Obsidian vault review tree; the vault holds notes/previews only.

## Step 1 — catalogue
`~/ObsidianVault/second_brain/assets/downloads/` contains:
- Kenney GLB packs: factory 143, fantasy-town 167, food 200, modular-buildings 108, modular-dungeon 39, nature 329, survival 80, weapon 37 (1,103 GLBs, ~18.6 MB, CC0).
- Poly Haven HDRIs: 31 `.hdr` files, 205.8 MB, lighting only.

License gate: each pack must carry its own CC0 license file. Kenney CC0 verified from `/root/3d-workspace/sources/kenney/*/License.txt`.

## Step 2 — organize
- GLBs → `assets/models/cc0/<pack_name>/` in the Godot repo.
- HDRIs → `assets/hdri/` in the repo; full catalog copy stays at `/root/3d-workspace/assets/hdri/polyhaven/` with `/root/3d-workspace/assets/ASSET_CATALOG.md`.

## Step 3 — generate Godot sidecars (mandatory)
```
cd /root/muakbank_zombie
xvfb-run -a /usr/local/bin/godot --headless --path /root/muakbank_zombie --import
```
A `.glb` without `<name>.glb.import` is fatal. Verify `*.glb.import` count equals `*.glb` count. PagedAllocator/RID-leak messages at shutdown are benign.

## Step 4 — wire blockout
`scripts/world/asset_blockout.gd` (extends Node3D, seeded RNG 20261118) scatters scaled props. Attach as a child node with properties `world_id`, `prop_count`, `seed_value`. Worlds:
- Suburban → `old_town_enhanced.tscn`, world_id `OldTown`, 24 props
- Industrial → `industrial_district.tscn`, world_id `IndustrialDistrict`, 24 props
- Bio-Lab → `endgame_heights.tscn`, world_id `EndgameHeights`, 28 props

## Step 5 — wire HDRI lighting
`scripts/world/hdri_lighting.gd` loads an HDRI as `Texture2D`, wraps it in `PanoramaSkyMaterial.panorama`, assigns to a `Sky.sky_material`, then sets `Environment.background_mode = BG_SKY` and `AMBIENT_SOURCE_SKY` on the parent `WorldEnvironment` (creating one if absent). Node properties: `hdri_path`, `ambient_energy`. Per-world picks:
- Suburban → `graveyard_pathways_2k.hdr`
- Industrial → `overcast_industrial_courtyard_2k.hdr`
- Bio-Lab → `night_bridge_2k.hdr`

Note: Godot 4.7 `Sky` has NO `panorama` property; use `PanoramaSkyMaterial`.

## Step 6 — gates
```
python3 tools/validate_project.py /root/muakbank_zombie   # ISSUES: 0
xvfb-run -a bash tools/regression_smoke.sh                # REGRESSION: PASS (9 checks, 0 errors)
```
Instantiation probe must print prop counts and confirm sky presence. Delete temporary probes from `tools/tests/` before committing.

## Caveat
Godot MCP `scene_manage save` truncates large `.tscn` files. Apply scene edits as targeted text patches and verify with `validate_project.py`, never with that MCP save.
