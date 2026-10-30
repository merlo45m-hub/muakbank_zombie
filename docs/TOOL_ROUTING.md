# TOOL ROUTING POLICY — Muakbank Zombie

Purpose: guarantee every tool in the studio earns its place. No tool sits idle on
work a better tool owns; no two tools duplicate the same job. A wave that doesn't
declare its tools isn't a wave — it's improvisation.

## Agents (paid subscriptions — the computation)

| Agent | Where | Best at | Owns |
|---|---|---|---|
| agy | VPS `/snap/bin/agy` (in-place) + phone | Level/scene architecture, Godot build work | LevelManager, env scenes, minigame placement, wiring |
| codex | phone (ChatGPT) — **verified headless**: `codex exec --skip-git-repo-check "<prompt>"` from Hermes' shell (glibc-runner + DNS/CA fix active; must pass --skip-git-repo-check when outside a repo) | Backend/logic, docs & test reconciliation, GDUnit, ANY prompt-as-file task — a solid parallel workhorse | DESIGN/GAME_DESIGN/README normalization, test gate, VPS service builds |
| claude | phone (OpenRouter) | Design specs, content pipelines, second coder/researcher | SAND3 specs, domain content, reviews |
| Hermes | — | Curator ONLY — dispatch, verify real state, GitHub, user comms | never builds in-house |

## Tools — best use (the routing table)

| Tool | Use it for | Do NOT use it for |
|---|---|---|
| **asset_grabber** (CC0: kenney/os3a/quaternius/polyhaven) | Sourcing every mesh/texture/HDRI for new props & sandbox dressing — the volume engine | Anything already-authored |
| **Blender MCP** (socket :9876) | Rescale, re-skin, rig, or bake any 3D asset after sourcing; custom props | Pure scene-node transforms (that's Godot) |
| **Godot-ai MCP** | Live editor driving of scenes/UI/signals during a build | Headless verification (that's GDUnit/gate) |
| **GDUnit** | Unit-test game logic (player food, minigame win, weapon, gate) | Build-correctness gate (that's smoke) |
| **regression_smoke.sh** | The build gate — import, boot, API, all-minigames-win | Unit behavior depth |
| **LampGate / plugins** | In-build runtime systems | — |
| **gloot / statecharts / dialogue** | Inventory / enemy AI / text — integrated, in-use | — |

## The routing clause — MANDATORY in every build brief

Every dispatched wave MUST declare its tool lane in the brief, so a wave that
needs assets routes through asset_grabber -> Blender -> Godot, and a logic-only
wave says "no asset tool lane." Defaults:

1. **New/edited 3D asset needed?** Source CC0 via `asset_grabber` first; if it needs
   rescale/re-skin/rig/bake, pass through **Blender MCP**; then land in Godot.
   Never hand-place a raw CC0 file without the Blender pass if it needs adjustment.
2. **Scene/UI node work?** **godot-ai MCP** or agy (in-place) — whichever runs where
   the files are.
3. **Logic correctness?** **GDUnit** test added with the change.
4. **Build integrity?** `bash tools/regression_smoke.sh` must end REGRESSION: PASS.
5. **Docs/tests reconciliation?** **codex**.
6. **Content/design spec?** **claude**.

## Usage rule (anti-redundancy)

A tool is either the named owner of a task in an active wave, or it's not in the
pipeline for that wave. We do NOT spin Blender for a transform-only edit, and we
do NOT source assets we already have. If two tools could both do a step, the table
above picks the single owner — no shadow pipelines.

## Current state

- Active wave: agy (VPS) on LevelManager 8→3 restructure. Tool lane: Godot via agy,
  GDUnit + smoke gate. No asset lane (arch layer).
- Under-used (must be worked next content wave): asset_grabber (0 real pulls) and
  Blender MCP (probed, no real bake yet). SAND2/SAND3 content waves MUST route
  dressing/source through them.
