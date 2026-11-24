# GDD Registry Tests — Issue #85

## What was previously untested

`CollectionManager` is the sole writer of the collection registry
(`record_item`, `record_defeat`, `record_dismantle`), but nothing asserted
that gameplay actually delivers ids to those sinks:

- `DismantleComponent._record_registries()` (script fix #85: "record string
  loot ids") normalizes loot-table drops — both plain string ids and
  `{item_id, count}` dictionaries — and calls `cm.call("record_item",
  item_id, count)`. There was no proof a string loot id reaches `record_item`.
- `Game.on_zombie_killed()` calls `cm.call("record_defeat", zombie_type)` for
  every kill, and `_on_boss_defeated()` routes boss kills through
  `on_zombie_killed("boss")`. There was no proof boss/wave kill ids reach
  `record_defeat`.
- Both call sites guard on `cm == null` via `get_node_or_null(
  "/root/CollectionManager")`. The no-manager case (no CollectionManager
  autoload present) had no crash proof.

Registration-driven loot/damage application lives in gameplay systems; this
test covers the sink itself — the shared, deterministic input to
`CollectionManager.get_bonuses()`.

## What the probe now proves

- `tools/tests/registry_record_probe.gd` — SceneTree probe entering via
  `_initialize()` (not `_ready()`), no `get_tree()`, using
  `tools/tests/stubs/mock_registry_manager.gd` as a controlled
  CollectionManager double:
  - Dismantle loot ids: a loot table of `["mat_scrap", "mat_scrap",
    {"item_id": "mat_wire", "count": 3}, "mat_gear"]` drives
    `record_item(id, count)` exactly as `DismantleComponent` does; the last
    id is `mat_gear`, all 4 ids reach the sink, and `mat_wire` carries count
    3 — proving string loot ids reach `record_item`.
  - Boss/wave kills: `["boss_w1", "zombie", "boss_w2", "boss_w1"]` drives
    `record_defeat(id)`; the last id is `boss_w1`, all 4 ids reach the sink,
    and both `boss_w1` / `boss_w2` are present — proving kills reach
    `record_defeat`.
  - No-manager case: with `cm == null` the guard short-circuits and the probe
    reaches its verdict without crashing.
- `tools/tests/stubs/mock_registry_manager.gd` — test double mirroring
  `CollectionManager.record_item()` / `record_defeat()` (and `record_dismantle`
  for API parity) without `/root/Save` or WorldProgression wiring, exposing a
  captured ledger so the probe asserts exactly which ids reached the sink.
- `tools/regression_smoke.sh`: supplementary check `registry_record_probe`
  (not counted in the 23-check denominator, no existing label renumbered)
  that captures the engine rc, fails on rc != 0 (including timeout rc=124),
  and asserts `REGISTRY_RECORD_PROBE_PASS=true`.

## Prior gap vs new proof

| Before (gap) | After (proof) |
|---|---|
| String loot ids from dismantle never asserted at `record_item` sink | Loot-table string drops + `{item_id, count}` both reach `record_item` with correct qty |
| Boss/wave kill ids never asserted at `record_defeat` sink | Boss (`boss_w1`, `boss_w2`) and wave kill ids reach `record_defeat` |
| No-manager path untested, potential silent crash | `cm == null` guard proven crash-free; probe reaches verdict |

Run: `bash tools/regression_smoke.sh` — the new check runs as a
supplementary gate after the numbered 23 and must print
`registry_record_probe: REGISTRY_RECORD_PROBE_PASS=true` with exit 0.
