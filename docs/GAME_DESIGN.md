# Muakbank Zombie — Game Design North Star

## Core Structure
- **5 levels total** — no more. Each level is BIG, explorable, free-roam (not linear corridors).
- Each level contains **mini-games** the player must complete to unlock the next level.
- Core loop per level: **survive + complete the mini-game(s) → advance to the next level.**

## What this means for the build
- Levels need real scale and open free-roam space to explore.
- A **mini-game / objective gating system** drives level progression — distinct from a pure
  wave-survival timer. Existing `ObjectiveManager` (scripts/gameplay/ObjectiveManager.gd) with
  its `all_objectives_completed` signal is the hook: when all mini-game objectives are done, the
  level is complete and the next unlocks.
- Trim `LevelManager` from its current 8-level map down to 5 levels.

## Quality bar (from anti-slop-principles.md)
- No god functions, no copy-paste, name constants, comments explain WHY.
- Small checkpointed changes; test before done.
- Specific to THIS game — nothing generic.
- Make it **fun and functional** — a game people want to play, not a tech demo.

## Level 1 mini-games (all 5 approved; each ACTIVATABLE — clear in-world start trigger, not auto-firing)
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

## Current focus
- Level 1 (Old Town): bring to life — interactive props (door/cart/crate/wall), explorable
  environment, working survival + mini-game loop.
