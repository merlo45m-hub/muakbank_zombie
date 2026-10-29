# Level 1 (Old Town) Audit — 2026-10-13

Auditor: gpt-6-luna (OpenAI Codex CLI via adb bridge)
Scope: static audit of scene + scripts (not a runtime test)

**Overall:** Scene and assets present, all 6 buildings + 3 cars have mesh + collider.
Two serious collider mistakes, a door that can't detect the player, and several
interactive-prop node-name mismatches.

## What works
- Level loading: LevelManager.gd:8 maps Level 1 -> Old Town; Game.gd:93 loads/instances it
- Scene structure: old_town_enhanced.tscn:412 — clean OldTown root (environment, floor,
  buildings, streets, obstacles, interactive props, lighting, debris)
- Buildings 1-6: each has imported model + CollisionShape3D under StaticBody3D (scene 429-481)
- Cars 1-3: each has imported model + collider (scene 717-745)
- Player/pickup wiring: Game scene supplies player, food detection, zombie spawner, food spawner
- All declared paths + 9 GLB assets exist

## Broken / missing

### P1 — Shared car collider and church collider are swapped
old_town_enhanced.tscn:403 — `BoxShape3D_church_building` has NO size assignment. The intended
church size (22x12x18) at line 410 falls after the car collider declaration, so it applies to
`BoxShape3D_car_glb` instead. Result: church keeps default-size collider; all 3 cars get a
22x12x18 collider (scaled further by each car's 2.5 transform).
FIX: move `size = Vector3(22,12,18)` into church shape; restore car shape to `Vector3(2.2,1.6,4.6)`.

### P1 — Hinged door cannot detect the player
InteractiveDoor.gd:54-60,89-92,110-112 — door only opens after `player_near` becomes true.
Door area mask = 256 (scene:1465), player collision layer = 2 (game.tscn:148). Area never
reports the player; door interaction returns without opening.
FIX: set door area mask to include the player layer, or make overlap logic detect player.

### P2 — Interactive-prop references don't match scene node names
- InteractiveWall.gd:26-29 looks for children `Mesh` and `Collision`/`Body`; scene names them
  `WallMesh` and `WallCollision` (scene 1510-1519). Punch works but flash-feedback can't find mesh.
- FoodCrate.gd:43-51 looks for `InteractionZone`; scene uses `CrateInteractionZone` (scene 1551).
  Enter/exit signals not connected -> reset-after-leave never runs.
- InteractiveVehicle.gd:54-57 looks for `InteractionZone` and `Body`/`Collision`; scene uses
  `CartInteractionZone` and `CartBody` (scene 1585-1601). Zone callbacks not wired.
- Player.gd:880-890 interaction search also looks specifically for `InteractionZone`.
FIX: align node names OR update scripts to use actual scene names.

### P2 — Interactive-prop collision bodies offset from their visuals
- Crate collision body repeats crate's local offset though already a child of crate (scene 1531-1544)
- Cart body repeats cart root's offset (scene 1581-1594)
- Wall collision body repeats wall offset beneath already-offset wall node (scene 1506-1519)
FIX: keep child collision bodies at local origin unless extra offset is intentional; compare
each body's world transform with its visible mesh.

### P2 — Level 1's configured enemy pool is ignored
LevelManager.gd:55-64 — Level 1 pool is `["chicken","rabbit"]`, but ZombieSpawner3D.gd:191-203
randomly selects from all 7 zombie types. The Level 1 pool is never consulted.
FIX: build spawn choices from `Level.get_enemy_pool(current_level)`.

### P3 — Five scene-local food spawners are dormant
Old Town attaches FoodSpawner.gd to 5 nodes (scene 1653-1693), but Game.gd:261-265 starts only
its root FoodSpawner. The 5 local spawners never get `start_spawning()`.
FIX: remove unused nodes or start them deliberately via level controller.

## TODO/FIXME/HACK
None found in audited scene or gameplay scripts.
