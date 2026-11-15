#!/usr/bin/env bash
# tools/setup_android_ci.sh — prepare a CLEAN Godot HOME for headless Android
# export on a CI runner (Issue #3 / #20). Idempotent + env-overridable.
#
# What a GitHub ubuntu-latest runner lacks out of the box:
#   1. Godot Android export templates (installed here via ranged HTTP, ~232MB
#      instead of the 1.28GB .tpz) — tools/install_android_templates.py
#   2. A debug keystore for signed exports — generated with keytool
#   3. Godot Editor Settings pointing at the Java/Android SDK paths — written here
#
# ubuntu-latest ships ANDROID_HOME=/usr/local/lib/android/sdk with build-tools
# 34-37 (apksigner/zipalign) and a JDK 17 at JAVA_HOME_17_X64.
#
# Env overrides (also used for local verification on the VPS):
#   GODOT_HOME          clean HOME to populate (default $HOME)
#   ANDROID_SDK         Android SDK path (default $ANDROID_HOME or runner default)
#   JAVA_SDK            Java SDK path (default $JAVA_HOME_17_X64 / $JAVA_HOME)
#   GODOT_TEMPLATES_*   passed through to install_android_templates.py
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_HOME="${GODOT_HOME:-$HOME}"
ANDROID_SDK="${ANDROID_SDK:-${ANDROID_HOME:-/usr/local/lib/android/sdk}}"
JAVA_SDK="${JAVA_SDK:-${JAVA_HOME_17_X64:-${JAVA_HOME:-}}}"
if [ -z "$JAVA_SDK" ]; then
  # ubuntu-latest ships several JDKs; prefer 17, else any java-*-openjdk/temurin.
  JAVA_SDK="$(ls -d /usr/lib/jvm/*17* /usr/lib/jvm/temurin-17* 2>/dev/null | head -1 || true)"
fi
if [ -z "$JAVA_SDK" ]; then
  JAVA_SDK="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
fi
VERSION="${GODOT_TEMPLATES_VERSION:-4.7.stable}"

DATA="$GODOT_HOME/.local/share/godot"
KEYSTORES="$DATA/keystores"
CONF="$GODOT_HOME/.config/godot"
TPL="$DATA/export_templates/$VERSION"
mkdir -p "$KEYSTORES" "$CONF" "$TPL"

echo "[setup] GODOT_HOME=$GODOT_HOME"
echo "[setup] ANDROID_SDK=$ANDROID_SDK"
echo "[setup] JAVA_SDK=$JAVA_SDK"

# 1) Debug keystore (standard Android debug credentials).
if [ ! -f "$KEYSTORES/debug.keystore" ]; then
  keytool -genkeypair -v -keystore "$KEYSTORES/debug.keystore" \
    -storepass android -alias androiddebugkey -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" > /dev/null 2>&1
  echo "[setup] generated debug.keystore"
else
  echo "[setup] debug.keystore already present"
fi

# 2) Editor settings with SDK paths (Godot refuses to export without these).
cat > "$CONF/editor_settings-4.7.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_SDK"
export/android/java_sdk_path = "$JAVA_SDK"
export/android/debug_keystore = "$KEYSTORES/debug.keystore"
export/android/debug_keystore_pass = "android"
export/android/debug_keystore_alias = "androiddebugkey"
EOF
echo "[setup] wrote editor_settings-4.7.tres"

# 3) Android export templates (ranged fetch; pass GODOT_TEMPLATES_LOCAL for offline tests).
GODOT_TEMPLATES_DIR="$TPL" \
GODOT_TEMPLATES_VERSION="$VERSION" \
  python3 "$REPO/tools/install_android_templates.py"

# 4) Post-conditions.
for f in android_debug.apk android_release.apk version.txt; do
  test -s "$TPL/$f" || { echo "[setup] MISSING $f"; exit 1; }
done
test -s "$KEYSTORES/debug.keystore" || { echo "[setup] MISSING keystore"; exit 1; }
echo "[setup] OK Android CI export environment ready"
