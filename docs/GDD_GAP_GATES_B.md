# GDD gap gates B — GDUnit4 and asset integrity

- `r_tests/` contains GDUnit4 suites for CollectionManager, AchievementManager Cure gate, DismantleComponent tier gate, and SaveSchema typing.
- `tools/gdunit4_gate.sh` runs the suite headless with project-local XDG paths and prints `GDUNIT4_PASS=true` only on a real pass.
- `tools/verify_asset_integrity.py` verifies every shipped .glb has its .glb.import sidecar, resolves images[].uri texture paths, enforces POT and <=2048 texture limits, and reuses tools/verify_glb_assets.py for contract bounds. Self-test covers clean, .godot exclusion, missing sidecar, unresolved URI, non-POT, and over-2048 cases.

These gates are wired by the orchestrator after VPS validation.
