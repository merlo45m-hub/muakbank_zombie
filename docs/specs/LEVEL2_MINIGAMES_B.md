# Level 2 Mini-Games B — Build Specification (Industrial)

**Scope:** One activatable, diegetic mini-game for Level 2 (Industrial): **Armory Lockdown** at the secure armory checkpoint, plus the shared Industrial region hooks that govern transport repair gating via `WorldProgression.can_hop`, secret-links reachability, and loot tier via `WorldProgression.get_active_loot_tier`. Armory Lockdown is a required Level 2 objective. This document defines gameplay, scene ownership, inputs, completion, and failure behavior; it does not implement them.

## Shared Industrial Region Hooks Contract

These hooks apply to ALL Level 2 mini-games (Triage Roundup Industrial, Quarantine Breach Industrial, Armory Lockdown) and are defined here once to avoid duplication.

### 3.1 WorldProgression.can_hop Gate

- Every Level 2 mini-game start trigger **must** check `WorldProgression.can_hop(2)` before allowing activation.
- If `false`, the prompt displays `INDUSTRIAL ACCESS REQUIRED` and the interaction is ignored.
- This gate is evaluated at interaction time, not at scene load, so a player who gains Industrial access via secret transport (`WorldHopManager` hop) can immediately activate the mini-games without a scene reload.
- **Controller anchor:** Each controller's `interact()` / `start_run()` / `start_trial()` entry point adds:
  ```gdscript
  var wp := get_node_or_null("/root/WorldProgression")
  if wp and not wp.can_hop(2):
      # Show "INDUSTRIAL ACCESS REQUIRED" on prompt, return early
      return
  ```

### 3.2 Loot Tier via WorldProgression.get_active_loot_tier()

- On mini-game **win only**, the reward loot tier = `WorldProgression.get_active_loot_tier()`.
- For Industrial (Region 2), this returns `2` (per `RegionDef.loot_tier` in `regions.tres`).
- If the player jumped ahead via secret transport before unlocking Region 2 linearly, `get_active_loot_tier()` still returns the tier of `current_region` (which will be 2 after `hop_completed`).
- **Controller anchor:** Each controller's `_win_run()` / `_win_trial()` adds:
  ```gdscript
  var wp := get_node_or_null("/root/WorldProgression")
  var reward_tier: int = wp.get_active_loot_tier() if wp else 1
  # Pass reward_tier to loot drop / reward system
  ```

### 3.3 Secret-Links Reachability (Non-Linear Access)

- `WorldProgression.is_secret_reachable(1, 2)` returns `true` when the Suburban→Industrial secret transport is repaired (`transport_done[1] == true`).
- This enables `can_hop(2)` to return `true` even if Region 2 is not in `unlocked_regions` (GDD §3: "Early hopping ahead for higher-tier gear is intended, not a bug").
- The secret transport repair is reported by `TransportHub` in the Suburban graveyard crypt (`TechPickup` feeds tech, `TransportHub` reports repair).
- **No mini-game code change needed** — the gate in 3.1 automatically respects secret reachability via `can_hop()`.

### 3.4 Rules Engine Integration (RULES_ENGINE.md)

- All Level 2 mini-game completions increment `Rules.increment_stat("MINIGAMES_WON", 1)` (Parameter ID 30).
- Industrial-specific LiveOps toggles may gate mini-game availability via `Rules.set_category_enabled(RequirementTypes.CAT_GAMEPLAY, ...)` or individual parameter toggles (IDs 150–157).
- `ACHIEVEMENT_TIER` (ID 72) unlocks may require Industrial mini-game completions as prerequisites.

---

## 1. Armory Lockdown

### 1.1 Player-Facing Loop Step by Step

1. **Discovery:** The player reaches the Secure Armory Checkpoint in the Shipping Yard perimeter. A heavy blast door blocks the transit tunnel leading to the Warehouse District. Flanking the door are reinforced containers, sandbag revetments, and a fortified kiosk with a central breach terminal (`CheckpointArmoryTerminal`).
2. **Initiation:** Approaching the terminal displays `ACTIVATE ARMORY BREACH`. The player presses ATTACK / INTERACT to activate.
3. **Lockdown & Supply Crack:**
   - Siren blares, amber strobes activate, and the blast door locks down (remains closed).
   - A 90.0-second breach clock starts on the HUD.
   - Two armory supply containers (`BreakableSupplyCrate`) sit at marked positions. Attack/interact with each to crack it once per container.
   - **Crate 1** drops: 1 Heavy Supply Case (physics rigid body, ~40 kg) + 2 Ammo Pickups.
   - **Crate 2** drops: 1 Heavy Supply Case + 2 Ammo Pickups.
   - Crates cannot be reopened to farm items.
4. **Door Breach:** The Armory Door (`InteractiveDoor` with two `RigidBody3D` panels) must be opened. Interact with the door's interaction zone to swing the panels open. The door opens when both panels are rotated clear.
5. **Victory:** Both crates cracked AND the armory door open before 90 seconds. The siren sounds an all-clear, strobes switch to steady green, the blast door slides open permanently, and Armory Lockdown reports its objective complete exactly once.

### 1.2 Activation Trigger

- **Entity:** `CheckpointArmoryTerminal` inside the sandbag bunker.
- **Trigger Volume:** `Area3D` (`InteractionZone`, box size 4×3×4 m).
- **State Guard:**
  - `IDLE`: Screen glows amber, prompt reads `ACTIVATE ARMORY BREACH`.
  - `ACTIVE`: Screen displays `LOCKDOWN ACTIVE` with countdown; trigger disabled.
  - `COMPLETED`: Screen reads `ARMORY CLEARED — TRANSIT OPEN`; permanently disabled.
  - `FAILED`: Screen reads `BREACH TIMED OUT — REARM AND RETRY`; re-enables after 3s reset.
- **Industrial Gate:** `WorldProgression.can_hop(2)` must be true. If false, prompt reads `INDUSTRIAL ACCESS REQUIRED` and interaction is ignored.
- **Input:** Player enters terminal zone and taps ATTACK / INTERACT.

### 1.3 Win and Fail Conditions

- **Win Condition:**
  - Both supply crates cracked (`is_cracked == true`).
  - Armory door open (`is_open == true` or `is_half_open == true` — panels cleared).
  - Player remains alive.
  - All before 90.0-second clock expires.
- **Fail Conditions:**
  - Timer reaches 0.0s before win conditions met.
  - Player dies (`Player.is_dead == true`).
- **Post-Failure State & Reset:**
  - On fail, terminal shows `BREACH TIMED OUT — REARM AND RETRY`.
  - After a 3.0-second delay, terminal resets to `IDLE`, crates reset (lids close, `is_cracked = false`), door closes.
  - Player health and inventory are NOT restored; mistakes carry real survival attrition.
  - The player may re-trigger the terminal immediately with full timer restored.
- **Loot Tier:** On win, reward tier = `WorldProgression.get_active_loot_tier()` (2 for Industrial).

### 1.4 Mechanics, Physics, and Reused Systems

- **Terminal & Controller:** Reuses `CheckpointArmoryTerminal.gd` (scripts/world/interactive/CheckpointArmoryTerminal.gd:11-57) and `ArmoryLockdownController.gd` (scripts/gameplay/ArmoryLockdownController.gd:47-78). Terminal routes `interact()` → `controller.start_trial()`. Controller owns 90s timer, win/fail logic, and objective reporting.
- **Supply Crates:** Reuses `BreakableSupplyCrate.gd` (scripts/world/interactive/BreakableSupplyCrate.gd:42-60). First interact cracks crate, releases assigned `supply_case_path` case via `release()`, spawns 2 ammo pickups (`food_ammo.tscn`). Sets `is_cracked = true`, disables interaction zone, rotates lid 75°. `reset_crate()` restores state.
- **Armory Door:** Reuses `InteractiveDoor.gd` (scripts/world/interactive/InteractiveDoor.gd — not shown but referenced in scene). Two `RigidBody3D` panels (PanelA, PanelB) with `DoorInteractionZone`. `interact()` toggles panels open/closed. Win condition checks `door.is_open` or `door.is_half_open`.
- **Supply Cases:** Reuses `QuarantineSupplyCase.gd` (scripts/world/interactive/QuarantineSupplyCase.gd:15-38) — mass 40 kg, linear_damp 4, angular_damp 9, `brace_type = "case"`, `freeze = true` until `release()` called. Cases are the "heavy supply cases" dropped by crates.
- **ObjectiveManager:** `OBJECTIVE_ID = "l2_armory_salvage"` (ArmoryLockdownController.gd:9). Reports via `objective_manager.update_progress(OBJECTIVE_ID, 1)` exactly once on win.
- **Rules Engine:** On win, `Rules.increment_stat("MINIGAMES_WON", 1)`.

### 1.5 Existing Files and Scenes (Already Implemented)

- `scripts/gameplay/ArmoryLockdownController.gd` — controller with 90s timer, crate/door win check, objective report.
- `scripts/world/interactive/CheckpointArmoryTerminal.gd` — terminal with state display, prompt, player proximity detection.
- `scripts/world/interactive/BreakableSupplyCrate.gd` — one-time crack, case release, ammo drops.
- `scripts/world/interactive/QuarantineSupplyCase.gd` — heavy rigid case (40 kg), freeze/stage/release logic.
- `scenes/minigames/armory_lockdown.tscn` — full scene with Controller, Terminal, ArmoryDoor (2 RigidBody3D panels), Crate1, Crate2, Cases.

### 1.6 Mobile Touch Controls Mapping

- **Left Virtual Joystick:** Navigating between the two crates, the door interaction zone, and defensive positions.
- **Right Screen Drag:** Scanning for incoming threats while monitoring breach timer.
- **ATTACK Button:**
  - In `CrateInteractionZone`: Priority context cracks the supply crate.
  - In `DoorInteractionZone`: Priority context swings door panels open.
  - Otherwise: Fires equipped firearm or executes melee strike against zombies.
- **SPRINT Button:** Vital for moving between crate positions and door quickly under time pressure.
- **JUMP Button:** Vaulting over sandbag revetments to create distance.
- **SWAP Button:** Quick-swapping weapons for combat efficiency.

### 1.7 Fun Hook

Tactical breach under a ticking clock: the player cracks two heavy containers, wrestles 40 kg supply cases into position (or ignores them — they're just loot), and punches the blast door open as the 90-second siren wails, with zombies converging on the checkpoint.

### 1.8 Implementation Status (Code-Grounded)

| Aspect | Status | Evidence |
|--------|--------|----------|
| Controller 90s timer + win/fail | IMPLEMENTED | `ArmoryLockdownController.gd:11, 56-69` |
| Crate crack → case + ammo drops | IMPLEMENTED | `BreakableSupplyCrate.gd:42-60`, `ArmoryLockdownController.gd:62-64` |
| Door open check (is_open/half_open) | IMPLEMENTED | `ArmoryLockdownController.gd:64` |
| Terminal state machine (IDLE/ACTIVE/COMPLETED/FAILED) | IMPLEMENTED | `CheckpointArmoryTerminal.gd:9, 27-57` |
| ObjectiveManager report (l2_armory_salvage) | IMPLEMENTED | `ArmoryLockdownController.gd:9-10, 76-77` |
| Terminal ↔ Controller wiring | IMPLEMENTED | `CheckpointArmoryTerminal.gd:24-25`, `ArmoryLockdownController.gd:52-53` |
| **WorldProgression.can_hop(2) gate on terminal** | TO BUILD | Not present in `CheckpointArmoryTerminal.gd:21-25` |
| **Loot tier via get_active_loot_tier() on win** | TO BUILD | Not present in `ArmoryLockdownController.gd:71-78` |
| **Rules.increment_stat("MINIGAMES_WON") on win** | TO BUILD | Not present |
| **FAILED state prompt text per spec** | PARTIAL | Current shows `TRIAL FAILED — REARM AND RETRY` (line 57) vs spec `BREACH TIMED OUT — REARM AND RETRY` |
| **3s failure reset + crate/door reset** | IMPLEMENTED | `ArmoryLockdownController.gd:85-91` |
| **Industrial scene placement (shipping yard)** | IMPLEMENTED | Scene exists at `scenes/minigames/armory_lockdown.tscn` |

---

## 2. Acceptance Criteria Summary (Per Minigame)

### 2.1 Triage Roundup — Industrial (`l2_triage_roundup`)

| Criterion | Status | Notes |
|-----------|--------|-------|
| Controller inherits Level 1 logic with Industrial IDs/types | TO BUILD | New controller script needed |
| `WorldProgression.can_hop(2)` gate on start | TO BUILD | Add to `interact()` |
| `get_active_loot_tier()` reward on win | TO BUILD | Add to `_win_run()` |
| 4 Industrial unit types (crate/cell/module/bundle) | TO BUILD | New `TriageIndustrialUnit.gd` + scene |
| 4 Industrial pens with matching visuals | TO BUILD | New `TriageIndustrialPen.gd` + scene |
| Scene placed in `industrial_shipping_yard.tscn` | TO BUILD | New `.tscn` |
| Rules stat increment on win | TO BUILD | Add `Rules.increment_stat("MINIGAMES_WON", 1)` |
| Mobile HUD layout (14sp/16sp, 44×44px) | TO BUILD | New HUD scene |

### 2.2 Quarantine Breach — Industrial (`l2_quarantine_breach`)

| Criterion | Status | Notes |
|-----------|--------|-------|
| Controller inherits Level 1 logic with Industrial IDs | TO BUILD | New controller script needed |
| `WorldProgression.can_hop(2)` gate on start | TO BUILD | Add to `interact()` |
| `get_active_loot_tier()` reward on win | TO BUILD | Add to `_win_run()` |
| 3 Industrial hatches (Valve/Junction/Stack) | TO BUILD | New hatch scene + `QuarantineIndustrialSealHatch.gd` |
| Industrial brace props (case/cart reskins) | TO BUILD | New prop scenes |
| Scene placed in `industrial_hazmat_rail.tscn` | TO BUILD | New `.tscn` |
| Industrial zombie spawn types | TO BUILD | Replace `zombie_dog.tscn` with Industrial variants |
| Rules stat increment on win | TO BUILD | Add `Rules.increment_stat("MINIGAMES_WON", 1)` |

### 2.3 Armory Lockdown (`l2_armory_salvage`)

| Criterion | Status | Notes |
|-----------|--------|-------|
| Core gameplay (timer, crates, door, win/fail) | IMPLEMENTED | Fully functional |
| `WorldProgression.can_hop(2)` gate | TO BUILD | Add to `CheckpointArmoryTerminal.interact()` |
| `get_active_loot_tier()` reward on win | TO BUILD | Add to `ArmoryLockdownController._win_trial()` |
| Rules stat increment on win | TO BUILD | Add `Rules.increment_stat("MINIGAMES_WON", 1)` |
| FAILED prompt text: `BREACH TIMED OUT` | PARTIAL | Change line 57 in `CheckpointArmoryTerminal.gd` |

---

## 3. Cross-Cutting Integration Points

### 3.1 Objective Registration (Level 2 Setup)

During Level 2 initialization (`Game._setup_objectives()` or level loader), before any activity can be activated:

```gdscript
objective_manager.add_objective("l2_triage_roundup", "Return escaped cargo units", 1)
objective_manager.add_objective("l2_quarantine_breach", "Seal the hazmat conduit", 1)
objective_manager.add_objective("l2_armory_salvage", "Recover armory supplies & breach lockdown", 1)
```

### 3.2 WorldProgression Signal Listeners

- `WorldProgression.region_unlocked(2, 2)` — Industrial unlocked → ensure all three mini-games' start triggers are enabled (they gate on `can_hop(2)` which now returns true).
- `WorldProgression.transport_repaired(1)` — Suburban→Industrial secret transport repaired → `can_hop(2)` becomes true via `is_secret_reachable(1, 2)` → mini-games immediately accessible to players who jumped ahead.
- `WorldProgression.hop_completed(2)` — Player hopped to Industrial → `current_region = 2` → `get_active_loot_tier()` returns 2 for subsequent mini-game wins.

### 3.3 Save Persistence

- All three mini-game completion states persist via `ObjectiveManager` (which feeds into `SaveManager`).
- `WorldProgression` serialization already includes `world_unlocked_regions`, `world_visited_regions`, `world_transport_repaired` — no additional save keys needed for the hooks.

---

## 4. What This Is NOT Going to Do (Explicit Anti-Slop Non-Goals)

1. **No Automatic Triggering:** Walking into any mini-game area will NEVER auto-start an activity. All activities require an explicit, player-initiated interaction press while facing an in-world terminal or board.
2. **No Vacuum Auto-Shoving in Triage:** Triage Roundup Industrial will NOT allow the player to sprint across the hall and shove all 4 units simultaneously.
3. **No Infinite Brace Farming:** Quarantine Breach Industrial will NOT allow re-cracking crates or respawning cases/carts upon leaving and returning.
4. **No Map-Wide Kiting:** Quarantine Breach Industrial will NOT permit the player to lure breach zombies across the entire Industrial map.
5. **No Invisible Swapping of Brace Physics:** Quarantine Breach Industrial will NOT snap cases/carts to sockets automatically.
6. **No Interruption of Free-Roam Exploration:** An unactivated mini-game is completely passive. The Industrial world remains open and fully explorable without invisible walls blocking paths before activities are triggered.
7. **No God Controllers:** Each mini-game is isolated into its own modular controller script and scene. No single script manages multiple mini-games; each interfaces with the game only through `ObjectiveManager`, `WorldProgression`, `Rules`, and `Player.gd`.
8. **No Click Targets < 44×44 px:** All mobile buttons, interaction prompts, and UI tap zones adhere strictly to mobile usability standards (minimum 44×44 px touch area, minimum 14sp text).
9. **No Fourth Minigame:** The MASTER_GDD defines three Industrial minigames (Triage Roundup, Quarantine Breach, Armory Lockdown) matching the three controllers found. This spec documents exactly these three — no inventions.
10. **No Level 1 Asset Reuse Without Industrial Reskin:** The Industrial variants must use Industrial-themed visuals — not the Level 1 hospital assets. The controllers are reused; the scenes and visuals are new.

---

## 5. File/Line Anchors for Implementers

| Feature | File | Line(s) |
|---------|------|---------|
| TriageRoundupController (L1 base) | `scripts/gameplay/TriageRoundupController.gd` | 12 (OBJECTIVE_ID), 94 (start_run), 115 (delivery), 136 (report) |
| TriageWardPen (L1 base) | `scripts/gameplay/TriageWardPen.gd` | 21 (required_animal_type), 46 (process_capture) |
| TriageAnimalBody (L1 base) | `scripts/gameplay/TriageAnimalBody.gd` | 29 (animal_type), 80 (apply_shove) |
| QuarantineBreachController (L1 base) | `scripts/gameplay/QuarantineBreachController.gd` | 14 (OBJECTIVE_ID), 116 (interact), 152 (door_sealed), 176 (report) |
| QuarantineSealDoor (L1 base) | `scripts/gameplay/QuarantineSealDoor.gd` | 17 (seal_step), 18 (assigned_brace), 59 (seal_tick) |
| BreakableSupplyCrate (L1 base) | `scripts/world/interactive/BreakableSupplyCrate.gd` | 42 (interact), 52 (release case) |
| QuarantineSupplyCase (L1 base) | `scripts/world/interactive/QuarantineSupplyCase.gd` | 17 (mass), 36 (release) |
| PushableServiceCart (L1 base) | `scripts/world/interactive/PushableServiceCart.gd` | 17 (mass) |
| ArmoryLockdownController | `scripts/gameplay/ArmoryLockdownController.gd` | 9 (OBJECTIVE_ID), 47 (start_trial), 56 (process), 71 (win) |
| CheckpointArmoryTerminal | `scripts/world/interactive/CheckpointArmoryTerminal.gd` | 21 (interact), 27 (set_trial_state), 49 (prompt texts) |
| WorldProgression.can_hop | `scripts/core/WorldProgression.gd` | 189-194 |
| WorldProgression.get_active_loot_tier | `scripts/core/WorldProgression.gd` | 278-282 |
| WorldProgression.is_secret_reachable | `scripts/core/WorldProgression.gd` | 248-257 |
| Rules.increment_stat | `scripts/core/rules/RulesEngine.gd` | (via Autoload `Rules`) |