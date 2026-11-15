#!/bin/bash
# Phone-side wrapper for the Issue #20 nightly regression cron.
# Runs the full chain on the VPS (where Godot lives) via SSH. Prints NOTHING when
# healthy; prints the VPS failure report on a broken run (delivered to Telegram).
set -uo pipefail
out=$(ssh -p 2222 -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 \
  root@10.9.0.1 'bash /root/bin/mkb_nightly_regression.sh' 2>&1)
rc=$?
if [ "$rc" -ne 0 ] || [ -n "$out" ]; then
  echo "NIGHTLY REGRESSION (VPS) rc=$rc $(date -u +%Y-%m-%dT%H:%MZ)"
  echo "$out"
fi
exit 0
