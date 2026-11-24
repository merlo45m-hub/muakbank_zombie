#!/usr/bin/env bash
# cure_persistence_harness.sh — fresh-process save→reload persistence proof for
# GDD Issue #28 cure state.
#
# Runs tools/tests/cure_save_reload_probe.gd twice in two FRESH Godot processes
# sharing one temp save file: SETUP (synthesize + persist) then VERIFY (reload +
# assert post_cure, 3 world bosses, cure_synthesized unlock). All paths are
# absolute; no secrets are hardcoded.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/root/Godot_v4.7-stable_linux.x86_64}"
TIMEOUT_S="${TIMEOUT_S:-420}"
XVFB_RUN="${XVFB_RUN:-xvfb-run -a}"

WORKDIR="$(mktemp -d /tmp/cure_persistence.XXXXXX)"
SAVE_PATH="${WORKDIR}/cure_savegame.save"
PROBE="${PROJECT_ROOT}/tools/tests/cure_save_reload_probe.gd"
SETUP_LOG="${WORKDIR}/setup.log"
VERIFY_LOG="${WORKDIR}/verify.log"

fail() {
    printf 'CURE_PERSISTENCE: FAIL — %s\n' "$*" >&2
    exit 1
}

log() { printf 'CURE_PERSISTENCE: %s\n' "$*"; }

[ -f "$GODOT_BIN" ] || fail "godot binary not found: $GODOT_BIN"
[ -f "$PROBE" ] || fail "probe missing: $PROBE"

# --- SETUP: fresh process synthesizes the cure and persists --------------------
env CURE_PROBE_MODE=SETUP CURE_SAVE_PATH="$SAVE_PATH" \
    timeout "${TIMEOUT_S}" env GODOT_SILENCE_ROOT_WARNING=1 $XVFB_RUN "$GODOT_BIN" \
    --headless --path "$PROJECT_ROOT" --script "$PROBE" > "$SETUP_LOG" 2>&1
SETUP_RC=$?
if [ "$SETUP_RC" -ne 0 ]; then
    fail "SETUP process rc=${SETUP_RC} (${SETUP_LOG})"
fi
grep -q "CURE_SETUP_PASS=true" "$SETUP_LOG" || fail "CURE_SETUP_PASS=true missing in setup log"
[ -f "$SAVE_PATH" ] || fail "save file not written to disk: $SAVE_PATH"
log "SETUP OK (save: $SAVE_PATH)"

# --- VERIFY: fresh process reloads and asserts ---------------------------------
env CURE_PROBE_MODE=VERIFY CURE_SAVE_PATH="$SAVE_PATH" \
    timeout "${TIMEOUT_S}" env GODOT_SILENCE_ROOT_WARNING=1 $XVFB_RUN "$GODOT_BIN" \
    --headless --path "$PROJECT_ROOT" --script "$PROBE" > "$VERIFY_LOG" 2>&1
VERIFY_RC=$?
if [ "$VERIFY_RC" -ne 0 ]; then
    fail "VERIFY process rc=${VERIFY_RC} (${VERIFY_LOG})"
fi
grep -q "CURE_VERIFY_PASS=true" "$VERIFY_LOG" || fail "CURE_VERIFY_PASS=true missing in verify log"

log "VERIFY OK (post_cure + 3 world bosses + cure_synthesized reload-asserted)"
printf 'CURE_PERSISTENCE_PASS=true\n'
exit 0
