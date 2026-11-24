#!/usr/bin/env bash
# tools/qa/device_preflight.sh — read-only device preflight gate.
#
# Reads ADB_TARGET (default 127.0.0.1:5555) and PKG (optional, reserved for
# callers targeting a specific package). Read-only checks only:
#   * power mWakefulness      -> Dozing means the device is locked
#   * current window focus    -> Bouncer/NotificationShade focus means locked
#
# Never launches an app and never injects input.
#
#   DEVICE_LOCKED + exit 2  -> do not proceed; do not launch or inject input
#   DEVICE_READY  + exit 0  -> safe to proceed
set -uo pipefail

ADB="${ADB:-adb}"
ADB_TARGET="${ADB_TARGET:-127.0.0.1:5555}"
PKG="${PKG:-}"

if ! "$ADB" -s "$ADB_TARGET" shell dumpsys power >/dev/null 2>&1; then
    printf 'DEVICE_LOCKED\n' >&2
    exit 2
fi

wake="$("$ADB" -s "$ADB_TARGET" shell dumpsys power 2>/dev/null | grep -i 'mWakefulness=' | head -1)"
if printf '%s' "$wake" | grep -iq 'Dozing'; then
    printf 'DEVICE_LOCKED\n'
    exit 2
fi

focus="$("$ADB" -s "$ADB_TARGET" shell dumpsys window windows 2>/dev/null \
    | grep -Ei 'mCurrentFocus|mFocusedApp' | head -1)"
if printf '%s' "$focus" | grep -Eiq 'Bouncer|NotificationShade'; then
    printf 'DEVICE_LOCKED\n'
    exit 2
fi

printf 'DEVICE_READY\n'
exit 0
