# Muakbank Zombie — Game Design North Star

## Core Structure
- **3 open-world sandbox levels** — SAND1 Old Town, SAND2 Industrial District,
  SAND3 Endgame Heights. No more, no fewer. Each sandbox is BIG, explorable,
  free-roam (not linear corridors), and embeds its mini-games.
- Each sandbox contains **mini-games** the player must complete to unlock the next level:
  - SAND1 Old Town embeds **five**: Spoil & Survive, Triage Roundup, Keep the
    Generator Fed, Quarantine Breach, Last Stand Station.
  - SAND2 Industrial District folds in hospital + warehouse and embeds
    **Armory Lockdown**.
  - SAND3 Endgame Heights folds in rooftop + sewers + mall and embeds
    **Endgame Extraction**.
- Core loop per level: **survive + complete ALL embedded mini-game(s) → advance to the next level.**
- Difficulty / enemy pool / ambient escalate across sandboxes **1.0 → 1.6 → 2.5**
  (`scripts/core/LevelManager.gd` — `difficulty_map`, `enemy_pool_map`).

## What this means for the build
- Levels need real scale and open free-roam space to explore.
- A **mini-game / objective gating system** drives level progression — distinct from a pure
  wave-survival timer. Existing `ObjectiveManager` (scripts/gameplay/ObjectiveManager.gd) with
  its `all_objectives_completed` signal is the hook: when all mini-game objectives are done, the
  level is complete and the next unlocks.
- `LevelManager` maps exactly 3 levels (`environments` / `level_names` in
  `scripts/core/LevelManager.gd`).

## Quality bar (from anti-slop-principles.md)
- No god functions, no copy-paste, name constants, comments explain WHY.
- Small checkpointed changes; test before done.
- Specific to THIS game — nothing generic.
- Make it **fun and functional** — a game people want to play, not a tech demo.

## SAND1 mini-games (Old Town — all 5 embedded; each ACTIVATABLE — clear in-world start trigger, not auto-firing)
1. **Spoil & Survive** (eating): a food table spawns a spread, some tainted (wrong glow/color);
   chain-eat the good ones fast for a combo before the timer; one bad bite costs health + breaks
   the chain. Uses the existing food system.
2. **Triage Roundup** (animal hospital): escaped zombie animals herded back into matching ward
   pens using physics (shove/flick via interactive-prop physics) before the hall overruns.
3. **Keep the Generator Fed**: a generator powers the level safe zone and runs on FOOD as fuel;
   feed it to keep the lights/safe-zone alive while waves close in; tension = eat to live vs.
   burn food for the safe zone.
4. **Quarantine Breach**: sequence of barricaded doors — crack crates for supplies, swing doors,
   push carts to seal breaches in order while zombies pour through missed ones; timed,
   physics-driven, uses the door/crate/cart props.
5. **Last Stand Station** (combat skill gate): hold a marked zone for N waves with limited ammo
   dropped between waves; tests build/aim before the bigger level opens.

Design principles for all: diegetic (live in the world using existing systems), analogue mechanics
(physics/placement/timing, not on/off switches), mobile-touch friendly, challenging but fun. Each
needs a START trigger the player activates. Progression gated by ObjectiveManager.all_objectives_completed.

## SAND2 / SAND3 mini-games
- **Armory Lockdown** (SAND2 — Industrial District): activate the armory terminal
  (`CheckpointArmoryTerminal`), crack the two supply crates, and breach the armory
  door to restore facility access. `ArmoryLockdownController` (objective `l2_armory_salvage`).
- **Endgame Extraction** (SAND3 — Endgame Heights): activate the rooftop extraction
  terminal, breach the maintenance door, and crack the flare crate to signal the
  extraction chopper. `EndgameExtractionController` (objective `l3_rooftop_extraction`).

## Current focus
- The 3-sandbox build is live: Old Town / Industrial District / Endgame Heights each
  embed their mini-game set. Current focus: sandbox polish and gate correctness across
  all three levels.
