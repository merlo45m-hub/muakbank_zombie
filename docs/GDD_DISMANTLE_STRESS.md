# Dismantle stress gate (GDD §2 / §6)

Baseline from clean main `b39a7228`, VPS headless `xvfb-run`, 10-second active window:

- 24 props x 6 joint markers dismantled progressively.
- 12 real zombies spawned through `ZombieSpawner3D`.
- Real `DebrisPool`, `CollectionManager`, and `FpsMonitor` autoloads.
- Result: avg 142.5 FPS, p05 141.0 FPS, jank 0.0%, 5 report windows.
- DebrisPool active count stayed within the 48 cap; all 24 props reached the registry sink.

`tools/tests/dismantle_stress_playtest.gd` is wired into the fast-probe manifest. Functional assertions (depletion, debris cap, registry writes, FPSMON windows) are hard failures. Numeric FPS is advisory: `FPS_BUDGET_PASS=true` or `FPS_BUDGET_ADVISORY=true` is printed, but shared CI runner jitter must not fail the gate. Read the exact metrics from the owner-controlled VPS/device lane.
