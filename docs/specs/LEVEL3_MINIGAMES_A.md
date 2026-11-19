# Level 3 Mini-Games A — Build Specification (Bio-Lab)

**Scope:** Three activatable, diegetic mini-games for Level 3 (Bio-Lab): **Triage Roundup — Bio-Lab** in the Containment Wing Cryo-Recovery Bay, **Quarantine Breach — Bio-Lab** in the Research Bay Containment Corridor, and **Armory Lockdown — Bio-Lab** at the Synthesis Core Access Lock. All three are required Level 3 objectives. This document defines gameplay, scene ownership, inputs, completion, and failure behavior; it does not implement them.

**Ground-truth sources:** `docs/MASTER_GDD.md` (World 3 row: containment wings, research bays, cryogenic vaults, synthesis core; loot bio-polymers/mutagen samples/cryo-cores/cure catalysts; connections: sub-level freight conduit from Industrial, emergency decontamination chute to Suburban & Industrial).gd:9-11`, `scripts/core/WorldProgression.gd:27-35,189-194,278-282`, `scripts/core/LevelManager.gd:11,20,34,41`, `scenes/world/environment/endgame_heights.tscn:82-100,299-300`, `scenes/world/environment/endgame_cache_network.tscn:367-870`, `tools/tests/cure_endgame_playtest.gd:26-122`, `scripts/core/Game.gd:239-250,429-444`, `scripts/gameplay/TriageRoundupController.gd:12-26,94-134`, `scripts/gameplay/QuarantineBreachController.gd:14-25,124-132`, `scripts/gameplay/ArmoryLockdownController.gd:9-11,47-78`, `scripts/world/interactive/CheckpointArmoryTerminal.gd:21-57`.

---

## Shared Implementation Contract

- Add all three objective records during Level 3 setup, before the player can start any activity:
  - `l3_triage_cryo_recovery`, title `Recover cryo-pods from containment`, target `1`.
  - `l3_quarantine_containment`, title `Seal the research breach`, target `1`.
  - `l3_synthesis_core_access`, title `Breach synthesis core lock`, target `1`.
- A mini-game controller owns its own state and timer. It calls `ObjectiveManager.update_progress(id, 1)` exactly once, only after a win. A failure never advances progress. Keep the level's existing `all_objectives_completed` listener as the sole level-complete/next-level gate; do not make any activity directly unlock the exit.
- All activities are idle until an explicit player action at a visible start marker. Show a diegetic prompt and a thumb-sized `START` interaction (minimum 44×44 px); never start from entering an Area3D alone. The start trigger is disabled while active and after a win. Failure returns the activity to a ready-to-retry state after its reset, without adding progress.
- Use a shared activity HUD panel: title, short objective, countdown, and clear success/failure state. Keep body text at least 14sp and action text at least 16sp. Place it above the bottom action row so joystick, camera drag, and buttons do not overlap.
- Add an `Area3D` start zone and route the player's existing `attack` action / mobile attack button to its prompt. Desktop left-click is `attack`. In this context only, the prompt consumes the attack press and does not swing a weapon. Player movement, camera, stamina, health, combat, and death remain owned by `Player.gd` and existing systems.
- **Mobile controls:** left thumb joystick moves; right-side camera drag aims/orients; existing `SPRINT`, `JUMP`, and `SWAP` buttons retain their current functions; existing attack button activates a nearby highlighted start/prop and performs combat when no interaction prompt is eligible. SPRINT is useful for repositioning, JUMP for crossing clutter, and SWAP for choosing a weapon. Do not add a second simultaneous attack/interact button. Update the mobile callback path to share the same interaction resolver as `InputMap` action `attack`; current mobile callbacks call `_perform_attack()` directly and bypass prop interaction. Preserve ordinary combat if no prompt is in range.
- Existing scripts to reuse where applicable:
  - `scripts/core/Player.gd`: locomotion, health/death, combat, attack action, mobile control signals, and prop interaction discovery. Keep activity input routing small and dispatch to the nearby prompt/controller.
  - `scripts/gameplay/ObjectiveManager.gd`: `add_objective`, `update_progress`, `all_objectives_completed`; add objectives before play and increment only on win.
  - `scripts/characters/ZombieSpawner3D.gd`: use bounded spawning for outside pressure in Quarantine. Do not let its ambient random spawns create activity targets or unpredictably satisfy/fail a mini-game. During the activity, set/restore its state through explicit `start_spawning()` / `stop_spawning()` ownership or a dedicated activity spawn point and bounded controller-owned spawn calls.
  - `scripts/world/interactive/InteractiveDoor.gd`, `BreakableSupplyCrate.gd`, `InteractiveVehicle.gd`: reuse their interaction/state conventions, meshes, audio hooks, and child layouts where suitable. `InteractiveVehicle` is explicitly kinematic and the current `FoodCrate` opens to spawn food; neither currently supplies the required physics cart or breakable supply behavior by itself. The builders must add the activity-specific behavior described below rather than assume those existing mechanics already exist.
- **Bio-Lab Gating (GDD §3, WorldProgression):**
  - All activities are gated by `WorldProgression.can_hop(3)` — the player must have access to Bio-Lab (Region 3) before any can be activated.
  - Loot tier for rewards uses `WorldProgression.get_active_loot_tier()` at the moment of completion (returns Region 3's `loot_tier` = 3).
  - Secret transport reachability (`WorldProgression.is_secret_reachable(2, 3)`) enables early Bio-Lab access via the sub-level freight conduit; if the player jumps ahead, these minigames become available immediately upon hop completion (`WorldHopManager` emits `hop_completed`).
  - The return chute (`is_secret_reachable(3, 1)` and `is_secret_reachable(3, 2)`) requires no repair and is always traversable once Region 3 is unlocked.

---

## 1. Triage Roundup — Bio-Lab (Cryo-Pod Recovery)

### 1.1 Player-Facing Loop Step by Step

1. **Discovery:** The player finds the lit cryo-manifest board in the Containment Wing Cryo-Recovery Bay. Four clearly marked empty cryo-recovery bays sit around the central thawing hall; a pod silhouette and matching painted stripe identify each bay: **Cryo-Pod Alpha (red), Cryo-Pod Beta (blue), Cryo-Pod Gamma (yellow), Cryo-Pod Delta (green)**. A frosted sign reads `RECOVER EACH CRYO-POD TO ITS BAY`.
2. **Initiation:** Entering the marked start zone reveals `START CRYO RECOVERY — 4 PODS — THAW OVERRUN IN 90s`. The player taps/interacts to begin. The game places four contained, non-attacking cryo-pods in marked release stalls at the far end of the hall, one of each type, and starts the 90-second overrun clock.
3. **Shove & Guide:** Move into a pod's side/rear and attack/flick it with the bat or bare-hand attack. A valid shove applies a forward impulse away from the player to the pod's physics body. The player can also body-bump it while moving; the shove is directional, so a front-on strike can push it toward the wrong bay. Do not allow normal weapon damage to destroy these objective pods.
4. **Delivery:** Guide each pod down the hall to its matching bay. The bay's floor marking and low entry gate make the target readable from the third-person camera. A wrong-type pod entering a bay is bounced gently back out and the HUD flashes the required color/name. Pods that escape the thawing-hall bounds are repositioned at their original release stall with their velocity cleared; this costs 8 seconds from the shared clock and does not count as a delivery.
5. **Capture:** Correct delivery requires the pod's body to remain inside its matching bay for 1.25 seconds. The gate closes, its bay lamp turns on, and the HUD changes that pod's row to complete. The pod is then frozen/parked inside the bay so later collisions cannot undo credit.
6. **Victory:** Deliver all four pods before the clock reaches zero. The board stamps `ALL CRYO-PODS RECOVERED`; the mini-game wins and the cryo-recovery objective advances once.

### 1.2 Activation Trigger

- `CryoStartBoard` has a player-only `StartZone`. While the activity is idle and the objective is incomplete, the in-world prompt `START CRYO RECOVERY` appears within 3.5 m and after zone overlap. Only an attack/interact press while that prompt is visible starts it. Walking through the zone never starts it.
- **Bio-Lab Gate:** `WorldProgression.can_hop(3)` must be true (player has Bio-Lab access). If false, prompt reads `BIO-LAB ACCESS REQUIRED` and interaction is ignored.
- On activation, lock the four release-stall doors open, place/reset the four pods, set the timer to 90 seconds, and show the compact activity HUD. No pods or countdown exist before activation.

### 1.3 Win and Fail Conditions

- **Win:** each of four unique pod instances is stably inside its own matching bay for 1.25 seconds before time expires. Set win state before emitting progress so a duplicate signal cannot increment twice.
- **Fail:** timer reaches 0 before all four deliveries; player dies; or a hostile mutant enters the thawing hall and reaches the `HallOverrunZone` for 2 seconds. The hall-overrun rule is an activity-local Area3D condition, not a global automatic failure on any mutant hit.
- On fail, stop the local timer, clear pod velocities, return pods to release stalls, reopen all bay gates, clear temporary delivery state, show `CRYO RECOVERY OVERRUN — TRY AGAIN`, and leave `l3_triage_cryo_recovery` incomplete. Allow retry at the board after 3 seconds. Do not heal or resurrect the player; normal death/respawn owns that flow. If death caused failure, reset the activity on player respawn and require another explicit start.
- **Loot Tier:** On win, reward tier = `WorldProgression.get_active_loot_tier()` (3 for Bio-Lab).

### 1.4 Physics and Reused Systems

- Pod bodies must be `RigidBody3D` or have a dedicated rigid-body root and collision shapes; set a stable mass in the 18–30 kg range, linear damping around 2, angular damping high enough to prevent uncontrolled rolling, and lock rotation except yaw/limited tipping. Set a capped shove impulse so a single hit moves a pod about 1–2 m on the cryo-floor without launching it. Use collision layers/masks that collide with floor, bays, player, and other pods.
- **Reuse Level 1 art/scenes where compatible:** `scenes/characters/zombie_dog.tscn`, `zombie_cat.tscn`, `zombie_rabbit.tscn`, `zombie_chicken.tscn` as visual/animation sources. Their combat AI and `ZombieBase` health/death behavior must be disabled or bypassed for these objective props; they are secured cryo-pods, not enemies to kill. Do not obtain them from ambient `ZombieSpawner3D` pools because pool activation/AI/death behavior conflicts with persistent delivery tracking.
- Reuse `Player.gd` movement and attack pose/feedback, but add a triage-target hit route: when the attack ray/area identifies a live roundup pod during the activity, apply the capped impulse and suppress damage. Keep enemy attack and health behavior unchanged outside this activity.
- Reuse `ObjectiveManager` exactly through the shared contract. `ZombieSpawner3D` remains an external threat source; the local overrun zone is the only hostile intrusion fail check.
- **Rules Engine Integration (RULES_ENGINE.md):** Mini-game completion increments `Rules.increment_stat("MINIGAMES_WON", 1)` (Parameter ) and may gate future unlocks via `ACHIEVEMENT_TIER` ().

### 1.5 New Files and Scenes to Create (Bio-Lab Variants)

- `scripts/gameplay/TriageCryoRecoveryController.gd` — idle/active/won/failed state, four-instance/type registry, clock, reset, unique delivery validation, one-shot objective report, **WorldProgression.can_hop(3) gate**, **loot tier via get_active_loot_tier()**. (Current `TriageRoundupController.gd:12` uses `l1_triage_roundup`; new controller uses `l3_triage_cryo_recovery`.)
- `scripts/gameplay/TriageCryoPod.gd` — pod type, shove response, return-to-stall bounds handling, bay capture lock, emitted delivery candidate signal. No combat AI. (Current `TriageAnimalBody.gd:29` uses `animal_type` string enum; new pod uses `pod_type: cryo_alpha | cryo_beta | cryo_gamma | cryo_delta`.)
- `scripts/gameplay/TriageCryoBay.gd` — exported `required_pod_type`, overlap detection, 1.25-second stable dwell timer, wrong-type bounce, matching lamp/gate feedback. (Current `TriageWardPen.gd:21` uses `required_animal_type`; new bay uses `required_pod_type`.)
- `scenes/minigames/triage_cryo_recovery.tscn` — board/start zone, four release stalls, hall bounds, four bay instances, overrun zone, pod spawn markers, controller, HUD anchor. Instance this inside `scenes/world/environment/endgame_heights.tscn` (SewerDistrict or MallDistrict placement) without replacing the environment.
- `scenes/minigames/triage_cryo_pod.tscn` — reusable rigid body with cryo-pod visual, collision capsule/shape, ground contact, and type assigned by controller.
- `scenes/ui/triage_cryo_recovery_hud.tscn` — title, 90s countdown, four named/type-colored rows, and transient wrong-bay/reset/fail feedback.

### 1.6 Mobile Touch Mapping

- Joystick: steer the player around to get behind/alongside the pod; do not steer the pod directly with UI.
- Attack/left-click: shove the highlighted nearby pod; the nearest valid pod hit is selected by the existing attack target query. Without a valid activity target, it remains ordinary combat.
- SPRINT: reposition before the pod drifts into another pod or wall. JUMP: clear dropped clutter/low obstacles only. SWAP: change weapon; both bat and bare-hand shove use the same capped impulse, so weapon choice cannot trivialize the physics.
- START prompt: use the same attack/interact press when standing by the board. Keep it inside the lower-right thumb area; no multi-touch hold sequence is required.

### 1.7 Fun Hook

The player is maneuvering four massive, recognizable cryo-pods through an actual thawing corridor, and every hit has a readable direction: lining up a clean side shove into the color-coded bay feels like a precision recovery maneuver, while a bad angle sends a pod pinballing across the hall as the overrun clock bites.

### 1.8 Implementation Status (Code-Grounded)

| Aspect | Status | Evidence |
|--------|--------|----------|
| Controller state machine (IDLE/ACTIVE/WON/FAILED) | IMPLEMENTED (base logic; L3 port TO BUILD) | `TriageRoundupController.gd:20-21, 94-113` |
| 90s timer + escape penalty (8s) | IMPLEMENTED (base logic; L3 port TO BUILD) | `TriageRoundupController.gd:14-16, 73-82, 168-178` |
| Four unique type delivery + 1.25s dwell | IMPLEMENTED (base logic; L3 port TO BUILD) | `TriageRoundupController.gd:115-129`, `TriageWardPen.gd:46-68` |
| Wrong-type bounce + HUD flash | IMPLEMENTED (base logic; L3 port TO BUILD) | `TriageWardPen.gd:54-59, 82-88` |
| Hall overrun zone (2s dwell fail) | IMPLEMENTED (base logic; L3 port TO BUILD) | `TriageRoundupController.gd:180-200` |
| ObjectiveManager one-shot report | IMPLEMENTED (base logic; L3 port TO BUILD) | `TriageRoundupController.gd:136-137` |
| **Bio-Lab objective ID (`l3_triage_cryo_recovery`)** | TO BUILD | Current uses `l1_triage_roundup` (line 12) |
| **WorldProgression.can_hop(3) gate** | TO BUILD | Not present in current controller |
| **Loot tier via get_active_loot_tier()** | TO BUILD | `TriageRoundupController.gd:145-146` reads it but uses L1/L2 IDs only |
| **Cryo pod types (alpha/beta/gamma/delta)** | TO BUILD | Current uses dog/cat/rabbit/chicken |
| **Cryo bay types + materials** | TO BUILD | Current uses animal colors |
| **Bio-Lab scene (containment wing placement)** | TO BUILD | Current in hospital |

---

## 2. Quarantine Breach — Bio-Lab (Research Bay Containment)

### 2.1 Player-Facing Loop Step by Step

1. **Discovery:** The player reaches the Research Bay Containment Corridor entrance where a quarantine board displays three breach indicators in order: **A—Intake Valve, B—Coolant Junction, C—Vent Stack**. Each hatch has a matching large letter and red breach lamp. The player can inspect the route before starting; the game is idle and no breach mutants spawn yet.
2. **Initiation:** The board prompt reads `START CONTAINMENT SEAL — 3 BREACHES — 120s`. The player explicitly taps/interacts. The clock starts and breach A opens first. Mutants begin entering only at the active breach lane and walk toward the marked red line. All unvisited lanes remain physically blocked by closed hatches.
3. **Breach A (Supply Case):** At the supply pallet beside A, attack/interact with the breakable crate to crack it once. It drops **one heavy supply case** (a physics rigid body) and two ammo pickups. The case is the required hatch brace. Ammo is optional and uses the normal pickup system. The crate cannot be reopened to farm items.
4. **Seal A:** Push/strike the case into the marked brace footprint across Hatch A's threshold, then interact with Hatch A to swing it shut. The hatch counts sealed only when it is closed and the case overlaps its brace socket continuously for 0.75 seconds. A hatch shut without a case is only a temporary hold and begins reopening after 4 seconds; a case outside the socket does not seal it.
5. **Breach B (Service Cart):** Once A is sealed, the board advances to B, opens the B breach lane, and sounds its alarm. The player reaches a parked industrial coolant cart near the junction. Push the cart using movement/body contact or capped attack impulse into B's marked threshold socket, then swing Hatch B shut. The cart must remain in the socket for 0.75 seconds with the hatch closed to seal B. The cart can be repositioned by collision; avoid scripting it to snap to the goal.
6. **Breach C (Second Supply Case):** Once B is sealed, C activates. A fresh supply crate at the vent stack provides one second heavy case (and two ammo pickups) only when cracked. Use it to brace Hatch C, then swing the hatch shut.
7. **Victory:** Seal A, then B, then C before 120 seconds. The board locks all three lamps green, the containment corridor shutter opens, and Quarantine Breach reports its objective complete exactly once.

### 2.2 Activation Trigger

- `ContainmentBoard` has a player-only `StartZone`, visible route diagram, and prompt `START CONTAINMENT SEAL`. Attack/interact while the prompt is visible starts the event. Zone entry, a mutant touching a hatch, or opening a crate never starts it.
- **Bio-Lab Gate:** `WorldProgression.can_hop(3)` must be true. If false, prompt reads `BIO-LAB ACCESS REQUIRED` and interaction is ignored.
- At start, reset all three hatches closed, reset both cases and cart to their staging marks, close/uncrack crates, set step to A, set timer to 120 seconds, and enable the activity-owned breach spawner. Do not use ambient random spawn events as step completion.

### 2.3 Win and Fail Conditions

- **Win:** complete A→B→C in that order before 120 seconds; each hatch's own seal test must pass. Reaching a later socket early does not bank it. Win freezes breach progression, closes the active lane, stops only this activity's spawn source, and advances `l3_quarantine_containment` once.
- **Fail:** timer reaches 0; player dies; or 6 mutants are simultaneously inside the corridor `BreachKillZone` beyond the marked interior red line. This gives missed hatches a visible, bounded consequence without treating every approaching mutant as instant failure.
- On fail, stop the activity clock/spawns, keep existing mutants as normal world threats (do not delete/kill them to fake a reset), show `CONTAINMENT LOST — RETREAT AND RESET`, and leave the objective incomplete. Require the player to clear the marked route of hostiles by normal combat before the board prompt returns; then allow an explicit retry. Reset only activity props and route counters at retry, not player health/ammo or world-wide mutant state. This keeps failure consequential while making the restart state deterministic.
- **Loot Tier:** On win, reward tier = `WorldProgression.get_active_loot_tier()` (3 for Bio-Lab).

### 2.4 Physics and Reused Systems

- Reuse `InteractiveDoor.gd` for the three hinged hatches and its explicit `interact()` call, but add a quarantine-specific sealed-state check. The current door script opens/closes by interaction and has no brace/socket semantics. Configure each hatch with `auto_reset` disabled during this activity; the existing 4-second hold-reset behavior is not the gameplay seal rule. A closed hatch plus correctly seated object, not a timer alone, is the seal.
- Reuse `BreakableSupplyCrate.gd` interaction zone and one-shot open pattern, but add `breakable_containment` mode for these two crates: the first attack/interact press opens and permanently marks the crate cracked for the round, drops the configured rigid-body supply case and two standard ammo pickups; it must not also spawn food. Use normal food/ammo pickup scripts where compatible. Existing `BreakableSupplyCrate` currently spawns a case and resets after the player leaves, so turn off auto-reset for the activity crate while active and prevent reopening/farming.
- Reuse the service-cart silhouette/visuals from `InteractiveVehicle` if helpful, but add a true `RigidBody3D` pushable cart configuration (mass 45–65 kg, angular damping, ground friction, capped player shove, no engine/AI). The existing `InteractiveVehicle` is kinematic; do not count its current visual `is_pushed` state as physical movement or seal evidence.
- Supply cases: `RigidBody3D`, approximately 35–45 kg, high enough friction to hold a hatch brace, with a visible handle/stripe and a small socket Area3D query. Use physics impulses for player hits; no teleport-to-socket or automatic snap. A subtle outline/arrow appears only when the case/cart is within 2.5 m of its intended socket.
- Each hatch step has a dedicated lane spawn marker and controller-owned spawn budget. Use `ZombieSpawner3D`'s mutant scenes/pools and death tracking where feasible, but expose a deterministic "spawn this type at this marker" path or have the mini-game controller own a bounded sequence. Spawn one mutant every 7 seconds at the current open lane, maximum 6 active in the corridor; stop generating at win/fail. Avoid calling global `stop_spawning()` if it would silence the level's unrelated ambient spawns—give the activity its own spawner/controller ownership. Existing mutants entering the red line count toward the six-mutant failure threshold.
- Hostile mutants use the existing combat target, damage, and death systems. The player can fight to buy time, but mutant kills do not advance hatch steps or the objective. Hatch and case/cart physics remain meaningful while combat occurs.
- `ObjectiveManager` integration is one `update_progress("l3_quarantine_containment", 1)` after final seal only. A failed/retried run never increments until a win. The level still waits for every registered objective through `all_objectives_completed`.
- **Rules Engine Integration:** Completion increments `Rules.increment_stat("MINIGAMES_WON", 1)` (). The ordered A→B→C gate may be toggled via `Rules.set_parameter_enabled(RequirementTypes.Type.CUSTOM_FLAG_0, ...)` for LiveOps variants.

### 2.5 New Files and Scenes to Create (Bio-Lab Variants)

- `scripts/gameplay/QuarantineContainmentController.gd` — idle/active/won/failed state, 120-second clock, ordered A/B/C gates, per-lane spawn ownership/budget, red-line crowd count, reset/start behavior, one-shot objective report, **WorldProgression.can_hop(3) gate**, **loot tier via get_active_loot_tier()**. (Current `QuarantineBreachController.gd:14-15` uses `l1_quarantine_breach`; new controller uses `l3_quarantine_containment`.)
- `scripts/gameplay/QuarantineContainmentSealHatch.gd` — wraps/extends door state with step id, assigned brace type (`case` or `cart`), socket overlap dwell (0.75 s), order validation, and temporary unbraced reopen after 4 s. (Current `QuarantineSealDoor.gd:17-18` uses `seal_step` + `assigned_brace`; structurally compatible.)
- `scripts/world/interactive/BreakableContainmentSupplyCrate.gd` — activity crate one-time crack and configured case/ammo drops; avoid altering BreakableSupplyCrate defaults for ordinary world crates. (Current `BreakableSupplyCrate.gd:14` uses `supply_case_path`; compatible.)
- `scripts/world/interactive/PushableContainmentCart.gd` — physical cart body, shove cap, staging reset, and socket eligibility. (Current `PushableServiceCart.gd:17` mass 55kg; compatible.)
- `scripts/world/interactive/QuarantineContainmentSupplyCase.gd` — physical case type, reset point, and socket eligibility. (Current `QuarantineSupplyCase.gd:17` mass 40kg; compatible.)
- `scenes/minigames/quarantine_containment.tscn` — board, A/B/C hatches and lane zones, route/spawn markers, three brace sockets, two breakable crates, cart staging mark, red-line crowd zone, activity-owned spawner, controller, and HUD. Instance into `scenes/world/environment/endgame_heights.tscn` (Research Bay / MallDistrict area) along the conduit, preserving free-roam approaches and readable sightlines.
- `scenes/world/props/quarantine_containment_supply_case.tscn`, `scenes/world/props/pushable_containment_cart.tscn`, `scenes/world/props/breakable_containment_supply_crate.tscn` — reusable configured physics props.
- `scenes/ui/quarantine_containment_hud.tscn` — title, countdown, ordered A/B/C checklist, active breach indicator, crowd warning, and retry state.

### 2.6 Mobile Touch Mapping

- Joystick: approach a crate, hatch, cart, case, and socket; push objects by walking into them and steering along the desired line.
- Attack/left-click: use the focused crate/hatch interaction when its prompt is active; otherwise swing at a hostile mutant. Attack the case/cart to add the same capped impulse as Triage if it is within the short shove radius. Interaction focus wins only when the prompt is visibly shown, so nearby enemies remain attackable with a small aim offset.
- SPRINT: cross between active breach lane and supply/brace position quickly. JUMP: clear debris and low cart clutter. SWAP: choose combat weapon; do not make weapon tier change the object's required socket/weight check.
- START and crate/hatch interaction are single attack/interact presses. The board/checklist stays above the touch controls; the active lane letter and timer remain readable without opening a menu.

### 2.7 Fun Hook

This is a physical, three-stop panic puzzle in the middle of a mutant fight: the player hears the next hatch start banging, has to decide whether to spend seconds wrestling a heavy coolant cart or keep the crowd down, and sees an unbraced hatch physically give way when the route order is ignored.

### 2.8 Implementation Status (Code-Grounded)

| Aspect | Status | Evidence |
|--------|--------|----------|
| Controller state machine (IDLE/ACTIVE/WON/FAILED) | IMPLEMENTED (base logic; L3 port TO BUILD) | `QuarantineBreachController.gd:25-26, 116-150` |
| 120s timer + 7s spawn interval | IMPLEMENTED (base logic; L3 port TO BUILD) | `QuarantineBreachController.gd:16-18, 93-96` |
| Ordered A→B→C gate + seal dwell (0.75s) | IMPLEMENTED (base logic; L3 port TO BUILD) | `QuarantineBreachController.gd:152-163`, `QuarantineSealDoor.gd:59-70` |
| Brace types (case/cart) + socket check | IMPLEMENTED (base logic; L3 port TO BUILD) | `QuarantineSealDoor.gd:17-18, 44-55` |
| Red-line crowd fail (6 mutants) | IMPLEMENTED (base logic; L3 port TO BUILD) | `QuarantineBreachController.gd:106-108, 232-247` |
| ObjectiveManager one-shot report | IMPLEMENTED (base logic; L3 port TO BUILD) | `QuarantineBreachController.gd:176-177` |
| Crate one-time crack + case/ammo drops | IMPLEMENTED (base logic; L3 port TO BUILD) | `BreakableSupplyCrate.gd:42-60` |
| Case mass 40kg + cart mass 55kg | IMPLEMENTED (base logic; L3 port TO BUILD) | `QuarantineSupplyCase.gd:17`, `PushableServiceCart.gd:17` |
| **Bio-Lab objective ID (`l3_quarantine_containment`)** | TO BUILD | Current uses `l1_quarantine_breach` (line 14) |
| **WorldProgression.can_hop(3) gate** | TO BUILD | `QuarantineBreachController.gd:62-66` has gate_region but only checks for 2 |
| **Loot tier via get_active_loot_tier()** | TO BUILD | `QuarantineBreachController.gd:192-193` reads it but uses L1/L2 IDs only |
| **Bio-Lab hatch labels (Valve/Junction/Stack)** | TO BUILD | Current uses Intake/Laundry/Loading Bay |
| **Bio-Lab scene (research bay placement)** | TO BUILD | Current in hospital service route |
| **Bio-Lab spawner (Bio-Lab mutant types)** | TO BUILD | Current uses `zombie_dog.tscn` (line 23) |

---

## 3. Armory Lockdown — Bio-Lab (Synthesis Core Access)

### 3.1 Player-Facing Loop Step by Step

1. **Discovery:** The player reaches the Synthesis Core Access Lock in the Cryogenic Vaults antechamber. A heavy blast door blocks the transit tunnel leading to the Synthesis Core. Flanking the door are reinforced containers, cryo-revetments, and a fortified kiosk with a central breach terminal (`SynthesisCoreTerminal`).
2. **Initiation:** Approaching the terminal displays `ACTIVATE SYNTHESIS BREACH`. The player presses ATTACK / INTERACT to activate.
3. **Lockdown & Supply Crack:**
   - Siren blares, amber strobes activate, and the blast door locks down (remains closed).
   - A 90.0-second breach clock starts on the HUD.
   - Two synthesis supply containers (`BreakableSupplyCrate`) sit at marked positions. Attack/interact with each to crack it once per container.
   - **Crate 1** drops: 1 Heavy Supply Case (physics rigid body, ~40 kg) + 2 Ammo Pickups.
   - **Crate 2** drops: 1 Heavy Supply Case + 2 Ammo Pickups.
   - Crates cannot be reopened to farm items.
4. **Door Breach:** The Synthesis Core Door (`InteractiveDoor` with two `RigidBody3D` panels) must be opened. Interact with the door's interaction zone to swing the panels open. The door opens when both panels are rotated clear.
5. **Victory:** Both crates cracked AND the synthesis core door open before 90 seconds. The siren sounds an all-clear, strobes switch to steady green, the blast door slides open permanently, and Synthesis Core Access reports its objective complete exactly once.

### 3.2 Activation Trigger

- **Entity:** `SynthesisCoreTerminal` inside the cryo-revetment bunker.
- **Trigger Volume:** `Area3D` (`InteractionZone`, box size 4×3×4 m).
- **State Guard:**
  - `IDLE`: Screen glows amber, prompt reads `ACTIVATE SYNTHESIS BREACH`.
  - `ACTIVE`: Screen displays `LOCKDOWN ACTIVE` with countdown; trigger disabled.
  - `COMPLETED`: Screen reads `SYNTHESIS CORE OPEN — TRANSIT CLEAR`; permanently disabled.
  - `FAILED`: Screen reads `BREACH TIMED OUT — REARM AND RETRY`; re-enables after 3s reset.
- **Bio-Lab Gate:** `WorldProgression.can_hop(3)` must be true. If false, prompt reads `BIO-LAB ACCESS REQUIRED` and interaction is ignored.
- **Input:** Player enters terminal zone and taps ATTACK / INTERACT.

### 3.3 Win and Fail Conditions

- **Win Condition:**
  - Both supply crates cracked (`is_cracked == true`).
  - Synthesis core door open (`is_open == true` or `is_half_open == true` — panels cleared).
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
- **Loot Tier:** On win, reward tier = `WorldProgression.get_active_loot_tier()` (3 for Bio-Lab).

### 3.4 Mechanics, Physics, and Reused Systems

- **Terminal & Controller:** Reuses `CheckpointArmoryTerminal.gd` (scripts/world/interactive/CheckpointArmoryTerminal.gd:11-57) and `ArmoryLockdownController.gd` (scripts/gameplay/ArmoryLockdownController.gd:47-78). Terminal routes `interact()` → `controller.start_trial()`. Controller owns 90s timer, win/fail logic, and objective reporting.
- **Supply Crates:** Reuses `BreakableSupplyCrate.gd` (scripts/world/interactive/BreakableSupplyCrate.gd:42-60). First interact cracks crate, releases assigned `supply_case_path` case via `release()`, spawns 2 ammo pickups (`food_ammo.tscn`). Sets `is_cracked = true`, disables interaction zone, rotates lid 75°. `reset_crate()` restores state.
- **Synthesis Core Door:** Reuses `InteractiveDoor.gd` (scripts/world/interactive/InteractiveDoor.gd — not shown but referenced in scene). Two `RigidBody3D` panels (PanelA, PanelB) with `DoorInteractionZone`. `interact()` toggles panels open/closed. Win condition checks `door.is_open` or `door.is_half_open`.
- **Supply Cases:** Reuses `QuarantineSupplyCase.gd` (scripts/world/interactive/QuarantineSupplyCase.gd:15-38) — mass 40 kg, linear_damp 4, angular_damp 9, `brace_type = "case"`, `freeze = true` until `release()` called. Cases are the "heavy supply cases" dropped by crates.
- **ObjectiveManager:** `OBJECTIVE_ID = "l3_synthesis_core_access"` (new). Reports via `objective_manager.update_progress(OBJECTIVE_ID, 1)` exactly once on win.
- **Rules Engine:** On win, `Rules.increment_stat("MINIGAMES_WON", 1)`.

### 3.5 Existing Files and Scenes (Already Implemented / Adaptable)

- `scripts/gameplay/ArmoryLockdownController.gd` — controller with 90s timer, crate/door win check, objective report. (Uses `l2_armory_salvage`; needs Bio-Lab variant.)
- `scripts/world/interactive/CheckpointArmoryTerminal.gd` — terminal with state display, prompt, player proximity detection. (Prompt texts are Industrial-themed; needs Bio-Lab texts.)
- `scripts/world/interactive/BreakableSupplyCrate.gd` — one-time crack, case release, ammo drops.
- `scripts/world/interactive/QuarantineSupplyCase.gd` — heavy rigid case (40 kg), freeze/stage/release logic.
- `scenes/minigames/armory_lockdown.tscn` — full scene with Controller, Terminal, ArmoryDoor (2 RigidBody3D panels), Crate1, Crate2, Cases. (Placed in Industrial; needs Bio-Lab instance in `endgame_heights.tscn`.)

### 3.6 Mobile Touch Controls Mapping

- **Left Virtual Joystick:** Navigating between the two crates, the door interaction zone, and defensive positions.
- **Right Screen Drag:** Scanning for incoming threats while monitoring breach timer.
- **ATTACK Button:**
  - In `CrateInteractionZone`: Priority context cracks the supply crate.
  - In `DoorInteractionZone`: Priority context swings door panels open.
  - Otherwise: Fires equipped firearm or executes melee strike against mutants.
- **SPRINT Button:** Vital for moving between crate positions and door quickly under time pressure.
- **JUMP Button:** Vaulting over cryo-revetments to create distance.
- **SWAP Button:** Quick-swapping weapons for combat efficiency.

### 3.7 Fun Hook

Tactical breach under a ticking clock: the player cracks two heavy containers, wrestles 40 kg supply cases into position (or ignores them — they're just loot), and punches the blast door open as the 90-second siren wails, with mutants converging on the synthesis core access.

### 3.8 Implementation Status (Code-Grounded)

| Aspect | Status | Evidence |
|--------|--------|----------|
| Controller 90s timer + win/fail | IMPLEMENTED (base logic; L3 port TO BUILD) | `ArmoryLockdownController.gd:11, 56-69` |
| Crate crack → case + ammo drops | IMPLEMENTED (base logic; L3 port TO BUILD) | `BreakableSupplyCrate.gd:42-60`, `ArmoryLockdownController.gd:62-64` |
| Door open check (is_open/half_open) | IMPLEMENTED (base logic; L3 port TO BUILD) | `ArmoryLockdownController.gd:64` |
| Terminal state machine (IDLE/ACTIVE/COMPLETED/FAILED) | IMPLEMENTED (base logic; L3 port TO BUILD) | `CheckpointArmoryTerminal.gd:9, 27-57` |
| ObjectiveManager report (l2_armory_salvage) | IMPLEMENTED (base logic; L3 port TO BUILD) | `ArmoryLockdownController.gd:9-10, 76-77` |
| Terminal ↔ Controller wiring | IMPLEMENTED (base logic; L3 port TO BUILD) | `CheckpointArmoryTerminal.gd:24-25`, `ArmoryLockdownController.gd:52-53` |
| **Bio-Lab objective ID (`l3_synthesis_core_access`)** | TO BUILD | Current uses `l2_armory_salvage` (line 9) |
| **WorldProgression.can_hop(3) gate on terminal** | TO BUILD | Not present in `CheckpointArmoryTerminal.gd:21-25` |
| **Loot tier via get_active_loot_tier() on win** | TO BUILD | Not present in `ArmoryLockdownController.gd:71-78` |
| **Rules.increment_stat("MINIGAMES_WON") on win** | TO BUILD | Not present |
| **FAILED prompt text per spec** | PARTIAL | Current shows `TRIAL FAILED — REARM AND RETRY` (line 57) vs spec `BREACH TIMED OUT — REARM AND RETRY` |
| **3s failure reset + crate/door reset** | IMPLEMENTED (base logic; L3 port TO BUILD) | `ArmoryLockdownController.gd:85-91` |
| **Bio-Lab scene placement (cryo vaults antechamber)** | TO BUILD | Scene exists at `scenes/minigames/armory_lockdown.tscn` but in Industrial |

---

## 4. What This Is NOT Going to Do (Explicit Anti-Slop Non-Goals)

To prevent scope creep, design bloat, and sloppy implementations, the following non-goals are strictly enforced:

1. **No Automatic Triggering:** Walking into any mini-game area will NEVER auto-start an activity. All activities require an explicit, player-initiated interaction press while facing an in-world console or board.
2. **No Vacuum Auto-Shoving in Triage:** Triage Roundup Bio-Lab will NOT allow the player to sprint across the hall and shove all 4 pods simultaneously. Each pod requires proximity targeting and conscious interaction, ensuring visual discrimination remains the primary skill.
3. **No Infinite Brace Farming:** Quarantine Breach Bio-Lab will NOT allow re-cracking crates or respawning cases/carts upon leaving and returning. Braces per breach are strictly finite.
4. **No Map-Wide Kiting:** Quarantine Breach Bio-Lab will NOT permit the player to lure breach mutants across the entire Bio-Lab map. Leaving the marked corridor route for the activity's fail conditions to apply.
5. **No Invisible Swapping of Brace Physics:** Quarantine Breach Bio-Lab will NOT snap cases/carts to sockets automatically. Physics impulses and player positioning remain the only way to seat a brace.
6. **No Interruption of Free-Roam Exploration:** An unactivated mini-game is completely passive. The Bio-Lab world remains open and fully explorable without invisible walls blocking paths before activities are triggered.
7. **No God Controllers:** Each mini-game is isolated into its own modular controller script and scene. No single script manages multiple mini-games; each interfaces with the game only through `ObjectiveManager`, `WorldProgression`, `Rules`, and `Player.gd`.
8. **No Click Targets < 44×44 px:** All mobile buttons, interaction prompts, and UI tap zones adhere strictly to mobile usability standards (minimum 44×44 px touch area, minimum 14sp text).
9. **No Fourth Minigame:** The MASTER_GDD defines three Bio-Lab minigames matching the three controller families found. This spec documents exactly these three — no inventions.
10. **No Level 1/2 Asset Reuse Without Bio-Lab Reskin:** The Bio-Lab variants must use Bio-Lab-themed visuals (cryo-pods, containment hatches, synthesis supply crates) — not the Level 1 hospital or Level 2 industrial assets. The controllers are reused; the scenes and visuals are new.

---

## 5. File/Line Anchors for Implementers

| Feature | File | Line(s) |
|---------|------|---------|
| TriageRoundupController (L1 base) | `scripts/gameplay/TriageRoundupController.gd` | 12 (OBJECTIVE_ID), 94 (start_run), 115 (delivery), 136 (report), 145-146 (loot tier read) |
| TriageWardPen (L1 base) | `scripts/gameplay/TriageWardPen.gd` | 21 (required_animal_type), 46 (process_capture) |
| TriageAnimalBody (L1 base) | `scripts/gameplay/TriageAnimalBody.gd` | 29 (animal_type), 80 (apply_shove) |
| QuarantineBreachController (L1/L2 base) | `scripts/gameplay/QuarantineBreachController.gd` | 14 (OBJECTIVE_ID), 124 (interact), 152 (door_sealed), 176 (report), 192-193 (loot tier read), 62-66 (gate_region check) |
| QuarantineSealDoor (L1/L2 base) | `scripts/gameplay/QuarantineSealDoor.gd` | 17 (seal_step), 18 (assigned_brace), 59 (seal_tick) |
| BreakableSupplyCrate (L1/L2 base) | `scripts/world/interactive/BreakableSupplyCrate.gd` | 42 (interact), 52 (release case) |
| QuarantineSupplyCase (L1/L2 base) | `scripts/world/interactive/QuarantineSupplyCase.gd` | 17 (mass), 36 (release) |
| PushableServiceCart (L1/L2 base) | `scripts/world/interactive/PushableServiceCart.gd` | 17 (mass) |
| ArmoryLockdownController (L2 base) | `scripts/gameplay/ArmoryLockdownController.gd` | 9 (OBJECTIVE_ID), 47 (start_trial), 56 (process), 71 (win) |
| CheckpointArmoryTerminal (L2 base) | `scripts/world/interactive/CheckpointArmoryTerminal.gd` | 21 (interact), 27 (set_trial_state), 49 (prompt texts) |
| EndgameExtractionController (L3 existing) | `scripts/gameplay/EndgameExtractionController.gd` | 9 (OBJECTIVE_ID), 44 (start_trial), 67 (win) |
| WorldProgression.can_hop | `scripts/core/WorldProgression.gd` | 189-194 |
| WorldProgression.get_active_loot_tier | `scripts/core/WorldProgression.gd` | 278-282 |
| WorldProgression.is_secret_reachable | `scripts/core/WorldProgression.gd` | 248-257 |
| Regions catalog (Bio-Lab def) | `resources/world/regions.tres` | 25-35 (id=3, loot_tier=3, prerequisite_region=2) |
| Secret links (Industrial→Bio-Lab) | `resources/world/secret_links.tres` | 18-22 (from=2, to=3, requires_repair=true) |
| Rules.increment_stat | `scripts/core/rules/RulesEngine.gd` | (via Autoload `Rules`) |
| Level 3 minigame IDs | `scripts/core/Game.gd` | 441-442 (_get_minigame_ids_for_level returns ["l3_rooftop_extraction"]) |
| Cure synthesis playtest | `tools/tests/cure_endgame_playtest.gd` | 26-122 (AchievementManager majority + boss defeat → synthesize_cure → post_cure) |

## Addendum (post-review engineering gaps confirmed 2026-11-19)

- Base controllers READ `get_active_loot_tier()` into `last_loot_tier` but never PASS the tier to loot-drop logic — the L2 acceptance verified the read, not a tiered drop. Closing this is implementation work for the L3 lanes (spec: pass-through on win path + probe assertion that the drop carries the tier).
- TriageRoundupController lacks the interact-time `can_hop` guard that QuarantineBreachController has; L3 triage adds it, and the L2 scenes inherit the fix.
