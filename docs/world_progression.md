# World-Hopping Progression — Schema & Gate Table (Issue #11)

Status: **P0 data layer landed**. P1 (autoload + emitters), P2 (transport hub + world map),
P3 (threaded hop manager), P4 (loot gate wiring) are follow-up phases, NOT claimed as done.

## Model
Region == one of the 3 existing environments; region ids reuse `LevelManager.environments`
keys (1..3) so `unlocked_levels` / `current_level` / the level-select UI stay valid.

## Gate table (all AND, evaluated against the target region)
| Gate | Condition | Reporter |
|---|---|---|
| tech | collect `tech_required` scavenge fragments in the prerequisite region | `TechPickup.report_tech` |
| transport | repair the region `TransportHub` (consumes parts) | `TransportHub.report_transport_repaired` |
| milestones | complete every id in `milestones_required` | `RegionObjectiveTracker.report_milestone` |
| prerequisite | `prerequisite_region` unlocked AND visited | `WorldProgression` |

## Loot tier
Each `RegionDef.loot_tier` (1/2/3). `LootTierGate.clamp_tier(t)` caps every drop at
`WorldProgression.max_loot_tier` = tier of highest unlocked region. Spawners query the gate.

## Canonical signal contract (approved 2026-11-15, see issue #16)
`region_unlocked`, `tech_collected`, `transport_repaired`, `milestone_reached`,
`max_loot_tier_changed`, `hop_started`, `hop_completed`, `hop_failed`.
`WorldProgression` is the single owner/emitter; listeners (UI/Audio/Achievement/Save/
CollectionManager) only subscribe. CollectionManager (P1 finish) already subscribes with a
null guard, so it has no hard dependency on this autoload existing yet.

## Save schema (flat `game_*` keys, `user://savegame.save`)
`game_world_current_region:int`, `game_world_unlocked_regions:Array[int]`,
`game_world_tech:Dictionary`, `game_world_transport_repaired:Dictionary`,
`game_world_milestones:Dictionary`, `game_world_max_loot_tier:int`.
`SAVE_VERSION` 2 -> 3; the pre-existing `old_version < SAVE_VERSION` branch backfills
defaults and rewrites old saves. `Save.get_world_state()` / `set_world_state()` are the
only writers (invoked on `region_unlocked` / `hop_completed`, never per-frame).

## Notes
- Autoloads must be referenced by `uid://` in `project.godot` (sparse-PCK pitfall).
- Keep `unlocked_levels` in sync with `world_unlocked_regions` so level select doesn't regress.
- Prefer node instancing under a persistent `WorldRoot` over `change_scene_to_file`.
