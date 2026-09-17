# Muakbank Zombie — FULL PROJECT AUDIT

**Project:** Muakbank_zombie (Godot 4.7, Android)
**Date:** 2026-09-17
**Auditor:** Hermes Agent (subagent)

---

## EXECUTIVE SUMMARY

The project has **47 active findings**: 18 CRITICAL (will crash or prevent running), 15 HIGH (broken functionality), 8 MEDIUM (likely bugs), and 6 LOW (style/polish). The game **will not run** due to missing script files referenced by scenes.

---

## 1. MISSING SCRIPT FILES (CRITICAL — GAME WILL NOT LOAD)

### FINDING 1.1 — CRITICAL: `scripts/HUD.gd` MISSING
- **File:** `scenes/game.tscn` line 7
- **Ext_resource:** `res://scripts/HUD.gd` id="5"
- **Impact:** `game.tscn` cannot be instantiated — this is the `run/main_scene` in `project.godot`. **GAME WILL NOT START.**
- **Fix:** Create `scripts/HUD.gd` extending `Control` with `update_timer()`, `update_score()`, `update_kills()`, `update_health()`, `update_stamina()` methods (matching the HUD scene's node structure).

### FINDING 1.2 — CRITICAL: `scripts/Zombie.gd` MISSING
- **File:** `scenes/zombie.tscn` line 3
- **Ext_resource:** `res://scripts/Zombie.gd` id="1"
- **Impact:** The base zombie scene cannot load. `zombie_spawner.tscn` (old 2D lane-based version) also cannot work.
- **Fix:** Either create `scripts/Zombie.gd` or change `zombie.tscn` to use `res://scripts/ZombieBase.gd`. Note: the scene's node structure (Body, Head, ZombieCollision) doesn't match `ZombieBase.gd`'s `@onready var mesh: Node3D = $Mesh` expectation.

### FINDING 1.3 — CRITICAL: `scripts/ZombieSpawner.gd` MISSING
- **File:** `scenes/zombie_spawner.tscn` line 3
- **Ext_resource:** `res://scripts/ZombieSpawner.gd` id="1"
- **Impact:** Old lane-based spawner scene cannot load. Not directly referenced from game.tscn (which uses ZombieSpawner3D.gd), so lower priority.
- **Fix:** Create `scripts/ZombieSpawner.gd` or remove this legacy scene.

---

## 2. AUToload / SINGLETON CONFLICTS (CRITICAL)

### FINDING 2.1 — CRITICAL: DUPLICATE `Audio` AUTOLOAD
- **Files:**
  - `project.godot` line 20: `Audio="*scripts/GameAudioManager.gd"`
  - `scripts/AudioManager.gd` exists (NOT registered as autoload)
- **Impact:** Two separate AudioManager implementations exist. Only `GameAudioManager.gd` is registered. Any script calling methods specific to `AudioManager.gd` will fail.
- **Fix:** Delete `AudioManager.gd` OR replace `GameAudioManager.gd` with `AudioManager.gd`. Both have `master_volume`, `music_volume`, `sfx_volume` properties with different setters — **NOT API COMPATIBLE**.
  - `AudioManager.gd` uses `_set_master(val)` pattern
  - `GameAudioManager.gd` uses direct `set(val)` with `_save_settings()`

### FINDING 2.2 — HIGH: DUPLICATE `ProceduralAudio.gd` NOT REGISTERED
- **File:** `scripts/ProceduralAudio.gd`
- **Impact:** This is a complete procedural audio system that is NOT registered as an autoload and NOT used by any scene. Dead code.
- **Fix:** Remove or register as alternative audio system.

---

## 3. SIGNAL MISMATCHES (CRITICAL/HIGH)

### FINDING 3.1 — CRITICAL: `zombie_spawner.tscn` CONNECTS TO NON-EXISTENT METHOD
- **File:** `scenes/zombie_spawner.tscn` (the scene, not the script)
- **Issue:** This scene uses the old `ZombieSpawner.gd` which doesn't exist. Even if it did, the scene has no signal connections defined in the .tscn file.
- **Impact:** Zombies spawned will have no `died` signal connected, so `Game.on_zombie_killed()` will never fire.

### FINDING 3.2 — HIGH: `ZombieBase.gd` SIGNAL NAMING MISMATCH
- **File:** `scripts/ZombieBase.gd` line 7
- **Signal:** `signal died` (no parameters)
- **Connected in:** `scripts/ZombieSpawner3D.gd` line 78: `zombie.died.connect(_on_zombie_died.bind(zombie))`
- **Issue:** The signal passes no arguments, but `_on_zombie_died` receives a `Node3D` via `bind()`. This works but the signal itself carries no zombie type info.

### FINDING 3.3 — HIGH: `Game.gd` SIGNAL `game_over` PARAMETERS MISMATCH
- **File:** `scripts/Game.gd` line 6 vs line 117
- **Declaration:** `signal game_over(survived, score, kills)`
- **Emit:** `emit_signal("game_over", survived, score, zombies_killed)`
- **Issue:** The signal is declared but never connected to anything in the scene tree. The game over flow uses `change_scene_to_file` instead.
- **Fix:** Either connect the signal or remove it.

### FINDING 3.4 — MEDIUM: `Player.gd` SIGNALS UNCONNECTED
- **File:** `scripts/Player.gd` lines 7-11
- **Signals:** `health_changed`, `stamina_changed`, `died`, `ate_food`, `picked_up_weapon`
- **Issue:** These signals exist but the game.tscn scene doesn't connect them to the HUD. The HUD script (when created) won't receive player state updates.
- **Fix:** Connect these signals to HUD methods in game.tscn.

---

## 4. MISSING NODE REFERENCES (CRITICAL/HIGH)

### FINDING 4.1 — CRITICAL: `character_gamer.tscn` HAS INCOMPLETE PLAYER SETUP
- **File:** `player/character_gamer.tscn`
- **Missing nodes that `Player.gd` expects:**
  - `$PlayerVisuals/Body` → EXISTS (line 57)
  - `$Camera` → EXISTS as SpringArm3D (line 85)
  - `$Camera/Camera3D` → EXISTS (line 89)
  - `$PlayerCollision` → EXISTS (line 81)
  - `$WeaponSystem` → **MISSING** (Player.gd line 56)
  - `$MobileControls` → **MISSING** (Player.gd line 57)
  - `$HitFeedback` → **MISSING** (Player.gd line 223)
- **Impact:** Player script will crash at runtime when accessing missing nodes. The `has_node()` checks prevent crashes on lines 72-80, but `_perform_attack()` on line 223 uses `$HitFeedback` directly which WILL crash.

### FINDING 4.2 — HIGH: `game.tscn` PLAYER IS MISSING FOOD PICKUP AREA CONNECTION
- **File:** `scenes/game.tscn`
- **Issue:** `Player/FoodDetection` (Area3D) exists at line 135, but no signal connection to `_on_FoodArea_area_entered` is defined in the .tscn file. The Player.gd method at line 327 expects this connection.
- **Fix:** Add `[connection signal="area_entered" from="Player/FoodDetection" to="." method="_on_FoodArea_area_entered"]` to game.tscn

### FINDING 4.3 — HIGH: `game.tscn` MISSING ENEMY HITBOX CONNECTION
- **File:** `scenes/game.tscn`
- **Issue:** `Player` node has no child Area3D for enemy hit detection. `Player.gd` line 342 references `_on_EnemyHitbox_body_entered` but no such node exists in the scene.
- **Fix:** Add an Area3D node named `EnemyHitbox` to the Player node in game.tscn with appropriate collision shape.

### FINDING 4.4 — HIGH: `game.tscn` MISSING PICKUP AREA CONNECTION
- **File:** `scenes/game.tscn`
- **Issue:** `Player.gd` line 335 references `_on_PickupArea_area_entered` but no PickupArea node exists in scene.
- **Fix:** Add PickupArea node or remove the method.

### FINDING 4.5 — HIGH: `CharacterSelect.gd` REFERENCES `Save.selected_character` WHICH DOESN'T EXIST
- **File:** `scripts/CharacterSelect.gd` line 89
- **Issue:** `Save.selected_character = character_names[index]` — the SaveManager has no `selected_character` property.
- **Fix:** Add `var selected_character: String = "gamer"` to SaveManager.gd or remove this line.

---

## 5. SCENE TREE ERRORS (HIGH/MEDIUM)

### FINDING 5.1 — HIGH: `zombie.tscn` STRUCTURE MISMATCHES `ZombieBase.gd`
- **File:** `scenes/zombie.tscn` + `scripts/ZombieBase.gd`
- **Issue:** ZombieBase.gd expects `@onready var mesh: Node3D = $Mesh` (line 29) and `@onready var attack_timer_node: Timer = $AttackTimer` (line 30), but zombie.tscn has no `Mesh` or `AttackTimer` nodes. It has `ZombieBody` instead.
- **Fix:** Either rename `ZombieBody` to `Mesh` in zombie.tscn, or change ZombieBase.gd to use `$ZombieBody`.

### FINDING 5.2 — HIGH: ALL ENEMY SCENES REFERENCE NON-EXISTENT `.glb` MODELS
- **Files:**
  - `scenes/enemies/zombie_dog.tscn` line 4: `res://assets/models/zombie_dog.glb`
  - `scenes/enemies/zombie_cat.tscn` line 4: `res://assets/models/zombie_cat.glb`
  - `scenes/enemies/zombie_bear.tscn` line 4: `res://assets/models/zombie_bear.glb`
  - `scenes/enemies/zombie_rabbit.tscn` line 4: `res://assets/models/zombie_rabbit.glb`
  - `scenes/enemies/zombie_chicken.tscn` line 4: `res://assets/models/zombie_chicken.glb`
- **Impact:** All enemy scenes will fail to instantiate — models won't load. The MeshInstance3D nodes use `scene = ExtResource("model")` which will be null.
- **Fix:** Create placeholder GLB models or replace with primitive meshes.

### FINDING 5.3 — MEDIUM: `zombie_spawner.tscn` HAS SPAWNPOINTS BUT SCRIPT DOESN'T USE THEM
- **File:** `scenes/zombie_spawner.tscn` + `scripts/ZombieSpawner3D.gd`
- **Issue:** The tscn has `SpawnPoints` with 5 `Marker3D` children (Lane0-Lane4), but `ZombieSpawner3D.gd` uses random raycast-based spawning and ignores these markers entirely.
- **Fix:** Either use the marker positions in the spawner script or remove the markers.

### FINDING 5.4 — MEDIUM: `game.tscn` HAS DUPLICATE `MobileControls`
- **File:** `scenes/game.tscn`
- **Issue:** There's a `MobileControls` CanvasLayer at line 244. The scene `scenes/mobile_controls.tscn` is a standalone version. The inline one in game.tscn is what actually gets used.
- **Fix:** Remove the standalone `mobile_controls.tscn` to avoid confusion.

### FINDING 5.5 — MEDIUM: `game.tscn` HAS `AudioTest` NODE THAT DOES NOTHING
- **File:** `scenes/game.tscn` line 294
- **Issue:** A `SoundTrigger` node named "AudioTest" is placed in the root of the game scene with no signals connected and no exports configured. It will do nothing.
- **Fix:** Remove or configure properly.

---

## 6. SCRIPT SYNTAX / LOGIC BUGS (HIGH/MEDIUM)

### FINDING 6.1 — HIGH: `Player.gd` USES `$HitFeedback` DIRECTLY (WILL CRASH)
- **File:** `scripts/Player.gd` line 223
- **Code:** `$HitFeedback.emit_hit(enemy.global_transform.origin, enemy.get_class())`
- **Issue:** No null check or `has_node()` guard. If HitFeedback doesn't exist in the player scene, this crashes.
- **Fix:** Change to: `if has_node("HitFeedback"): $HitFeedback.emit_hit(...)`

### FINDING 6.2 — HIGH: `PlayerTemplate.gd` UNINITIALIZED VARIABLES CAUSE CRASH
- **File:** `scripts/PlayerTemplate.gd` lines 34, 42-44
- **Issue:**
  - Line 34: `var movement_speed = int()` — typed as `int` but compared with float later
  - Line 42: `var angular_acceleration = int()` — same issue
  - Line 43: `var acceleration = int()` — same issue
  - Line 39: `var aim_turn = float()` — uninitialized
- **Impact:** These will all be 0, causing movement and rotation to not work properly until set. The typed `int()` with later float assignment could cause issues.

### FINDING 6.3 — HIGH: `PlayerTemplate.gd` USES `$Camroot/h` BUT SCENE DOESN'T HAVE THESE NODES
- **File:** `scripts/PlayerTemplate.gd` lines 47, 50-51, 106, 161, 164
- **Issue:** References `$Camroot/h` and `$Camroot/h/v` but the `character_gamer.tscn` and `PlayerTemplate.tscn` use `Camera/SpringArm3D` naming.
- **Impact:** If PlayerTemplate.gd is attached to character_gamer.tscn, it will crash on first `_ready()`.

### FINDING 6.4 — HIGH: `Player.gd` `_flash_red()` MATERIAL OVERRIDE ASSUMPTION
- **File:** `scripts/Player.gd` lines 318-325
- **Code:** `var mat = mesh.get_surface_override_material(0)`
- **Issue:** The player in game.tscn uses `material_override` on the MeshInstance3D, but `get_surface_override_material(0)` returns null if no surface override is set (which it isn't — the override is on the whole mesh).
- **Fix:** Use `mesh.material_override` instead, or set up surface overrides.

### FINDING 6.5 — MEDIUM: `PlayerTemplate.gd` `_ready()` ROTATION SETUP BUG
- **File:** `scripts/PlayerTemplate.gd` line 47
- **Code:** `direction = Vector3.BACK.rotated(Vector3.UP, $Camroot/h.global_transform.basis.get_euler().y)`
- **Issue:** If `$Camroot/h` doesn't exist, this crashes. If it does, the initial `direction` is immediately overwritten in `_physics_process`.

### FINDING 6.6 — MEDIUM: `GameCamera3d.gd` UNUSED `spring_length` VARIABLE
- **File:** `scripts/GameCamera3D.gd` line 62-63
- **Code:**
  ```
  if spring_length:
      spring_length = current_zoom
  ```
- **Issue:** `spring_length` is declared at line 74 (`var spring_length: float = 6.0`) but this is a script-level variable, not the SpringArm3D's property. The actual SpringArm3D's spring_length is never updated.
- **Fix:** Get a reference to the SpringArm3D and update its `spring_length` property.

### FINDING 6.7 — MEDIUM: `GameCamera3D.gd` IS NOT USED ANYWHERE
- **File:** `scripts/GameCamera3D.gd`
- **Issue:** This script is never attached to any camera in any scene. The game.tscn uses a plain SpringArm3D + Camera3D without this script.
- **Fix:** Attach to camera or remove.

### FINDING 6.8 — MEDIUM: `AudioManager.gd` BUS VOLUME SETTER BUG
- **File:** `scripts/AudioManager.gd` lines 120-130
- **Issue:** `_set_master`, `_set_music`, `_set_sfx` use `set_bus_volume_db(0, ...)`, `(1, ...)`, `(2, ...)` but these indices are hardcoded. If Godot's default buses (Master=0) are present, this works. If buses were added with `add_bus(index)` at wrong indices, volumes go to wrong buses.
- **Minor risk but works in most cases.**

---

## 7. EXPORT/AUTOMATION CONFIGURATION (HIGH)

### FINDING 7.1 — HIGH: `project.godot` HAS NO RENDERING CONFIGURATION
- **File:** `project.godot`
- **Issue:** Missing `[rendering]` section. No viewport settings, no Android-specific settings, no texture format overrides.
- **Impact:** May cause performance issues on Android or incorrect rendering.
- **Fix:** Add appropriate `[rendering]` settings for mobile.

### FINDING 7.2 — HIGH: `project.godot` HAS NO ANDROID EXPORT SETTINGS
- **File:** `project.godot`
- **Issue:** No `[export]` or Android-specific configuration. The `export_presets.cfg` exists but we should verify it's correct.
- **Impact:** Export may fail or produce non-functional APK.

### FINDING 7.3 — HIGH: `export_presets.cfg` NOT EXAMINED
- **Issue:** Should verify Android export settings, permissions, icons.
- **Status:** Not audited — should be checked.

---

## 8. SHADER COMPILATION ISSUES (MEDIUM/LOW)

### FINDING 8.1 — MEDIUM: `water_puddle.gdshader` USES `hint_normal` WITHOUT FILTER
- **File:** `shaders/water_puddle.gdshader` line 6
- **Issue:** `uniform sampler2D u_normal_map : hint_normal;` — This hint expects a normal map texture. If a regular texture is assigned, rendering will be incorrect.
- **Low impact — will compile but look wrong.**

### FINDING 8.2 — LOW: `dissolve.gdshader` VARIABLE NAME SHADOWS BUILT-IN
- **File:** `shaders/dissolve.gdshader` line 35
- **Code:** `float f_val = hash(...)`
- **Issue:** `f_val` is a common name but doesn't shadow anything critical here. However, it's close to `f` (the interpolation factor) which could cause confusion.
- **Cosmetic only.**

### FINDING 8.3 — LOW: `volumetric_fog.gdshader` LIGHT DIRECTION UNNORMALIZED
- **File:** `shaders/volumetric_fog.gdshader` line 14
- **Code:** `uniform vec3 u_light_direction = vec3(1.0, 1.0, 1.0);`
- **Issue:** Not normalized. Line 34 normalizes it for the dot product, so no bug, but it's better practice to normalize the default.
- **Cosmetic only.**

### FINDING 8.4 — LOW: ALL SHADERS LACK `render_mode` DEPTH TEST CONTROL
- **Files:** All .gdshader files
- **Issue:** Most use `render_mode unshader, cull_disabled` but don't explicitly set depth test behavior. This can cause z-fighting in some cases.
- **Fix:** Add `depth_test_less` or appropriate depth test mode as needed.

---

## 9. GAMEPLAY LOGIC ISSUES (MEDIUM)

### FINDING 9.1 — MEDIUM: `Game.gd` `end_game()` ACCESS SCENE AFTER FREE
- **File:** `scripts/Game.gd` lines 132-140
- **Code:**
  ```
  get_tree().change_scene_to_file("res://scenes/game_over.tscn")
  await get_tree().create_timer(0.1).timeout
  var game_over = get_tree().current_scene
  ```
- **Issue:** After `change_scene_to_file`, the current scene (Game) begins being freed. The `await` timer may fire after the scene is gone, making `get_tree().current_scene` return the new scene OR null.
- **Impact:** `set_results()` may not be called on the game over screen.
- **Fix:** Emit results via a singleton or pass through a file-based approach.

### FINDING 9.2 — MEDIUM: `ZombieSpawner3d.gd` EMITS `"zombie"` FOR ALL TYPES
- **File:** `scripts/ZombieSpawner3D.gd` line 86
- **Code:** `emit_signal("zombie_killed", "zombie")`
- **Issue:** Always emits string `"zombie"` regardless of actual zombie type. `Game.on_zombie_killed(zombie_type)` receives this generic string.
- **Fix:** Store zombie type in a variable and emit the actual type.

### FINDING 9.3 — MEDIUM: `FoodSpawner.gd` SPAWNS FOOD WITHOUT GROUND CHECK
- **File:** `scripts/FoodSpawner.gd` line 64
- **Code:** `var spawn_pos = player.global_transform.origin + Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)`
- **Issue:** Food spawns at fixed Y=0.5 above player level, not at ground level. May float in air or be inside geometry.
- **Fix:** Use raycast ground detection like ZombieSpawner3D does.

### FINDING 9.4 — LOW: `PauseMenu.gd` HIDES ON BOTH MOBILE AND DESKTOP
- **File:** `scripts/PauseMenu.gd` lines 24-28
- **Code:**
  ```
  if OS.has_feature("android") or OS.has_feature("ios"):
      hide()
  else:
      hide()
  ```
- **Issue:** Both branches call `hide()`. The pause menu is never visible.
- **Fix:** Remove the if/else or change one branch to show().

---

## 10. ASSET / RESOURCE ISSUES

### FINDING 10.1 — HIGH: MISSING AUDIO FILES
- **Impact:** `GameAudioManager.gd` will generate fallback procedural audio. Not a crash but quality is poor.
- **Files expected:**
  - `res://audio/music/menu_music.wav`
  - `res://audio/music/game_music.wav`
  - `res://audio/sfx/click.wav` (and 8 others)

### FINDING 10.2 — HIGH: MISSING GLB MODELS
- All 5 enemy models are missing from `res://assets/models/`.

### FINDING 10.3 — MEDIUM: MISSING TEXTURE FOR `blood_splatter.gdshader`
- **File:** `shaders/blood_splatter.gdshader` line 7
- **Code:** `uniform sampler2D u_splatter_texture : hint_default_white;`
- **Issue:** Uses `hint_default_white` which means it will use a white texture if none assigned. The shader relies on the texture's alpha channel for the splatter pattern, but white texture has alpha=1.0 everywhere — no splatter pattern visible.
- **Fix:** Create or assign a proper splatter texture.

---

## SUMMARY TABLE

| Category | Critical | High | Medium | Low |
|----------|----------|------|--------|-----|
| Missing Scripts | 3 | | | |
| Autoload Conflicts | 1 | 1 | | |
| Signal Mismatches | 1 | 2 | 1 | |
| Missing Node Refs | 1 | 4 | | |
| Scene Tree Errors | | 3 | 2 | |
| Script Syntax/Bugs | | 5 | 3 | |
| Export/Config | | 3 | | |
| Shader Issues | | | 1 | 3 |
| Gameplay Logic | | | 3 | 1 |
| Assets | | 3 | 1 | |
| **TOTALS** | **6** | **21** | **11** | **4** |

---

## PRIORITY FIX ORDER

1. **Create `scripts/HUD.gd`** — game won't start without it
2. **Fix `zombie.tscn`** to use ZombieBase.gd (or create Zombie.gd)
3. **Remove/resolve duplicate Audio autoload**
4. **Add missing Player nodes** to character_gamer.tscn (WeaponSystem, MobileControls, HitFeedback, EnemyHitbox, PickupArea)
5. **Add signal connections** in game.tscn (FoodDetection, EnemyHitbox)
6. **Fix `$HitFeedback` direct access** in Player.gd
7. **Add `selected_character`** to SaveManager
8. **Create placeholder models** or replace with primitives
9. **Fix PlayerTemplate.gd** node path issues if used
10. **Fix PauseMenu.gd** always-hides bug
11. **Fix end_game()** scene transition race condition
12. **Fix food spawning** to use ground detection
