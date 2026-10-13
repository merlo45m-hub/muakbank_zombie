# Level 1 Mini-Games A — Build Specification

**Scope:** Three activatable, diegetic mini-games for Level 1 (Old Town): **Spoil & Survive** in the food market plaza, **Keep the Generator Fed** at the central town square substation, and **Last Stand Station** at the police checkpoint armory. Along with Triage Roundup and Quarantine Breach (specified in `LEVEL1_MINIGAMES_B.md`), these complete the five gating objectives for Level 1. This document defines concrete gameplay loops, activation mechanics, failure boundaries, file structures, input schemes, and system reuse; it does not write engine code.

---

## Shared Implementation Contract

1. **Objective Registration:**
   - Register all three objective IDs during Level 1 initialization (`Game._setup_objectives()` or level loader) before any activity can be activated:
     - `l1_spoil_and_survive`: title `"Eat 15 fresh buffet dishes"`, target `1`.
     - `l1_generator_fed`: title `"Defend and power the bio-generator (90s)"`, target `1`.
     - `l1_last_stand`: title `"Survive 3 checkpoint assault waves"`, target `1`.
   - Each activity controller owns its internal counter (e.g. dishes eaten, seconds powered, waves cleared). The controller reports progress to `ObjectiveManager.update_progress(id, 1)` **exactly once upon winning**.
   - A failed or aborted attempt never advances progress. Level completion remains gated exclusively by `ObjectiveManager.all_objectives_completed`.

2. **In-World Activation Triggers:**
   - No mini-game ever starts automatically when the player enters a trigger volume.
   - Each mini-game features an explicit, diegetic activation prop (`BuffetStartPodium`, `GeneratorConsole`, `CheckpointTerminal`).
   - When the player is within interaction range (≤ 3.0 m) and facing the prop, an on-screen prompt displays a clear action label (e.g., `"START BUFFET"`, `"POWER GENERATOR"`, `"BEGIN LAST STAND"`).
   - Pressing the attack/interact button (or tapping the mobile button) consumes the input, engages the activity, and locks out the activation prompt.
   - While an activity is running or after it has been completed, the start trigger remains disabled.

3. **Activity HUD & Mobile Layout:**
   - A dedicated activity HUD overlay appears below the top-center game status bar and above the bottom mobile control zone.
   - Text conforms to anti-slop typography rules: Minimum 14sp for status/counters, minimum 16sp for interactive prompts. No emoji icons; use concise text labels (`COMBO: 3x`, `FUEL: 64%`, `WAVE 2/3`).
   - Screen bounds keep the bottom 250 px clear on both sides to avoid overlapping the left virtual joystick (`MobileControls.gd`) and right button cluster (`SPRINT`, `JUMP`, `SWAP`, `ATTACK`).

4. **Input Dispatch & Combat Coexistence:**
   - Player movement, camera orbit, health, stamina, sprint, and jump remain owned by `Player.gd`.
   - The primary action button routes through `Player._handle_attack()` and `Interactor.try_interact()`. When an interactive prompt (such as a buffet plate or generator hopper) is active and prioritized, the button triggers interaction. Otherwise, it executes normal combat swings or gunfire.
   - Mobile buttons:
     - **Left Joystick:** Locomotion (walk/run).
     - **Right Screen Drag:** Third-person camera orbit and aim vector.
     - **ATTACK:** Contextual interaction when in prompt range; melee attack or firearm discharge when free.
     - **SPRINT:** Repositioning, evading toxic puddles, rushing food between crates and the generator.
     - **JUMP:** Vaulting low street barriers, debris piles, and sandbags.
     - **SWAP:** Cycling weapon inventory between melee and ranged weapons.

---

## 1. Spoil & Survive (Eating / Mukbang Challenge)

### 1.1 Player-Facing Loop Step by Step

1. **Discovery:** The player discovers an abandoned outdoor banquet terrace in the Old Town Market. A long U-shaped banquet table holds 8 empty serving platters under a flickering neon marquee: `"FRESH BITES ONLY — AVOID THE ROT"`.
2. **Initiation:** The player approaches the order podium at the head of the terrace. A prompt appears: `START BUFFET CHALLENGE — EAT 15 FRESH DISHES IN 60s`. The player presses ATTACK / INTERACT to activate the event.
3. **Round Start:** A 60.0-second countdown begins on the activity HUD. All 8 platters simultaneously populate with randomly rolled dishes from the food system. An upbeat arcade eating chime plays.
4. **Visual Discrimination:** The player patrols the table. At any moment, exactly 2 out of the 8 dishes are tainted; the other 6 are fresh.
   - **Fresh Dishes:** Standard vibrant food meshes (golden burgers, steaming noodle bowls, glossy sushi, cheesy pizza). Clean golden glint particles emit from the plate, accompanied by a subtle sizzle/steam audio cue.
   - **Tainted Dishes:** Albedo tint darkened to sickly olive-green (`Color(0.35, 0.52, 0.22)`), covered in faint green mold spore particles (`ToxicFumes`), accompanied by a low buzzing fly loop when within 1.5 m.
5. **Consumption Action:** The player steps up to a platter and presses ATTACK/INTERACT (or steps directly into the platter's eating zone while stationary).
   - **Eating a Fresh Dish:**
     - Consumes the dish with a crisp eating crunch sound (`Audio.play_sfx("eat_crunch")`).
     - Restores +10 HP to the player (standard mukbang reward).
     - Increments the streak counter by +1 (`COMBO: 1x → 2x → 3x → 4x → 5x MAX`).
     - Adds +1 to the objective counter (`FRESH DISHES: X / 15`).
     - At 5x combo, triggers a 2.5-second `Mukbang Rush` (player movement speed increased by 15% to help sprint to distant platters).
     - The emptied platter goes on a 0.6-second cooldown, then automatically spawns a fresh replenishment dish.
   - **Eating a Tainted Dish (The Spoil Penalty):**
     - Consumes the dish, triggering a harsh gag/cough sound (`Audio.play_sfx("food_gag")`).
     - Player takes 18 instant poison damage (`Player.take_damage(18)`).
     - Full combo streak instantly resets to `0x`.
     - Deducts 5.0 penalty seconds from the 60.0-second clock.
     - Screen flashes a sickly green peripheral vignette for 0.8 seconds.
     - Player suffers a 0.6-second stagger (locomotion velocity clamped to 40%).
6. **Victory / Round End:** The player reaches 15 fresh dishes eaten before time expires. The activity freezes the clock, displays `BUFFET CONQUERED!`, plays a fanfare chime, and updates `l1_spoil_and_survive`. Remaining food platters clear cleanly.

### 1.2 Activation Trigger

- **Entity:** `BuffetStartPodium` (placed at table entrance, `Vector3(-14.2, 0.0, 18.5)`).
- **Trigger Volume:** An `Area3D` child node (`InteractionZone`, cylinder radius 2.2 m, height 2.0 m).
- **State Guard:**
  - `IDLE`: Displays 3D floating label `"START BUFFET"`.
  - `ACTIVE`: Prompt hidden, interaction zone disabled.
  - `COMPLETED`: Board reads `"COMPLETED — CERTIFIED CLEAN"`, permanently inert.
- **Input:** Tapping the mobile `ATTACK` button while standing inside the zone starts the 60.0s challenge. Walking into the zone without pressing input does nothing.

### 1.3 Win and Fail Conditions

- **Win Condition:**
  - Consume 15 clean dishes before the 60.0-second countdown reaches zero.
  - Player must be alive at the moment the 15th dish is ingested.
- **Fail Conditions:**
  - Countdown timer reaches 0.0s before 15 clean dishes are eaten.
  - Player health reaches 0 (death from poison damage or wandering zombie attack).
- **Post-Failure State & Reset:**
  - On failure, HUD displays `SPOILED RUN — BUFFET RESETTING (3s)`.
  - All active food items on the table despawn immediately.
  - The controller enters a 3.0-second cooldown, then returns `BuffetStartPodium` to `IDLE`.
  - Progress resets to 0/15 dishes. The player may re-trigger the podium immediately with full timer restored.
  - Player health and inventory are NOT restored; mistakes carry real survival attrition.

### 1.4 Mechanics, Physics, and Reused Systems

- **Food Scene Reuse:**
  - Reuses existing food scenes preloaded in `scripts/gameplay/FoodSpawner.gd`:
    - `res://scenes/world/food_burger.tscn`
    - `res://scenes/world/food_pizza.tscn`
    - `res://scenes/world/food_noodles.tscn` (or fries)
    - `res://scenes/world/food_sushi.tscn`
    - `res://scenes/world/food_takis.tscn`
    - `res://scenes/world/food_soda.tscn`
- **Food System Extension:**
  - Reuses `FoodItem3D.gd` mesh hierarchy and bobbing logic, but replaces normal walkover pickup with an explicit `is_tainted: bool` property and material override.
  - Tainted material override: Modulates instance `StandardMaterial3D.albedo_color` with `Color(0.35, 0.52, 0.22)` and sets `roughness = 0.85`, distinct from clean items.
- **Platter Management:**
  - Platter slots are fixed `Node3D` markers (`BuffetPlatterSlot.gd`). Each manages its own item spawn, despawn, and 0.6s replenishment timer.
  - Spawning ensures strict fairness: Exactly 2 out of 8 platters are tainted at any moment. When a tainted dish is eaten, the replacement dish is guaranteed to be clean; when a clean dish is eaten, the replacement has a calculated roll (25% chance) only if fewer than 2 platters are currently tainted.
- **Player & Combat Integration:**
  - Calls `Player.heal(10)` on good bites.
  - Calls `Player.take_damage(18)` on bad bites.
  - Does NOT alter standard zombie behavior; wandering zombies in Old Town can still wander onto the terrace, forcing the player to fight or weave around them while eating.

### 1.5 New Files and Scenes to Create

- `scripts/gameplay/SpoilAndSurviveController.gd`: Master round state machine (`IDLE`, `ACTIVE`, `WON`, `FAILED`), 60.0s clock, combo multiplier, objective dispatch, and dish allocation manager.
- `scripts/world/interactive/BuffetPlatterSlot.gd`: Platter slot controller handling local dish instantiation, interaction query, plate glow particles, and cooldown tween.
- `scripts/gameplay/BuffetFoodItem.gd`: Specialization of `FoodItem3D` with `is_tainted` flag, eat interaction routing, particle anchors, and combo score hooks.
- `scenes/minigames/spoil_and_survive.tscn`: Root mini-game scene containing table colliders, podium, 8 platter slots, audio players, and controller node.
- `scenes/world/props/buffet_table.tscn`: 3D environment prop with wooden picnic/terrace banquet tables arranged in a U-formation.
- `scenes/ui/spoil_and_survive_hud.tscn`: Minimalist HUD overlay with 60s countdown bar, `DISHES: X/15` tally, combo multiplier popup, and poison vignette.

### 1.6 ObjectiveManager Reporting and Progression Gating

- During level start: `objective_manager.add_objective("l1_spoil_and_survive", "Eat 15 fresh buffet dishes", 1)`
- Upon 15th successful clean bite:
  ```gdscript
  if dishes_eaten >= TARGET_DISHES and not is_won:
      is_won = true
      _stop_activity()
      objective_manager.update_progress("l1_spoil_and_survive", 1)
  ```
- Progression gating: Only advances by 1 on victory. Level exit remains locked until `ObjectiveManager.all_objectives_completed` fires.

### 1.7 Mobile Touch Controls Mapping

- **Left Virtual Joystick:** Continuous movement along the U-table corridor to position the character in front of the next desired platter.
- **Right Screen Drag:** Orbit camera to quickly read which platters on the opposite table wing have clean golden glints vs green mold smoke.
- **ATTACK Button:**
  - When within 1.2 m of a platter: Interactor prioritizes platter interaction (`EAT`).
  - When away from platters: Normal weapon swing / pistol shot to fend off intruding zombies.
- **SPRINT Button:** Essential during `Mukbang Rush` to dash between far table ends before the 60s timer runs down.
- **JUMP Button:** Allows leaping over corner table benches to cut seconds off rotation paths.
- **SWAP Button:** Retains standard weapon switching; having a bat equipped vs fists does not affect eating speed.

### 1.8 The Fun Hook

High-speed visual reflex meets mukbang gluttony: The player locks into an intense arcade rhythm of *glance-identify-dash-chomp*, stacking combo multipliers and listening to rapid crunch sound effects, until a split-second misread makes them chomp a green mold burger, breaking the combo with a violent cough and shaving 5 seconds off the clock with only 3 dishes to go.

---

## 2. Keep the Generator Fed (Resource Tension / Safe-Zone Defense)

### 2.1 Player-Facing Loop Step by Step

1. **Discovery:** The player discovers the Old Town Central Substation in the middle of a sunken brick plaza. Four tall industrial stadium floodlights stand dark around an electrified wire perimeter fence. At the center sits a rumbling, soot-stained industrial generator (`BioGenerator3D`) with a large hopper chute labeled: `"AUXILIARY BIO-FUEL ONLY — FOOD & BIOMASS"`.
2. **Initiation:** The player walks up to the generator control panel. An interactive terminal displays: `ENGAGE AUXILIARY GRID — REQUIRES 90s DEFENSE`. The player presses ATTACK / INTERACT to start.
3. **Power Up & Safe Zone Activation:**
   - The generator roars to life. An overhead analog fuel gauge snaps to **40% Fuel**.
   - A 90.0-second grid synchronization clock starts ticking down on the HUD.
   - The 4 floodlights blast brilliant illumination over a 14-meter radius around the generator.
   - The electrified UV perimeter fence hums with blue arcing electricity. Any zombie attempting to cross the perimeter takes 30 shock damage per second and suffers a 50% movement slow.
   - The player regenerates stamina at double speed while standing inside the lighted perimeter.
4. **The Constant Fuel Drain:**
   - The generator continuously consumes fuel at **2.2% per second**. Without intervention, 40% fuel lasts only 18 seconds.
   - As fuel drops below 25%, the generator sputters, warning sirens wail, and lights flicker yellow.
   - At 0% fuel, the safe zone experiences a **Total Blackout**:
     - Floodlights cut out completely.
     - UV fence deactivates, leaving the generator exposed.
     - A 12.0-second Emergency Reserve countdown begins. If fuel is not restored before 12 seconds elapse, the generator turbine seizes permanently.
5. **The Resource Dilemma (Feed vs Eat):**
   - The player must feed food items into the generator hopper to sustain power.
   - In Muakbank Zombie, food in inventory (`Player._inventory`) is the player's sole method of restoring HP.
   - Standing in the `HopperZone` (yellow-striped floor square, 2.0 m × 2.0 m) displays a prompt: `FEED HOPPER [ATTACK / TAP FEED]`.
   - Pressing the button deposits one food item from inventory into the chute, converting calories to fuel:
     - **Burger:** +22% fuel
     - **Pizza:** +28% fuel
     - **Fries / Takis / Sushi:** +18% fuel
     - **Soda / Coffee:** +12% fuel
     - **Medkit / Battery:** +35% fuel
   - *The Core Tension:* The player is taking claw damage from perimeter breach zombies and bleeding at 25 HP. Do they consume the pizza to save their own life, or dump the pizza into the chute to stop the floodlights from dying and letting 8 fast runners flood the safe zone?
6. **Scavenge and Defense:**
   - Three dedicated supply crates (`FoodCrate.gd`) sit around the plaza perimeter. Players can sprint out of the safe zone into the dark, crack open a crate, loot 2 food items, and sprint back before the generator dies.
   - Dedicated runner waves spawn from outer alleyways, attempting to attack the player and bash the generator (generator has 400 structural HP).
7. **Victory:** The player maintains fuel > 0% and generator HP > 0 for the entire 90 seconds. The grid locks on permanently: the floodlights flash green, a massive UV pulse vaporizes all zombies in the 14m radius, and the controller reports completion to `ObjectiveManager`.

### 2.2 Activation Trigger

- **Entity:** `GeneratorConsole` mounted to the side of `BioGenerator3D`.
- **Trigger Volume:** `Area3D` (`ConsoleInteractionZone`, box size 1.8 m × 1.8 m × 2.0 m).
- **State Guard:**
  - `IDLE`: Displays prompt `START AUXILIARY GENERATOR`.
  - `ACTIVE`: Console displays digital countdown and fuel bar; interaction disabled.
  - `COMPLETED`: Status light permanently green; prompt reads `GRID ONLINE`.
- **Input:** Player enters console zone and presses ATTACK/INTERACT.

### 2.3 Win and Fail Conditions

- **Win Condition:**
  - Complete 90.0 seconds of generator operation without structural destruction or prolonged blackout.
  - Generator must have > 0% fuel and > 0 structure HP at T = 0.0s.
- **Fail Conditions:**
  - Fuel remains at 0% for 12.0 consecutive seconds (emergency reserve timer runs out).
  - Generator structural health drops to 0 (destroyed by zombies).
  - Player dies (`Player.is_dead == true`).
- **Post-Failure State & Reset:**
  - Generator emits a loud backfire, belches black smoke, and powers down.
  - HUD displays `GENERATOR LOST — REBOOT AVAILABLE IN 5s`.
  - Remaining wave zombies continue attacking as normal world enemies.
  - After a 5.0-second delay and upon clearing the immediate perimeter, the console resets to `IDLE`.
  - Crates around the plaza reset their loot tables to allow a fresh attempt.

### 2.4 Mechanics, Physics, and Reused Systems

- **Food Inventory Integration:**
  - Directly inspects and modifies `Player._inventory` via existing API:
    - Checks `player.has_food(food_type)` or finds highest-calorie item in inventory.
    - Calls `player.consume_food_type(food_type)` without applying health gain to the player, routing the item's caloric value into generator fuel instead.
- **Physics Props & Crates:**
  - Reuses `scripts/world/interactive/FoodCrate.gd` for the 3 plaza supply crates. Each crate is placed at an alleyway mouth 15–20 m outside the safe zone to force risk/reward scavenging runs.
- **Perimeter & Hazard Zones:**
  - UV perimeter fence uses an `Area3D` with collision mask monitoring `layer 3` (zombies). Overlapping zombies receive `zombie.take_damage(30 * delta)` and have their movement speed scaled down while fuel is active.
- **Zombie Waves:**
  - Mini-game controller owns an isolated `BioGeneratorWaveSpawner` (does not rely on ambient spawner pools):
    - 0–30s: 6 Walkers approaching along south stairs.
    - 30–60s: 6 Walkers + 4 Runners attacking from east alleyway.
    - 60–90s: 8 Walkers + 4 Runners + 1 Heavy Butcher targeting the generator.
  - Hostile zombies target the generator if the player is outside, or target the player if inside the zone.

### 2.5 New Files and Scenes to Create

- `scripts/gameplay/BioGeneratorController.gd`: Manages 90s clock, fuel drain (2.2%/s), blackout reserve timer (12s), structural HP, UV fence state, and objective reporting.
- `scripts/world/interactive/BioGeneratorHopper.gd`: Hopper drop zone script handling player proximity, inventory food query, deposit button prompt, and fuel injection logic.
- `scripts/world/interactive/UVPerimeterFence.gd`: Electric fence volume managing particle sparks, shock damage ticks, and slow status on zombies.
- `scenes/minigames/keep_generator_fed.tscn`: Root scene containing generator model, hopper zone, 4 floodlight nodes, UV fence collision, audio loops, and controller.
- `scenes/world/props/bio_generator.tscn`: 3D diesel generator model with animated exhaust fan, vibrating engine block, and analog fuel gauge needle.
- `scenes/ui/generator_fed_hud.tscn`: UI overlay with 90s timer, large segmented fuel gauge (Green → Yellow → Flashing Red), and blackout warning banner.

### 2.6 ObjectiveManager Reporting and Progression Gating

- Registration during level setup: `objective_manager.add_objective("l1_generator_fed", "Power the Safe Zone Generator (90s)", 1)`
- Completion dispatch:
  ```gdscript
  func _on_timer_completed() -> void:
      if generator_hp > 0 and fuel > 0.0 and not is_won:
          is_won = true
          _trigger_victory_pulse()
          objective_manager.update_progress("l1_generator_fed", 1)
  ```
- Failure leaves `l1_generator_fed` incomplete.

### 2.7 Mobile Touch Controls Mapping

- **Left Virtual Joystick:** Navigating between the hopper drop zone, the defensive perimeter, and outer supply crates.
- **Right Screen Drag:** Scanning dark alleyways for incoming runners while monitoring generator fuel status.
- **ATTACK Button:**
  - In `HopperZone`: Priority context feeds food from inventory into the generator.
  - Outside `HopperZone`: Fires equipped firearm or executes melee strike against zombies breaching the fence.
- **SPRINT Button:** Vital for survival. Scavenging food from outer crates requires sprinting into the dark and sprinting back before the 12s blackout timer finishes.
- **JUMP Button:** Hopping over sandbag barricades around the generator station to bypass chokepoints.
- **SWAP Button:** Quick-swapping from shotgun/pistol to bat/axe when conserving ammo during low-pressure moments.

### 2.8 The Fun Hook

Desperate economic triage under pressure: Standing in a flickering circle of light with 18 HP, bleeding out while hearing runners screeching in the dark, and having to manually sacrifice the hot pizza in your bag into the roaring furnace to keep the lights on for another 12 seconds.

---

## 3. Last Stand Station (Combat Skill Gate / Armory Defense)

### 3.1 Player-Facing Loop Step by Step

1. **Discovery:** The player reaches the Police Precinct Armory Checkpoint at the edge of Old Town. A heavy reinforced steel security gate blocks the transit tunnel leading to the next level sector. Flanking the gate are concrete barriers, sandbags, and a fortified kiosk with a central defense terminal (`CheckpointTerminal`).
2. **Initiation:** Approaching the terminal displays: `ENGAGE COMBAT PROFICIENCY TRIAL — 3 ASSAULT WAVES`. The player presses ATTACK / INTERACT to activate.
3. **Lockdown & Initial Supply:**
   - Siren blares, red security strobes activate, and rear steel security bollards rise from the asphalt, sealing the player inside a 12 m × 10 m fortified courtyard (`LastStandPerimeter`).
   - A 10.0-second preparation countdown displays on the HUD.
   - Two armory wall lockers slide open with pneumatic hisses, revealing starting munitions:
     - 20 Pistol rounds (`food_ammo.tscn` set to pistol)
     - 10 Shotgun shells (`food_ammo.tscn` set to shotgun)
     - 1 Medkit (+50 HP)
   - (If the player does not currently possess a firearm, the locker also provides a standard service Pistol and pump Shotgun).
4. **Wave 1 — The Swarm (Target Prioritization & Accuracy):**
   - 10 Walkers and 4 Crawlers spawn from the outer street barricades.
   - Crawlers move fast and low, testing aim pitch and melee spacing; Walkers advance in a staggered line.
   - HUD displays: `WAVE 1/3 — HOSTILES REMAINING: 14`.
   - Ammo is strictly limited; players must aim carefully and avoid wasting shotgun shells on isolated low-HP crawlers.
5. **Intermission 1 (12.0s Resupply):**
   - Wave 1 defeated. Siren changes to an amber advisory tone.
   - A 12-second intermission timer begins.
   - An overhead armory crane lowers a sealed military drop crate into the courtyard center.
   - Player opens the crate (1 tap) to receive: 14 Pistol rounds, 6 Shotgun shells, 1 Soda (+15 HP / stamina boost).
6. **Wave 2 — The Rush (Mobility, Sprint & Evasion):**
   - 8 Fast Runners and 2 Acid Spitters spawn.
   - Spitters hang back near barricades lobbing toxic bile; Runners vault over sandbags straight toward the player.
   - Tests mobile agility: Player must use `SPRINT` to dodge bile pools and `SWAP` to shotgun to burst down incoming runners before they initiate grapple attacks.
7. **Intermission 2 (12.0s Final Resupply):**
   - Final supply drop delivers: 16 Pistol rounds, 8 Shotgun shells, 1 Medkit (+50 HP).
8. **Wave 3 — The Heavy Breach (DPS Check & Weapon Cycling):**
   - 1 Armored Butcher Boss (high HP, cleaver melee, frontal damage reduction) accompanied by 6 Walkers and 4 Runners.
   - Tests weapon cycling: Emptying shotgun into the Butcher's vulnerable back, swapping to pistol to clear flankers, and switching to baseball bat / fists when ammunition runs dry to finish off the remaining wounded infected.
9. **Victory:** With all Wave 3 hostiles eliminated, the siren sounds an all-clear double chime, perimeter strobes switch to steady green, the massive steel armory transit gate slides open, and `l1_last_stand` reports complete.

### 3.2 Activation Trigger

- **Entity:** `CheckpointTerminal` inside the sandbag bunker.
- **Trigger Volume:** `Area3D` (`TerminalZone`, box size 1.6 m × 1.6 m × 2.0 m).
- **State Guard:**
  - `IDLE`: Screen glows amber, prompt reads `ACTIVATE LAST STAND TRIAL`.
  - `ACTIVE`: Screen displays active wave, enemy count, and lockdown status; trigger disabled.
  - `COMPLETED`: Screen reads `GATE CLEARED — TRANSIT OPEN`; permanently disabled.
- **Input:** Player enters terminal zone and taps ATTACK / INTERACT.

### 3.3 Win and Fail Conditions

- **Win Condition:**
  - Eliminate all enemies across all 3 waves.
  - Player remains alive and inside the designated station perimeter throughout the engagement.
- **Fail Conditions:**
  - Player dies (`Player.is_dead == true`).
  - **Desertion Penalty (Anti-Cheese):** If the player jumps the barricade and remains outside the `LastStandPerimeter` for more than 6.0 consecutive seconds, the terminal triggers an emergency abort: klaxon sounds, auto-turrets lock the zone, and the trial is marked failed. This prevents players from kiting waves across the open city.
- **Post-Failure State & Reset:**
  - On fail, security bollards lower, active trial enemies are purged, and HUD displays `TRIAL FAILED — REARM AND RETRY`.
  - Terminal resets to `IDLE` after an 8.0-second delay.
  - Lockers lock shut until the trial is restarted, ensuring players cannot hoard infinite ammo drops across failed attempts.

### 3.4 Mechanics, Physics, and Reused Systems

- **Combat & Weapon System:**
  - Reuses `scripts/gameplay/WeaponSystem.gd` directly:
    - `equip_weapon()`, `switch_to_next_weapon()`, `add_ammo()`, `current_ammo`, `can_fire()`.
    - Leverages weapon stats: Pistol range (15m, 20 dmg) vs Shotgun spread (0.15, 60 dmg).
  - Reuses `scripts/core/Player.gd` health, stamina, sprint speed, and damage routing.
- **Pickups & Resupply Drops:**
  - Drops use `scenes/world/food_ammo.tscn` and `scenes/world/food_medkit.tscn` configured with explicit ammo quantities via `WeaponPickup.gd`.
  - Drops are spawned at fixed marker coordinates (`LockerSpawnPoint_1`, `LockerSpawnPoint_2`, `CraneDropPoint`) to guarantee readable pickup locations on mobile screens.
- **Wave Sequencing:**
  - Controller manages an internal 3-phase wave state machine. Does not connect to the global level `WaveManager` to prevent desynchronizing overall level pacing.
  - Zombies are instantiated from standard character scenes (`zombie_basic.tscn`, `zombie_runner.tscn`, `zombie_spitter.tscn`, `zombie_butcher.tscn`) and assigned target priority to the player.
- **Perimeter Boundaries:**
  - The courtyard is bounded by an `Area3D` (`PerimeterBoundaryZone`).
  - `body_exited` signals track player presence. A 6.0s countdown timer starts when the player leaves; returning cancels the timer.

### 3.5 New Files and Scenes to Create

- `scripts/gameplay/LastStandStationController.gd`: 3-wave progression controller, enemy tally, intermission timers (12s), desertion watchdog (6s), ammo drop orchestration, and objective reporting.
- `scripts/world/interactive/CheckpointArmoryTerminal.gd`: Interactive station kiosk handling player trigger, UI status screen, and gate animation dispatch.
- `scripts/world/interactive/SupplyDropCrate.gd`: One-touch interactive supply crate dropped between waves that pops open with sound and spawns ammo/health pickups.
- `scenes/minigames/last_stand_station.tscn`: Root scene containing sandbag models, gate colliders, terminal, locker nodes, drop markers, and boundary volumes.
- `scenes/world/props/checkpoint_barricade.tscn`: Modular barricade prop with concrete jersey barriers, sandbags, and military floodlights.
- `scenes/ui/last_stand_hud.tscn`: UI overlay displaying current wave (`WAVE 1/3`), hostiles remaining, desertion warning banner, and intermission countdown.

### 3.6 ObjectiveManager Reporting and Progression Gating

- Registration during level start: `objective_manager.add_objective("l1_last_stand", "Survive 3 checkpoint assault waves", 1)`
- Completion dispatch:
  ```gdscript
  func _on_wave_3_cleared() -> void:
      if not is_won:
          is_won = true
          _open_transit_gate()
          objective_manager.update_progress("l1_last_stand", 1)
  ```
- Progression gating: Advances progress by 1 only upon final wave clearance. Unlocks Level 1 completion when all 5 objectives are fulfilled.

### 3.7 Mobile Touch Controls Mapping

- **Left Virtual Joystick:** Tactical strafing around sandbag cover, backpedaling away from rushing runner zombies, and circling the Butcher.
- **Right Screen Drag:** High-precision aiming for headshots and tracking low-crawling zombies.
- **ATTACK Button:** Primary firearm trigger. Tapping fires pistol or shotgun. In intermission, opens the supply drop crate.
- **SPRINT Button:** Essential for sprinting away when Runners close into melee distance or to dodge acid vomit projectiles.
- **JUMP Button:** Vaulting over sandbag barriers to create distance when cornered by the Butcher.
- **SWAP Button:** Critical gameplay action: Instantly cycling between shotgun (bursting runners) and pistol (picking off walkers), or falling back to baseball bat when ammo is exhausted.

### 3.8 The Fun Hook

Strict tactical survival under tight ammunition constraints: The adrenaline rush of holding a claustrophobic sandbag bunker, watching your shotgun shell counter dwindle from 4 to 2 to 0 as a screeching pack vaults the barricade, forcing a frantic last-second switch to a baseball bat to crack the final runner's skull.

---

## 4. What This Is NOT Going to Do (Explicit Anti-Slop Non-Goals)

To prevent scope creep, design bloat, and sloppy implementations, the following non-goals are strictly enforced:

1. **No Automatic Triggering:**
   - Walking into any mini-game area will NEVER auto-start an activity. All activities require an explicit, player-initiated interaction press while facing an in-world console or podium.
2. **No Vacuum Auto-Eating in the Buffet:**
   - Spoil & Survive will NOT allow the player to sprint across the table and vacuum all 8 dishes simultaneously. Each dish requires proximity targeting and conscious interaction, ensuring visual discrimination remains the primary skill.
3. **No Infinite Ammo or Resupply Farming:**
   - Last Stand Station will NOT spawn infinite ammo lockers or respawn crates upon leaving and returning. Munitions per wave are strictly finite.
4. **No Map-Wide Kiting:**
   - Last Stand Station will NOT permit the player to lure wave zombies across the entire Old Town map. Leaving the marked 12m × 10m courtyard for > 6 seconds terminates the event.
5. **No Invisible Swapping of Food Healing:**
   - Keep the Generator Fed will NOT consume food without player awareness. Feeding the generator is an explicit, deliberate player action at the hopper chute. Food in inventory remains the player's personal healing supply until willingly deposited.
6. **No Interruption of Free-Roam Exploration:**
   - An unactivated mini-game is completely passive. The Old Town remains open and fully explorable without invisible walls blocking paths before activities are triggered.
7. **No God Controllers:**
   - Each mini-game is isolated into its own modular controller script and scene. No single script manages multiple mini-games; each interfaces with the game only through `ObjectiveManager` and `Player.gd`.
8. **No Click Targets < 44×44 px:**
   - All mobile buttons, interaction prompts, and UI tap zones adhere strictly to mobile usability standards (minimum 44×44 px touch area, minimum 14sp text).
