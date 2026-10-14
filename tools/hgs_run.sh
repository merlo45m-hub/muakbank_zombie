#!/usr/bin/env bash
# Headless Godot runner for Muakbank Zombie (headless-godot-skill-kit).
#
# The kit mandates a project-local XDG environment because the default
# ~/.local / ~/.cache paths are unavailable in sandboxes. On the VPS the real
# home works, but pinning XDG keeps behaviour identical everywhere and stops
# Godot writing import caches into $HOME.
#
# Usage:
#   tools/hgs_run.sh import                      # full project import
#   tools/hgs_run.sh smoke                       # start main scene ~5s
#   tools/hgs_run.sh test                        # logic tests (tools/tests/run_tests.gd)
#   tools/hgs_run.sh patch <patch.json> [--dry-run]
#   tools/hgs_run.sh script <res://path.gd>
#   tools/hgs_run.sh export-android <out.apk>
#   tools/hgs_run.sh -- <raw godot args>

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

# The VPS has the export templates in the default location; pin them anyway so a
# changed XDG_DATA_HOME cannot hide them.
if [ -d "$HOME/.local/share/godot/export_templates/4.7.stable" ]; then
  export GODOT_TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/4.7.stable"
fi

GODOT="${GODOT_BIN:-godot}"
CMD="${1:-help}"
shift || true

run() {
  local label="$1"; shift
  local log="logs/${label}.log"
  echo "=== $label : $* ==="
  "$@" 2>&1 | tee "$log"
  local rc="${PIPESTATUS[0]}"
  echo "=== $label rc=$rc (log: $log) ==="
  return "$rc"
}

case "$CMD" in
  import)
    run import "$GODOT" --headless --path "$PROJECT_DIR" --import --quit
    ;;
  smoke)
    run smoke "$GODOT" --headless --path "$PROJECT_DIR" --quit-after 300
    ;;
  test)
    run test "$GODOT" --headless --path "$PROJECT_DIR" --script res://tools/tests/run_tests.gd
    ;;
  patch)
    PATCH="${1:?usage: patch <patch.json> [--dry-run]}"
    case "$PATCH" in
      /*) PATCH_ABS="$PATCH" ;;
      *)  PATCH_ABS="$PROJECT_DIR/$PATCH" ;;
    esac
    if [ ! -f "$PATCH_ABS" ]; then echo "patch not found: $PATCH_ABS"; exit 1; fi
    shift
    if [ "${1:-}" = "--dry-run" ]; then
      run patch_dry_run "$GODOT" --headless --path "$PROJECT_DIR" --script res://tools/godot_apply_patch.gd -- "$PATCH_ABS" --dry-run
    else
      run patch_apply "$GODOT" --headless --path "$PROJECT_DIR" --script res://tools/godot_apply_patch.gd -- "$PATCH_ABS"
    fi
    ;;
  script)
    SCRIPT="${1:?usage: script <res://path.gd>}"
    shift
    run "script_$(basename "$SCRIPT" .gd)" "$GODOT" --headless --path "$PROJECT_DIR" --script "$SCRIPT" -- "$@"
    ;;
  export-android)
    OUT="${1:?usage: export-android <out.apk>}"
    case "$OUT" in /*) ;; *) OUT="$PROJECT_DIR/$OUT" ;; esac
    mkdir -p "$(dirname "$OUT")"
    run export_android "$GODOT" --headless --path "$PROJECT_DIR" --export-debug "Android" "$OUT"
    ;;
  --)
    run raw "$GODOT" --headless --path "$PROJECT_DIR" "$@"
    ;;
  *)
    cat <<'USAGE'
Headless Godot runner (headless-godot-skill-kit)

  tools/hgs_run.sh import                  full project import (the real gate)
  tools/hgs_run.sh smoke                   start main scene ~5s
  tools/hgs_run.sh test                    logic tests
  tools/hgs_run.sh patch <p.json>          apply a scene patch
  tools/hgs_run.sh patch <p.json> --dry-run
  tools/hgs_run.sh script <res://x.gd>     run a SceneTree script
  tools/hgs_run.sh export-android <out.apk>
  tools/hgs_run.sh -- <raw godot args>
USAGE
    ;;
esac
