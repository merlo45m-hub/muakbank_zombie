# GDD Gap Gates A

Three gates, no wiring (the orchestrator owns `fast_probe_manifest.json` / smoke / workflows).

## 1. Fog default-off — `tools/tests/gdd_presentation_probe.gd`

Run: `godot --headless --path . --script res://tools/tests/gdd_presentation_probe.gd`

Measures the default tier is MOBILE/0 (script default, `game.tscn` `VinylLook`, `tunable_baseline.json`),
forces volumetric fog ON in a fresh `Environment`, lets the default tier apply, and requires it to end OFF.
It also checks HIGH re-enables and MOBILE re-disables, that no shipped scene/resource sets
`volumetric_fog_enabled = true`, and that none references `volumetric_fog.gdshader` (only `ShaderManager`
builds that material; its `u_fog_density` default is 0.4, so it is not zero-strength, only unused by scenes).
Marker: `FOG_DEFAULT_PROBE_PASS=true`. Note: cheap height fog (`fog_enabled`) is intentionally on in several environments.

## 2. Survivor pedestal/perk — same file (write lane allowed one GDScript file)

Marker: `SURVIVOR_PEDESTAL_PROBE_PASS=true`. Checks 5 ids/colors/scenes in `characters.json` against the
character-select screen, 5 visible models, 5 pedestal materials/lights, and that selecting each survivor sets
`Save.selected_character` and moves the pedestal highlight. It restores the original selection afterward.

**Known gap (found by static reading, probe fails closed on it):** `characters.json` `base_stats` use
`health/speed/damage`, but `Player.gd` resolves `assets/materials/stats_<id>.tres` first
(`max_health/move_speed/weapon_damage_multiplier`, different values, e.g. gamer 100/5.0/1.0 vs json 90/6.8/1.1),
and its Rules fallback reads `max_health/move_speed/attack_damage`, keys json does not have. So json
`base_stats` are never applied to the player. The probe prints the per-survivor mismatch and reports
`SURVIVOR_PEDESTAL_PROBE_PASS=false` until the data or the key mapping is reconciled.

## 3. CSG / fracture scan — `tools/check_no_realtime_fracture.py`

Run: `python3 tools/check_no_realtime_fracture.py --project-dir .`
Output: `NO_REALTIME_FRACTURE: PASS (n files)` or `NO_REALTIME_FRACTURE: FAIL file:line (reason)`; exit 1 on FAIL.
Project-wide: CSG* nodes/identifiers and mesh boolean ops. Dismantle-path files (path contains "dismantle"):
fracture/shatter/voronoi/mesh slice, and `SurfaceTool`/`MeshDataTool`/`add_surface_from_arrays` in `.gd`.
Comments are ignored; the `split_parts_scene` swap and debris are allowed. Fails closed on a bad dir,
missing `project.godot`, missing `DismantleComponent.gd`, unreadable files, or zero files. Skips `.git`,
`.godot`, `addons`, and top-level `tools`, `tests`, `docs`, `renders`.

Negative control: `python3 tools/check_no_realtime_fracture.py --self-test` builds fixtures in a temp dir
(CSG scene, CSG in script, boolean op, fracture and runtime mesh build in dismantle path, missing anchor,
empty dir) and requires each to FAIL while the clean split-swap fixture PASSes. Nothing lives in the scan tree.
