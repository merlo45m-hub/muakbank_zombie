# Level 2 Mini-Games A — Build Specification (Industrial)

**Scope:** Two activatable, diegetic mini-games for Level 2 (Industrial): **Triage Roundup — Industrial** in the shipping yard triage bay, and **Quarantine Breach — Industrial** on the hazmat rail conduit. Both are required Level 2 objectives. This document defines gameplay, scene ownership, inputs, completion, and failure behavior; it does not implement them.

## Shared Implementation Contract

- Add both objective records during Level 2 setup, before the player can start either activity:
  - `l2_triage_roundup`, title `Return escaped cargo units`, target `1`.
  - `l2_quarantine_breach`, title `Seal the hazmat conduit`, target `1`.
- A mini-game controller owns its own state and timer. It calls `ObjectiveManager.update_progress(id, 1)` exactly once, only after a win. A failure never advances progress. Keep the level's existing `all_objectives_completed` listener as the sole level-complete/next-level gate; do not make either activity directly unlock the exit.
- Both activities are idle until an explicit player action at a visible start marker. Show a diegetic prompt and a thumb-sized `START` interaction (minimum 44×44 px); never start from entering an Area3D alone. The start trigger is disabled while active and after a win. Failure returns the activity to a ready-to-retry state after its reset, without adding progress.
- Use a shared activity HUD panel: title, short objective, countdown, and clear success/failure state. Keep body text at least 14sp and action text at least 16sp. Place it above the bottom action row so joystick, camera drag, and buttons do not overlap.
- Add an `Area3D` start zone and route the player's existing `attack` action / mobile attack button to its prompt. Desktop left-click is `attack`. In this context only, the prompt consumes the attack press and does not swing a weapon. Player movement, camera, stamina, health, combat, and death remain owned by `Player.gd` and existing systems.
- **Mobile controls:** left thumb joystick moves; right-side camera drag aims/orients; existing `SPRINT`, `JUMP`, and `SWAP` buttons retain their current functions; existing attack button activates a nearby highlighted start/prop and performs combat when no interaction prompt is eligible. SPRINT is useful for repositioning, JUMP for crossing clutter, and SWAP for choosing a weapon. Do not add a second simultaneous attack/interact button. Update the mobile callback path to share the same interaction resolver as `InputMap` action `attack`; current mobile callbacks call `_perform_attack()` directly and bypass prop interaction. Preserve ordinary combat if no prompt is in range.
- Existing scripts to reuse where applicable:
  - `scripts/core/Player.gd`: locomotion, health/death, combat, attack action, mobile control signals, and prop interaction discovery. Keep activity input routing small and dispatch to the nearby prompt/controller.
  - `scripts/gameplay/ObjectiveManager.gd`: `add_objective`, `update_progress`, `all_objectives_completed`; add objectives before play and increment only on win.
  - `scripts/characters/ZombieSpawner3D.gd`: use bounded spawning for outside pressure in Quarantine. Do not let its ambient random spawns create activity targets or unpredictably satisfy/fail a mini-game. During the activity, set/restore its state through explicit `start_spawning()` / `stop_spawning()` ownership or a dedicated activity spawn point and bounded controller-owned spawn calls.
  - `scripts/world/interactive/InteractiveDoor.gd`, `FoodCrate.gd`, `InteractiveVehicle.gd`: reuse their interaction/state conventions, meshes, audio hooks, and child layouts where suitable. `InteractiveVehicle` is explicitly kinematic and the current `FoodCrate` opens to spawn food; neither currently supplies the required physics cart or breakable supply behavior by itself. The builders must add the activity-specific behavior described below rather than assume those existing mechanics already exist.
- **Industrial Gating (GDD §3, WorldProgression):**
  - Both activities are gated by `WorldProgression.can_hop(2)` — the player must have access to Industrial (Region 2) before either can be activated.
  - Loot tier for rewards uses `WorldProgression.get_active_loot_tier()` at the moment of completion (returns Region 2's `loot_tier` = 2).
  - Secret transport reachability (`WorldProgression.is_secret_reachable(1, 2)`) enables early Industrial access; if the player jumps ahead, these minigames become available immediately upon hop completion (`WorldHopManager` emits `hop_completed`).

---

## 1. Triage Roundup — Industrial

### 1.1 Player-Facing Loop Step by Step

1. **Discovery:** The player finds the lit triage manifest board in the Shipping Yard Triage Bay. Four clearly marked empty containment pens sit around the central sorting hall; a cargo silhouette and matching painted stripe identify each pen: **Heavy Crate (red), Fuel Cell (blue), Hydraulic Module (yellow), Wiring Bundle (green)**. A scorched sign reads `RETURN EACH CARGO UNIT TO ITS PEN`.
2. **Initiation:** Entering the marked start zone reveals `START TRIAGE — 4 UNITS — BAY OVERRUN IN 90s`. The player taps/interacts to begin. The game places four contained, non-attacking industrial cargo units in marked release stalls at the far end of the hall, one of each type, and starts the 90-second overrun clock.
3. **Shove & Guide:** Move into a unit's side/rear and attack/flick it with the bat or bare-hand attack. A valid shove applies a forward impulse away from the player to the unit's physics body. The player can also body-bump it while moving; the shove is directional, so a front-on strike can push it toward the wrong pen. Do not allow normal weapon damage to destroy these objective units.
4. **Delivery:** Guide each unit down the hall to its matching pen. The pen's floor marking and low entry gate make the target readable from the third-person camera. A wrong-type unit entering a pen is bounced gently back out and the HUD flashes the required color/name. Units that escape the sorting-hall bounds are repositioned at their original release stall with their velocity cleared; this costs 8 seconds from the shared clock and does not count as a delivery.
5. **Capture:** Correct delivery requires the unit's body to remain inside its matching pen for 1.25 seconds. The gate closes, its pen lamp turns on, and the HUD changes that unit's row to complete. The unit is then frozen/parked inside the pen so later collisions cannot undo credit.
6. **Victory:** Deliver all four units before the clock reaches zero. The board stamps `ALL CARGO ACCOUNTED FOR`; the mini-game wins and the triage objective advances once.

### 1.2 Activation Trigger

- `TriageStartBoard` has a player-only `StartZone`. While the activity is idle and the objective is incomplete, the in-world prompt `START TRIAGE` appears within 3.5 m and after zone overlap. Only an attack/interact press while that prompt is visible starts it. Walking through the zone never starts it.
- **Industrial Gate:** `WorldProgression.can_hop(2)` must be true (player has Industrial access). If false, prompt reads `INDUSTRIAL ACCESS REQUIRED` and interaction is ignored.
- On activation, lock the four release-stall doors open, place/reset the four units, set the timer to 90 seconds, and show the compact activity HUD. No units or countdown exist before activation.

### 1.3 Win and Fail Conditions

- **Win:** each of four unique unit instances is stably inside its own matching pen for 1.25 seconds before time expires. Set win state before emitting progress so a duplicate signal cannot increment twice.
- **Fail:** timer reaches 0 before all four deliveries; player dies; or a hostile zombie enters the sorting hall and reaches the `HallOverrunZone` for 2 seconds. The hall-overrun rule is an activity-local Area3D condition, not a global automatic failure on any zombie hit.
- On fail, stop the local timer, clear unit velocities, return units to release stalls, reopen all pen gates, clear temporary delivery state, show `TRIAGE OVERRUN — TRY AGAIN`, and leave `l2_triage_roundup` incomplete. Allow retry at the board after 3 seconds. Do not heal or resurrect the player; normal death/respawn owns that flow. If death caused failure, reset the activity on player respawn and require another explicit start.
- **Loot Tier:** On win, reward tier = `WorldProgression.get_active_loot_tier()` (2 for Industrial).

### 1.4 Physics and Reused Systems

- Unit bodies must be `RigidBody3D` or have a dedicated rigid-body root and collision shapes; set a stable mass in the 18–30 kg range, linear damping around 2, angular damping high enough to prevent uncontrolled rolling, and lock rotation except yaw/limited tipping. Set a capped shove impulse so a single hit moves a unit about 1–2 m on the concrete floor without launching it. Use collision layers/masks that collide with floor, pens, player, and other units.
- **Reuse Level 1 art/scenes where compatible:** `scenes/characters/zombie_dog.tscn`, `zombie_cat.tscn`, `zombie_rabbit.tscn`, `zombie_chicken.tscn` as visual/animation sources. Their combat AI and `ZombieBase` health/death behavior must be disabled or bypassed for these objective props; they are secured cargo, not enemies to kill. Do not obtain them from ambient `ZombieSpawner3D` pools because pool activation/AI/death behavior conflicts with persistent delivery tracking.
- Reuse `Player.gd` movement and attack pose/feedback, but add a triage-target hit route: when the attack ray/area identifies a live roundup unit during the activity, apply the capped impulse and suppress damage. Keep enemy attack and health behavior unchanged outside this activity.
- Reuse `ObjectiveManager` exactly through the shared contract. `ZombieSpawner3D` remains an external threat source; the local overrun zone is the only hostile intrusion fail check.
- **Rules Engine Integration (RULES_ENGINE.md):** Mini-game completion increments `Rules.increment_stat("MINIGAMES_WON", 1)` (Parameter ID 30) and may gate future unlocks via `ACHIEVEMENT_TIER` (ID 72).

### 1.5 New Files and Scenes to Create (Industrial Variants)

- `scripts/gameplay/TriageRoundupIndustrialController.gd` — idle/active/won/failed state, four-instance/type registry, clock, reset, unique delivery validation, one-shot objective report, **WorldProgression.can_hop(2) gate**, **loot tier via get_active_loot_tier()**. (Current `TriageRoundupController.gd:12` uses `l1_triage_roundup`; new controller uses `l2_triage_roundup`.)
- `scripts/gameplay/TriageIndustrialUnit.gd` — unit type, shove response, return-to-stall bounds handling, pen capture lock, emitted delivery candidate signal. No combat AI. (Current `TriageAnimalBody.gd:29` uses `animal_type` string enum; new unit uses `unit_type: heavy_crate | fuel_cell | hydraulic_module | wiring_bundle`.)
- `scripts/gameplay/TriageIndustrialPen.gd` — exported `required_unit_type`, overlap detection, 1.25-second stable dwell timer, wrong-type bounce, matching lamp/gate feedback. (Current `TriageWardPen.gd:21` uses `required_animal_type`; new pen uses `required_unit_type`.)
- `scenes/minigames/triage_roundup_industrial.tscn` — board/start zone, four release stalls, hall bounds, four pen instances, overrun zone, unit spawn markers, controller, HUD anchor. Instance this inside `scenes/world/environment/industrial_shipping_yard.tscn` without replacing the environment.
- `scenes/minigames/triage_industrial_unit.tscn` — reusable rigid body with industrial cargo visual, collision capsule/shape, ground contact, and type assigned by controller.
- `scenes/ui/triage_roundup_industrial_hud.tscn` — title, 90s countdown, four named/type-colored rows, and transient wrong-pen/reset/fail feedback.

### 1.6 Mobile Touch Mapping

- Joystick: steer the player around to get behind/alongside the unit; do not steer the unit directly with UI.
- Attack/left-click: shove the highlighted nearby unit; the nearest valid unit hit is selected by the existing attack target query. Without a valid activity target, it remains ordinary combat.
- SPRINT: reposition before the unit drifts into another unit or wall. JUMP: clear dropped clutter/low obstacles only. SWAP: change weapon; both bat and bare-hand shove use the same capped impulse, so weapon choice cannot trivialize the physics.
- START prompt: use the same attack/interact press when standing by the board. Keep it inside the lower-right thumb area; no multi-touch hold sequence is required.

### 1.7 Fun Hook

The player is batting four massive, recognizable industrial cargo units through an actual shipping corridor, and every hit has a readable direction: lining up a clean side shove into the color-coded pen feels like a precision forklift maneuver, while a bad angle sends a fuel cell pinballing across the hall as the overrun clock bites.

### 1.8 Implementation Status (Code-Grounded)

| Aspect | Status | Evidence |
|--------|--------|----------|
| Controller state machine (IDLE/ACTIVE/WON/FAILED) | IMPLEMENTED | `TriageRoundupController.gd:20-21, 94-113` |
| 90s timer + escape penalty (8s) | IMPLEMENTED | `TriageRoundupController.gd:14-16, 73-82, 168-178` |
| Four unique type delivery + 1.25s dwell | IMPLEMENTED | `TriageRoundupController.gd:115-129`, `TriageWardPen.gd:46-68` |
| Wrong-type bounce + HUD flash | IMPLEMENTED | `TriageWardPen.gd:54-59, 82-88` |
| Hall overrun zone (2s dwell fail) | IMPLEMENTED | `TriageRoundupController.gd:180-200` |
| ObjectiveManager one-shot report | IMPLEMENTED | `TriageRoundupController.gd:136-137` |
| **Industrial objective ID (`l2_triage_roundup`)** | TO BUILD | Current uses `l1_triage_roundup` (line 12) |
| **WorldProgression.can_hop(2) gate** | TO BUILD | Not present in current controller |
| **Loot tier via get_active_loot_tier()** | TO BUILD | Not present |
| **Industrial unit types (crate/cell/module/bundle)** | TO BUILD | Current uses dog/cat/rabbit/chicken |
| **Industrial pen types + materials** | TO BUILD | Current uses animal colors |
| **Industrial scene (shipping yard placement)** | TO BUILD | Current in hospital |

---

## 2. Quarantine Breach — Industrial

### 2.1 Player-Facing Loop Step by Step

1. **Discovery:** The player reaches the hazmat rail conduit entrance where a quarantine board displays three breach indicators in order: **A—Intake Valve, B—Coolant Junction, C—Vent Stack**. Each hatch has a matching large letter and red breach lamp. The player can inspect the route before starting; the game is idle and no breach zombies spawn yet.
2. **Initiation:** The board prompt reads `START SEALDOWN — 3 BREACHES — 120s`. The player explicitly taps/interacts. The clock starts and breach A opens first. Zombies begin entering only at the active breach lane and walk toward the marked red line. All unvisited lanes remain physically blocked by closed hatches.
3. **Breach A (Supply Case):** At the supply pallet beside A, attack/interact with the breakable crate to crack it once. It drops **one heavy supply case** (a physics rigid body) and two ammo pickups. The case is the required hatch brace. Ammo is optional and uses the normal pickup system. The crate cannot be reopened to farm items.
4. **Seal A:** Push/strike the case into the marked brace footprint across Hatch A's threshold, then interact with Hatch A to swing it shut. The hatch counts sealed only when it is closed and the case overlaps its brace socket continuously for 0.75 seconds. A hatch shut without a case is only a temporary hold and begins reopening after 4 seconds; a case outside the socket does not seal it.
5. **Breach B (Service Cart):** Once A is sealed, the board advances to B, opens the B breach lane, and sounds its alarm. The player reaches a parked industrial coolant cart near the junction. Push the cart using movement/body contact or capped attack impulse into B's marked threshold socket, then swing Hatch B shut. The cart must remain in the socket for 0.75 seconds with the hatch closed to seal B. The cart can be repositioned by collision; avoid scripting it to snap to the goal.
6. **Breach C (Second Supply Case):** Once B is sealed, C activates. A fresh supply crate at the vent stack provides one second heavy case (and two ammo pickups) only when cracked. Use it to brace Hatch C, then swing the hatch shut.
7. **Victory:** Seal A, then B, then C before 120 seconds. The board locks all three lamps green, the hazmat conduit shutter opens, and Quarantine Breach reports its objective complete exactly once.

### 2.2 Activation Trigger

- `QuarantineBoard` has a player-only `StartZone`, visible route diagram, and prompt `START SEALDOWN`. Attack/interact while the prompt is visible starts the event. Zone entry, a zombie touching a hatch, or opening a crate never starts it.
- **Industrial Gate:** `WorldProgression.can_hop(2)` must be true. If false, prompt reads `INDUSTRIAL ACCESS REQUIRED` and interaction is ignored.
- At start, reset all three hatches closed, reset both cases and cart to their staging marks, close/uncrack crates, set step to A, set timer to 120 seconds, and enable the activity-owned breach spawner. Do not use ambient random spawn events as step completion.

### 2.3 Win and Fail Conditions

- **Win:** complete A→B→C in that order before 120 seconds; each hatch's own seal test must pass. Reaching a later socket early does not bank it. Win freezes breach progression, closes the active lane, stops only this activity's spawn source, and advances `l2_quarantine_breach` once.
- **Fail:** timer reaches 0; player dies; or 6 zombies are simultaneously inside the conduit `BreachKillZone` beyond the marked interior red line. This gives missed hatches a visible, bounded consequence without treating every approaching zombie as instant failure.
- On fail, stop the activity clock/spawns, keep existing zombies as normal world threats (do not delete/kill them to fake a reset), show `CONDUIT LOST — RETREAT AND RESET`, and leave the objective incomplete. Require the player to clear the marked route of hostiles by normal combat before the board prompt returns; then allow an explicit retry. Reset only activity props and route counters at retry, not player health/ammo or world-wide zombie state. This keeps failure consequential while making the restart state deterministic.
- **Loot Tier:** On win, reward tier = `WorldProgression.get_active_loot_tier()` (2 for Industrial).

### 2.4 Physics and Reused Systems

- Reuse `InteractiveDoor.gd` for the three hinged hatches and its explicit `interact()` call, but add a quarantine-specific sealed-state check. The current door script opens/closes by interaction and has no brace/socket semantics. Configure each hatch with `auto_reset` disabled during this activity; the existing 4-second hold-reset behavior is not the gameplay seal rule. A closed hatch plus correctly seated object, not a timer alone, is the seal.
- Reuse `FoodCrate.gd` interaction zone and one-shot open pattern, but add `breakable_supply` mode for these two crates: the first attack/interact press opens and permanently marks the crate cracked for the round, drops the configured rigid-body supply case and two standard ammo pickups; it must not also spawn food. Use normal food/ammo pickup scripts where compatible. Existing `FoodCrate` currently spawns food and resets after the player leaves, so turn off auto-reset for the activity crate while active and prevent reopening/farming.
- Reuse the service-cart silhouette/visuals from `InteractiveVehicle` if helpful, but add a true `RigidBody3D` pushable cart configuration (mass 45–65 kg, angular damping, ground friction, capped player shove, no engine/AI). The existing `InteractiveVehicle` is kinematic; do not count its current visual `is_pushed` state as physical movement or seal evidence.
- Supply cases: `RigidBody3D`, approximately 35–45 kg, high enough friction to hold a hatch brace, with a visible handle/stripe and a small socket Area3D query. Use physics impulses for player hits; no teleport-to-socket or automatic snap. A subtle outline/arrow appears only when the case/cart is within 2.5 m of its intended socket.
- Each hatch step has a dedicated lane spawn marker and controller-owned spawn budget. Use `ZombieSpawner3D`'s zombie scenes/pools and death tracking where feasible, but expose a deterministic "spawn this type at this marker" path or have the mini-game controller own a bounded sequence. Spawn one zombie every 7 seconds at the current open lane, maximum 6 active in the conduit; stop generating at win/fail. Avoid calling global `stop_spawning()` if it would silence the level's unrelated ambient spawns—give the activity its own spawner/controller ownership. Existing zombies entering the red line count toward the six-zombie failure threshold.
- Hostile zombies use the existing combat target, damage, and death systems. The player can fight to buy time, but zombie kills do not advance hatch steps or the objective. Hatch and case/cart physics remain meaningful while combat occurs.
- `ObjectiveManager` integration is one `update_progress("l2_quarantine_breach", 1)` after final seal only. A failed/retried run never increments until a win. The level still waits for every registered objective through `all_objectives_completed`.
- **Rules Engine Integration:** Completion increments `Rules.increment_stat("MINIGAMES_WON", 1)` (ID 30). The ordered A→B→C gate may be toggled via `Rules.set_parameter_enabled(RequirementTypes.Type.CUSTOM_FLAG_0, ...)` for LiveOps variants.

### 2.5 New Files and Scenes to Create (Industrial Variants)

- `scripts/gameplay/QuarantineBreachIndustrialController.gd` — idle/active/won/failed state, 120-second clock, ordered A/B/C gates, per-lane spawn ownership/budget, red-line crowd count, reset/start behavior, one-shot objective report, **WorldProgression.can_hop(2) gate**, **loot tier via get_active_loot_tier()**. (Current `QuarantineBreachController.gd:14-15` uses `l1_quarantine_breach`; new controller uses `l2_quarantine_breach`.)
- `scripts/gameplay/QuarantineIndustrialSealHatch.gd` — wraps/extends door state with step id, assigned brace type (`case` or `cart`), socket overlap dwell (0.75 s), order validation, and temporary unbraced reopen after 4 s. (Current `QuarantineSealDoor.gd:17-18` uses `seal_step` + `assigned_brace`; structurally compatible.)
- `scripts/world/interactive/BreakableIndustrialSupplyCrate.gd` — activity crate one-time crack and configured case/ammo drops; avoid altering FoodCrate defaults for ordinary world crates. (Current `BreakableSupplyCrate.gd:14` uses `supply_case_path`; compatible.)
- `scripts/world/interactive/PushableIndustrialCart.gd` — physical cart body, shove cap, staging reset, and socket eligibility. (Current `PushableServiceCart.gd:17` mass 55kg; compatible.)
- `scripts/world/interactive/QuarantineIndustrialSupplyCase.gd` — physical case type, reset point, and socket eligibility. (Current `QuarantineSupplyCase.gd:17` mass 40kg; compatible.)
- `scenes/minigames/quarantine_breach_industrial.tscn` — board, A/B/C hatches and lane zones, route/spawn markers, three brace sockets, two breakable crates, cart staging mark, red-line crowd zone, activity-owned spawner, controller, and HUD. Instance into `scenes/world/environment/industrial_hazmat_rail.tscn` along the conduit, preserving free-roam approaches and readable sightlines.
- `scenes/world/props/quarantine_industrial_supply_case.tscn`, `scenes/world/props/pushable_industrial_cart.tscn`, `scenes/world/props/breakable_industrial_supply_crate.tscn` — reusable configured physics props.
- `scenes/ui/quarantine_breach_industrial_hud.tscn` — title, countdown, ordered A/B/C checklist, active breach indicator, crowd warning, and retry state.

### 2.6 Mobile Touch Mapping

- Joystick: approach a crate, hatch, cart, case, and socket; push objects by walking into them and steering along the desired line.
- Attack/left-click: use the focused crate/hatch interaction when its prompt is active; otherwise swing at a hostile zombie. Attack the case/cart to add the same capped impulse as Triage if it is within the short shove radius. Interaction focus wins only when the prompt is visibly shown, so nearby enemies remain attackable with a small aim offset.
- SPRINT: cross between active breach lane and supply/brace position quickly. JUMP: clear debris and low cart clutter. SWAP: choose combat weapon; do not make weapon tier change the object's required socket/weight check.
- START and crate/hatch interaction are single attack/interact presses. The board/checklist stays above the touch controls; the active lane letter and timer remain readable without opening a menu.

### 2.7 Fun Hook

This is a physical, three-stop panic puzzle in the middle of a zombie fight: the player hears the next hatch start banging, has to decide whether to spend seconds wrestling a heavy coolant cart or keep the crowd down, and sees an unbraced hatch physically give way when the route order is ignored.

### 2.8 Implementation Status (Code-Grounded)

| Aspect | Status | Evidence |
|--------|--------|----------|
| Controller state machine (IDLE/ACTIVE/WON/FAILED) | IMPLEMENTED | `QuarantineBreachController.gd:25-26, 116-150` |
| 120s timer + 7s spawn interval | IMPLEMENTED | `QuarantineBreachController.gd:16-18, 93-96` |
| Ordered A→B→C gate + seal dwell (0.75s) | IMPLEMENTED | `QuarantineBreachController.gd:152-163`, `QuarantineSealDoor.gd:59-70` |
| Brace types (case/cart) + socket check | IMPLEMENTED | `QuarantineSealDoor.gd:17-18, 44-55` |
| Red-line crowd fail (6 zombies) | IMPLEMENTED | `QuarantineBreachController.gd:106-108, 232-247` |
| ObjectiveManager one-shot report | IMPLEMENTED | `QuarantineBreachController.gd:176-177` |
| Crate one-time crack + case/ammo drops | IMPLEMENTED | `BreakableSupplyCrate.gd:42-60` |
| Case mass 40kg + cart mass 55kg | IMPLEMENTED | `QuarantineSupplyCase.gd:17`, `PushableServiceCart.gd:17` |
| **Industrial objective ID (`l2_quarantine_breach`)** | TO BUILD | Current uses `l1_quarantine_breach` (line 14) |
| **WorldProgression.can_hop(2) gate** | TO BUILD | Not present in current controller |
| **Loot tier via get_active_loot_tier()** | TO BUILD | Not present |
| **Industrial hatch labels (Valve/Junction/Stack)** | TO BUILD | Current uses Intake/Laundry/Loading Bay |
| **Industrial scene (hazmat rail placement)** | TO BUILD | Current in hospital service route |
| **Industrial spawner (Industrial zombie types)** | TO BUILD | Current uses `zombie_dog.tscn` (line 23) |

---

## 3. What This Is NOT Going to Do (Explicit Anti-Slop Non-Goals)

To prevent scope creep, design bloat, and sloppy implementations, the following non-goals are strictly enforced:

1. **No Automatic Triggering:** Walking into any mini-game area will NEVER auto-start an activity. All activities require an explicit, player-initiated interaction press while facing an in-world console or board.
2. **No Vacuum Auto-Shoving in Triage:** Triage Roundup will NOT allow the player to sprint across the hall and shove all 4 units simultaneously. Each unit requires proximity targeting and conscious interaction, ensuring visual discrimination remains the primary skill.
3. **No Infinite Brace Farming:** Quarantine Breach will NOT allow re-cracking crates or respawning cases/carts upon leaving and returning. Braces per breach are strictly finite.
4. **No Map-Wide Kiting:** Quarantine Breach will NOT permit the player to lure breach zombies across the entire Industrial map. Leaving the marked conduit route for the activity's fail conditions to apply.
5. **No Invisible Swapping of Brace Physics:** Quarantine Breach will NOT snap cases/carts to sockets automatically. Physics impulses and player positioning remain the only way to seat a brace.
6. **No Interruption of Free-Roam Exploration:** An unactivated mini-game is completely passive. The Industrial world remains open and fully explorable without invisible walls blocking paths before activities are triggered.
7. **No God Controllers:** Each mini-game is isolated into its own modular controller script and scene. No single script manages multiple mini-games; each interfaces with the game only through `ObjectiveManager`, `WorldProgression`, `Rules`, and `Player.gd`.
8. **No Click Targets < 44×44 px:** All mobile buttons, interaction prompts, and UI tap zones adhere strictly to mobile usability standards (minimum 44×44 px touch area, minimum 14sp text).
9. **No Level 1 Asset Reuse Without Industrial Reskin:** The Industrial variants must use Industrial-themed visuals (cargo units, hatches, coolant carts, hazmat crates) — not the Level 1 hospital assets. The controllers are reused; the scenes and visuals are new.