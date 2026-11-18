# On-device testing harness (Issue #21 / #23 follow-up)

Configured 2026-11-15. Purpose: lock down **mobile-specific shader behaviours**
that the Xvfb/llvmpipe capture pipeline (#23) cannot prove — the shipped game
uses `rendering_method="mobile"` (Vulkan) on an Adreno GPU, a different backend
from `gl_compatibility`.

## Hardware (verified live)

| Property | Value |
|---|---|
| Device | Samsung SM-S948U (Galaxy S26 Ultra) |
| Android | 16 |
| GPU | Qualcomm Adreno 840, OpenGL ES 3.2 V@0842.19.8 |
| Game package | `com.merlo45.muakbankzombie` (installed) |
| Mesh transport | WireGuard `10.9.0.2:5555`, adbd pinned to TCP 5555 |
| `adb shell id` | `uid=2000(shell) ... context=u:r:shell:s0` |

## Artifacts

- `tools/device/phone-adb.sh` — canonical, self-healing adb wrapper. Byte-identical
  to the live `/root/bin/phone-adb`. Env overrides `CAP_ADB_BIN`, `CAP_ADB_TARGET`.
  Fixes the flaky vault push: `adb -s` requires an already-registered transport,
  so a daemon restart caused `device '10.9.0.2:5555' not found`. `ensure()`
  reconnects with a bounded retry loop. Verified by `adb kill-server` cold start.
- `tools/device/device_harness.sh` — launches the shipped APK, then captures:
  gfxinfo framestats + summary, `dumpsys thermalservice`, 77 thermal-zone temps,
  an on-device `screencap` PNG of the real Vulkan renderer, and a shader/GPU
  error log. Writes `build/device_capture/` (gitignored) and prints
  `DEVICE_HARNESS_PASS=1`. Env: `CAP_PKG`, `CAP_OUT`, `CAP_DURATION`.

## Android 16 LogAccessDialog workaround — VERIFIED

Reading logcat as an **app uid** pops
`com.android.systemui/.logcat.LogAccessDialogActivity` ("allow access only one
time") on every read; `pm grant READ_LOGS` does not cover it. `adb shell logcat`
runs as **uid 2000(shell)**, which is allowed and triggers nothing.

Verification (2026-11-15): three consecutive `adb shell logcat -d` reads
(32 lines each) produced `dialog_windows=0`, no `LogAccessDialogActivity` /
`LogcatManagerService` launches in the log, and `uid=2000(shell)` confirmed.
A negative control that deliberately triggers the dialog was **not** run on the
live device (it would pop a UI prompt while the user is using the phone); the
positive-path evidence plus the documented uid mechanism is the proof.

Rule: **never** invoke `/system/bin/logcat` directly from Termux/app code;
route every read through `adb shell logcat`.

## Harness result (live run)

```
LOGCAT_ROUTE adb_shell lines=52 dialog_windows=0
LOGCAT_UID uid=2000(shell)
FOREGROUND mCurrentFocus=... com.merlo45.muakbankzombie/com.godot.game.GodotAppLauncher
GFXINFO_BYTES 9677
THERMAL_ZONES 77
DEVICE_FRAME_OK bytes=2449249
SHADER_LOG_LINES 864
DEVICE_HARNESS_PASS=1
```

## Honest scope

The harness proves the device launches the game, produces a real-renderer frame,
and that logcat is readable without the dialog. It does **not** yet assert
perceptual shader fidelity (rim bloom, fog banding, temporal accumulation) or
frame-rate/thermal thresholds — those need a human review against reference
photos #12/#13/#14 and remain the #21 device visual sign-off. The frame/thermal
metrics are captured for that review, not judged here.
