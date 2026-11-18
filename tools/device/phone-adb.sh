#!/usr/bin/env bash
# phone-adb — self-healing adb transport to the phone over the WireGuard mesh.
# Canonical copy of /root/bin/phone-adb (kept byte-identical on the VPS).
#
# Root cause of the flaky Issue #23 vault push: `adb -s 10.9.0.2:5555` requires
# an ALREADY-registered transport. Whenever the VPS adb daemon restarts (or the
# wireless-debugging socket rotates) the target is absent and every push dies
# with "device '10.9.0.2:5555' not found". Ensure the transport first.
# adbd is pinned to TCP 5555 on the phone; WireGuard routes 10.9.0.2 to it, so
# this also works with the phone's Wi-Fi off / on cellular failover.
#
# Env overrides: CAP_ADB_BIN (default /usr/bin/adb), CAP_ADB_TARGET
# (default 10.9.0.2:5555). Verified cold-start: adb kill-server -> one call
# reconnects and returns `shell`.
set -uo pipefail
ADB="${CAP_ADB_BIN:-/usr/bin/adb}"
TARGET="${CAP_ADB_TARGET:-10.9.0.2:5555}"

is_up() {
  "$ADB" devices 2>/dev/null | grep -q "^${TARGET}[[:space:]]*device$"
}

ensure() {
  is_up && return 0
  "$ADB" connect "$TARGET" >/dev/null 2>&1
  local i=0
  while [ "$i" -lt 5 ]; do
    is_up && return 0
    i=$((i + 1))
    sleep 1
  done
  return 1
}

if ! ensure; then
  echo "phone-adb: cannot establish transport to $TARGET" >&2
  exit 1
fi
exec "$ADB" -s "$TARGET" "$@"
