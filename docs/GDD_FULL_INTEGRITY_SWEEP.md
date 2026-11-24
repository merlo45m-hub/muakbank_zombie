# GDD full integrity sweep — 2026-11-24

Scope: main `0c8a549e95bfeec748b18db1c66bcb0d83dacc85`.

## Results
- `validate_project.py .`: 127 scenes, 221 scripts, 44 resources; `ISSUES: 0`.
- `audit_project.py .`: after the GLB parent-path fix, `0 errors / 0 warnings`. Negative control with a fake missing parent segment produced `1 error`, then restored to 0.
- `verify_scene_resolves.py`: `REF_SCAN: PASS`.
- GDScript typing analyzer: `TYPING_FINDINGS=0`.
- Batched full engine scene sweep (`MKB_SWEEP=full`): 10 batches, all rc=0; 94 shipped scenes loaded and instantiated; 5,040 resolved MeshInstance3D; 0 allowed-WIP failures. The collector intentionally skips `tools/` and `addons/`; those are covered by the static validator and the all-resources export.
- All-resources Android export: valid signed APK (88,366,889 bytes, zip CRC clean, manifest/dex/arsc present); 0 non-leak parse/load errors. `rc=134` after the export is a benign post-export shutdown abort.

## Artifact fixes
`tools/audit_project.py` previously flagged parent paths that drill into instanced GLB/PackedScene roots (e.g. `PlayerVisuals/Model/character-b/root/torso/head`). Those internal nodes are not declared in the `.tscn`. The checker now records node headers with unquoted `instance=ExtResource(...)` properties and stops validating segments after an instance root. Genuine missing siblings still fail.

## GDD alignment
Covered by explicit gates: dismantling chain, tool tier, secret transport links, registry coverage (5 survivors / 5 animals / 6 core props), boss catalyst drops and tier gate, majority/Cure gate, post-cure persistence, 60 FPS destruction stress (144 avg / 140 p05 / 0% jank headless), 60 FPS UI/typography rails, dynamic export, zero type errors, full scene resolve, valid APK.

Honest remaining gaps from the independent GDD cross-reference:
1. GDUnit4 `r_tests/` headless screenshot suite not present.
2. On-device 60 FPS capture not possible while the phone is locked; headless stress passes.
3. Volumetric fog default-off check not yet a named gate.
4. LOD/atlas/1:1 scale audit beyond current asset contracts not yet a named gate.
5. Explicit CSG/rigid-body-fracture static scan not yet a named gate.
6. Survivor pedestal/perk verification is covered visually by earlier device acceptance but not a deterministic gate.

The task is therefore NOT declared fully complete; these gaps are ranked backlog items.
