# Issue #32 — GDScript Strict Typing: static analysis & prioritized refactor plan

Date: 2026-11-15. Repo: `merlo45m-hub/muakbank_zombie`, branch `feat/ui-restructure`.
Engine: Godot 4.7-stable (headless, verified).

## What "strict mode" actually means here

Godot 4.7 has **no single "strict mode" toggle**. Type safety is controlled by ~50
per-key warning levels under `debug/gdscript/warnings/*`, each `0=ignore`,
`1=warn`, `2=error`. Values were read live from the engine via `ProjectSettings`
before any change (see verification below).

The setting that actually eliminates **dynamic type inference** is
`inference_on_variant = 2` — `var x := <Variant>` becomes a hard parse error.
That was already `2` (engine default); it is now pinned explicitly. `:=` on a
statically-typed expression is **safe** (compile-time inferred), so it is NOT
flagged as error — promoting it would break 148 scripts with no safety gain.

## Changes delivered

1. **Explicit return types + typed parameters, all scripts.** Fixed all 26
   functions missing `-> type` and all 12 untyped parameters across 8 files
   (LevelSelect, Settings, GameOver, SaveManager, verify_scenes, Credits,
   ZombieBase, ZombieSpawner3D). Types derived from real callers/signals:
   `value_changed -> float`, `item_selected -> int`, `pressed.bind(i) -> int`,
   `pending_results` (bool/int/int), `_coerce -> Variant`,
   `_create_pool(scene: PackedScene)`, `set_vfn_field(field: Variant)`.

2. **`[debug]` section in project.godot** — 13 warning settings. Type-safety
   warnings (`untyped_declaration`, `inferred_declaration`, `unsafe_*`,
   `return_value_discarded`, `missing_await`, `narrowing_conversion`,
   `incompatible_ternary`) set to **1 (warn)** so they surface in the editor
   without breaking the build; `inference_on_variant` stays **2 (error)**.

3. **`tools/check_gdscript_strict.py`** — stdlib static analyzer. Maps and
   prioritizes type debt per file; `--gate` mode fails closed on any missing
   return type or untyped param (both now 0), `--json` for machine use.

4. **Enforcement wired** into `.github/workflows/pre_merge_gates.yml`
   (static-gate job) and `tools/regression_smoke.sh` (now 9 checks, check 9).

## Static analysis pass — measured baseline (174 files, 1265 functions)

| Metric | Count | Status |
|---|---|---|
| Missing explicit return types | **0** | FIXED (was 26) |
| Untyped parameters | **0** | FIXED (was 12) |
| Inferred declarations (`:=`) | 1244 | statically typed, safe — backlog only |
| Untyped `var` / `const` | 446 | real dynamic-typing debt — prioritized below |

## Prioritized refactor backlog (untyped declarations)

Ranked by untyped-var count (highest-value first). These are the files to convert
to explicit types before considering `untyped_declaration = 2` (error). Each is
independent and should land one file at a time with the 9-check regression green.

1. `scripts/characters/ZombieSpawner3D.gd` — 42
2. `scripts/characters/ZombieBase.gd` — 28
3. `scripts/core/GameAudioManager.gd` — 27
4. `scripts/ui/HUD.gd` — 23
5. `scripts/characters/ZombieSpitter.gd` — 19
6. `scripts/gameplay/FoodSpawner.gd` — 18
7. `scripts/world/interactive/FoodCrate.gd` — 14
8. `scripts/characters/ZombieButcher.gd` — 11
9. `scripts/characters/ZombieCat.gd` — 11
10. `scripts/core/Game.gd` — 9
11. `scripts/characters/ZombieDog.gd` — 9
12. `scripts/characters/ZombieRabbit.gd` — 9
13. `scripts/gameplay/MobileControls.gd` — 8
14. `scripts/characters/ZombieBear.gd` — 8
15. `scripts/characters/ZombieBoss.gd` — 8

`:=`-heavy files (CharacterSelect 111, BlockyAnim 111, LevelDetail 95,
Player 64) are low priority: `:=` is statically inferred and already safe.

## Verification (real execution)

- Engine settings probe: `inference_on_variant=2`, `untyped_declaration=1`,
  `inferred_declaration=1`, `unsafe_method_access=1`, `return_value_discarded=1`.
- `godot --headless --import`: rc 0, **0 parse/script errors**, 0 INFERENCE_ON_VARIANT.
- `tools/check_gdscript_strict.py --gate .`: `missing_return_types=0
  untyped_params=0`, rc 0. Negative control (injected missing `-> void`) → rc 1
  with file:line.
- `validate_project.py .`: ISSUES 0. `check_gdscript_typing.py --changed`: 0 findings.
- `bash tools/regression_smoke.sh`: **PASS (9 checks, 0 errors)**.
- `bash -n tools/regression_smoke.sh`: OK.

## Honest notes

- `:=` is static type inference, not dynamic. The 1244 `:=` sites are not a
  defect and are deliberately excluded from the gate. Only `inference_on_variant`
  (already error) governs the dynamic-inference case the issue names.
- Setting `untyped_declaration`/`inferred_declaration` to `2` (error) today would
  make the project un-importable (446 + 1244 violations). They are set to `1`
  (warn) and tracked as a phased backlog instead — that is the only non-breaking
  strict configuration.
- The `--gate` enforces the two classes now at zero; it does not gate the backlog,
  so CI stays green while the refactors land incrementally.
