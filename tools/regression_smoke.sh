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
# CHECKS (in order — 12 checks total)
#   1. import            : headless engine import with a FRESH .godot cache
#                          (rm -rf .godot), run in up to 3 passes until one pass is
#                          CLEAN, gated on that pass. Multiple passes are required
#                          because Godot's FIRST cold pass can transiently fail to
#                          resolve resources whose import remap artifacts are built in
#                          the SAME pass (observed on this tip: main_theme.tres
#                          ->assets/fonts/*.ttf 'Cannot open file
#                          res://.godot/imported/...' / 'referenced non-existent
#                          resource' — the files exist and pass 2-3 import clean; the
#                          Godot editor does the same repeated-pass import on first
#                          open). Any GENUINE defect (script parse error, missing or
#                          un-importable asset, broken theme) re-fails every retry
#                          pass and is caught when no pass goes clean.
#                          NOTE: --import exits 0 even when scripts fail to parse
#                          (verified), so this gate is log-based, not exit-code-based.
#   2. boot_dev          : boots res://scenes/dev/test_zombie.tscn headless for
#                          BOOT_FRAMES_DEV frames under xvfb-run.
#                          FAIL on 'Animation.*not found' / 'SCRIPT ERROR' /
#                          non-allowlisted 'ERROR:' line, or nonzero exit.
#   3. boot_game         : boots res://scenes/main/game.tscn (real game scene, level 1
#                          old_town) headless for BOOT_FRAMES_GAME frames under xvfb.
#                          Same failure criteria as check 2.
#   4. player_api        : runs the EXISTING probe tools/addon_probe.tscn (reused, not
#                          duplicated). Instantiates the real Player and asserts the
#                          public food API (get_food_count / has_food / add_food /
#                          consume_food_type / get_food_heal) against the GLoot-backed
#                          GootInventory, plus the DialogueManager resource parse.
#                          PASS = probe prints 'PROBE_RESULT: PASS' and exits 0.
#   5. minigames         : runs the EXISTING probe tools/minigame_win_probe.tscn
#                          (reused, not duplicated). Instantiates each REAL controller
#                          (BioGenerator / SpoilAndSurvive / LastStandStation /
#                          TriageRoundup / QuarantineBreach / ArmoryLockdown /
#                          EndgameExtraction) and drives each state machine to its
#                          WIN state within a bounded simulation.
#                          PASS = probe exits 0 AND prints exactly
#                          MINIGAME_COUNT 'WON=true' lines AND 'ALL WIN REACHABLE'.
#   6. scale_contract    : locked GLB + live gameplay AABB drift guard (verifier + in-engine).
#   7. scale_perf        : FpsMonitor sampling with GLB instanced.
#   8. strict_typing     : explicit return types + typed params (Issue #32).
#   9. dismantle_playtest: GDD Issue #26 full-chain dismantling regression (tool-tier gate
#                          -> joint disconnect -> loot -> sole-writer registries -> debris cap -> recycle).
#                          Lightweight: no scene load, all nodes created programmatically.
#   10. cure_endgame_playtest: GDD Issue #28 Cure synthesis, majority achievement threshold,
#                          and post-cure open world state verification.
#                          Lightweight: AchievementManager instantiated programmatically.
#   11. save_migration_playtest: SaveManager v5->v6 migration roundtrip. Writes v5-shaped payload
#                          via SaveSystem, loads through SaveManager._load_game(), asserts all
#                          C1-C4 default keys backfilled and version==6.
#                          Lightweight: SaveManager instantiated programmatically.
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
PYTHON_BIN="${PYTHON_BIN:-python3}"
DETAILS=""
WORKDIR="$(mktemp -d /tmp/regression_smoke.XXXXXX)"

log()  { printf '%s\n' "$*"; }
# Fire a standardized telemetry webhook (type/severity/name/value/ts) on any
# regression failure. The notifier is fail-open: a webhook outage must NEVER
# break the build. Value is passed as a plain string; the notifier stores it as
# the event value. Non-blocking (>/dev/null 2>&1 || true).
notify_failure() {
    if [ -f "${PROJECT_ROOT}/tools/asset_registry_notify.py" ]; then
        "${PYTHON_BIN}" "${PROJECT_ROOT}/tools/asset_registry_notify.py" \
            --severity error --name "regression_failure" --value "$1" >/dev/null 2>&1 || true
    fi
}
bad()  { ERRORS=$((ERRORS + 1)); DETAILS="${DETAILS}${DETAILS:+; }$1"; log "  FAIL [$1]"; notify_failure "$1"; }

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
    log "[check ${CHECK}/12] ${name}: ${tscn} (${frames} frames max, xvfb)"
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

# --- pre-build asset registry gate (check 0/12) ------------------------------
CHECK=$((CHECK + 1))
log "[check ${CHECK}/12] asset_registry: pre-build referenced-model path integrity"
REG_LOG="${WORKDIR}/asset_registry.log"
if [ -f "${PROJECT_ROOT}/tools/check_asset_registry.py" ]; then
    (cd "$PROJECT_ROOT" && "${PYTHON_BIN}" tools/check_asset_registry.py --no-notify) > "$REG_LOG" 2>&1 || true
    if grep -q "ASSET_REGISTRY_OK True" "$REG_LOG"; then
        log "  asset_registry: OK ($(grep 'ASSET_REGISTRY_REFS' "$REG_LOG" | tail -1))"
    else
        bad "asset_registry: broken reference ($(grep -E 'ASSET_REGISTRY_BROKEN|ASSET_REGISTRY_SIDECARS_MISSING' "$REG_LOG" | head -1))"
    fi
else
    bad "asset_registry: check_asset_registry.py missing"
fi

# --- 2/8 fresh headless import (regenerates .godot) ------------------------
CHECK=$((CHECK + 1))
log "[check ${CHECK}/12] import: fresh headless import until stable (max 3 passes)"
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

# --- 6/6 scale-lock drift guard: GLB verifier + in-engine live AABB ----------
CHECK=$((CHECK + 1))
log "[check ${CHECK}/12] scale_contract: locked GLB + live gameplay AABB drift guard"
SCALE_LOG="${WORKDIR}/scale_contract.log"
if [ -f "${PROJECT_ROOT}/tools/blender/verify_scale_contract.py" ]; then
    (cd "$PROJECT_ROOT" && python3 tools/blender/verify_scale_contract.py) > "$SCALE_LOG" 2>&1 || true
    if grep -q "VERIFY_OK True" "$SCALE_LOG"; then
        log "  scale_contract: GLB lock OK"
    else
        bad "scale_contract: verifier did not report VERIFY_OK True ($(grep VERIFY_OK "$SCALE_LOG" | tail -1))"
    fi
else
    bad "scale_contract: verify_scale_contract.py missing"
fi
# in-engine: instance the GLB and assert live world AABBs match locked dims
RUNTIME_LOG="${WORKDIR}/scale_runtime.log"
if [ -f "${PROJECT_ROOT}/tools/tests/scale_runtime_playtest.gd" ]; then
    timeout "${TIMEOUT_S}" env GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" \
        --headless --path "$PROJECT_ROOT" --script tools/tests/scale_runtime_playtest.gd > "$RUNTIME_LOG" 2>&1
    if grep -q "RUNTIME_PASS=true" "$RUNTIME_LOG"; then
        _drift="$(grep 'LIVE_AABB' "$RUNTIME_LOG" | tail -1)"
        log "  scale_runtime: live AABB guard OK (${_drift})"
    else
        bad "scale_runtime: RUNTIME_PASS=true missing ($(grep -E 'RUNTIME_FAIL|drift=' "$RUNTIME_LOG" | tail -1)"
    fi
else
    bad "scale_runtime: playtest missing"
fi
unset _drift

# --- 7/7 runtime perf monitoring with the asset resident --------------------
CHECK=$((CHECK + 1))
log "[check ${CHECK}/12] scale_perf: FpsMonitor sampling with GLB instanced"
PERF_LOG="${WORKDIR}/scale_perf.log"
if [ -f "${PROJECT_ROOT}/tools/tests/scale_perf_probe.gd" ]; then
    timeout "${TIMEOUT_S}" env GODOT_SILENCE_ROOT_WARNING=1 "$GODOT_BIN" \
        --headless --path "$PROJECT_ROOT" --script tools/tests/scale_perf_probe.gd > "$PERF_LOG" 2>&1
    if grep -q "PERF_MONITORED=true" "$PERF_LOG"; then
        log "  scale_perf: FpsMonitor OK ($(grep 'FPSMON_AVG_FPS' "$PERF_LOG" | tail -1))"
    else
        bad "scale_perf: PERF_MONITORED=true missing ($(grep -E 'PERF_FAIL|SCRIPT ERROR' "$PERF_LOG" | tail -1)"
    fi
else
    bad "scale_perf: probe missing"
fi

# --- 8/12 strict typing gate (Issue #32) -------------------------------------
CHECK=$((CHECK + 1))
log "[check ${CHECK}/12] strict_typing: explicit return types + typed params"
STRICT_LOG="${WORKDIR}/strict_typing.log"
if (cd "$PROJECT_ROOT" && "${PYTHON_BIN}" tools/check_gdscript_strict.py --gate .) > "$STRICT_LOG" 2>&1; then
    log "  strict_typing: OK ($(grep 'STRICT_GATE' "$STRICT_LOG" | tail -1))"
else
    bad "strict_typing: $(grep -E 'STRICT_GATE|  FIX' "$STRICT_LOG" | head -1)"
fi

# --- 9/12 dismantle playtest (GDD Issue #26) ----------------------------------
CHECK=$((CHECK + 1))
log "[check ${CHECK}/12] dismantle_playtest: GDD26 full-chain dismantling regression"
DISMANTLE_LOG="${WORKDIR}/dismantle_playtest.log"
if [ -f "${PROJECT_ROOT}/tools/tests/dismantle_playtest.gd" ]; then
    timeout "${TIMEOUT_S}" env GODOT_SILENCE_ROOT_WARNING=1 $XVFB_RUN "$GODOT_BIN" \
        --headless --path "$PROJECT_ROOT" --script tools/tests/dismantle_playtest.gd > "$DISMANTLE_LOG" 2>&1
    if grep -q "GDD26_PASS=true" "$DISMANTLE_LOG"; then
        log "  dismantle_playtest: GDD26_PASS=true"
    else
        bad "dismantle_playtest: GDD26_PASS=true missing ($(grep -E 'GDD26_FAIL|SCRIPT ERROR' "$DISMANTLE_LOG" | tail -1))"
    fi
else
    bad "dismantle_playtest: playtest missing"
fi

# --- 10/12 cure endgame playtest (GDD Issue #28) --------------------------------
CHECK=$((CHECK + 1))
log "[check ${CHECK}/12] cure_endgame_playtest: GDD28 cure synthesis & post-cure"
CURE_LOG="${WORKDIR}/cure_endgame_playtest.log"
if [ -f "${PROJECT_ROOT}/tools/tests/cure_endgame_playtest.gd" ]; then
    timeout "${TIMEOUT_S}" env GODOT_SILENCE_ROOT_WARNING=1 $XVFB_RUN "$GODOT_BIN" \
        --headless --path "$PROJECT_ROOT" --script tools/tests/cure_endgame_playtest.gd > "$CURE_LOG" 2>&1
    if grep -q "GDD28_CURE_PASS=true" "$CURE_LOG"; then
        log "  cure_endgame_playtest: GDD28_CURE_PASS=true"
    else
        bad "cure_endgame_playtest: GDD28_CURE_PASS=true missing ($(grep -E 'GDD28_CURE_FAIL|SCRIPT ERROR' "$CURE_LOG" | tail -1))"
    fi
else
    bad "cure_endgame_playtest: playtest missing"
fi

# --- 11/12 save migration roundtrip (v5 -> v6) ----------------------------------
CHECK=$((CHECK + 1))
log "[check ${CHECK}/12] save_migration_playtest: SaveManager v5->v6 migration roundtrip"
MIGRATE_LOG="${WORKDIR}/save_migration_playtest.log"
if [ -f "${PROJECT_ROOT}/tools/tests/save_migration_playtest.gd" ]; then
    timeout "${TIMEOUT_S}" env GODOT_SILENCE_ROOT_WARNING=1 $XVFB_RUN "$GODOT_BIN" \
        --headless --path "$PROJECT_ROOT" --script tools/tests/save_migration_playtest.gd > "$MIGRATE_LOG" 2>&1
    if grep -q "MIGRATION_ROUNDTRIP_PASS=true" "$MIGRATE_LOG"; then
        log "  save_migration_playtest: MIGRATION_ROUNDTRIP_PASS=true"
    else
        bad "save_migration_playtest: MIGRATION_ROUNDTRIP_PASS=true missing ($(grep -E 'FAIL:|MIGRATION_ROUNDTRIP_FAIL|SCRIPT ERROR' "$MIGRATE_LOG" | tr '\n' ' | '))"
    fi
else
    bad "save_migration_playtest: playtest missing"
fi

# --- 12/12 world_hop_bidirectional playtest (GDD Issue #25 / C1) ---------------
# Heavy: instantiates full game.tscn + WorldProgression + WorldHopManager + waits for hops.
# Belongs in nightly-regression.yml, not the fast PR gate. NOT counted as a check.
log "[skip] world_hop_bidirectional_playtest: gated in nightly-regression.yml (heavy multi-scene boot: game.tscn + 3x secret hops, up to 1800 frames)"

# ---------------------------------------------------------------------------
# Verdict — MUST be the last stdout line (machine-parseable).
if [ "${ERRORS}" -eq 0 ]; then
    log "REGRESSION: PASS (${CHECK} checks, 0 errors)"
    exit 0
else
    log "REGRESSION: FAIL (${DETAILS})"
    exit 1
fi
