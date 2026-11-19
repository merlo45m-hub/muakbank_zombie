# Level 3 Mini-Games B — Build Specification (Bio-Lab)

**Scope:** Shared Bio-Lab region hooks that govern all three Level 3 mini-games (Triage Roundup Bio-Lab, Quarantine Breach Bio-Lab, Armory Lockdown Bio-Lab) via `WorldProgression.can_hop`, secret-links reachability, and loot tier via `WorldProgression.get_active_loot_tier`. Plus acceptance criteria summary and cross-cutting integration points. This document defines contracts and verification; it does not implement them.

**Ground-truth sources:** `docs/MASTER_GDD.md` (World 3 row: containment wings, research bays, cryogenic vaults, synthesis core; loot bio-polymers/mutagen samples/cryo-cores/cure catalysts; connections: sub-level freight conduit from Industrial, emergency decontamination chute to Suburban & Industrial).gd:27-35,189-194,248-257,278-282`, `scripts/core/LevelManager.gd:11,20,34,41`, `scripts/core/Game.gd:239-250,429-444`, `scripts/gameplay/TriageRoundupController.gd:12-26,94-134,145-146`, `scripts/gameplay/QuarantineBreachController.gd:14-25,124-132,192-193`, `scripts/gameplay/ArmoryLockdownController.gd:9-11,47-78`, `scripts/world/interactive/CheckpointArmoryTerminal.gd:21-57`, `scripts/gameplay/EndgameExtractionController.gd:9-11,44-74`, `resources/world/regions.tres:25-35`, `resources/world/secret_links.tres:18-22,23-32`, `tools/tests/cure_endgame_playtest.gd:26-122`.

---

## Shared Bio-Lab Region Hooks Contract

These hooks apply to ALL Level 3 mini-games (Triage Roundup Bio-Lab, Quarantine Breach Bio-Lab, Armory Lockdown Bio-Lab) and are defined here once to avoid duplication.

### 5.1 WorldProgression.can_hop Gate

- Every Level 3 mini-game start trigger **must** check `WorldProgression.can_hop(3)` before allowing activation.
- If `false`, the prompt displays `BIO-LAB ACCESS REQUIRED` and the interaction is ignored.
- This gate is evaluated at interaction time, not at scene load, so a player who gains Bio-Lab access via secret transport (`WorldHopManager` hop) can immediately activate the mini-games without a scene reload.
- **Controller anchor:** Each controller's `interact()` / `start_run()` / `start_trial()` entry point adds:
  ```gdscript
  var wp := get_node_or_null("/root/WorldProgression")
  if wp and not wp.can_hop(3):
      # Show "BIO-LAB ACCESS REQUIRED" on prompt, return early
      return
  ```
- The existing `TriageRoundupController.gd:47-51` and `QuarantineBreachController.gd:62-66` already implement a `gate_region` export check at `_ready()` and in `interact()`. The Bio-Lab variants must set `gate_region = 3` and keep both checks (early queue_free at ready and interaction-time guard).

### 5.2 Loot Tier via WorldProgression.get_active_loot_tier()

- On mini-game **win only**, the reward loot tier = `WorldProgression.get_active_loot_tier()`.
- For Bio-Lab (Region 3), this returns `3` (per `RegionDef.loot_tier` in `regions.tres:25-35`).
- If the player jumped ahead via secret transport before unlocking Region 3 linearly, `get_active_loot_tier()` still returns the tier of `current_region` (which will be 3 after `hop_completed`).
- **Controller anchor:** Each controller's `_win_run()` / `_win_trial()` adds:
  ```gdscript
  var wp := get_node_or_null("/root/WorldProgression")
  var reward_tier: int = wp.get_active_loot_tier() if wp else 1
  # Pass reward_tier to loot drop / reward system
  ```
- The existing `TriageRoundupController.gd:145-146` and `QuarantineBreachController.gd:192-193` already read `get_active_loot_tier()` into `last_loot_tier` on win. The Bio-Lab variants must ensure this value is passed to the loot/reward drop logic (currently not implemented in the base controllers).

### 5.3 Secret-Links Reachability (Non-Linear Access)

- `WorldProgression.is_secret_reachable(2, 3)` returns `true` when the Industrial→Bio-Lab sub-level freight conduit is repaired (`transport_done[2] == true`).
- This enables `can_hop(3)` to return `true` even if Region 3 is not in `unlocked_regions` (GDD §3: "Early hopping ahead for higher-tier gear is intended, not a bug").
- The secret transport repair is reported by `TransportHub` in the Industrial hazmat rail (`TechPickup` feeds tech, `TransportHub` reports repair).
- **Return chutes (always traversable once Region 3 unlocked):**
  - `is_secret_reachable(3, 1)` — Emergency decontamination chute to Suburban (no repair required, `secret_links.tres:28-32`).
  - `is_secret_reachable(3, 2)` — Return conduit to Industrial (no repair required, `secret_links.tres:23-26`).
- **No mini-game code change needed** — the gate in 5.1 automatically respects secret reachability via `can_hop()`.

### 5.4 Rules Engine Integration (RULES_ENGINE.md)

- All Level 3 mini-game completions increment `Rules.increment_stat("MINIGAMES_WON", 1)` (Parameter ).
- Bio-Lab-specific LiveOps toggles may gate mini-game availability via `Rules.set_category_enabled(RequirementTypes.CAT_GAMEPLAY, ...)` or individual parameter toggles (IDs 150–157).
- `ACHIEVEMENT_TIER` () unlocks may require Bio-Lab mini-game completions as prerequisites.
- Cure synthesis gating: `CURE_SYNTHESIZED` (ID 100) and `POST_CURE_MODE` (ID 101) are set by `AchievementManager.synthesize_cure()` after majority achievements + all three boss defeats (`tools/tests/cure_endgame_playtest.gd:78-90`). Post-cure mini-game variants (if any) would check these flags.

---

## 6. Acceptance Criteria Summary (Per Minigame)

### 6.1 Triage Roundup — Bio-Lab (`l3_triage_cryo_recovery`)

| Criterion | Status | Notes |
|-----------|--------|-------|
| Controller inherits Level 1 logic with Bio-Lab IDs/types | TO BUILD | New controller script needed (`TriageCryoRecoveryController.gd`) |
| `WorldProgression.can_hop(3)` gate on start | TO BUILD | Set `gate_region = 3`; add check to `interact()` and `_ready()` |
| `get_active_loot_tier()` reward on win | TO BUILD | Pass `last_loot_tier` to loot drop system |
| 4 Cryo pod types (alpha/beta/gamma/delta) | TO BUILD | New `TriageCryoPod.gd` + scene |
| 4 Cryo bays with matching visuals | TO BUILD | New `TriageCryoBay.gd` + scene |
| Scene placed in `endgame_heights.tscn` (containment wing) | TO BUILD | New `.tscn` instanced in SewerDistrict or MallDistrict |
| Rules stat increment on win | TO BUILD | Add `Rules.increment_stat("MINIGAMES_WON", 1)` |
| Mobile HUD layout (14sp/16sp, 44×44px) | TO BUILD | New HUD scene |

### 6.2 Quarantine Breach — Bio-Lab (`l3_quarantine_containment`)

| Criterion | Status | Notes |
|-----------|--------|-------|
| Controller inherits Level 1/2 logic with Bio-Lab IDs | TO BUILD | New controller script needed (`QuarantineContainmentController.gd`) |
| `WorldProgression.can_hop(3)` gate on start | TO BUILD | Set `gate_region = 3`; add check to `interact()` and `_ready()` |
| `get_active_loot_tier()` reward on win | TO BUILD | Pass `last_loot_tier` to loot drop system |
| 3 Bio-Lab hatches (Valve/Junction/Stack) | TO BUILD | New hatch scene + `QuarantineContainmentSealHatch.gd` |
| Bio-Lab brace props (case/cart reskins) | TO BUILD | New prop scenes |
| Scene placed in `endgame_heights.tscn` (research bay corridor) | TO BUILD | New `.tscn` instanced in MallDistrict area |
| Bio-Lab mutant spawn types | TO BUILD | Replace `zombie_dog.tscn` with Bio-Lab variants (spitter, bear, runner per `LevelManager.gd:41`) |
| Rules stat increment on win | TO BUILD | Add `Rules.increment_stat("MINIGAMES_WON", 1)` |

### 6.3 Armory Lockdown — Bio-Lab (`l3_synthesis_core_access`)

| Criterion | Status | Notes |
|-----------|--------|-------|
| Core gameplay (timer, crates, door, win/fail) | IMPLEMENTED (base logic; L3 port TO BUILD) | Fully functional in `ArmoryLockdownController.gd` |
| `WorldProgression.can_hop(3)` gate | TO BUILD | Add to `CheckpointArmoryTerminal.interact()` |
| `get_active_loot_tier()` reward on win | TO BUILD | Add to `ArmoryLockdownController._win_trial()` |
| Rules stat increment on win | TO BUILD | Add `Rules.increment_stat("MINIGAMES_WON", 1)` |
| FAILED prompt text: `BREACH TIMED OUT` | PARTIAL | Change line 57 in `CheckpointArmoryTerminal.gd` from `TRIAL FAILED` |
| 3s failure reset + crate/door reset | IMPLEMENTED (base logic; L3 port TO BUILD) | `ArmoryLockdownController.gd:85-91` |
| Bio-Lab scene placement (cryo vaults antechamber) | TO BUILD | Instance `armory_lockdown.tscn` variant in `endgame_heights.tscn` (RooftopDistrict or MallDistrict) |
| Bio-Lab terminal prompt texts | TO BUILD | Update `CheckpointArmoryTerminal._refresh_prompt()` for Bio-Lab theming |
| Bio-Lab objective ID (`l3_synthesis_core_access`) | TO BUILD | Change `OBJECTIVE_ID` in controller |

---

## 7. Cross-Cutting Integration Points

### 7.1 Objective Registration (Level 3 Setup)

During Level 3 initialization (`Game._setup_objectives()` or level loader), before any activity can be activated:

```gdscript
objective_manager.add_objective("l3_triage_cryo_recovery", "Recover cryo-pods from containment", 1)
objective_manager.add_objective("l3_quarantine_containment", "Seal the research breach", 1)
objective_manager.add_objective("l3_synthesis_core_access", "Breach synthesis core lock", 1)
```

Current `Game.gd:239-260` registers objectives per level. Level 3 currently only registers `l3_rooftop_extraction` (line 442). The three new IDs must be added for level 3.

### 7.2 WorldProgression Signal Listeners

- `WorldProgression.region_unlocked(3, 3)` — Bio-Lab unlocked → ensure all three mini-games' start triggers are enabled (they gate on `can_hop(3)` which now returns true).
- `WorldProgression.transport_repaired(2)` — Industrial→Bio-Lab sub-level freight conduit repaired → `can_hop(3)` becomes true via `is_secret_reachable(2, 3)` → mini-games immediately accessible to players who jumped ahead.
- `WorldProgression.hop_completed(3)` — Player hopped to Bio-Lab → `current_region = 3` → `get_active_loot_tier()` returns 3 for subsequent mini-game wins.
- `WorldProgression.hop_completed(1)` / `hop_completed(2)` — Player returns via emergency decontamination chute or return conduit → `current_region` updates → `get_active_loot_tier()` returns appropriate tier for that world.

### 7.3 Save Persistence

- All three mini-game completion states persist via `ObjectiveManager` (which feeds into `SaveManager`).
- `WorldProgression` serialization already includes `world_unlocked_regions`, `world_visited_regions`, `world_transport_repaired` — no additional save keys needed for the hooks.
- `region_state` dictionary (WorldProgression.gd:30) can store per-region mini-game completion flags if needed for post-cure state.

### 7.4 Cure Synthesis / Post-Cure Interaction

- Per `MASTER_GDD.md §6` and `tools/tests/cure_endgame_playtest.gd`: Cure synthesis requires all three world bosses defeated AND majority achievement threshold (>50%).
- `AchievementManager.synthesize_cure()` sets `CURE_SYNTHESIZED` (ID 100) and `POST_CURE_MODE` (ID 101) flags.
- Post-cure, the game continues seamlessly with full world access. The three Bio-Lab mini-games remain playable (or replayable) in post-cure mode.
- If LiveOps desires post-cure variants (e.g., "containment breach" events), they would gate via `Rules.get_parameter_enabled(RequirementTypes.Type.POST_CURE_MODE)`.

---

## 8. What This Is NOT Going to Do (Explicit Anti-Slop Non-Goals)

1. **No Automatic Triggering:** Walking into any mini-game area will NEVER auto-start an activity. All activities require an explicit, player-initiated interaction press while facing an in-world terminal or board.
2. **No Vacuum Auto-Shoving in Triage:** Triage Roundup Bio-Lab will NOT allow the player to sprint across the hall and shove all 4 pods simultaneously.
3. **No Infinite Brace Farming:** Quarantine Breach Bio-Lab will NOT allow re-cracking crates or respawning cases/carts upon leaving and returning.
4. **No Map-Wide Kiting:** Quarantine Breach Bio-Lab will NOT permit the player to lure breach mutants across the entire Bio-Lab map.
5. **No Invisible Swapping of Brace Physics:** Quarantine Breach Bio-Lab will NOT snap cases/carts to sockets automatically.
6. **No Interruption of Free-Roam Exploration:** An unactivated mini-game is completely passive. The Bio-Lab world remains open and fully explorable without invisible walls blocking paths before activities are triggered.
7. **No God Controllers:** Each mini-game is isolated into its own modular controller script and scene. No single script manages multiple mini-games; each interfaces with the game only through `ObjectiveManager`, `WorldProgression`, `Rules`, and `Player.gd`.
8. **No Click Targets < 44×44 px:** All mobile buttons, interaction prompts, and UI tap zones adhere strictly to mobile usability standards (minimum 44×44 px touch area, minimum 14sp text).
9. **No Fourth Minigame:** The MASTER_GDD defines three Bio-Lab minigames matching the three controller families found. This spec documents exactly these three — no inventions.
10. **No Level 1/2 Asset Reuse Without Bio-Lab Reskin:** The Bio-Lab variants must use Bio-Lab-themed visuals (cryo-pods, containment hatches, synthesis supply crates) — not the Level 1 hospital or Level 2 industrial assets. The controllers are reused; the scenes and visuals are new.
11. **No Fourth Game Family:** The GDD's Bio-Lab themes (containment wings, research bays, cryogenic vaults, synthesis core) map exactly to the three existing controller families (Triage, Quarantine, Armory). No new mechanic family is introduced.

---

## 9. File/Line Anchors for Implementers

| Feature | File | Line(s) |
|---------|------|---------|
| TriageRoundupController (L1 base) | `scripts/gameplay/TriageRoundupController.gd` | 12 (OBJECTIVE_ID), 26 (gate_region), 47-51 (_ready gate), 94 (start_run), 115 (delivery), 136 (report), 145-146 (loot tier read) |
| TriageWardPen (L1 base) | `scripts/gameplay/TriageWardPen.gd` | 21 (required_animal_type), 46 (process_capture) |
| TriageAnimalBody (L1 base) | `scripts/gameplay/TriageAnimalBody.gd` | 29 (animal_type), 80 (apply_shove) |
| QuarantineBreachController (L1/L2 base) | `scripts/gameplay/QuarantineBreachController.gd` | 14 (OBJECTIVE_ID), 25 (gate_region), 62-66 (interact gate), 124 (interact), 152 (door_sealed), 176 (report), 192-193 (loot tier read) |
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
| Secret links (Bio-Lab→Suburban) | `resources/world/secret_links.tres` | 28-32 (from=3, to=1, requires_repair=false) |
| Secret links (Bio-Lab→Industrial) | `resources/world/secret_links.tres` | 23-26 (from=3, to=2, requires_repair=false) |
| Rules.increment_stat | `scripts/core/rules/RulesEngine.gd` | (via Autoload `Rules`) |
| Level 3 minigame IDs | `scripts/core/Game.gd` | 441-442 (_get_minigame_ids_for_level returns ["l3_rooftop_extraction"]) |
| Cure synthesis playtest | `tools/tests/cure_endgame_playtest.gd` | 26-122 (AchievementManager majority + boss defeat → synthesize_cure → post_cure) |
| Level 3 environment | `scenes/world/environment/endgame_heights.tscn` | 82-100 (districts), 299-300 (EndgameExtraction, EndgameSupplyCacheNetwork) |
| Endgame cache network (supply crates) | `scenes/world/environment/endgame_cache_network.tscn` | 367-870 (18 BreakableSupplyCrate instances) |

---

## 10. OPEN DECISION Items (Creative Lane)

The GDD is silent on several Bio-Lab-specific details. These are explicitly marked as **OPEN DECISION** for the creative owner to resolve:

| Item | Context | Suggested Owner |
|------|---------|-----------------|
| Cryo-pod visual design (alpha/beta/gamma/delta) | Triage Roundup Bio-Lab needs 4 distinct cryo-pod models | Art lead |
| Containment hatch visual design (Valve/Junction/Stack) | Quarantine Breach Bio-Lab needs 3 distinct hatch models | Art lead |
| Bio-Lab mutant types for breach spawns | `LevelManager.gd:41` lists bear/runner/spitter/dog/cat for level 3; which subset for breach lanes? | Game designer |
| Synthesis supply crate visual | Armory Lockdown Bio-Lab uses same `BreakableSupplyCrate` but needs Bio-Lab skin | Art lead |
| Cryo-revetment / synthesis core door visuals | Armory Lockdown Bio-Lab needs Bio-Lab themed door panels | Art lead |
| HUD color palette for Bio-Lab (neon-cyan accent per GDD §1) | All three Bio-Lab HUDs need consistent theming | UI/UX |
| Post-cure mini-game variants (if any) | GDD §6 says post-cure continues seamlessly; no spec for variant activities | LiveOps / Game designer |
| Exact placement coordinates in `endgame_heights.tscn` | Three districts (Sewer/Mall/Rooftop) — which hosts which minigame? | Level designer |
| Loot tables for Bio-Lab tier 3 (bio-polymers, mutagen samples, cryo-cores, cure catalysts) | `MASTER_GDD.md` lists resources but no drop tables | Systems designer |
| Whether EndgameExtractionController (`l3_rooftop_extraction`) is a fourth minigame or the campaign finale | GDD lists 3 Bio-Lab minigames + cure synthesis; `Game.gd:442` only has `l3_rooftop_extraction` | Game director |

---

## 11. TO BUILD / PARTIAL / IMPLEMENTED Classification Summary

### TO BUILD (not started)
- `TriageCryoRecoveryController.gd` (Bio-Lab variant of Triage)
- `TriageCryoPod.gd` + `triage_cryo_pod.tscn`
- `TriageCryoBay.gd` + bay scene
- `triage_cryo_recovery.tscn` + HUD scene
- `QuarantineContainmentController.gd` (Bio-Lab variant of Quarantine)
- `QuarantineContainmentSealHatch.gd`
- `BreakableContainmentSupplyCrate.gd` + scene
- `PushableContainmentCart.gd` + scene
- `QuarantineContainmentSupplyCase.gd` + scene
- `quarantine_containment.tscn` + HUD scene
- `ArmoryLockdownController` Bio-Lab variant (objective ID, gate, loot tier, Rules stat)
- `CheckpointArmoryTerminal` Bio-Lab variant (gate, prompt texts)
- `armory_lockdown` Bio-Lab instance in `endgame_heights.tscn`
- Level 3 objective registration in `Game._setup_objectives()` (3 new IDs)

### PARTIAL (base exists, needs Bio-Lab wiring)
- `TriageRoundupController` base logic — IMPLEMENTED; needs Bio-Lab IDs, gate=3, pod types, bay types, scene, HUD
- `QuarantineBreachController` base logic — IMPLEMENTED; needs Bio-Lab IDs, gate=3, hatch labels, mutant types, scene, HUD
- `ArmoryLockdownController` base logic — IMPLEMENTED; needs Bio-Lab objective ID, gate=3 on terminal, loot tier pass-through, Rules stat, prompt text fix
- `CheckpointArmoryTerminal` base logic — IMPLEMENTED; needs Bio-Lab gate and prompt texts
- `BreakableSupplyCrate` / `QuarantineSupplyCase` / `InteractiveDoor` — IMPLEMENTED; need Bio-Lab visual reskins only

### IMPLEMENTED (done, no Bio-Lab work needed)
- `WorldProgression.can_hop(3)`, `get_active_loot_tier()`, `is_secret_reachable(2,3)`, `is_secret_reachable(3,1)`, `is_secret_reachable(3,2)`
- `regions.tres` Region 3 (Bio-Lab) definition with loot_tier=3
- `secret_links.tres` Industrial→Bio-Lab (requires_repair) + Bio-Lab→Suburban/Industrial (no repair)
- `EndgameExtractionController` (rooftop extraction, `l3_rooftop_extraction`)
- `endgame_heights.tscn` environment with 3 districts
- `endgame_cache_network.tscn` (18 supply crates for potential reuse)
- `LevelManager` level 3 config (environment, difficulty, enemy pool, name "Bio-Lab")
- `Game._get_minigame_ids_for_level(3)` returns `["l3_rooftop_extraction"]`
- Cure synthesis / post-cure flow verified by `cure_endgame_playtest.gd`