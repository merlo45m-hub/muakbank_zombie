# CI/CD — Deployment Pipeline & Nightly Regression (Issues #20, #3)

## Workflows (`.github/workflows/`)

| File | Trigger | Jobs | Purpose |
|---|---|---|---|
| `pre_merge_gates.yml` | PR/push to `main` | `static-gate`, `headless-gate` | Pre-existing PR gates. **These job names are required by main's branch protection** — do not rename. |
| `deploy.yml` | push to `main`, `workflow_dispatch` | `verify-deploy-contract`, `build-apk`, `deploy-record` | Validates deploy tooling + poller engine, **builds the Android APK** and uploads it as an artifact, then records a GitHub Deployment. |
| `nightly-regression.yml` | `cron 0 3 * * *` (03:00 UTC), `workflow_dispatch` | `nightly-full-regression` | Full gate suite + the world-progression 1→2→3 acceptance playtest, nightly. |

All three lint clean under `actionlint 1.7.7`. New job names deliberately avoid
`static-gate`/`headless-gate` so branch protection is unaffected.

## Android export templates in CI (Issue #3 follow-up)

CI now builds the APK itself. `tools/install_android_templates.py` fetches only
the three Android entries (~232 MB: `android_debug.apk`, `android_release.apk`,
`version.txt`) from the 1.28 GB `Godot_v4.7-stable_export_templates.tpz` using
HTTP Range requests against the ZIP central directory — stdlib only, CRC-verified,
idempotent (0 bytes on a second run). `tools/setup_android_ci.sh` wraps it and
also seeds the two other things a clean runner lacks: a `keytool` debug keystore
and `editor_settings-4.7.tres` with `android_sdk_path` / `java_sdk_path` (Godot
refuses to export without them). ubuntu-latest ships `ANDROID_HOME` build-tools
34–37 incl. `apksigner`/`zipalign` and a JDK 17 (auto-detected by the script;
verified via browser_search against actions/runner-images).

`deploy.yml`'s `build-apk` job installs Godot 4.7 + xvfb, runs
`setup_android_ci.sh`, exports, validates the APK structure
(`AndroidManifest.xml` / `classes.dex` / `resources.arsc`, clean CRC), and uploads
`muakbank-zombie-apk-<sha>`. Godot 4.7 headless can return 134 at shutdown AFTER
a valid export, so the job asserts `[ DONE ] export` + the artifact, not the rc.

The VPS systemd timer `muakbank-auto-export.timer` → `tools/vps_auto_export.py`
remains the channel that copies the APK to the phone's `Download/` (issue #3,
`c692858`); CI now produces the artifact independently so the loop no longer
depends on the VPS being reachable.

## Nightly regression — two layers
1. **GitHub Actions** `nightly-regression.yml` — scheduled, uploads the playtest
   log on failure. Note: a `schedule` trigger only fires on the **default branch**,
   so this activates once `feat/ui-restructure` merges to `main`.
2. **On-device cron (active now)** — hermes job `4f5ea5e23641`
   (`mkb-nightly-regression`, `0 3 * * *`, `--no-agent`, deliver telegram).
   Phone wrapper `~/.hermes/scripts/mkb_nightly_cron.sh` SSHes to the VPS and runs
   `~root/bin/mkb_nightly_regression.sh`, which executes the SAME full chain on
   the real engine: static → fresh import → `regression_smoke.sh` → GDUnit →
   world-progression playtest. It asserts the machine-parseable verdict lines
   (`ISSUES: 0`, `REGRESSION: PASS (5 checks, 0 errors)`,
   `FULL_PROGRESSION_PASS=true`), prints **nothing when healthy**, and reports the
   failure log to Telegram otherwise. Env-overridable (`MKB_GODOT`, `MKB_REPO`,
   `MKB_STATE_DIR`) so the failure path is testable without breaking live state.

## Verification performed (2026-11-15, all live)
- `actionlint .github/workflows/*.yml` → rc 0.
- Deploy contract + 5-case poller harness (local bare origin) → `DEPLOY_STEPS_PASS`.
- `deploy-record` REST path → created deployment `7803531671`, set success status,
  deployments 0→1; smoke record then marked `inactive`.
- Full nightly chain on VPS → static 0, import 0 parse errors, REGRESSION PASS 5/5,
  GDUnit 12/12, `FULL_PROGRESSION_PASS=true`, `NIGHTLY_CHAIN_PASS`.
- Cron wrapper: silent/empty when healthy; forced-failure prints the report.
- **Template installer**: offline (local .tpz) and live HTTP-range installs both
  produced byte-identical, CRC-verified templates fetching only 229,526,609 bytes
  (vs 1,279,207,690); second run fetched 0 bytes; `version.txt = 4.7.stable`.
- **Clean-HOME CI export** (the decisive test for #3): a fresh HOME with ONLY the
  installed templates, generated keystore, and seeded editor settings produced a
  valid 61,050,196-byte signed APK (2,650 zip entries, manifest/dex/arsc, CRC
  clean) with `[ DONE ] export`, `export_rc=0`. Both the explicit-SDK and the
  auto-detected-JDK paths were proven. Note: an earlier attempt WITHOUT the
  editor settings failed with "A valid Java SDK path is required in Editor
  Settings" — that is what `setup_android_ci.sh` fixes.
- Pre-existing non-fatal parse warnings during export:
  `assets/materials/final_truck_emission.tres:9 Unexpected identifier 'True'` and
  `tools/verify_rects_probe.gd get_viewport_rect()` — both stray files, not part
  of this change; the static gate still reports `ISSUES: 0`.
