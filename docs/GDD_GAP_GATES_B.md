# GDD Gap Gates B

Two bounded lanes, no wiring (the orchestrator owns `fast_probe_manifest.json` /
`regression_smoke.sh` / workflows / existing tools). Lane A lives in
`docs/GDD_GAP_GATES_A.md`; this doc covers lane B.

## 1. GDUnit4 suites — `r_tests/`

Run: `tools/gdunit4_gate.sh` (defaults to every suite under `res://r_tests`)
or `tools/gdunit4_gate.sh res://r_tests/<suite>.gd`.

The gate sets `GODOT_BIN`, uses the project-local XDG environment from
`tools/hgs_run.sh` (`.tmp-godot-data|config|cache`), runs the suite headless
via `addons/gdUnit4/bin/GdUnitCmdTool.gd -a <suite>`, and prints
`GDUNIT4_PASS=true` only when the engine exits 0. It does not claim a local
engine run when Godot is unavailable; the orchestrator runs it on the VPS.

| Suite | Covers | Marker |
|---|---|---|
| `r_tests/collection_manager_test.gd` | `CollectionManager.record_item` / `consume_item`: increment, seen-tracking, empty-id guard, insufficient-qty `false`, depletion removal | GDUnit4 rc 0 |
| `r_tests/achievement_manager_cure_test.gd` | `AchievementManager` cure gate: requires all 3 world bosses, majority achievements, all 3 catalysts; synthesize consumes each catalyst once and enters `post_cure` | GDUnit4 rc 0 |
| `r_tests/dismantle_component_test.gd` | `DismantleComponent` tool-tier gate (no-op below tier) and `loot_descriptor()` | GDUnit4 rc 0 |
| `r_tests/save_schema_test.gd` | `SaveSchema` field typing: deserialize coercion, unknown-key drop, defaults, int-key normalization, serialize round-trip | GDUnit4 rc 0 |

## 2. Asset integrity — `tools/verify_asset_integrity.py`

Run: `python3 tools/verify_asset_integrity.py --project-dir <dir>`

Stdlib-only gate with explicit `--project-dir`. For every shipped `.glb`:
* `.glb.import` sidecar present,
* every GLB `images[].uri` texture resolves (relative to the glb file),
* every resolved shipped texture is power-of-two and `<= 2048` px,
* contract bounds from `tools/glb_asset_contract.json` still match — delegated
  to `tools/verify_glb_assets.py` via subprocess; its parser is NOT duplicated.

Output: `ASSET_INTEGRITY: PASS (n glb)` or
`ASSET_INTEGRITY: FAIL file:line reason` (one line per problem), exit 1 on FAIL.

Negative control: `python3 tools/verify_asset_integrity.py --self-test` builds
fixtures in a temp dir outside the scan tree and requires missing sidecar,
unresolved URI, non-power-of-two, and over-2048 textures each to FAIL while a
clean fixture and a `.godot`-cached glb PASS/are not scanned. Nothing lives in
the scan tree.

### Known pre-existing gap (not introduced here)
80 glbs under `assets/models/cc0/kenney_survival/` reference
`Textures/colormap.png` with no sibling texture file, so the image-URI check
reports `FAIL ... images[].uri Textures/colormap.png unresolved` for them.
This is a data issue, out of scope for the gate (assets are not in the write
lane); the gate correctly fails closed on it rather than false-passing.
