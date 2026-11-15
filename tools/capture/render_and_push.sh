#!/usr/bin/env bash
# Issue #23 — headless (Xvfb software-GL) visual capture to the Obsidian vault.
# --headless has NO GL context; renders run under Xvfb with gl_compatibility.
# CI=1 skips the vault push (GitHub runner has no WireGuard mesh / adb).
set -uo pipefail
REPO="${CAP_REPO:-/root/muakbank_zombie}"
cd "$REPO" || exit 1
G="${CAP_GODOT:-/root/Godot_v4.7-stable_linux.x86_64}"
OUT="$REPO/build/capture"
VAULT="${CAP_VAULT:-/storage/emulated/0/ObsidianVault/muakbank_zombie/renders}"
PHONE_ADB="${CAP_ADB:-/root/bin/phone-adb}"
MANIFEST=tools/capture/manifest.txt
mkdir -p "$OUT"
export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe

echo "=== fresh import (no GL needed; populates .godot/) ==="
xvfb-run -a "$G" --headless --import --path . > /tmp/cap_import.log 2>&1
echo "import_rc=$? parse_errors=$(grep -cE 'SCRIPT ERROR|Parse Error' /tmp/cap_import.log)"

fail=0
capture() {
  local scene="$1" name="$2" frames="${3:-8}"
  echo "--- capture $name <- $scene ---"
  CAP_SCENE="$scene" CAP_OUT="$OUT/${name}.png" CAP_FRAMES="$frames" \
  xvfb-run -a -s "-screen 0 1600x900x24" "$G" \
      --display-driver x11 \
      --rendering-method gl_compatibility \
      --rendering-driver opengl3 \
      --resolution 1600x900 \
      --fixed-fps 60 \
      --path . \
      --script tools/capture/capture_scenetree.gd \
      > "/tmp/cap_${name}.log" 2>&1
  local rc=$?
  # NEVER pipe Godot through head -N: closing the pipe SIGPIPEs the engine.
  grep -E 'CAP:|SCRIPT ERROR|Parse Error|shader.*error' "/tmp/cap_${name}.log" | tail -12 || true
  if [ "$rc" -ne 0 ] || [ ! -s "$OUT/${name}.png" ]; then
    echo "CAPTURE_FAIL $name rc=$rc"; fail=1
  else
    echo "CAPTURE_OK $name bytes=$(wc -c < "$OUT/${name}.png")"
  fi
}

while IFS='|' read -r scene name frames; do
  [[ "$scene" == \#* || -z "$scene" ]] && continue
  capture "$scene" "$name" "$frames"
done < "$MANIFEST"

echo "=== validate captures ==="
python3 tools/capture/check_captures.py "$OUT" "$MANIFEST" || fail=1

# Markdown index note (renderer labelling is mandatory: different backend).
{
  echo "# Visual capture — $(date -u +%Y-%m-%dT%H:%MZ)"
  echo
  echo "- git SHA: $(git rev-parse --short HEAD)"
  echo "- renderer: gl_compatibility/llvmpipe (Xvfb software GL)"
  echo "- **mobile-renderer-unverified**: shipped project uses rendering_method=mobile (Vulkan)"
  echo "- headless PASS = structural/compile/regression signal, NOT device visual sign-off"
  echo "- report: capture_report.json"
} > "$OUT/README.md"

if [ "${CI:-0}" != "1" ]; then
  echo "=== vault push (VPS mesh only) ==="
  if timeout 20 "$PHONE_ADB" shell whoami 2>/dev/null | grep -qx shell; then
    "$PHONE_ADB" shell mkdir -p "$VAULT" 2>/dev/null || true
    "$PHONE_ADB" push "$OUT/." "$VAULT/" 2>&1 | tail -4
    echo "vault_push_rc=${PIPESTATUS[0]}"
  else
    echo "VAULT_PUSH_SKIPPED phone-adb unreachable (non-fatal)"
  fi
else
  echo "VAULT_PUSH_SKIPPED CI=1 (no mesh on GitHub runner)"
fi

echo "RENDER_AND_PUSH_FAIL=$fail"
exit "$fail"
