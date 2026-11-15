# CI/CD — Deployment Pipeline & Nightly Regression (Issue #20)

## Workflows (`.github/workflows/`)

| File | Trigger | Jobs | Purpose |
|---|---|---|---|
| `pre_merge_gates.yml` | PR/push to `main` | `static-gate`, `headless-gate` | Pre-existing PR gates. **These job names are required by main's branch protection** — do not rename. |
| `deploy.yml` | push to `main`, `workflow_dispatch` | `verify-deploy-contract`, `deploy-record` | Validates the deploy tooling + poller engine, then records a GitHub Deployment (`vps-android`). |
| `nightly-regression.yml` | `cron 0 3 * * *` (03:00 UTC), `workflow_dispatch` | `nightly-full-regression` | Full gate suite + the world-progression 1→2→3 acceptance playtest, nightly. |

All three lint clean under `actionlint 1.7.7`. New job names deliberately avoid
`static-gate`/`headless-gate` so branch protection is unaffected.

## What actually deploys
GitHub-hosted runners cannot build the Android APK (no Godot export templates /
`apksigner`). The real deployment is executed by the **VPS systemd timer**
`muakbank-auto-export.timer` → `tools/vps_auto_export.py`, which polls
`origin/main`, exports the APK with Godot 4.7 under xvfb, and scp's it to the
phone's `Download/` (issue #3, commit `c692858`). `deploy.yml` does NOT claim to
build the APK — it verifies the deploy contract (tooling present, `py_compile`,
`bash -n`, `validate_project.py`, Android preset, and the 5-case poller harness
against a **local bare git origin** so CI needs no credentials) and records the
deployment + success status via the GitHub REST API using `GITHUB_TOKEN`.

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
- Cron wrapper: silent/empty output when healthy; forced-failure (`MKB_GODOT` bad)
  prints the failure report. Cron doctor shows the new job enabled; its two reported
  issues are pre-existing unrelated jobs (curator-weekly etc.), not this one.
