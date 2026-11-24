# GDD Boss Catalyst Tests — Issue #86

## What was previously untested

Issue #86 (boss catalyst tier gate) added behavior that nothing asserted:

- `WaveManager._spawn_boss()` gates boss spawn on `WorldProgression.get_active_loot_tier() >= _level` (world level): when the active loot tier is below the world level the boss is not spawned and `boss_gate_blocked` is emitted; when it meets or exceeds the level the gate passes. The block vs allow decision had no runtime proof.
- `AchievementManager.record_boss_defeat()` now grants exactly one cure catalyst (via `CureCatalysts.get_catalyst_id_for_world()`) through `CollectionManager.record_item()`, the collection sole writer. No test verified a boss defeat delivers a catalyst to the collection sink.
- `AchievementManager.can_synthesize_cure()` now additionally requires all three catalysts, and `synthesize_cure()` consumes each catalyst exactly once via `CollectionManager.consume_item()`. Synthesis had no catalyst-aware proof.
- Call sites guard on missing managers (`get_node_or_null("/root/CollectionManager")`, `/root/Save`, `/root/WorldProgression`); the no-manager paths had no crash proof.

## What the probe now proves

- `tools/tests/boss_catalyst_probe.gd` — SceneTree probe entering via `_initialize()` (not `_ready()`), no `get_tree()`:
  - (a) Boss tier gate at the real `WaveManager._spawn_boss` sink: `WorldProgression` region 1 (active tier 1) vs world level 2 blocks spawn (`boss_gate_blocked` emitted with required 2, actual 1); region 2 (active tier 2) vs level 2 allows; level 1 vs tier 1 allows.
  - (b) `record_boss_defeat` grants exactly one catalyst per defeated world at the `CollectionManager.record_item` sink: `catalyst_suburban`, `catalyst_industrial`, `catalyst_biolab` each reach quantity 1 after their world's boss defeat.
  - (c) `can_synthesize_cure()` fails without all catalysts and `synthesize_cure()` fails too; once all three catalysts (one per defeated world), all bosses and a majority achievement threshold are present, `can_synthesize_cure()` is true and `synthesize_cure()` succeeds; `consume_item` leaves every catalyst at 0 (consumed exactly once), and a second synthesis hits the `post_cure` shortcut without consuming again.
  - (d) With `CollectionManager`, `Save`, or `WorldProgression` removed from the tree, the guarded call sites and the gate degrade (default tier 1) without crashing.
- `tools/tests/stubs/mock_catalyst_collection.gd` — test double mirroring `CollectionManager.record_item()` / `consume_item()` / `get_items()` without `/root/Save` or WorldProgression wiring, exposing the catalyst quantities so the probe asserts exactly what reached the sink.
- `tools/regression_smoke.sh`: supplementary check `boss_catalyst_probe` (not counted in the 23-check denominator, no existing label renumbered) that captures the engine rc, fails on rc != 0 (including timeout rc=124), and asserts `BOSS_CATALYST_PROBE_PASS=true`.

## Prior gap vs new proof

| Before (gap) | After (proof) |
|---|---|
| Boss spawn tier gate (`active loot tier < world level` blocks) unproven | `WaveManager._spawn_boss` block/allow proved via `boss_gate_blocked` at the real sink |
| Boss defeat → catalyst grant via `CollectionManager` unasserted | Exactly one catalyst per defeated world reaches `record_item` |
| Cure synthesis had no catalyst requirement; consume-once unproven | `can_synthesize_cure` false without catalysts, true with them; `synthesize_cure` consumes each catalyst exactly once |
| No-manager paths untested, potential silent crash | Missing `CollectionManager` / `Save` / `WorldProgression` proven crash-free |

Run: `bash tools/regression_smoke.sh` — the new check runs as a supplementary gate after the numbered 23 and must print

```
  boss_catalyst_probe: BOSS_CATALYST_PROBE_PASS=true
```

as part of `REGRESSION: PASS (23 checks, 0 errors)`.
