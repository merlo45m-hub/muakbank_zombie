# GDD Test Gaps — Issue #28 (Cure / Main Objective)

## False-passing sink (before this change)

Regression smoke `tools/regression_smoke.sh` check 11
(`cure_endgame_playtest`, GDD Issue #28) launched the cure playtest probe and
grepped the log for `GDD28_CURE_PASS=true`, but never captured the Godot exit
code. A process that emitted the marker then crashed, timed out, or exited
non-zero (rc != 0) was still counted as a pass — the marker could be printed
while the underlying save/persistence path silently failed, so the check
false-passed on the sink.

The in-probe save/reload (same process, same `AchievementManager` lifetime)
also never proved on-disk persistence across the process boundary: state held
only in memory would round-trip inside one boot but not survive a restart.

## How the new harness proves the sink

- `tools/regression_smoke.sh` check 11 now captures the engine rc and fails
  when rc != 0 (including `timeout` rc=124) even if `GDD28_CURE_PASS=true` is
  present.
- `tools/tests/cure_save_reload_probe.gd` runs in two modes:
  - SETUP: synthesize the cure (3 world bosses + majority achievement
    threshold), persist to an absolute temp save path, assert `post_cure` +
    persisted bosses, prove the file exists on disk, exit.
  - VERIFY: a FRESH Godot process reloads the same save file and asserts
    `post_cure == true`, all 3 world bosses defeated, and the
    `cure_synthesized` unlock.
- `tools/tests/cure_persistence_harness.sh` drives both modes in separate
  engine processes over a `mktemp -d` save path, checks the on-disk save file
  exists between processes, and fails on any non-zero rc or missing pass
  marker. Absolute paths only; no hardcoded secrets.
- Wired into `regression_smoke.sh` as a clearly labeled supplementary check;
  the 23-check denominator and every existing label are unchanged.

## Result

Cure persistence now requires a real disk write read back by a fresh engine
instance — the sink is covered end-to-end.
