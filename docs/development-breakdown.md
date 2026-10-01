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

## Section 4: Food & Economy

**Scope:** Food pickups, hunger meter, score, loot drops, food types

**Done when:** Food spawns, hunger drains, score increments, loot drops on kill

**Test:** `test_food.tscn` + dev_room + on-device

**Files:** `scripts/core/FoodDetection.gd`, `scripts/world/FoodSpawner.gd`, `scripts/core/LootTable.gd`

## Section 5: HUD & UI

**Scope:** Health bar, food bar, score display, pause menu, settings, level transitions

**Done when:** All HUD elements update, pause works, settings persist

**Test:** on-device only (UI is visual)

**Files:** `scenes/main/HUD.tscn`, `scenes/main/pause_menu.tscn`, `scripts/ui/`

## Section 6: Level Progression

**Scope:** Level transitions, difficulty curves, win/lose conditions, unlock logic

**Done when:** 6 levels playable, difficulty ramps, win/lose triggers correctly

**Test:** on-device playthrough

**Files:** `scripts/core/LevelManager.gd`, `scripts/core/Game.gd`, `scenes/world/`

## Section 7: Audio & Feedback

**Scope:** SFX, music, haptics, screen shake, hit feedback, death effects

**Done when:** Every action has audio, music loops, haptics fire

**Test:** on-device (audio is sensory)

**Files:** `scripts/core/AudioManager.gd`, `scripts/gameplay/CameraShake.gd`, `assets/audio/`

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
- Section 3: IN PROGRESS
  - Scope: VFN navigation, spawn pacing, object pooling, difficulty scaling
  - 3 agents dispatched for review & fixes
- Sections 4-9: NOT STARTED

## Anti-Slop Principles

All code, UI, and design decisions must follow `docs/anti-slop-principles.md`.
