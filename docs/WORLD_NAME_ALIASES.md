# World name aliases — GDD-3 (#27)

Law of truth: `docs/MASTER_GDD.md` / `Mukbang_Zombie_GDD.pdf` §3–4.
Three GDD worlds: **World 1 Suburban, World 2 Industrial, World 3 Bio-Lab**.

## Decision: display-name aliases, NOT scene renames

There are **12 inbound `res://` references** to the three world scenes
(`LevelManager.environments`, `resources/world/regions.tres`, `tools/gen_regions.gd`,
`tools/find_spawn.gd`, `tools/tests/run_tests.gd`). Renaming the scene files would
break every one of them for zero gameplay gain. So the scene paths stay
authoritative and unchanged; only the **display names** change.

| Region id | GDD display name | Scene path (unchanged) | Legacy display name |
|---|---|---|---|
| 1 | Suburban | `res://scenes/world/environment/old_town_enhanced.tscn` | Old Town |
| 2 | Industrial | `res://scenes/world/environment/industrial_district.tscn` | Industrial District |
| 3 | Bio-Lab | `res://scenes/world/environment/endgame_heights.tscn` | Endgame Heights |

Legend codes `SAND1/2/3` are retained — they are internal identifiers, not world names.

## Files changed
- `scripts/core/LevelManager.gd` — `level_names` (the UI-visible source via `get_level_name()`).
- `resources/world/regions.tres` — 3 × `RegionDef.display_name` (consumed by `WorldMap.gd`).
- `tools/gen_regions.gd` — **must** match, or regenerating `regions.tres` reverts the remap.
- Current-state docs: `docs/GAME_DESIGN.md`, `CODEX.md`, `DESIGN.md`, controller headers,
  `Game.gd` spawn comments, `default_env.tres` comment.
- `README.md` already used the GDD names (from the #24 alignment step) — no change needed.

## Deliberately unchanged
- **Scene filenames and all `res://` paths** — alias approach, no rename.
- **Dated historical audits** (`docs/LEVEL1_AUDIT.md` 2026-10-13, `docs/LEVEL1_DESIGN.md`,
  `docs/specs/LEVEL1_MINIGAMES_*.md`, `docs/specs/*`). These record what was designed
  at that date under the old names; rewriting them would falsify the historical record.
  The mapping table above is the cross-reference.

## Open decisions owed to the user (NOT decided here)
1. **Title naming** — GDD says "Mukbang Zombie", repo/README say "Muakbank Zombie".
   Requires an explicit naming decision; not assumed.
2. **1 World Boss per world** — repo has a single `zombie_boss.tscn`; GDD wants per-world
   variants. Design/asset work, tracked separately.

## Out of scope for this naming change
Actual world *content* (Suburban neighborhoods/graveyard vs Industrial shipping yards
vs Bio-Lab containment wings) is a geometry/art remap, far larger than a display-name
alias. This issue only aligns the names.
