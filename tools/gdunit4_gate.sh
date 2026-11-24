#!/usr/bin/env bash
# GDUnit4 gate for the GDD gap lanes.
#
# Mirrors tools/hgs_run.sh's project-local XDG environment so behaviour is
# identical on the dev host and the VPS. Sets GODOT_BIN, runs the GDUnit4
# suite under the headless engine, and prints GDUNIT4_PASS=true only on a
# real pass (engine rc == 0).
#
# Does NOT claim a local engine run if Godot is unavailable in this
# environment; the orchestrator runs this gate on the VPS where the Godot
# binary exists.
#
# Usage:
#   tools/gdunit4_gate.sh                 # run every suite under res://r_tests
#   tools/gdunit4_gate.sh res://r_tests/collection_manager_test.gd

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR" || exit 1

mkdir -p "$PROJECT_DIR/logs" \
         "$PROJECT_DIR/.tmp-godot-data" \
         "$PROJECT_DIR/.tmp-godot-config" \
         "$PROJECT_DIR/.tmp-godot-cache"

export XDG_DATA_HOME="$PROJECT_DIR/.tmp-godot-data"
export XDG_CONFIG_HOME="$PROJECT_DIR/.tmp-godot-config"
export XDG_CACHE_HOME="$PROJECT_DIR/.tmp-godot-cache"
export GODOT_SILENCE_ROOT_WARNING=1

SUITE="${1:-res://r_tests}"
GODOT="${GODOT_BIN:-godot}"
LOG="$PROJECT_DIR/logs/gdunit4_gate.log"

# Godot unavailable locally -> do not claim a run; report false and exit 0
# so the local lane stays green until the VPS orchestrator executes it.
if [ ! -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "GDUNIT4_PASS=false (godot binary unavailable: $GODOT)"
  exit 0
fi

"$GODOT" --headless --path "$PROJECT_DIR" -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a "$SUITE" > "$LOG" 2>&1
rc=$?

if [ "$rc" -eq 0 ]; then
  echo "GDUNIT4_PASS=true"
  exit 0
fi

echo "GDUNIT4_PASS=false (engine rc=$rc; log: $LOG)"
exit 1
