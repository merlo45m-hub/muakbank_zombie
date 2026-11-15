# MASTER GAME DESIGN DOCUMENT — Mukbang Zombie

**STATUS: LAW OF TRUTH (adopted 2026-11-15).**

Canonical source: Obsidian vault
`hermes_brain/second_brain/Mukbang_Zombie_GDD.pdf` (6 pages, 258,154 bytes,
2026-11-15 08:56), reached via the `Master game design plan.md` embed.
This file is the version-controlled transcription + precedence contract.

## 0. Precedence (read first)

When this document conflicts with any other repo doc, **this document wins**:

| Doc | Status |
|---|---|
| `MASTER_GDD.md` (this file) | **CANONICAL** — game design law of truth |
| `DESIGN.md` §2 palette, §3 type/geometry, §6 perf budget | Still normative (art direction + hard budgets) |
| `DESIGN.md` §1 direction / §5 implementation status | **Superseded** by this GDD's vision + §7 directive |
| `docs/GAME_DESIGN.md` "Core Structure" | **Superseded** — that doc mandates *linear* all-mini-game gating; GDD §3 mandates **non-linear** hopping |
| `README.md` Play / Systems sections | Legacy loop description; see the Current design direction banner |
| `STATE.md`, `CODEX.md` | Stale snapshots; not design sources |
| `docs/world_progression.md` | Describes the shipped **linear** #11 model — now a legacy implementation to be evolved by GDD-1 (#25) |
| GitHub #24 / #25–#29 | The implementation plan and conflict decisions |

Master tracking: GitHub #24 (alignment), #15 (roadmap). Workstreams #25–#29.

---

## 1. Vision & Design Pillars

A lightweight, **60 FPS dismantling action-survival** game across three
interconnected **Miami-themed** worlds, built in **Godot 4.7** with a
**Vinyl Action-Figure** aesthetic. Dysmantle-inspired tactile scavenging and
object destruction without heavy physics or 120 Hz hardware demands.

- **Tactile Dismantling First** — every prop and defeated zombie breaks into
  recognizable parts; snappy and rewarding, no mobile slowdown.
- **Non-Linear World Hopping** — players are *never* trapped behind 100% zone
  checklists; secret transport areas let explorers jump ahead for better gear
  and return stronger.
- **Lightweight 60 FPS Target** — locked 60 FPS on mobile (Galaxy S26 Ultra),
  zero reliance on heavy physics or 120 Hz rendering.
- **Vinyl Toy Charm** — glossy vinyl action-figure silhouettes, sharp rim
  lighting, readable neon-cyan UI accents.

Core creative direction: break apart props and zombies via lightweight
component swapping, hop non-linearly between three worlds through secret
transport areas, defeat world bosses, synthesize an apocalypse-ending cure —
while keeping the world alive for post-cure side quests.

## 2. Core Loop & Dismantling Mechanics

Explore & identify → **dismantle via component swapping** → scavenge & log →
unlock & advance (higher tool tiers open tougher props, secret transport routes,
boss arenas).

Pipeline: `Intact Prop / Zombie (single root mesh + hitpoints)` →
`Strike Event (tool tier check & impact FX)` →
`Joint Disconnect (swap to pre-split part meshes)` →
`Component Drop (lightweight impulse + loot pickup)`.

**Performance rule:** NEVER use real-time CSG mesh slicing or continuous
rigid-body fracture simulation. All destructible props use pre-authored Blender
sub-meshes (`.glb`) tagged for simple joint detachment and pooled despawn
timers. Collected parts feed crafting recipes, tool-tier upgrades, Collection
Log / Museum / Bestiary entries for stat bonuses and lore.

## 3. Three Interconnected Worlds & Non-Linear Progression

| World | Setting & Props | Primary Resources | Secret Transport Link |
|---|---|---|---|
| **World 1: Suburban** | Miami neighborhoods, graveyard, wooden crates, overturned vending machines | Scrap wood, snack-tech parts, basic electronics, organic residue | Hidden graveyard crypt / utility tunnel → Industrial |
| **World 2: Industrial** | Shipping yards, warehouses, heavy machinery, pressurized tanks | Reinforced alloys, hydraulics, industrial wiring, fuel cells | Sub-level freight conduit / hazmat rail → Bio-Lab |
| **World 3: Bio-Lab** | Containment wings, research bays, cryogenic vaults, synthesis core | Bio-polymers, mutagen samples, cryo-cores, cure catalysts | Emergency decontamination chute → Suburban & Industrial |

Graph (Figure 2): `World 1 Suburban (Start, Boss 1) ↔ Secret Transport ↔
World 2 Industrial (Mid-Tier, Boss 2) ↔ Secret Transport ↔ World 3 Bio-Lab
(Cure Core, Boss 3)`, with a return chute from Bio-Lab back to both earlier
worlds. Managed by `WorldHopManager` with **bidirectional** routes. Early
hopping ahead for higher-tier gear is intended, not a bug.

## 4. Entities

All characters follow stylized Vinyl Action-Figure proportions at **1:1 metric
scale**. Survivor selection on illuminated neon-cyan circular pedestals.

- **Survivor Archetypes (5):** Gamer, Doctor, Nurse, Streamer, Hunter — distinct
  starting perks and silhouettes.
- **Zombie Animals (5):** Dog, Cat, Bear, Rabbit, Chicken — fast flankers, heavy
  bruisers (Bear), swarmers; drop Bestiary entries and bio-parts.
- **World Bosses (3):** 1 per world (Suburban, Industrial, Bio-Lab) — guard Cure
  synthesis catalysts and major regional achievements; require upgraded tool tiers.

## 5. Cure Synthesis, Achievements & Post-Cure Endgame

Cure is synthesized in the Bio-Lab synthesis core. It does **NOT** demand 100%
completion.

- **Majority Completion Threshold:** defeat the World Boss in each of the three
  worlds AND reach a majority achievement threshold (tracked by
  `AchievementManager`) across Worlds 1–3 → unlock Cure synthesis.
- **Collection Log & Bestiary Synergy:** dismantling unique props and zombie
  types unlocks museum entries, lore snippets, crafting blueprints, passive
  stat boosts that accelerate boss readiness.
- **Post-Cure Endgame:** deploying the Cure stops the main outbreak but the game
  continues **seamlessly** — full world access retained for side quests, 100%
  achievements, Collection Log completion, high-tier survival challenges.

## 6. Visual Style & 60 FPS Performance Budget

Visual fidelity relies on clean materials and lighting, not expensive
post-processing.

| System / Feature | Design Standard | Performance Guardrail |
|---|---|---|
| VinylLook Shader | Fresnel rim-light overlay with clean vinyl specular highlights | Keep shader math lightweight; avoid multi-pass screen-space reflections |
| Volumetric Fog | Calibrated atmospheric depth for mood in graveyard and Bio-Lab | **Opt-in only (OFF by default)** to protect mobile 60 FPS budget |
| 3D Assets (`.glb`) | 1:1 metric scale Blender exports with unified pivot points | Shared material atlases, LODs, object pooling for dismantled debris |
| Physics & Debris | Simple capsule/box colliders, short-lived rigid-body pops | Cap active debris count, auto-despawn detached parts after collection |

`DESIGN.md` §6 remains the authoritative numeric budget (60 FPS / 30 FPS floor,
<350 MB RSS, <=3 real-time lights, <=1 shadow caster, <120 draw calls).

## 7. Agent Implementation Directive (Hermes Pipeline)

| Godot Module | Implementation Requirement | Verification Gate |
|---|---|---|
| `DismantleComponent` | Attachable node: hitpoints, required tool tier, joint-disconnect mesh swap, loot table drops | 60 FPS under multi-prop destruction stress test |
| `WorldHopManager` | Autoload threaded hop engine that serializes player inventory, world state and achievements **before unloading scenes** | Suburban ↔ Industrial ↔ Bio-Lab hops with zero state loss |
| `AchievementManager` | Per-world achievements, boss kills, majority completion threshold for Cure unlock + post-cure state flag | Regression: confirm script assignment persists after VinylLook node insertion |
| `CollectionLog & Bestiary` | Persistent registry linking dismantled prop IDs and defeated zombie/animal IDs to stat bonuses and recipes | All 5 survivors, 5 zombie animals, core props register cleanly |
| Validation & CI | Headless Godot scene-rendering screenshots + GDUnit4 tests across all 117 scenes / ~158 scripts | Zero type-inference errors; APK builds cleanly with Android export templates |

**Immediate Next Step for Hermes:** (1) audit `AchievementManager` node script
assignment in the main scene tree, (2) finalize the `DismantleComponent`
interface spec in Obsidian, (3) wire the first secret transport trigger between
World 1 (Suburban) and World 2 (Industrial) via `WorldHopManager`.

## 8. Implementation status against this GDD (2026-11-15)

Already landed (verified): VinylLook Fresnel rim shader + opt-in volumetric fog
tier (`b4beb7f`), 1:1 metric Blender GLB scale guard (`192b1fb`), threaded
`WorldHopManager` + structured transient-state serialization (`bce870c`,
`cea5fa5`), 60 FPS budget (`1698ee8`), headless/CI gates + Android templates in
CI (`b322faa`, `22cab96`), and the AchievementManager-script-assignment
regression the GDD calls out (found & fixed in `b4beb7f`).

#26 GDD-2 LANDED (`06e9f2c`): `DismantleComponent` (stateless, tool-tier gate,
joint-disconnect mesh swap, NO CSG), `DebrisPool` autoload (MAX_ACTIVE=48 cap),
`CollectionLog`/`Bestiary` read-only facades, sole-writer `CollectionManager`
registries, SAVE_VERSION 4->5, `dismantle_tables.json`, full-chain
`dismantle_playtest.gd` (GDD26_PASS=true). Split-part GLBs (#9.2) still owed;
per-prop scene wiring is the art-gated next step.

Open workstreams: #27 GDD-3 world remap, #28 GDD-4 Cure/post-cure,
#29 GDD-5 (registry exists via #26; catalog-coverage validation owed),
#21 device visual review (manual pass scheduled 14:32 EST), #23 headless
rendering to vault, #9.2 asset replacement.

## 9. Delegation map (curator: Hermes)

| Lane | Lens | Deliverable |
|---|---|---|
| agy / Claude lane | Architecture & failure modes | non-linear hop spec, `lane_arch_nonlineHop.md` |
| codex lane | Concrete patch / state | DismantleComponent + save schema, `lane_code_dismantle.md` |
| CI lane | Validation / headless rendering | #23 pipeline spec, `lane_ci_headless.md` |

All three bounded (max 6 tool calls, explicit STOP, no repo/GitHub writes);
curator verifies premises before applying.
