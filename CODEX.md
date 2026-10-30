# CODEX.md — your operating context for Muakbank Zombie

You are codex, working headless on the Muakbank Zombie Godot 4.7 Android game. Read
this FIRST before any work. It routes you to every tool, plugin, asset source, and
MCP server you have — use the right one per job, never guess. If a tool is listed
here, it exists; if a task needs it, reach for it.

## Where things live (canonical paths)
- Godot project (VPS mirror you work on): `/root/muakbank_zombie` (via `ssh vps`)
- Canonical git (phone): `/storage/emulated/0/Games/Muakbank_zombie` — you edit the
  VPS mirror; Hermes commits from the phone.
- VPS Godot headless: `/root/Godot_v4.7-stable_linux.x86_64` (render anything with
  `xvfb-run` — real GL is required, `--headless` alone cannot render 3D).
- Godot project root files: `project.godot`, `export_presets.cfg` (Android preset).

## The game's architecture (summary)
3 open-world sandbox levels, each with embedded minigames that must all clear to advance:
- SAND1 Old Town (`scenes/world/environment/old_town_enhanced.tscn`) — 5 minigames
- SAND2 Industrial District (`.../industrial_district.tscn`) — armory_lockdown
- SAND3 Endgame Heights (`.../endgame_heights.tscn`) — endgame_extraction
Controllers: `scripts/gameplay/*Controller.gd`. Level map + difficulty/enemy/ambient:
`scripts/core/LevelManager.gd`. Crown: `scripts/core/Game.gd`.

## Tools and what they're FOR (routing policy — use the right lane)
- **GitHub MCP** — the PREFERRED tool for GitHub work (issues, PRs, single-file edits
  in existing repos). You (the agent) request it via the Hermes gate; if it is not in
  your toolset, do NOT fabricate a GitHub call — report that you need the gate to
  expose it. The **gh CLI** is the fallback ONLY for what the MCP cannot do: repo
  create with explicit visibility, `workflow`-scope pushes, and multi-file fresh
  branch pushes. Hermes owns commit/push for this repo; you work the VPS tree and
  Hermes commits — see AGENTS.md.
- **asset_grabber MCP** — source CC0 meshes/textures (Kenney / os3a / Quaternius /
  Poly Haven / CC0Tree sources) for ANY new prop or dressing. This is the volume
  engine for content. Do NOT hand-make art you can source.
- **Blender MCP** (VPS, socket `127.0.0.1:9876`, Blender 4.0.2 on Xvfb :99) —
  rescale / re-skin / rig / bake any sourced asset BEFORE it goes into Godot. A raw
  CC0 file that needs size/rotation/material adjustment passes through Blender first.
- **Godot-ai MCP** — live editor scene/UI/signal work in the running editor.
- **GDUnit** (`addons/gdUnit4/`, tests under `tests/`) — unit-test game LOGIC
  (player food/GLoot, minigame win conditions, weapon system). Add a test with each
  logic change.
- **regression_smoke.sh** (`tools/regression_smoke.sh`) — the BUILD GATE. After ANY
  change run it; it MUST end `REGRESSION: PASS` (5 checks: import, boot_dev,
  boot_game, player_api, minigames_win).
- **LampGate** (`scripts/world/LampGate.gd`) — lighting budget control: street lamps
  off unless player near. New content must NOT add always-on lights beyond the gated
  floodlight pattern.

## Plugins already integrated (do not re-install / do not fight)
GLoot (inventory) · godot-statecharts (enemy AI FSM) · Dialogue Manager (text) ·
godotx_health_bar · damage numbers · save_system · sound_manager ·
VectorFieldNavigation · object pooling. All registered in `project.godot`.

## MCP servers that exist (standalone VPS services)
`/root/mcp-servers/` — godot_mcp, gorrent_mcp, jellyfin_mcp, litellm_mcp, searxng_mcp,
todo_mcp, tor_mcp (+ the aggregate/icepick servers as built). Match their convention
(a Python MCP SDK server under `/root/mcp-servers/servers/` + a config entry +
`shared.py` last-used tracking) if you ever add one.

## What to NEVER do
- Never edit `addons/` internals. Never touch the minigame controllers' logic
  without a specific brief. Never add always-on lights. Never hardcode a full path
  that is not canonical above. Never delete a scene file (retire from the map only).
- Never trust `git status` "clean" on the VPS as done — Hermes re-verifies the tree.

## Your output contract
End every task with a `RESULT:`-prefixed block (RESULT / FILES / VERIFIED / GATE /
GDUNIT / CAVEAT / NEXT). Run `bash tools/regression_smoke.sh` + GDUnit and paste the
real tails — never claim green from a self-report.

## Verify actual state, not self-report
After you land work, re-check what your own script/command actually wrote to the tree
before calling it done. Empty output = not done.
