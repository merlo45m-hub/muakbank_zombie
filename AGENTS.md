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
