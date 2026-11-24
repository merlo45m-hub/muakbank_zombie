# GDD Bonus Tests — Issue #84

## What was previously untested

`CollectionManager.get_bonuses()` — the effect sink that derives
`bestiary_power_bonus` (player damage multiplier) and
`scavenge_yield_bonus` (dismantle loot yield multiplier) from collection
registrations — had no coverage. There was no assertion that:

- a fresh collection state yields a zero bonus (baseline), and
- registering dismantled props / defeated enemies moves both bonuses at the
  sink, i.e. player damage and dismantle loot yield actually change.

Registration-driven loot/damage application lives in gameplay systems; this
test covers the bonus sink itself, which is the shared, deterministic input
to both.

## What the probe now proves

- `tools/tests/collection_bonus_probe.gd` — SceneTree probe entering via
  `_initialize()` (not `_ready()`), no `get_tree()`, using
  `tools/tests/stubs/mock_collection_manager.gd` as a controlled
  CollectionManager double:
  - Zero-bonus baseline: `scavenge_yield_bonus == 0`,
    `bestiary_power_bonus == 0`, `recipes_unlocked == false`; damage sink
    equals base damage, loot-yield sink equals base quantity.
  - Nonzero bonus: after 10 unique dismantled props and 20 kills,
    `scavenge_yield_bonus > 0` and `bestiary_power_bonus > 0`;
    the damage sink rises above baseline and the dismantle loot-yield sink
    rises above baseline.
- `tools/regression_smoke.sh`: supplementary check
  `collection_bonus_probe` (not counted in the 23-check denominator, no
  existing label renumbered) that captures the engine rc, fails on rc != 0
  (including timeout rc=124), and asserts `COLLECTION_BONUS_PROBE_PASS=true`.
