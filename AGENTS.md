# AGENTS.md — Muakbank Zombie

## Project
- **Root:** `/storage/emulated/0/Games/Muakbank_zombie/`
- **GitHub:** `merlo45m-hub/muakbank_zombie` (main)
- **Godot:** 4.7 — arms64 binary can't run on Termux; exports on VPS
- **VPS:** `root@162.35.174.155`

## Roles
- **Hermes (Solar Pro4):** Oversight, review, user comms
- **agy:** Heavy coding, Godot 4 API lookups, build troubleshooting

## Workflow
1. Read file → plan → edit locally on phone storage
2. Heavy coding → delegate to agy (MCPs: filesystem, fs-project, docs)
3. Hermes reviews → commits → pushes to GitHub

## Constraints
- Phone project `.git` is healthy — use it directly, no clones needed
- Every path absolute: `/storage/emulated/0/...` or `/data/data/com.termux/files/home/...`
- Read before write. Check `.git/HEAD` before git ops.

## Last verified: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Headless Godot pipeline (headless-godot-skill-kit)

All Godot work runs on the VPS — Termux cannot run the binary. Run EVERYTHING through
`tools/hgs_run.sh`, never `godot` directly; it pins the XDG dirs and GODOT_TEMPLATES_DIR so
behaviour is identical everywhere and writes logs/.

After ANY change (scene, script, autoload, preset), run the full pipeline and fix failures
before committing:

1. Import gate:   tools/hgs_run.sh import
                   # full reimport = the real compile gate (autoloads register here)
2. Apply patch:   tools/hgs_run.sh patch tools/patches/<x>.json --dry-run   # pre-validate first
                   tools/hgs_run.sh patch tools/patches/<x>.json
3. Smoke start:   tools/hgs_run.sh smoke            # starts title_screen; catches _ready errors
4. Logic tests:   tools/hgs_run.sh test             # must print "tests passed"
5. Android export: tools/hgs_run.sh export-android build/muakbank_zombie.apk

Rules (from the skill):
- NEVER edit .tscn as raw text. Scene changes go through a reviewable patch.json applied by
  godot_apply_patch.gd. Re-run via hgs_run.sh after any manual tweak.
- Always dry-run a patch before applying; the applier auto-.baks and restores on failure.
- The applier resolves the scene ROOT only for node path "" or ".", not the root's name.
- Do NOT rely on --check-only or --script to type-check autoload-referencing scripts — they
  compile BEFORE autoloads register. The import step is the compile gate.
- All command output lands in logs/*.log; quote it when debugging.
- After a rename_node op, update $OldName / get_node() references in scripts.
