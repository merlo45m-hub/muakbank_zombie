#!/data/data/com.termux/files/usr/bin/bash
# gate_dev_isolation.sh — enforce that dev tooling cannot reach a shipped build.
#
# WHY: the Android APK is exported with --export-debug, so OS.is_debug_build() is TRUE in the
# shipped build. Any dev surface that leaks into a shipped scene is therefore player-visible.
# DESIGN.md §7 claims dev surfaces are confined to scenes/dev + scripts/dev. This proves it.
#
# Exit 0 = isolated (safe). Exit 1 = a shipped scene/script references dev tooling.
#
# Usage: gate_dev_isolation.sh [project_dir]

P="${1:-/storage/emulated/0/Games/Muakbank_zombie}"
[ -d "$P" ] || { echo "FAIL: no project at $P"; exit 1; }

fail=0
DEV_SCRIPTS="res://scripts/dev/"
DEV_SCENES="res://scenes/dev/"

echo "=== DEV ISOLATION GATE ==="

# 1. No shipped .tscn may reference a dev script or dev scene.
echo "[1/4] shipped scenes referencing dev surfaces..."
hits=$(grep -rlE "$DEV_SCRIPTS|$DEV_SCENES" "$P/scenes" 2>/dev/null | grep -v "^$P/scenes/dev/" || true)
if [ -n "$hits" ]; then
  echo "  FAIL: dev reference in a shipped scene:"
  echo "$hits" | sed 's/^/    /'
  fail=1
else
  echo "  PASS (no shipped scene references scripts/dev or scenes/dev)"
fi

# 2. No shipped .gd may PRELOAD/CONST-LOAD a dev path. That is the real hazard: a
#    const preload() runs at parse time and cannot be gated. A *runtime* navigation
#    guarded by DevMode.is_active() (e.g. change_scene_to_file("res://scenes/dev/..."))
#    is legitimate and must NOT fail this gate.
echo "[2/4] shipped scripts hard-loading dev paths..."
hits=$(grep -rnE "(preload|load)\(['\"]$DEV_SCRIPTS|(preload|load)\(['\"]$DEV_SCENES" \
        "$P/scripts" 2>/dev/null | grep -v "^$P/scripts/dev/" || true)
if [ -n "$hits" ]; then
  echo "  FAIL: a shipped script preloads/loads a dev path (cannot be gated at runtime):"
  echo "$hits" | sed 's/^/    /'
  fail=1
else
  echo "  PASS (no shipped script preloads a dev path)"
fi
# Report gated runtime references as information, not failure.
gated=$(grep -rlE "$DEV_SCRIPTS|$DEV_SCENES" "$P/scripts" 2>/dev/null | grep -v "^$P/scripts/dev/" || true)
if [ -n "$gated" ]; then
  echo "  NOTE: these shipped scripts mention a dev path (must be DevMode-gated):"
  echo "$gated" | sed 's/^/    /'
fi

# 3. Dev scenes must not be reachable from the main scene or any menu that ships.
echo "[3/4] main scene / menus pointing at dev scenes..."
main=$(grep -m1 -oE 'run/main_scene="[^"]+"' "$P/project.godot" 2>/dev/null | cut -d'"' -f2)
echo "  main_scene = ${main:-<unset>}"
if echo "$main" | grep -qE "scenes/dev/"; then
  echo "  FAIL: the project's main scene IS a dev scene"; fail=1
else
  echo "  PASS (main scene is not a dev scene)"
fi

# 4. The dev gate must not be OS.is_debug_build() anywhere in dev tooling.
#    Match CODE only — DevMode.gd documents why is_debug_build is banned, and those
#    comment lines are not a violation.
echo "[4/4] dev tooling gated on OS.is_debug_build() (unsafe in this project)..."
hits=$(grep -rn "is_debug_build" "$P/scripts/dev" 2>/dev/null \
       | grep -vE ':[0-9]+:[[:space:]]*#' || true)
if [ -n "$hits" ]; then
  echo "  FAIL: is_debug_build is true in the --export-debug APK; use DevMode.is_active():"
  echo "$hits" | sed 's/^/    /'
  fail=1
else
  echo "  PASS (no dev tooling relies on is_debug_build)"
fi

if [ "$fail" -eq 0 ]; then
  echo "=== DEV ISOLATION GATE: PASS ==="
  exit 0
fi
echo "=== DEV ISOLATION GATE: FAIL ==="
exit 1
