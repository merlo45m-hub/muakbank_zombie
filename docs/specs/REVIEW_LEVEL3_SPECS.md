# Adversarial evidence review of the LEVEL3 specs (codex lane, read-only, 2026-11-19)

The spec files as committed already incorporate this review's ranked defects 1-5 (row requalification, fabricated Rules IDs removed, TRC interact-guard note, fourth-family contradiction resolution, invalid breakdown citation removed). Verdict table retained as evidence.

# Hermes Adversarial Spec Review — Level-3 Bio-Lab Minigames

**Repo:** `/data/data/com.termux/files/home/mb-l2b` (branch `docs/level3-biolab-specs`)
**Files under review:** `docs/specs/LEVEL3_MINIGAMES_A.md` (319 lines), `docs/specs/LEVEL3_MINIGAMES_B.md` (237 lines)
**Lens:** evidence integrity — try to break every claim, do not praise. Read-only.
**Canonical:** `docs/MASTER_GDD.md` (World 3 row) wins on conflicts.

## Executive verdict

The specs are **well-structured and closely mirror the LEVEL2 format contract**, and most low-level file:line anchors check out against the code. However, the review found **multiple CONFIRMED defects**: fabricated Rules parameter IDs, mis-classified "IMPLEMENTED" rows that are actually Level-1/Level-2 base logic (the exact L2-arc failure mode), a missing interaction-time can_hop guard in TriageRoundupController, an invalid ground-truth citation (`development-breakdown.md` has no Bio-Lab sections), and an internal contradiction between "No Fourth Minigame" and the existing `l3_rooftop_extraction` Level-3 minigame. These must be fixed before implementation lanes dispatch.

---

## Verdict table — every claim row and file:line citation

| # | Claim (as written in spec) | Verdict | Evidence |
|---|---|---|---|
| A1 | `TriageRoundupController.gd:12` OBJECTIVE_ID = `l1_triage_roundup` | CONFIRMED | `@export var objective_id: String = "l1_triage_roundup"` at line 12. L3 variant needs `l3_triage_cryo_recovery`. |
| A2 | `TriageRoundupController.gd:94` start_run | CONFIRMED | `start_run()` -> `interact()` -> `_start_run()` around line 94. |
| A3 | `TriageRoundupController.gd:115` delivery | CONFIRMED | `_on_animal_delivered(animal_type, _pen)` around line 115. |
| A4 | `TriageRoundupController.gd:136` objective report | CONFIRMED | `objective_manager.update_progress(objective_id, 1)` in `_win_run` around line 136. |
| A5 | `TriageRoundupController.gd:145-146` loot tier read | CONFIRMED | `last_loot_tier = int(wp.call("get_active_loot_tier"))` around lines 145-146. Reads tier into `last_loot_tier`; does NOT pass it to loot-drop logic. |
| A6 | `TriageWardPen.gd:21` required_animal_type | CONFIRMED | `@export var required_animal_type: String = "dog"` line 21. |
| A7 | `TriageWardPen.gd:46` process_capture | CONFIRMED | `process_capture(delta)` with `STABLE_DWELL := 1.25` (line 10), capture at line 66. |
| A8 | `TriageAnimalBody.gd:29` animal_type | CONFIRMED | `@export var animal_type: String = "dog"` line 29; MODEL_PATHS dog/cat/rabbit/chicken. |
| A9 | `TriageAnimalBody.gd:80` apply_shove | CONFIRMED | `apply_shove(impulse)` with SHOVE_IMPULSE_CAP around line 80. |
| A10 | `QuarantineBreachController.gd:14` OBJECTIVE_ID = `l1_quarantine_breach` | CONFIRMED | `@export var objective_id: String = "l1_quarantine_breach"` line 14. |
| A11 | `QuarantineBreachController.gd:124` interact | CONFIRMED-ish | `interact()` at line 126 (not 124); gates on `can_hop(gate_region)` and shows `"INDUSTRIAL ACCESS REQUIRED"`. |
| A12 | `QuarantineBreachController.gd:152` door_sealed | CONFIRMED-ish | `signal door_sealed(step)` line 11; `_on_door_sealed(step)` around line 152. |
| A13 | `QuarantineBreachController.gd:176` objective report | CONFIRMED-ish | `update_progress(objective_id, 1)` in `_win_run` around line 188 (spec says 176). |
| A14 | `QuarantineBreachController.gd:192-193` loot tier read | CONFIRMED-ish | `last_loot_tier = ... get_active_loot_tier` around lines 190-192 (spec says 192-193). |
| A15 | `QuarantineBreachController.gd:62-66` gate_region check | CONFIRMED-ish | `gate_region` check is `_ready()` lines 62-64 (queue_free on fail). The interact-time guard is lines 126-130, not 62-66. |
| A16 | `QuarantineSealDoor.gd:17` seal_step | CONFIRMED | `@export var seal_step: String = "A"` line 17. |
| A17 | `QuarantineSealDoor.gd:18` assigned_brace | CONFIRMED | `@export var assigned_brace: String = "case"` line 18; `SEAL_DWELL := 0.75` line 13. |
| A18 | `QuarantineSealDoor.gd:59` seal_tick | CONFIRMED | `seal_tick(delta)` closed+braced dwell test around line 59. |
| A19 | `BreakableSupplyCrate.gd:42` interact / :52 release | CONFIRMED | `interact()` line 42: sets `is_cracked=true`, rotates lid 75°, disables zone, calls `case.release()`, spawns `ammo_drop_count` ammo. |
| A20 | `QuarantineSupplyCase.gd:17` mass=40 / :36 release | CONFIRMED | `mass = 40.0` line ~17; `release()` sets `freeze=false` around line 33-35 (spec says 36). |
| A21 | `PushableServiceCart.gd:17` mass=55 | CONFIRMED | `mass = 55.0` line ~17; `brace_type = "cart"`. |
| A22 | `ArmoryLockdownController.gd:9` OBJECTIVE_ID | CONFIRMED | `const OBJECTIVE_ID := "l2_armory_salvage"` line 9 — Level-2/Industrial ID, NOT Bio-Lab. L3 variant needs `l3_synthesis_core_access`. |
| A23 | `ArmoryLockdownController.gd:47` start_trial | CONFIRMED | `start_trial()` line 47. |
| A24 | `ArmoryLockdownController.gd:56` process win check | CONFIRMED | `_process` checks crates cracked + door open around line 56-62. |
| A25 | `ArmoryLockdownController.gd:71` win | CONFIRMED | `_win_trial()` around line 71; reports `l2_armory_salvage`, no loot tier, no Rules stat. |
| A26 | `CheckpointArmoryTerminal.gd:21` interact | CONFIRMED | `interact()` line 21 -> `controller.start_trial()`. NO can_hop gate. |
| A27 | `CheckpointArmoryTerminal.gd:27` set_trial_state | CONFIRMED | `set_trial_state(value)` line 27. |
| A28 | `CheckpointArmoryTerminal.gd:49` prompt texts | CONFIRMED | `_refresh_prompt()` line ~49; IDLE=`"ACTIVATE LAST STAND TRIAL"`. |
| A29 | `CheckpointArmoryTerminal.gd:57` FAILED text | CONFIRMED | `"FAILED": prompt.text = "TRIAL FAILED — REARM AND RETRY"` line 57. Spec's PARTIAL (change to BREACH TIMED OUT) is correct. |
| A30 | `EndgameExtractionController.gd:9` OBJECTIVE_ID | CONFIRMED | `const OBJECTIVE_ID := "l3_rooftop_extraction"` line 9 — existing Level-3 campaign-finale minigame. |
| A31 | `EndgameExtractionController.gd:44` start_trial / :67 win | CONFIRMED | `start_trial()` ~44, `_win_trial()` ~67; RUN_DURATION=120 (not 90). |
| A32 | `WorldProgression.can_hop(3)` | CONFIRMED | `can_hop(to_region)` lines 189-194; returns true if unlocked OR secret_reachable. `can_hop(3)` valid. |
| A33 | `WorldProgression.get_active_loot_tier()` | CONFIRMED | lines 278-282; returns `def.loot_tier` of `current_region` (3 for Bio-Lab). |
| A34 | `WorldProgression.is_secret_reachable()` | CONFIRMED | lines 248-257; checks secret_catalog edge + transport_done repair gate. |
| A35 | `regions.tres:25-35` id=3, loot_tier=3, prerequisite_region=2 | CONFIRMED | `id = 3`, `display_name = "Bio-Lab"`, `loot_tier = 3`, `prerequisite_region = 2`, scene `endgame_heights.tscn`. |
| A36 | `secret_links.tres:18-22` from=2,to=3,requires_repair=true | CONFIRMED | edge from=2 to=3 label "Sub-level freight conduit / hazmat rail", requires_repair=true (lines 18-21). |
| A37 | `secret_links.tres:23-26` from=3,to=2 no repair | CONFIRMED | edge from=3 to=2 "Return conduit to Industrial", requires_repair=false. |
| A38 | `secret_links.tres:28-32` from=3,to=1 no repair | CONFIRMED | edge from=3 to=1 "Emergency decontamination chute to Suburban", requires_repair=false (lines 28-31). |
| A39 | `Rules.increment_stat` | CONFIRMED | `func increment_stat(stat_name, amount=1.0)` `RulesEngine.gd:268`. Accepts string stat name. |
| A40 | `Game.gd:441-442` `_get_minigame_ids_for_level(3)` = `["l3_rooftop_extraction"]` | CONFIRMED | match level 3 returns `["l3_rooftop_extraction"]` lines 441-442. Only one L3 minigame ID registered. |
| A41 | `cure_endgame_playtest.gd:26-122` / :78-90 | CONFIRMED | playtest at line 26; `record_boss_defeat(3)`, `can_synthesize_cure()`, `synthesize_cure()`, `is_post_cure()` around lines 78-90. |
| A42 | `LevelManager.gd:41` level-3 enemy pool | CONFIRMED | `3: ["bear", "runner", "spitter", "dog", "cat"]` line 41. NOTE: "runner"/"spitter" are NOT in GDD §4's canonical 5 zombie animals (Dog, Cat, Bear, Rabbit, Chicken). |
| A43 | `ZombieBreachController` ZOMBIE_SCENE = `zombie_dog.tscn` | CONFIRMED | `const ZOMBIE_SCENE = preload("res://scenes/characters/zombie_dog.tscn")` line 23. |
| A44 | `development-breakdown.md` Bio-Lab/level-3 sections | MISSING-EVIDENCE | File is a process doc (movement, combat, AI, food, UI, level progression...). Grep for biolab/level-3/triage/quarantine/armory/synthesis returns NOTHING. Cited ground-truth sections do not exist. |
| A45 | ObjectiveManager `add_objective` / `update_progress` / `all_objectives_completed` | CONFIRMED | `ObjectiveManager.gd`: `add_objective(id,title,target=1)`, `update_progress` (no-ops if completed = one-shot), `all_objectives_completed` signal. |
| A46 | Player.gd mobile `_perform_attack()` bypass | CONFIRMED | `Player.gd:586` comment "mobile button used to call `_perform_attack()` directly, which skipped this"; `:593` `_perform_attack()`. Spec's mobile-routing claim is accurate. |
| A47 | ZombieSpawner3D `start_spawning()`/`stop_spawning()` | CONFIRMED | lines 189, 201. Spec's spawner-reuse claim is accurate. |
| A48 | `endgame_heights.tscn:82-100` 3 districts; :299-300 EndgameExtraction | CONFIRMED | SewerDistrict, MallDistrict, RooftopDistrict lines 82-100; `EndgameExtraction` instanced at RooftopDistrict transform (140,0,0) lines 299-300. |
| A49 | `endgame_cache_network.tscn:367-870` 18 crates | CONFIRMED-ish | 18 instances of `ExtResource("1_xldl7")` (BreakableSupplyCrate). File is 869 lines, spec cites :870 (off-by-one minor). |

### Status-table verdicts (mis-classification — the L2-arc pattern)

The specs mark numerous **Level-1 / Level-2 base-controller behaviors as "IMPLEMENTED" for the Level-3 Bio-Lab variants**. No Bio-Lab controller, scene, or HUD exists (no `TriageCryoRecoveryController`, no `QuarantineContainmentController`, no Bio-Lab armory instance in `endgame_heights.tscn`). Every row below should be **TO BUILD** for the L3 variant; the base exists only as reference.

| Spec section | Row (as written) | Correct verdict | Reason |
|---|---|---|---|
| §1.8 | Controller state machine IMPLEMENTED (TRC:20-21, 94-113) | CORRECTED → TO BUILD | State machine exists only in L1 base (`l1_triage_roundup`). L3 Bio-Lab controller not written. |
| §1.8 | 90s timer + 8s escape penalty IMPLEMENTED (TRC:14-16, 73-82, 168-178) | CORRECTED → TO BUILD | L1 base constants only. |
| §1.8 | Four unique type delivery + 1.25s dwell IMPLEMENTED | CORRECTED → TO BUILD | L1 base uses dog/cat/rabbit/chicken; L3 needs cryo pod types alpha/beta/gamma/delta. |
| §1.8 | Wrong-type bounce + HUD flash IMPLEMENTED | CORRECTED → TO BUILD | L1 base (`TriageWardPen` animal colors). |
| §1.8 | Hall overrun zone IMPLEMENTED (TRC:180-200) | CORRECTED → TO BUILD | L1 base only. |
| §1.8 | ObjectiveManager one-shot report IMPLEMENTED (TRC:136-137) | CORRECTED → TO BUILD | L1 base reports `l1_triage_roundup`; L3 needs `l3_triage_cryo_recovery`. |
| §1.8 | can_hop(3) gate TO BUILD — "Not present in current controller" | CORRECTED | `gate_region` @export (default 0) + `_ready()` guard EXIST (TRC:26, 47-49), but unset for Bio-Lab and **no interact-time guard**. Partially present, not absent. |
| §1.8 | Loot tier via get_active_loot_tier() TO BUILD — "reads it but uses L1/L2 IDs only" | CORRECTED | `get_active_loot_tier()` reads `current_region` dynamically, not L1/L2 IDs. Real gap: `last_loot_tier` is never passed to loot-drop logic. |
| §2.8 | Controller state machine / 120s timer / A→B→C gate / seal dwell / crowd fail / one-shot report IMPLEMENTED | CORRECTED → TO BUILD | All are QBC L1/L2 base behaviors (`l1_quarantine_breach`). L3 variant not written. |
| §2.8 | can_hop(3) gate TO BUILD — "QBC:62-66 has gate_region but only checks for 2" | REJECTED → CORRECTED | `gate_region` is `@export int = 0` (QBC:25), comment "Industrial variant sets 2". It is parameterized, dynamically checked, and settable to 3. Not "only checks for 2". Interact-time guard is at QBC:126-130, not :62-66. |
| §2.8 | Loot tier "uses L1/L2 IDs only" | CORRECTED | Same as A5 — reads current_region tier; gap is no pass-through to loot drop. |
| §3.8 | Controller 90s timer + win/fail IMPLEMENTED (ALC:11, 56-69) | CORRECTED → TO BUILD | L2 base (`l2_armory_salvage`). |
| §3.8 | Terminal state machine IMPLEMENTED | CORRECTED → TO BUILD | L2 base terminal (`CheckpointArmoryTerminal` Industrial texts). |
| §3.8 | ObjectiveManager report (l2_armory_salvage) IMPLEMENTED (ALC:9-10, 76-77) | CORRECTED → TO BUILD | L2 base reports `l2_armory_salvage`; L3 needs `l3_synthesis_core_access`. |
| §3.8 | 3s failure reset + crate/door reset IMPLEMENTED (ALC:85-91) | CORRECTED → PARTIAL/REJECTED | Base `_fail_trial` resets terminal state to IDLE after 3s but does **not** reset crates (`is_cracked`) or door (`is_open`). On retry they remain cracked/open. |
| §6.3 | Armory "Core gameplay IMPLEMENTED — Fully functional" | CORRECTED → PARTIAL | Core loop functional in L2 base, but Bio-Lab variant (objective ID, gate=3, loot tier, Rules stat, prompt text, scene placement) is TO BUILD. |

---

## GDD-noun coverage matrix (MASTER_GDD.md World 3 row)

GDD World 3: setting = containment wings, research bays, cryogenic vaults, synthesis core; resources = bio-polymers, mutagen samples, cryo-cores, cure catalysts; transport = sub-level freight conduit IN from Industrial, emergency decontamination chute OUT to Suburban AND Industrial.

| GDD noun | Addressed in specs? | Disposition | Evidence |
|---|---|---|---|
| containment wings | Yes | TO BUILD | Triage Roundup in "Containment Wing Cryo-Recovery Bay" (§1). |
| research bays | Yes | TO BUILD | Quarantine Breach in "Research Bay Containment Corridor" (§2). |
| cryogenic vaults | Yes | TO BUILD | Armory Lockdown in "Cryogenic Vaults antechamber" (§3). |
| synthesis core | Yes | TO BUILD | Armory Lockdown at "Synthesis Core Access Lock" (§3). |
| bio-polymers | Yes (partial) | OPEN DECISION | Listed in §10 OPEN DECISION: "Loot tables for Bio-Lab tier 3 (bio-polymers, ...)". No drop table defined. |
| mutagen samples | Yes (partial) | OPEN DECISION | Same as above. No drop table. |
| cryo-cores | Yes (partial) | OPEN DECISION | Same as above. No drop table. |
| cure catalysts | Yes (partial) | OPEN DECISION | Same as above. No drop table. |
| freight conduit IN from Industrial | Yes | Covered | §5.3: `is_secret_reachable(2,3)`, secret_links from=2 to=3 requires_repair=true (freight conduit/hazmat rail). |
| decon chute OUT to Suburban | Yes | Covered | §5.3: `is_secret_reachable(3,1)`, from=3 to=1 "Emergency decontamination chute to Suburban", no repair. |
| decon chute OUT to Industrial | Yes | Covered | §5.3: `is_secret_reachable(3,2)`, from=3 to=2 "Return conduit to Industrial", no repair. |

**GDD coverage result:** No GDD noun is dropped. All are addressed as implemented-reference, TO BUILD, or OPEN DECISION. The four GDD resources (bio-polymers, mutagen samples, cryo-cores, cure catalysts) are correctly left as OPEN DECISION with no drop tables — the spec does not invent drop tables, which is good.

---

## Parameterization mechanism check (requirement #5)

| Mechanism | Spec claim | Code reality | Verdict |
|---|---|---|---|
| `TriageRoundupController` / `QuarantineBreachController` `gate_region` export | Export exists; Bio-Lab sets `gate_region=3` | CONFIRMED `@export var gate_region: int = 0` (TRC:26, QBC:25). Comment notes "Industrial variant sets 2". | CONFIRMED (parameterized, settable to 3). |
| `can_hop(3)` gate at interact | Both controllers guard in `interact()` | QBC: YES (QBC:126-130, shows "INDUSTRIAL ACCESS REQUIRED"). TRC: **NO** — `interact()` (TRC:90-94) just calls `_start_run()`, no can_hop re-check. Only `_ready()` guards (queue_free). | **DEFECT** — TRC missing interact-time guard. |
| `regions.tres` id-3 entry | id=3, loot_tier=3, prereq=2 | CONFIRMED (A35). | CONFIRMED. |
| `get_active_loot_tier()` reward on win | Read into `last_loot_tier`, pass to loot drop | Read confirmed (TRC:145-146, QBC:~190-192); **pass-to-loot-drop NOT implemented** in either base. | Partially confirmed; gap is the pass-through. |

---

## Requirement #4 — no invented fourth minigame family / no unmarked GDD-silent mechanics

1. **"No Fourth Minigame" (non-goal #9, A §4 / B §8) is contradicted by existing code.** `EndgameExtractionController` = `l3_rooftop_extraction` is a registered Level-3 minigame (`Game.gd:441-442`) already instanced in `endgame_heights.tscn` RooftopDistrict (transform 140,0,0, lines 299-300). B §10 OPEN DECISION #10 flags whether it is "a fourth minigame or the campaign finale," but non-goal #9 states "No Fourth Minigame" as absolute. **Internal contradiction** — the spec both denies and acknowledges a fourth L3 minigame. Resolve OPEN DECISION #10 or reword non-goal #9 before lanes treat it as settled.

2. **`runner`/`spitter` mutant types are not GDD-canonical zombie animals.** `LevelManager.gd:41` level-3 pool = `["bear", "runner", "spitter", "dog", "cat"]`. GDD §4 canonical zombie animals = Dog, Cat, Bear, Rabbit, Chicken. "runner" and "spitter" are absent. B §6.2 OPEN DECISION treats them as available Bio-Lab breach mutants without flagging they are non-canonical / not in the GDD's canonical 5. **Unmarked invention adjacent** — either justify them as extensible roster or mark as invention.

3. **No fourth minigame family otherwise introduced.** The three controller families (Triage, Quarantine, Armory) map to the three GDD settings. Confirmed no unmarked fourth family beyond the existing `l3_rooftop_extraction` tension above.

---

## Format contract vs LEVEL2 specs (requirement #3)

**Satisfied overall.** LEVEL3 mirrors LEVEL2 structure: title/scope pattern, Shared Implementation Contract, numbered sub-sections, per-minigame loops, activation trigger, win/fail, mobile mapping, implementation-status tables, anti-slop non-goals, file/line anchor table, and a TO BUILD / PARTIAL / IMPLEMENTED classification summary. LEVEL2 specs contain the same IMPLEMENTED/TO BUILD/PARTIAL markers (26 in LEVEL2_A, 33 in LEVEL2_B) and section headers (20/24). Tuning tables use real code defaults (90s, 120s, 0.75s, 1.25s, 40kg/55kg, 6 mutants, 44×44px, 14sp/16sp) or explicit TO BUILD. No format violation found.

---

## Requirement #5 — cited parameterization mechanism summary

All three mechanism anchors exist in code:
- `TriageRoundupController`/`QuarantineBreachController` `gate_region` @export (default 0) + `_ready()` can_hop guard — CONFIRMED.
- `WorldProgression.can_hop(3)` — CONFIRMED (WorldProgression.gd:189-194).
- `regions.tres` id-3 (Bio-Lab, loot_tier=3, prerequisite_region=2) — CONFIRMED.

**Defects within this mechanism:** (a) TRC lacks the interact-time can_hop guard; (b) QBC/TRC interact-time prompt text is hardcoded `"INDUSTRIAL ACCESS REQUIRED"` and must become `"BIO-LAB ACCESS REQUIRED"` for Bio-Lab; (c) gate_region defaults to 0 and must be set to 3 per variant.

---

## Fabricated / unsupported claims (requirement #4 & #5)

| Claim | Reality | Severity |
|---|---|---|
| `Rules.increment_stat("MINIGAMES_WON", 1)` is "Parameter ID 30" | **False.** RequirementTypes ID 30 = `UNLOCKED_CHARACTERS_COUNT`. `MINIGAMES_WON` does not exist as a typed parameter (grep found nothing). `increment_stat()` accepts a string stat name so it works as a user stat, but not as "ID 30". | HIGH |
| `ACHIEVEMENT_TIER` (ID 72) | **False.** RequirementTypes ID 72 = `HAS_ACTIVE_SEASON_HUNT`. `ACHIEVEMENT_TIER` does not exist as a parameter. | HIGH |
| LiveOps parameter toggles IDs 150–157 gate Bio-Lab mini-games | Unverified/speculative; TOTAL_PARAMETERS=158 so IDs 150-157 may exist, but no evidence they gate mini-games. | MEDIUM |
| `Rules.set_category_enabled(RequirementTypes.CAT_GAMEPLAY, ...)` | CONFIRMED `set_category_enabled(category, enabled)` at RulesEngine.gd:121 and `CAT_GAMEPLAY = "Gameplay"` at RequirementTypes.gd:18. | CONFIRMED |
| `CURE_SYNTHESIZED`=100, `POST_CURE_MODE`=101 | CONFIRMED (RequirementTypes.gd:126-127, enum entries lines 294-295). | CONFIRMED |

---

## Invalid / imprecise citations

| Citation (as written) | Reality |
|---|---|
| `development-breakdown.md` (Bio-Lab/level-3 sections) as ground truth | File has no such sections; it is a development process doc. **Remove/replace citation.** |
| QBC interact-time gate at :62-66 | :62-64 is `_ready()` queue_free guard; interact-time guard is :126-130. |
| TRC has can_hop guard in `interact()` | **Absent.** `interact()` (TRC:90-94) calls `_start_run()` directly. |
| QBC loot-tier read at :192-193 | Actually ~190-192. Minor. |
| `endgame_cache_network.tscn:367-870` | File is 869 lines. Minor off-by-one. |
| Armory "crate/door reset IMPLEMENTED :85-91" | Base only resets terminal state; crates/door not reset. |

---

## Ranked list of spec defects the writer must fix before implementation lanes dispatch

1. **HIGH — Fabricated Rules parameter IDs.** `MINIGAMES_WON` is not ID 30 (ID 30 = `UNLOCKED_CHARACTERS_COUNT`); `ACHIEVEMENT_TIER` is not ID 72 (ID 72 = `HAS_ACTIVE_SEASON_HUNT`); neither exists as a typed parameter. Fix §5.4: drop the false ID claims; if using `increment_stat("MINIGAMES_WON", 1)`, treat it as a plain string user stat, not a parameter ID.
2. **HIGH — Mis-classified IMPLEMENTED rows (L2-arc failure mode).** §1.8/§2.8/§3.8 mark Level-1/Level-2 base-controller behavior (state machine, timer, one-shot report, loot-tier read) as IMPLEMENTED for L3 Bio-Lab variants. No Bio-Lab controller/scene/HUD exists. Re-mark all L3-variant rows TO BUILD; cite base only as "base logic exists, not ported."
3. **HIGH — TriageRoundupController missing interact-time can_hop guard.** §5.1 claims both controllers guard in `interact()`; TRC's `interact()` (90-94) has no can_hop re-check. Add the guard or retract the claim.
4. **HIGH — Internal contradiction: "No Fourth Minigame" vs existing `l3_rooftop_extraction`.** Non-goal #9 states no fourth minigame, but `EndgameExtractionController` (`l3_rooftop_extraction`) is a registered Level-3 minigame already placed in `endgame_heights.tscn` RooftopDistrict. B §10 OPEN DECISION #10 acknowledges the tension. Resolve it (re-scope non-goal #9 or close the open decision) before lanes treat "no fourth minigame" as settled.
5. **MEDIUM — Invalid ground-truth citation.** `development-breakdown.md` contains no Bio-Lab/level-3/minigame sections. Remove or replace the citation in both specs' ground-truth paragraphs.
6. **MEDIUM — Fix line citations and behavior claims.** QBC interact gate is :126-130 not :62-66; TRC interact has no guard; `endgame_cache_network.tscn` is 869 not 870 lines; armory "crate/door reset" only resets terminal state.
7. **MEDIUM — Correct loot-tier gap description.** `get_active_loot_tier()` reads `current_region` dynamically (not "L1/L2 IDs only"). The true defect: `last_loot_tier` is read on win but never passed to loot-drop logic in either base controller.
8. **MEDIUM — Deconflict Armory Bio-Lab placement.** `EndgameExtraction` already occupies RooftopDistrict transform (140,0,0) in `endgame_heights.tscn`; B §6.3 suggests RooftopDistrict or MallDistrict for the armory instance. OPEN DECISION #8 placement must deconflict with the existing finale.
9. **MEDIUM — Flag non-canonical mutants.** `runner`/`spitter` in `LevelManager.gd:41` are not in GDD §4's canonical 5 zombie animals (Dog, Cat, Bear, Rabbit, Chicken). B §6.2 OPEN DECISION should flag this before using them as Bio-Lab breach mutants.
10. **LOW — Bio-Lab interact prompt text.** QBC/TRC interact-time denial text is hardcoded `"INDUSTRIAL ACCESS REQUIRED"`; Bio-Lab variants must show `"BIO-LAB ACCESS REQUIRED"` and set `gate_region = 3`.

---

## Bottom line

The specs' **structure, GDD coverage, and most low-level anchors are CONFIRMED**. The blockers are the **fabricated Rules parameter IDs**, the **mis-classified IMPLEMENTED rows**, the **missing TRC interact-time gate**, the **invalid development-breakdown citation**, and the **"No Fourth Minigame" contradiction**. Fix these ten defects (ranked above) before the implementation lanes dispatch. Nothing in the specs should be implemented as-is until rows 1–4 are resolved.

