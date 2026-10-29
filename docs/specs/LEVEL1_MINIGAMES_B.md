# Level 1 Mini-Games B — Build Specification

**Scope:** Two activatable, diegetic mini-games for Level 1 (Old Town): **Triage Roundup** in the animal hospital and **Quarantine Breach** on the hospital service route. Both are required Level 1 objectives. This document defines gameplay, scene ownership, inputs, completion, and failure behavior; it does not implement them.

## Shared implementation contract

- Add both objective records during Level 1 setup, before the player can start either activity:
  - `l1_triage_roundup`, title `Return escaped animals`, target `1`.
  - `l1_quarantine_breach`, title `Seal the service route`, target `1`.
- A mini-game controller owns its own state and timer. It calls `ObjectiveManager.update_progress(id, 1)` exactly once, only after a win. A failure never advances progress. Keep the level’s existing `all_objectives_completed` listener as the sole level-complete/next-level gate; do not make either activity directly unlock the exit.
- Both activities are idle until an explicit player action at a visible start marker. Show a diegetic prompt and a thumb-sized `START` interaction (minimum 44×44 px); never start from entering an Area3D alone. The start trigger is disabled while active and after a win. Failure returns the activity to a ready-to-retry state after its reset, without adding progress.
- Use a shared activity HUD panel: title, short objective, countdown, and clear success/failure state. Keep body text at least 14sp and action text at least 16sp. Place it above the bottom action row so joystick, camera drag, and buttons do not overlap.
- Add an `Area3D` start zone and route the player’s existing `attack` action / mobile attack button to its prompt. Desktop left-click is `attack`. In this context only, the prompt consumes the attack press and does not swing a weapon. Player movement, camera, stamina, health, combat, and death remain owned by `Player.gd` and existing systems.
- **Mobile controls:** left thumb joystick moves; right-side camera drag aims/orients; existing `SPRINT`, `JUMP`, and `SWAP` buttons retain their current functions; existing attack button activates a nearby highlighted start/prop and performs combat when no interaction prompt is eligible. SPRINT is useful for repositioning, JUMP for crossing clutter, and SWAP for choosing a weapon. Do not add a second simultaneous attack/interact button. Update the mobile callback path to share the same interaction resolver as `InputMap` action `attack`; current mobile callbacks call `_perform_attack()` directly and bypass prop interaction. Preserve ordinary combat if no prompt is in range.
- Existing scripts to reuse where applicable:
  - `scripts/core/Player.gd`: locomotion, health/death, combat, attack action, mobile control signals, and prop interaction discovery. Keep activity input routing small and dispatch to the nearby prompt/controller.
  - `scripts/gameplay/ObjectiveManager.gd`: `add_objective`, `update_progress`, `all_objectives_completed`; add objectives before play and increment only on win.
  - `scripts/characters/ZombieSpawner3D.gd`: use bounded spawning for outside pressure in Quarantine. Do not let its ambient random spawns create activity targets or unpredictably satisfy/fail a mini-game. During the activity, set/restore its state through explicit `start_spawning()` / `stop_spawning()` ownership or a dedicated activity spawn point and bounded controller-owned spawn calls.
  - `scripts/world/interactive/InteractiveDoor.gd`, `FoodCrate.gd`, `InteractiveVehicle.gd`: reuse their interaction/state conventions, meshes, audio hooks, and child layouts where suitable. `InteractiveVehicle` is explicitly kinematic and the current `FoodCrate` opens to spawn food; neither currently supplies the required physics cart or breakable supply behavior by itself. The builders must add the activity-specific behavior described below rather than assume those existing mechanics already exist.

---

## 1. Triage Roundup

### Player-facing loop

1. The player finds the lit triage board in the animal hospital lobby. Four clearly marked empty ward pens sit around the central treatment hall; an animal silhouette and matching painted stripe identify each pen: **dog (red), cat (blue), rabbit (yellow), chicken (green)**. A bloodied sign reads `RETURN EACH PATIENT TO ITS WARD`.
2. Entering the marked start zone reveals `START TRIAGE — 4 PATIENTS — HALL OVERRUN IN 90s`. The player taps/interacts to begin. The game places four contained, non-attacking zombie animals in marked release stalls at the far end of the hall, one of each type, and starts the 90-second overrun clock.
3. Move into an animal’s side/rear and attack/flick it with the bat or bare-hand attack. A valid shove applies a forward impulse away from the player to the animal’s physics body. The player can also body-bump it while moving; the shove is directional, so a front-on strike can push it toward the wrong ward. Do not allow normal weapon damage to kill these objective animals.
4. Guide each animal down the hall to its matching pen. The pen’s floor marking and low entry gate make the target readable from the third-person camera. A wrong-type animal entering a pen is bounced gently back out and the HUD flashes the required color/name. Animals that escape the treatment-hall bounds are repositioned at their original release stall with their velocity cleared; this costs 8 seconds from the shared clock and does not count as a delivery.
5. Correct delivery requires the animal’s body to remain inside its matching pen for 1.25 seconds. The gate closes, its ward lamp turns on, and the HUD changes that animal’s row to complete. The animal is then frozen/parked inside the pen so later collisions cannot undo credit.
6. Deliver all four animals before the clock reaches zero. The board stamps `ALL PATIENTS ACCOUNTED FOR`; the mini-game wins and the triage objective advances once.

### Activation trigger

- `TriageStartBoard` has a player-only `StartZone`. While the activity is idle and the objective is incomplete, the in-world prompt `START TRIAGE` appears within 3.5 m and after zone overlap. Only an attack/interact press while that prompt is visible starts it. Walking through the zone never starts it.
- On activation, lock the four release-stall doors open, place/reset the four animals, set the timer to 90 seconds, and show the compact activity HUD. No animals or countdown exist before activation.

### Win and fail conditions

- **Win:** each of four unique animal instances is stably inside its own matching pen for 1.25 seconds before time expires. Set win state before emitting progress so a duplicate signal cannot increment twice.
- **Fail:** timer reaches 0 before all four deliveries; player dies; or a hostile zombie enters the treatment hall and reaches the `HallOverrunZone` for 2 seconds. The hall-overrun rule is an activity-local Area3D condition, not a global automatic failure on any zombie hit.
- On fail, stop the local timer, clear animal velocities, return animals to release stalls, reopen all pen gates, clear temporary delivery state, show `TRIAGE OVERRUN — TRY AGAIN`, and leave `l1_triage_roundup` incomplete. Allow retry at the board after 3 seconds. Do not heal or resurrect the player; normal death/respawn owns that flow. If death caused failure, reset the activity on player respawn and require another explicit start.

### Physics and reused systems

- Animal bodies must be `RigidBody3D` or have a dedicated rigid-body root and collision shapes; set a stable mass in the 18–30 kg range, linear damping around 2, angular damping high enough to prevent uncontrolled rolling, and lock rotation except yaw/limited tipping. Set a capped shove impulse so a single hit moves an animal about 1–2 m on the hospital floor without launching it. Use collision layers/masks that collide with floor, pens, player, and other animals.
- Use existing zombie animal art/scenes (`scenes/characters/zombie_dog.tscn`, `zombie_cat.tscn`, `zombie_rabbit.tscn`, `zombie_chicken.tscn`) as visual/animation sources where compatible. Their combat AI and `ZombieBase` health/death behavior must be disabled or bypassed for these objective props; they are frightened patients, not enemies to kill. Do not obtain them from ambient `ZombieSpawner3D` pools because pool activation/AI/death behavior conflicts with persistent delivery tracking.
- Reuse `Player.gd` movement and attack pose/feedback, but add a triage-target hit route: when the attack ray/area identifies a live roundup animal during the activity, apply the capped impulse and suppress damage. Keep enemy attack and health behavior unchanged outside this activity.
- Reuse `ObjectiveManager` exactly through the shared contract. `ZombieSpawner3D` remains an external threat source; the local overrun zone is the only hostile intrusion fail check.

### New files/scenes to create

- `scripts/gameplay/TriageRoundupController.gd` — idle/active/won/failed state, four-instance/type registry, clock, reset, unique delivery validation, and one-shot objective report.
- `scripts/gameplay/TriageAnimalBody.gd` — patient type, shove response, return-to-stall bounds handling, pen capture lock, and emitted delivery candidate signal. No combat AI.
- `scripts/gameplay/TriageWardPen.gd` — exported `required_animal_type`, overlap detection, 1.25-second stable dwell timer, wrong-type bounce, matching lamp/gate feedback.
- `scenes/minigames/triage_roundup.tscn` — board/start zone, four release stalls, hall bounds, four pen instances, overrun zone, animal spawn markers, controller, HUD anchor. Instance this inside `scenes/world/environment/hospital_enhanced.tscn` without replacing the hospital environment.
- `scenes/minigames/triage_animal_body.tscn` — reusable rigid body with animal visual, collision capsule/shape, ground contact, and type assigned by controller.
- `scenes/ui/triage_roundup_hud.tscn` — title, 90s countdown, four named/type-colored rows, and transient wrong-pen/reset/fail feedback.

### Mobile touch mapping

- Joystick: steer the player around to get behind/alongside the patient; do not steer the animal directly with UI.
- Attack/left-click: shove the highlighted nearby animal; the nearest valid animal hit is selected by the existing attack target query. Without a valid activity target, it remains ordinary combat.
- SPRINT: reposition before the patient drifts into another animal or wall. JUMP: clear dropped clutter/low obstacles only. SWAP: change weapon; both bat and bare-hand shove use the same capped impulse, so weapon choice cannot trivialize the physics.
- START prompt: use the same attack/interact press when standing by the board. Keep it inside the lower-right thumb area; no multi-touch hold sequence is required.

### Fun hook

The player is batting four twitchy, recognizable zombie pets through an actual hospital corridor, and every hit has a readable direction: lining up a clean side shove into the color-coded ward feels like a rescue shot, while a bad angle sends a rabbit pinballing across the hall as the overrun clock bites.

---

## 2. Quarantine Breach

### Player-facing loop

1. The player reaches the ambulance/service entrance where a quarantine board displays three breach indicators in order: **A—Intake, B—Laundry, C—Loading Bay**. Each door has a matching large letter and red breach lamp. The player can inspect the route before starting; the game is idle and no breach zombies spawn yet.
2. The board prompt reads `START SEALDOWN — 3 BREACHES — 120s`. The player explicitly taps/interacts. The clock starts and breach A opens first. Zombies begin entering only at the active breach lane and walk toward the marked red line. All unvisited lanes remain physically blocked by closed doors.
3. At the supply pallet beside A, attack/interact with the breakable crate to crack it once. It drops **one heavy supply case** (a physics rigid body) and two ammo pickups. The case is the required door brace. Ammo is optional and uses the normal pickup system. The crate cannot be reopened to farm items.
4. Push/strike the case into the marked brace footprint across Door A’s threshold, then interact with Door A to swing it shut. The door counts sealed only when it is closed and the case overlaps its brace socket continuously for 0.75 seconds. A door shut without a case is only a temporary hold and begins reopening after 4 seconds; a case outside the socket does not seal it.
5. Once A is sealed, the board advances to B, opens the B breach lane, and sounds its alarm. The player reaches a parked hospital laundry cart near the junction. Push the cart using movement/body contact or capped attack impulse into B’s marked threshold socket, then swing Door B shut. The cart must remain in the socket for 0.75 seconds with the door closed to seal B. The cart can be repositioned by collision; avoid scripting it to snap to the goal.
6. Once B is sealed, C activates. A fresh supply crate at the loading bay provides one second heavy case (and two ammo pickups) only when cracked. Use it to brace Door C, then swing the door shut. The active breach lane advances zombie pressure through the spawner controller; any earlier unsealed route stays open and keeps leaking zombies, so skipping a step compounds the defense instead of pausing it.
7. Seal A, then B, then C before 120 seconds. The board locks all three lamps green, the service-route shutter opens, and Quarantine Breach reports its objective complete exactly once.

### Activation trigger

- `QuarantineBoard` has a player-only `StartZone`, visible route diagram, and prompt `START SEALDOWN`. Attack/interact while the prompt is visible starts the event. Zone entry, a zombie touching a door, or opening a crate never starts it.
- At start, reset all three doors closed, reset both cases and cart to their staging marks, close/uncrack crates, set step to A, set timer to 120 seconds, and enable the activity-owned breach spawner. Do not use ambient random spawn events as step completion.

### Win and fail conditions

- **Win:** complete A→B→C in that order before 120 seconds; each door’s own seal test must pass. Reaching a later socket early does not bank it. Win freezes breach progression, closes the active lane, stops only this activity’s spawn source, and advances `l1_quarantine_breach` once.
- **Fail:** timer reaches 0; player dies; or 6 zombies are simultaneously inside the service-route `BreachKillZone` beyond the marked interior red line. This gives missed doors a visible, bounded consequence without treating every approaching zombie as instant failure.
- On fail, stop the activity clock/spawns, keep existing zombies as normal world threats (do not delete/kill them to fake a reset), show `ROUTE LOST — RETREAT AND RESET`, and leave the objective incomplete. Require the player to clear the marked route of hostiles by normal combat before the board prompt returns; then allow an explicit retry. Reset only activity props and route counters at retry, not player health/ammo or world-wide zombie state. This keeps failure consequential while making the restart state deterministic.

### Physics and reused systems

- Reuse `InteractiveDoor.gd` for the three hinged doors and its explicit `interact()` call, but add a quarantine-specific sealed-state check. The current door script opens/closes by interaction and has no brace/socket semantics. Configure each door with `auto_reset` disabled during this activity; the existing 4-second hold-reset behavior is not the gameplay seal rule. A closed door plus correctly seated object, not a timer alone, is the seal.
- Reuse `FoodCrate.gd` interaction zone and one-shot open pattern, but add `breakable_supply` mode for these two crates: the first attack/interact press opens and permanently marks the crate cracked for the round, drops the configured rigid-body supply case and two standard ammo pickups; it must not also spawn food. Use normal food/ammo pickup scripts where compatible. Existing `FoodCrate` currently spawns food and resets after the player leaves, so turn off auto-reset for the activity crate while active and prevent reopening/farming.
- Reuse the service-cart silhouette/visuals from `InteractiveVehicle` if helpful, but add a true `RigidBody3D` pushable cart configuration (mass 45–65 kg, angular damping, ground friction, capped player shove, no engine/AI). The existing `InteractiveVehicle` is kinematic; do not count its current visual `is_pushed` state as physical movement or seal evidence.
- Supply cases: `RigidBody3D`, approximately 35–45 kg, high enough friction to hold a door brace, with a visible handle/stripe and a small socket Area3D query. Use physics impulses for player hits; no teleport-to-socket or automatic snap. A subtle outline/arrow appears only when the case/cart is within 2.5 m of its intended socket.
- Each door step has a dedicated lane spawn marker and controller-owned spawn budget. Use `ZombieSpawner3D`’s zombie scenes/pools and death tracking where feasible, but expose a deterministic “spawn this type at this marker” path or have the mini-game controller own a bounded sequence. Spawn one zombie every 7 seconds at the current open lane, maximum 6 active in the service route; stop generating at win/fail. Avoid calling global `stop_spawning()` if it would silence the level’s unrelated ambient spawns—give the activity its own spawner/controller ownership. Existing zombies entering the red line count toward the six-zombie failure threshold.
- Hostile zombies use the existing combat target, damage, and death systems. The player can fight to buy time, but zombie kills do not advance door steps or the objective. Door and case/cart physics remain meaningful while combat occurs.
- `ObjectiveManager` integration is one `update_progress("l1_quarantine_breach", 1)` after final seal only. A failed/retried run never increments until a win. The level still waits for every registered objective through `all_objectives_completed`.

### New files/scenes to create

- `scripts/gameplay/QuarantineBreachController.gd` — idle/active/won/failed state, 120-second clock, ordered A/B/C gates, per-lane spawn ownership/budget, red-line crowd count, reset/start behavior, and one-shot objective report.
- `scripts/gameplay/QuarantineSealDoor.gd` — wraps/extends door state with step id, assigned brace type (`case` or `cart`), socket overlap dwell (0.75 s), order validation, and temporary unbraced reopen after 4 s.
- `scripts/world/interactive/BreakableSupplyCrate.gd` — activity crate one-time crack and configured case/ammo drops; avoid altering FoodCrate defaults for ordinary world crates.
- `scripts/world/interactive/PushableServiceCart.gd` — physical cart body, shove cap, staging reset, and socket eligibility.
- `scripts/world/interactive/QuarantineSupplyCase.gd` — physical case type, reset point, and socket eligibility.
- `scenes/minigames/quarantine_breach.tscn` — board, A/B/C doors and lane zones, route/spawn markers, three brace sockets, two breakable crates, cart staging mark, red-line crowd zone, activity-owned spawner, controller, and HUD. Instance into `scenes/world/environment/hospital_enhanced.tscn` along the service route, preserving free-roam approaches and readable sightlines.
- `scenes/world/props/quarantine_supply_case.tscn`, `scenes/world/props/pushable_laundry_cart.tscn`, and `scenes/world/props/breakable_supply_crate.tscn` — reusable configured physics props.
- `scenes/ui/quarantine_breach_hud.tscn` — title, countdown, ordered A/B/C checklist, active breach indicator, crowd warning, and retry state.

### Mobile touch mapping

- Joystick: approach a crate, door, cart, case, and socket; push objects by walking into them and steering along the desired line.
- Attack/left-click: use the focused crate/door interaction when its prompt is active; otherwise swing at a hostile zombie. Attack the case/cart to add the same capped impulse as Triage if it is within the short shove radius. Interaction focus wins only when the prompt is visibly shown, so nearby enemies remain attackable with a small aim offset.
- SPRINT: cross between active breach lane and supply/brace position quickly. JUMP: clear debris and low cart clutter. SWAP: choose combat weapon; do not make weapon tier change the object’s required socket/weight check.
- START and crate/door interaction are single attack/interact presses. The board/checklist stays above the touch controls; the active lane letter and timer remain readable without opening a menu.

### Fun hook

This is a physical, three-stop panic puzzle in the middle of a zombie fight: the player hears the next door start banging, has to decide whether to spend seconds wrestling a heavy cart or keep the crowd down, and sees an unbraced door physically give way when the route order is ignored.
