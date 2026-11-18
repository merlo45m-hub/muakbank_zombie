#!/bin/bash
# Nightly regression runner (Issue #20). Prints NOTHING when all green; on failure
# prints a concise report for Telegram delivery. Env-overridable for testing.
# Runs the SAME full chain as .github/workflows/nightly-regression.yml on the VPS,
# where the real Godot engine lives.
set -uo pipefail
GODOT_BIN="${MKB_GODOT:-/root/Godot_v4.7-stable_linux.x86_64}"
REPO="${MKB_REPO:-/root/muakbank_zombie}"
STATE_DIR="${MKB_STATE_DIR:-/root/.hermes}"
LOG="$STATE_DIR/mkb_nightly.log"
cd "$REPO" || { echo "NIGHTLY FAIL: cannot cd $REPO"; exit 1; }
mkdir -p "$STATE_DIR"
: > "$LOG"
fail=0

run_step() {
  local name="$1"; shift
  if "$@" >> "$LOG" 2>&1; then
    echo "$name OK" >> "$LOG"
  else
    echo "$name FAIL rc=$?" >> "$LOG"
    fail=1
  fi
}

run_step static   python3 tools/validate_project.py .
run_step import   timeout 200 xvfb-run -a "$GODOT_BIN" --headless --import --path .
run_step smoke    bash tools/regression_smoke.sh
run_step gdunit   timeout 180 xvfb-run -a "$GODOT_BIN" --headless --path . --script tools/tests/run_tests.gd
run_step playtest timeout 300 xvfb-run -a "$GODOT_BIN" --headless --path . --script tools/tests/world_progression_playtest.gd
rm -f /root/.local/share/godot/app_userdata/Muakbank_zombie/savegame.save

# Assert the machine-parseable verdicts, not just exit codes.
if ! grep -q "ISSUES: 0" "$LOG"; then fail=1; fi
if ! grep -q "REGRESSION: PASS (5 checks, 0 errors)" "$LOG"; then fail=1; fi
if ! grep -q "FULL_PROGRESSION_PASS=true" "$LOG"; then fail=1; fi

if [ "$fail" -eq 0 ]; then
  exit 0  # silent when healthy
fi
echo "NIGHTLY REGRESSION FAILURE $(date -u +%Y-%m-%dT%H:%MZ)"
echo "--- last 20 log lines ---"
tail -20 "$LOG"
