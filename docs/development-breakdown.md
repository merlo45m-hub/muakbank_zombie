# Muakbank Zombie — Development Breakdown

How we attack game development: 9 sections, each independently testable, each with a clear "done" definition.

## Process for each section

1. Describe architecture + list files to touch
2. State assumptions
3. Make ONE small change
4. F6 the relevant test scene
5. Test on Android
6. Checkpoint commit if good, revert if broken

## Section 1: Core Movement & Camera

**Scope:** Player controller, camera follow/collision, mobile joystick, sprint/dodge

**Done when:** Movement feels tight, camera doesn't clip, joystick is responsive

**Test:** `test_player.tscn` + on-device feel

**Files:** `scripts/core/Player.gd`, `scripts/ui/MobileControls.gd`, `scripts/gameplay/CameraShake.gd`

## Section 2: Combat & Weapons

**Scope:** Weapon pickup/switch, hit detection, damage numbers, enemy death/anim

**Done when:** Every weapon kills reliably, damage numbers show, death anim plays

**Test:** `test_weapons.tscn` + dev_room spawn + combat

**Files:** `scripts/core/WeaponSystem.gd`, `scripts/characters/ZombieBase.gd`, `addons/minos_damage_numbers/`

## Section 3: Zombie AI & Spawning

**Scope:** VFN navigation, spawn pacing, object pooling, difficulty scaling

**Done when:** Zombies path around obstacles, spawn rate scales with level, no leaks

**Test:** `test_spawner.tscn` + `test_zombie.tscn` + on-device wave test

**Files:** `scripts/characters/ZombieSpawner3D.gd`, `scripts/characters/ZombieBase.gd`, `addons/VectorFieldNavigation/`

## Section 4: Food & Economy — COMPLETE

**Scope:** Food pickups, hunger meter, score, loot drops, food types

**Done when:** Food spawns, hunger drains, score increments, loot drops on kill

**Test:** `test_food.tscn` + dev_room + on-device

**Files:** `scripts/gameplay/FoodItem3D.gd`, `scripts/gameplay/FoodSpawner.gd`, `scripts/gameplay/LootTable.gd`, `scripts/core/Game.gd`, `scripts/core/Player.gd`, `scripts/ui/HUD.gd`

**Commits:** `6312974` (root-cause fix), `0ebfcdf` (review fixes)

**Lessons:**
- Food pickup was 100% dead: `area.get_parent()` returned the spawner, not the FoodItem3D (script on Area3D root). Proven with live probe.
- Spawner `remove_child` during synchronous emit → `get_tree()` null → `on_food_eaten` dead for every spawned food. Resolve game BEFORE emit.
- Double-heal: pickup healed via `on_food_eaten`, consume healed again. Single owner = `consume_food`.
- Collision layers were a mess: takis defaults 1/1 (uncollectable), medkit/coffee/battery/ammo were body-detected (layer=0/mask=2) while burger/sushi were area-detected (layer=4/mask=0). All 10 unified to layer=4/mask=0.
- Two heal tables disagreed on every type (burger 25 vs 35). Scene `health_amount` is now single source of truth, carried in inventory entry.
- Write-only `foods` flat log removed. Dead `_on_PickupArea` weapon path removed.
- `eat_food` objective was advanced inside dead `on_food_eaten`. Now in `consume_food`.

## Section 5: HUD & UI — COMPLETE

**Scope:** Health bar, food bar, score display, pause menu, settings, level transitions

**Done when:** All HUD elements update, pause works, settings persist

**Test:** on-device only (UI is visual)

**Files:** `scenes/main/HUD.tscn`, `scenes/main/pause_menu.tscn`, `scripts/ui/`

**Commits:** `36a27b5` (anti-slop sweep), `66c9666` (Sprite3D fix, god function split, audio), `c86c3cd` (review fixes)

**Lessons:**
- 29 emoji removed across 9 UI files (HUD, pause, settings, game_over, level_select, credits + their .tscn). Anti-slop rule: named text labels, never glyphs.
- `Sprite2D` cannot be a child of `Node3D` — TitleScreen food decor silently did not render. Fixed to `Sprite3D` with billboard, then corrected from 2D pixel coords to 3D metric coords (agy CRITICAL: (80, 420) is outside the camera frustum).
- `_select_character()` called `change_scene_to_file()` on `_ready()` — skipped the whole character select menu. Removed; scene transition is a separate step.
- Local `_play_click()` helpers in Settings/LevelSelect bypassed `Audio.play_click()` (no pitch variation). Standardized.
- Copy-paste style functions in CharacterSelect.gd → one `make_style()` helper + 10 color constants.
- ⚔ emoji in game.tscn + character_gamer.tscn → "VS".

## Section 6: Level Progression — COMPLETE

**Scope:** Level transitions, difficulty curves, win/lose conditions, unlock logic

**Done when:** 6 levels playable, difficulty ramps, win/lose triggers correctly

**Test:** on-device playthrough

**Files:** `scripts/core/LevelManager.gd`, `scripts/core/Game.gd`, `scenes/world/`

**Commits:** `3bdf8e8` (difficulty wiring, per-level scaling, MAX_LEVELS), `d2aa772` (review fixes)

**Lessons:**
- `DifficultyManager.get_enemy_health_multiplier()` etc. were DEAD CODE — difficulty only affected spawn rate, never enemy stats. Wired via `apply_difficulty()`.
- `apply_difficulty()` mutated stats in-place → pooled zombies inflated exponentially (2.5x → 6.25x → 15.6x). Must scale FROM stored base stats and reset on pool return.
- `start_spawning(level: int = 1)` default parameter → WaveManager's arg-less call reset the level to 1 on wave 2. Read `Save.get_current_level()` internally instead of taking a parameter.
- `zombies_to_kill = 5` was hardcoded but WaveManager spawned 23 — player won midway through wave 2. Level completion now driven by WaveManager's `all_waves_cleared` signal, not a kill quota.
- `MAX_LEVELS = 30` but only 8 environments exist — levels 9-30 fell back to level 1. Now `Level.get_level_count()`.
- Boss spawn bypassed the spawner, so it never got `apply_difficulty()`. Bosses were weaker than the horde on high levels.
- `get_difficulty()` returned 1.0 for unmapped levels — difficulty reset above level 8. Now `2.5 + (level-8)*0.3`.

## Section 7: Audio & Feedback

**Scope:** SFX, music, haptics, screen shake, hit feedback, death effects

**Done when:** Every action has audio, music loops, haptics fire

**Test:** on-device (audio is sensory)

**Files:** `scripts/core/GameAudioManager.gd`, `scripts/gameplay/CameraShake.gd`, `scripts/gameplay/HitFeedback.gd`, `res://audio/`

## Section 8: Save & Persistence

**Scope:** Save/load, settings, high scores, achievements, migration

**Done when:** Save survives restart, settings persist, achievements unlock

**Test:** on-device (kill app, relaunch)

**Files:** `scripts/core/SaveManager.gd`, `scripts/core/AchievementManager.gd`

## Section 9: Polish & Performance

**Scope:** Particles, screen shake, LOD, memory, FPS stability, mobile perf

**Done when:** 60 FPS on S26, <350 MB RSS, no jank

**Test:** `perf_monitor.sh` + on-device

**Files:** `scripts/core/Game.gd`, `scripts/dev/DebugOverlay.gd`, `DESIGN.md §6`

## Current status

- Section 1: COMPLETE (commit 1266b45)
  - Mobile camera rotation, sprint/jump buttons, anti-slop cleanup
  - Verified: 6/6 harness, clean boot, no crash
- Section 2: COMPLETE (commit 06c9b70)
  - WeaponSystem wired, medkit healing, cooldown, weapon switch, emoji→text
  - 3 bugs found & fixed (heal path, cooldown, tick)
  - Verified: 6/6 harness, clean boot, no crash
- Section 3: COMPLETE (commits 10aa55d, f1b4917)
  - Zombie separation (was dead code — VFN override erased it), AI LOD, difficulty scaling
  - 8 real bugs fixed; 2 reviewer findings rejected with evidence (both false positives)
  - Verified: 6/6 harness, clean boot, runtime probe (died signal = 1 conn across reuse)
  - APK installed, hash a6dfefa8… byte-identical to build artifact
- Section 4: COMPLETE (commits 6312974, 0ebfcdf, 3b88b52, 94d7740, e4287ed)
  - Food economy was 100% dead — fixed pickup, signal arity, game group, double-heal, collision layers
  - Anti-slop pass + review fixes
  - Verified: real-FoodSpawner probe (pickup → inventory → HUD → consume → score), 6/6 harness
- Section 5: COMPLETE (commits 36a27b5, 66c9666, c86c3cd)
  - 29 emoji removed, copy-paste dedup, magic numbers, dead code
  - Sprite2D→Sprite3D, `_select_character()` god function split, audio standardized
  - Review: agy 10 findings (6 valid, 4 borderline rejected). pi review failed (noise, no output).
  - Verified: boot clean, 6/6 harness
- Section 6: COMPLETE (commits 3bdf8e8, d2aa772)
  - Difficulty wiring (was dead code), per-level scaling, win condition (was trivially easy), MAX_LEVELS fix
  - Review: agy 5 findings (all valid). pi review failed (969KB runaway thinking, no findings).
  - Two self-introduced agent bugs caught and fixed (broken indentation, wrong objective call)
  - Verified: boot clean, 6/6 harness
- **Section 7: Audio & Feedback — NOT STARTED (next)**
- Section 8: Save & Persistence — NOT STARTED
- Section 9: Polish & Performance — NOT STARTED

## Reviewer notes (Section 3)

Both pi and agy reviewed the Section 3 cut. Neither is reliable alone — pi found the
dead DifficultyManager path, agy found the ATTACK velocity slide and the WaveManager
conflict, and each raised false positives the other got right. Always verify a finding
against the code before fixing it.

- **Rejected: agy 6b** ("spawner permanently stalls after a blocked spawn") — `SpawnTimer.one_shot = false` (game.tscn:206), so it auto-restarts; the early `return` is correct.
- **Rejected: pi 14** ("runner behaviour changed") — runner contact damage flows through `Player.gd:665 body.attack(self)`, untouched by `_should_engage()`.
- **Verified real: pooled `died` disconnect** — `disconnect(_on_zombie_died)` uses the bare method ref, but the connection is `.bind(...)`; different Callable, so it failed on every spawn. Fixed by storing the bound Callable on the zombie.

## Anti-Slop Principles

All code, UI, and design decisions must follow `docs/anti-slop-principles.md`.
