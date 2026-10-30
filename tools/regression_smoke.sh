#!/usr/bin/env bash
# ============================================================================
# regression_smoke.sh — Muakbank Zombie CANONICAL regression smoke gate
# ----------------------------------------------------------------------------
# WHAT THIS IS
#   A single, deterministic, machine-parseable smoke suite that proves the game
#   machinery (script compilation, scene boots, player food API + GLoot wiring,
#   all SEVEN embedded mini-game WIN states) is sound after ANY change.
#
# HOW TO RUN (human or CI — identical command, identical verdict)
#       bash tools/regression_smoke.sh
#
# ACCEPTANCE RULE
#   Exit code 0  AND final stdout line "REGRESSION: PASS (N checks, M errors)"
#                                                          == GATE GREEN.
#   Exit code !=0 / final line "REGRESSION: FAIL (...)"    == GATE RED.
#   In CI: run the same command; the exit code IS the gate.
#
# CHECKS (in order — 5 checks total)
#   1. import      : headless engine import with a FRESH .godot cache
#                    (rm -rf .godot), run in up to 3 passes until one pass is
#                    CLEAN, gated on that pass. Multiple passes are required
#                    because Godot's FIRST cold pass can transiently fail to
#                    resolve resources whose import remap artifacts are built in
#                    the SAME pass (observed on this tip: main_theme.tres
#                    ->assets/fonts/*.ttf 'Cannot open file
#                    res://.godot/imported/...' / 'referenced non-existent
#                    resource' — the files exist and pass 2-3 import clean; the
#                    Godot editor does the same repeated-pass import on first
#                    open). Any GENUINE defect (script parse error, missing or
#                    un-importable asset, broken theme) re-fails every retry
#                    pass and is caught when no pass goes clean.
#                    NOTE: --import exits 0 even when scripts fail to parse
#                    (verified), so this gate is log-based, not exit-code-based.
#   2. boot_dev    : boots res://scenes/dev/test_zombie.tscn headless for
#                    BOOT_FRAMES_DEV frames under xvfb-run.
#                    FAIL on 'Animation.*not found' / 'SCRIPT ERROR' /
#                    non-allowlisted 'ERROR:' line, or nonzero exit.
#   3. boot_game   : boots res://scenes/main/game.tscn (real game scene, level 1
#                    old_town) headless for BOOT_FRAMES_GAME frames under xvfb.
#                    Same failure criteria as check 2.
#   4. player_api  : runs the EXISTING probe tools/addon_probe.tscn (reused, not
#                    duplicated). Instantiates the real Player and asserts the
#                    public food API (get_food_count / has_food / add_food /
#                    consume_food_type / get_food_heal) against the GLoot-backed
#                    GootInventory, plus the DialogueManager resource parse.
#                    PASS = probe prints 'PROBE_RESULT: PASS' and exits 0.
#   5. minigames   : runs the EXISTING probe tools/minigame_win_probe.tscn
#                    (reused, not duplicated). Instantiates each REAL controller
#                    (BioGenerator / SpoilAndSurvive / LastStandStation /
#                    TriageRoundup / QuarantineBreach / ArmoryLockdown /
#                    EndgameExtraction) and drives each state machine to its
#                    WIN state within a bounded simulation.
#                    PASS = probe exits 0 AND prints exactly
#                    MINIGAME_COUNT 'WON=true' lines AND 'ALL WIN REACHABLE'.
#
# ALLOWLIST — the EXPLICIT set of tolerated lifecycle noise lines (only these
#   'ERROR'/warning lines may appear; anything else fails the gate):
#     - 'resources still in use at exit'                 Godot exit-time orphaned-resource report (fires on any heavy headless quit)
#     - 'RID allocations of type ... were leaked at exit'  dummy-renderer RID leak report emitted at exit
#     - 'Pages in use exist at exit in PagedAllocator:'    dummy-renderer / VariantPool allocator report at exit
#     - 'ObjectDB instances were leaked at exit'            object leak notice at exit (WARNING in 4.7; allowlisted for robustness)
#     - 'cannot connect to daemon tcp:5037'                adb/daemon probe noise on CI images — unrelated to game code
#     - 'llvmpipe' / 'libGL error' / 'Mesa'                software-GL driver chatter under xvfb-run
#     - 'GODOT_SILENCE_ROOT_WARNING'                       root-user boot notice (also suppressed via env)
#
# CONFIG (env overrides, all optional)
#   GODOT_BIN  engine binary      (default: /root/Godot_v4.7-stable_linux.x86_64)
#   TIMEOUT_S  per-step timeout s (default: 420; the fresh import is the slowest)
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/root/Godot_v4.7-stable_linux.x86_64}"
TIMEOUT_S="${TIMEOUT_S:-420}"
XVFB_RUN="${XVFB_RUN:-xvfb-run -a}"

BOOT_FRAMES_DEV=180
BOOT_FRAMES_GAME=240
MINIGAME_COUNT=7
MINIGAME_SUMMARY="MINIWIN RESULT ALL WIN REACHABLE"

ALLOWED='resources still in use at exit|RID allocations of type .* were leaked at exit|RID allocations leaked|Pages in use exist at exit in PagedAllocator|ObjectDB instances were leaked at exit|cannot connect to daemon tcp:5037|llvmpipe|libGL error|Mesa|GODOT_SILENCE_ROOT_WARNING'

CHECK=0
ERRORS=0
DETAILS=""
WORKDIR="$(mktemp -d /tmp/regression_smoke.XXXXXX)"

log()  { printf '%s\n' "$*"; }
bad()  { ERRORS=$((ERRORS + 1)); DETAILS="${DETAILS}${DETAILS:+; }$1"; log "  FAIL [$1]"; }

# scan_errors <logfile> <check_name> — the fixed error criteria for a run log:
# any animation-not-found, script error / parse error, or non-allowlisted ERROR.
scan_errors() {
    local logf="$1" name="$2" badline script_anim

    script_anim="$(grep -iE "animation[^.]*not found|not found[^.]*animation|SCRIPT ERROR|Parse Error" "$logf" || true)"
    if [ -n "$script_anim" ]; then
        bad "${name}: script/animation error present: $(printf '%s\n' "$script_anim" | head -1)"
        return
    fi

    badline="$(grep -E "^ERROR:|^SCRIPT ERROR:| ERROR:" "$logf" | grep -Ev "$ALLOWED" || true)"
    if [ -n "$badline" ]; then
        bad "${name}: non-allowlisted ERROR: $(printf '%s\n' "$badline" | head -1)"
        return
    fi
}

# run_scene <tscn> <check_name> <quit_after> <expected_marker> <expected_count>
run_scene() {
    local tscn="$1" name="$2" frames="$3" marker="$4" want="$5" rc got logf
    logf="${WORKDIR}/${name}.log"
    CHECK=$((CHECK + 1))
    log "[check ${CHECK}/5] ${name}: ${tscn} (${frames} frames max, xvfb)"
    # shellcheck disable=SC2086
    timeout "${TIMEOUT_S}" env GODOT_SILENCE_ROOT_WARNING=1 $XVFB_RUN "$GODOT_BIN" \
        --headless --path "$PROJECT_ROOT" "$tscn" --quit-after "$frames" > "$logf" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        [ "$rc" -eq 124 ] && bad "${name}: TIMEOUT after ${TIMEOUT_S}s" \
                          || bad "${name}: engine exited rc=${rc}"
        return
    fi
    scan_errors "$logf" "$name"
    if [ -n "$marker" ]; then
        got="$(grep -c "$marker" "$logf" || true)"
        if [ "$got" -ne "$want" ]; then
            bad "${name}: expected ${want}x '${marker}' in log, found ${got}"
        fi
    fi
}

# ---------------------------------------------------------------------------
log "=== Muakbank Zombie regression smoke gate ==="
log "project : ${PROJECT_ROOT}"
log "engine  : ${GODOT_BIN}"
log "logs    : ${WORKDIR}"

# --- 1/5 fresh headless import (regenerates .godot) ------------------------
CHECK=$((CHECK + 1))
log "[check 1/5] import: fresh headless import until stable (max 3 passes)"
rm -rf "${PROJECT_ROOT}/.godot"

IMPORT_PASS=""
for p in 1 2 3; do
    timeout "${TIMEOUT_S}" env GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" \
        --headless --path "$PROJECT_ROOT" --import > "${WORKDIR}/import${p}.log" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        [ "$rc" -eq 124 ] && bad "import: pass ${p} TIMEOUT after ${TIMEOUT_S}s" \
                          || bad "import: pass ${p} engine exited rc=${rc}"
        continue
    fi
    # A pass is 'clean' when it contains no script/animation/parse error and no
    # non-allowlisted ERROR line. Pass 1 of a cold cache is expected to be
    # racy (import remaps built in-pass); the first clean pass is the gate.
    _bad="$(grep -iE "animation[^.]*not found|not found[^.]*animation|SCRIPT ERROR|Parse Error|^ERROR:|^SCRIPT ERROR:| ERROR:" "${WORKDIR}/import${p}.log" \
        | grep -Ev "$ALLOWED" || true)"
    if [ -z "$_bad" ]; then
        IMPORT_PASS="$p"
        log "  import: pass ${p} clean (stable)"
        break
    fi
done
if [ -z "$IMPORT_PASS" ]; then
    _last="$(grep -iE "SCRIPT ERROR|Parse Error|^ERROR:" "${WORKDIR}/import3.log" | grep -Ev "$ALLOWED" | head -1 || true)"
    bad "import: never stable after 3 passes; last error: ${_last:-see import3.log}"
fi
unset _bad _last

# --- 2/5 + 3/5 scene boots --------------------------------------------------
run_scene "res://scenes/dev/test_zombie.tscn"  "boot_dev"  "${BOOT_FRAMES_DEV}"  "" 0
run_scene "res://scenes/main/game.tscn"        "boot_game" "${BOOT_FRAMES_GAME}" "" 0

# --- 4/5 player food API + GLoot wiring (existing probe, reused) ------------
run_scene "res://tools/addon_probe.tscn" "player_api" 3000 "PROBE_RESULT: PASS" 1

# --- 5/5 mini-game WIN states (existing probe, reused) ----------------------
run_scene "res://tools/minigame_win_probe.tscn" "minigames_win" 3000 "WON=true" "${MINIGAME_COUNT}"
if ! grep -q "${MINIGAME_SUMMARY}" "${WORKDIR}/minigames_win.log" 2>/dev/null; then
    bad "minigames_win: summary line '${MINIGAME_SUMMARY}' missing from log"
fi

# ---------------------------------------------------------------------------
# Verdict — MUST be the last stdout line (machine-parseable).
if [ "${ERRORS}" -eq 0 ]; then
    log "REGRESSION: PASS (${CHECK} checks, 0 errors)"
    exit 0
else
    log "REGRESSION: FAIL (${DETAILS})"
    exit 1
fi
