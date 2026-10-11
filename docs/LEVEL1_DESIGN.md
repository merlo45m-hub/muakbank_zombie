# LEVEL1_DESIGN.md — Old Town

## 1. Intent

**What level 1 is for:** The tutorial. The player learns movement, combat, pickup, and wave survival in a space that reads as a place people fled from — not a prop dump. Difficulty 1.0, enemies are chickens and rabbits (the smallest, slowest zombies).

**What the player should feel:** Dusk in a dead town. The sun is gone, street lamps flicker on, and every storefront is boarded up. Cars sit at odd angles with doors open. A construction barrier blocks half the main road. An ambulance left running pulses red somewhere ahead. The story is *recent abandonment* — people left in a hurry, not a gradual decline.

**The story the street tells:** A small-town main street during an outbreak. The player spawns at the west end of Main Street, facing east toward the construction zone and the ambulance. The Corner Store (NW) has its awning torn and debris leading to the door — someone barricaded inside. The Back Alley (N) has a dumpster and scattered trash — a dead end people fled into. The Parking Lot (SE) has cars frozen mid-evacuation. The Construction Zone (NE) blocks the road — the crew never finished, and the equipment is still running.

**Visual target:** Semi-abandoned, not post-apocalyptic. Think *The Last of Us* episode 1 town, not *Mad Max*. Everything should look like it was functional last week.

---

## 2. Zone Breakdown & Placement Plan

### Coordinate System

The play area is a 60×60 m square centered at origin (0, 0). Ground plane at y = 0. Main road runs east-west at z = −4. Cross road runs north–south at x = 11. Player spawns at (−2, 0.15, −6), facing east (+X).

All coordinates below are world-space (x, y, z) in metres, y = ground level. Rotation is yaw in radians (0 = facing −Z, the Godot forward).

---

### Zone A: Main Street (Corridor, z ≈ −4)

The primary east-west artery. Commercial buildings line both sides. This is the player's main combat space — wide enough for kiting, with parked cars as cover.

#### Buildings (replacing all 6 primitive buildings)

| Slot | Current | Replacement model | Position | Rotation | Scale | Rationale |
|------|---------|-------------------|----------|----------|-------|-----------|
| Building1 | 9×7×9 box at (−20, 5, −15) | `res://assets/models/cc0/city/commercial/Models/building-a.glb` | (−20, 0, −15) | 0.0 | Fit to ~7 m height | Tallest commercial block; anchors the west end |
| Building2 | 12×10×10 box at (18, 5, −18) | `res://assets/models/cc0/city/commercial/Models/building-b.glb` | (18, 0, −18) | 0.0 | Fit to ~10 m height | Wide storefront; main street east side |
| Building3 | 7×6×7 box at (−22, 3, 18) | `res://assets/models/cc0/city/commercial/Models/building-c.glb` | (−22, 0, 18) | 0.0 | Fit to ~6 m height | Corner store; smaller, approachable |
| Building4 | 14×8×12 box at (5, 4, 20) | `res://assets/models/cc0/city/commercial/Models/building-d.glb` | (5, 0, 20) | 0.0 | Fit to ~8 m height | Mid-block shops; breaks the skyline |
| Building5 | 16×14×16 box at (−8, 6, 8) | `res://assets/models/cc0/city/commercial/Models/building-e.glb` | (−8, 0, 8) | 0.0 | Fit to ~14 m height | Largest block; the "department store" |
| Building6 | 6×12×6 box at (8, 7, 10) | `res://assets/models/cc0/city/commercial/Models/building-f.glb` | (8, 0, 10) | 0.0 | Fit to ~12 m height | Narrow tower; vertical accent |

**Church** at (−30, 6, 25): Keep as a primitive landmark (22×12×18 box + steeple cylinder). It is the visual anchor at the far west end. Its simple silhouette reads fine against the sky. Do not replace with a commercial building.

**Backdrop ring:** 8–10 `building-skyscraper-a..e.glb` models placed at r = 24–28 around the arena, no colliders. These are the "rest of the city" the player sees over the rooftops. Use `low-detail-building-a..n.glb` for the inner ring (r = 20–24) to fill gaps.

#### Street furniture along Main Street

| Model | Path | Position | Rotation | Notes |
|-------|------|----------|----------|-------|
| Light pole 1 | `res://assets/models/cc0/city/roads/Models/light-curved.glb` | (−12, 0, −6.2) | 0.0 | With warm OmniLight3D at (0, 3, 0), energy 1.6, range 7 |
| Light pole 2 | `res://assets/models/cc0/city/roads/Models/light-curved.glb` | (−4, 0, −6.2) | 0.0 | With warm OmniLight3D |
| Light pole 3 | `res://assets/models/cc0/city/roads/Models/light-curved.glb` | (4, 0, −6.2) | 0.0 | With warm OmniLight3D |
| Light pole 4 | `res://assets/models/cc0/city/roads/Models/light-curved.glb` | (12, 0, −6.2) | 0.0 | With warm OmniLight3D |
| Traffic light | `res://assets/models/cc0/city/roads/Models/traffic-light.glb` | (10.5, 0, −2.5) | π/2 | At the crossroad intersection |
| Stop sign | `res://assets/models/cc0/city/roads/Models/road-sign-stop.glb` | (12.5, 0, −6.0) | 0.0 | West side of intersection |
| Warning sign | `res://assets/models/cc0/city/roads/Models/road-sign-warning.glb` | (−14, 0, −5.5) | 0.3 | Leaning slightly |
| Electricity pole | `res://assets/models/cc0/city/roads/Models/electricity-pole.glb` | (−18, 0, −1.5) | 0.0 | North side of street |
| Electricity wires | `res://assets/models/cc0/city/roads/Models/electricity-wires.glb` | (−18, 4.5, −1.5) | 0.0 | Strung between poles (visual only) |

#### Parked / abandoned cars on Main Street

| Model | Path | Position | Rotation | Scale | Rationale |
|-------|------|----------|----------|-------|-----------|
| Sedan | `res://assets/models/cc0/cars/Models/sedan.glb` | (−6, 0, −3.0) | 0.15 | 1.2 | Parked north side, slightly angled |
| Taxi | `res://assets/models/cc0/cars/Models/taxi.glb` | (2, 0, −4.5) | π + 0.2 | 1.1 | Wrong side of the road, mid-escape |
| Police | `res://assets/models/cc0/cars/Models/police.glb` | (14, 0, −3.5) | −0.3 | 1.15 | Abandoned near intersection, lights off |
| Delivery | `res://assets/models/cc0/cars/Models/delivery.glb` | (−16, 0, −4.0) | π/2 | 1.1 | Backed into the Corner Store loading zone |

---

### Zone B: Corner Store (NW quadrant, x < −15, z > 10)

A small shop at the corner of Main Street and the north side road. The awning is torn, debris leads to the door. Someone barricaded inside.

| Model | Path | Position | Rotation | Notes |
|-------|------|----------|----------|-------|
| Awning | `res://assets/models/cc0/city/commercial/Models/detail-awning.glb` | (−22, 2.8, 15.5) | 0.0 | Torn over the storefront |
| Overhang | `res://assets/models/cc0/city/commercial/Models/detail-overhang.glb` | (−22, 3.2, 15.5) | 0.0 | Second floor overhang |
| Parasol | `res://assets/models/cc0/city/commercial/Models/detail-parasol-a.glb` | (−19, 0, 14) | 0.5 | Fallen outdoor café umbrella |
| Planter | `res://assets/models/cc0/city/suburban/Models/planter.glb` | (−20, 0, 16) | 0.0 | Overturned |
| Debris door | `res://assets/models/cc0/cars/Models/debris-door.glb` | (−21.5, 0, 15.2) | 0.8 | Door ripped off, leaning against the wall |
| Debris plate A | `res://assets/models/cc0/cars/Models/debris-plate-a.glb` | (−23, 0, 14.5) | 0.3 | Scattered near the entrance |
| Debris tire | `res://assets/models/cc0/cars/Models/debris-tire.glb` | (−19.5, 0, 16.5) | 0.0 | Rolled to a stop |

---

### Zone C: Construction Zone (NE quadrant, x > 8, z < −10)

Road work abandoned mid-job. The main road is half-blocked. Equipment is still running.

| Model | Path | Position | Rotation | Notes |
|-------|------|----------|----------|-------|
| Barrier 1 | `res://assets/models/cc0/city/roads/Models/construction-barrier.glb` | (10, 0, −4) | 0.0 | Half-blocking the main road |
| Barrier 2 | `res://assets/models/cc0/city/roads/Models/construction-barrier.glb` | (13, 0, −4) | 0.15 | Second barrier, angled |
| Construction fence | `res://assets/models/cc0/city/roads/Models/construction-fence.glb` | (11.5, 0, −6.5) | π/2 | Fencing off the work area |
| Construction light | `res://assets/models/cc0/city/roads/Models/construction-light.glb` | (14, 0, −3) | 0.0 | Flashing amber work light (OmniLight3D, orange, energy 2, range 8) |
| Cone 1 | `res://assets/models/cc0/cars/Models/cone.glb` | (8.5, 0, −3) | 0.0 | Knocked over |
| Cone 2 | `res://assets/models/cc0/cars/Models/cone.glb` | (12, 0, −5.5) | 0.0 | Standing |
| Cone 3 | `res://assets/models/cc0/cars/Models/cone-flat.glb` | (10.5, 0, −2.5) | 0.0 | Flattened |
| Ambulance | `res://assets/models/cc0/cars/Models/ambulance.glb` | (16, 0, −8) | π/2 + 0.4 | Left running, rear doors open |
| Debris bumper | `res://assets/models/cc0/cars/Models/debris-bumper.glb` | (15, 0, −6) | 0.5 | Ripped off the ambulance |
| Debris plate B | `res://assets/models/cc0/cars/Models/debris-plate-b.glb` | (13, 0, −7) | 0.2 | Scattered |
| Hatchback (crashed) | `res://assets/models/cc0/cars/Models/hatchback-sports.glb` | (11, 0, −12) | π/4 | Crashed into the barrier from the north |

---

### Zone D: Back Alley (N strip, z < −14)

A narrow service alley between buildings. Dumpster, debris, fire escape. Claustrophobic — a dead end.

| Model | Path | Position | Rotation | Notes |
|-------|------|----------|----------|-------|
| Dumpster | `res://assets/models/cc0/city/roads/Models/dumpster.glb` | (−14, 0, −16) | 0.3 | Overflowing |
| Fence | `res://assets/models/cc0/city/suburban/Models/fence.glb` | (−10, 0, −17) | 0.0 | Alley boundary |
| Fence low | `res://assets/models/cc0/city/suburban/Models/fence-low.glb` | (−18, 0, −16.5) | π/2 | Broken section |
| Tree large | `res://assets/models/cc0/city/suburban/Models/tree-large.glb` | (−16, 0, −18) | 0.0 | Dead tree, overhanging the alley |
| Debris plate small A | `res://assets/models/cc0/cars/Models/debris-plate-small-a.glb` | (−13, 0, −15) | 0.7 | Litter |
| Debris plate small B | `res://assets/models/cc0/cars/Models/debris-plate-small-b.glb` | (−15, 0, −14.5) | 1.2 | Litter |
| Debris bolt | `res://assets/models/cc0/cars/Models/debris-bolt.glb` | (−12.5, 0, −16) | 0.0 | Small scattered parts |
| Debris nut | `res://assets/models/cc0/cars/Models/debris-nut.glb` | (−14, 0, −15.5) | 0.0 | Small scattered parts |
| Debris drivetrain | `res://assets/models/cc0/cars/Models/debris-drivetrain.glb` | (−17, 0, −15) | 0.4 | Heavy part, unlikely to have moved far |

---

### Zone E: Parking Lot (SE quadrant, x > 8, z > 10)

An open asphalt lot behind the eastern shops. Cars frozen mid-evacuation. Open sightlines — a dangerous fight area.

| Model | Path | Position | Rotation | Notes |
|-------|------|----------|----------|-------|
| SUV | `res://assets/models/cc0/cars/Models/suv.glb` | (12, 0, 14) | 0.2 | Parked, doors closed |
| Van | `res://assets/models/cc0/cars/Models/van.glb` | (18, 0, 16) | π − 0.3 | Facing the exit, engine off |
| Sedan sports | `res://assets/models/cc0/cars/Models/sedan-sports.glb` | (16, 0, 12) | π/4 | Diagonal parking |
| Firetruck | `res://assets/models/cc0/cars/Models/firetruck.glb` | (20, 0, 18) | π/2 | Emergency vehicle, lights off |
| Trash truck | `res://assets/models/cc0/cars/Models/garbage-truck.glb` | (14, 0, 18) | 0.0 | Overturned bin beside it |

---

### Zone F: Town Plaza (Center-South, −8 < x < 8, −2 < z < 12)

A small open square with benches and a central monument. The social heart of the town, now empty. Good for wave fights — open sightlines, benches for cover.

| Model | Path | Position | Rotation | Notes |
|-------|------|----------|----------|-------|
| Bench 1 (overturned) | Procedural (box + cylinder) | (−4, 0, 4) | 0.5 | Tipped on its side |
| Bench 2 | Procedural (box + cylinder) | (5, 0, 6) | −0.3 | Upright but weathered |
| Bench 3 | Procedural (box + cylinder) | (0, 0, 8) | π/2 | Facing the monument |
| Tree small | `res://assets/models/cc0/city/suburban/Models/tree-small.glb` | (−6, 0, 2) | 0.0 | Planter tree |
| Tree small 2 | `res://assets/models/cc0/city/suburban/Models/tree-small.glb` | (7, 0, 3) | 0.0 | Planter tree |
| Planter | `res://assets/models/cc0/city/suburban/Models/planter.glb` | (−2, 0, 6) | 0.0 | Intact |
| Planter (overturned) | `res://assets/models/cc0/city/suburban/Models/planter.glb` | (4, 0, 5) | π/2 | Soil spilled |
| Path stones | `res://assets/models/cc0/city/suburban/Models/path-stones-messy.glb` | (0, 0, 5) | 0.0 | Worn footpath through the plaza |

---

### Zone G: Residential Edge (S strip, z > 16)

Suburban-style houses at the town's edge. Fences, driveways, trees. Transition to the residential neighbourhood beyond.

| Model | Path | Position | Rotation | Notes |
|-------|------|----------|----------|-------|
| House type A | `res://assets/models/cc0/city/suburban/Models/building-type-a.glb` | (−10, 0, 22) | 0.0 | Small house |
| House type B | `res://assets/models/cc0/city/suburban/Models/building-type-b.glb` | (−2, 0, 24) | 0.1 | Small house |
| House type C | `res://assets/models/cc0/city/suburban/Models/building-type-c.glb` | (6, 0, 22) | −0.1 | Small house |
| Driveway long | `res://assets/models/cc0/city/suburban/Models/driveway-long.glb` | (−10, 0, 19) | 0.0 | Leading to house A |
| Driveway short | `res://assets/models/cc0/city/suburban/Models/driveway-short.glb` | (6, 0, 19) | 0.0 | Leading to house C |
| Fence run | `res://assets/models/cc0/city/suburban/Models/fence.glb` | (−6, 0, 20) | π/2 | Between properties |
| Fence 1×4 | `res://assets/models/cc0/city/suburban/Models/fence-1x4.glb` | (2, 0, 20) | π/2 | Garden boundary |
| Tree large | `res://assets/models/cc0/city/suburban/Models/tree-large.glb` | (−14, 0, 24) | 0.0 | Mature tree |
| Tree small | `res://assets/models/cc0/city/suburban/Models/tree-small.glb` | (10, 0, 24) | 0.0 | Young tree |

---

### Zone H: West End / Spawn Area (x < −15, −10 < z < 10)

The player's spawn zone. Open, safe, with a clear view east down Main Street. The church is visible to the west.

| Model | Path | Position | Rotation | Notes |
|-------|------|----------|----------|-------|
| Road end | `res://assets/models/cc0/city/roads/Models/road-end.glb` | (−19, 0, −4) | 0.0 | Main road terminates here |
| Barrier | `res://assets/models/cc0/city/roads/Models/construction-barrier.glb` | (−18, 0, −4) | 0.2 | Partially blocking the road end |
| Crate (procedural) | `scenes/world/props/crate.tscn` | (−16, 0, 0) | 0.3 | Near the spawn, cover |
| Barrel (procedural) | `scenes/world/props/barrel.tscn` | (−17, 0, 2) | 0.0 | Near the spawn, cover |

---

## 3. Road / Ground Plan

### What happens to the current flat Floor

The current 60×60 flat Floor (BoxMesh 60×0.3×60) stays as the **ground plane** — it is the collision base and the visual ground for areas not covered by road models. Its material should be changed from the current brown (0.16, 0.15, 0.13) to a dark asphalt/earth mix: `Color(0.12, 0.12, 0.13)` with the cobblestone texture from `res://assets/textures/cobblestone.jpg` at uv1_scale (14, 14, 14).

### Road model tiling

The current LevelDetail.gd builds the road as procedural asphalt boxes with dashed lines. This should be **replaced** by actual road models from the city kit, placed on top of the ground plane at y = 0.02.

**Main Road (east–west, z = −4, length 38 m):**
- 5× `road-straight.glb` end-to-end, each ~7.6 m long, at x = −19, −11.4, −3.8, 3.8, 11.4, z = −4, y = 0.02, rotation 0
- 1× `road-crossroad.glb` at x = 11, z = −4 (the intersection)
- 1× `road-end.glb` at x = −19.5, z = −4 (west end)
- 1× `road-end.glb` at x = 19.5, z = −4, rotation π (east end)

**Cross Road (north–south, x = 11, length 24 m):**
- 3× `road-straight.glb` end-to-end, each ~8 m long, at x = 11, z = −14, −6, 2, y = 0.02, rotation π/2
- 1× `road-crossroad.glb` at x = 11, z = −4 (shared with main road)
- 1× `road-end.glb` at x = 11, z = −16, rotation π/2 (north end)
- 1× `road-end.glb` at x = 11, z = 8, rotation −π/2 (south end)

**Sidewalks:** Keep the current procedural sidewalks from LevelDetail.gd — they are simple light-grey slabs that work well and do not need a model replacement.

**Driveway connections:**
- `road-driveway-single.glb` at (−22, 0.02, 12) rotation 0 — Corner Store loading zone
- `road-driveway-double.glb` at (5, 0.02, 17) rotation 0 — Building4 rear access

### Road surface materials

All road models from the Kenney city kit come with their own asphalt materials. No override needed. The procedural dashed centre-line markings from LevelDetail.gd can be removed — the road models include their own lane markings.

---

## 4. Interactive Content

### Pickups (already handled by FoodSpawner.gd)

The game.tscn already has a FoodSpawner node that spawns food pickups (burger, soda, pizza, fries, sushi, takis, medkit, coffee, battery, ammo) around the player at 4.5 s intervals, max 8 active. **No static food placement needed** — the spawner handles it. The spawn radius is 12 m from the player, which is fine for the open street layout.

### Weapon pickups (manual placement)

Place 3 weapon pickups at fixed locations. Each is an Area3D with a WeaponPickup script and a weapon model mesh.

| Weapon | Model | Position | weapon_id | Rationale |
|--------|-------|----------|-----------|-----------|
| Bat | `res://assets/models/weapon_bat.glb` | (−16, 0.5, −2) | `"bat"` | Near spawn — tutorial pickup |
| Axe | `res://assets/models/weapon_axe.glb` | (−20, 0.5, 14) | `"axe"` | At the Corner Store — rewards exploration |
| Knife | `res://assets/models/weapon_knife.glb` | (14, 0.5, 14) | `"knife"` | In the Parking Lot — risky pickup |

### Power-ups (already handled by PowerUpManager.gd)

The game.tscn already has a PowerUpManager that spawns power-ups (health, speed, damage, shield, frenzy) every 15 s, max 3 active. **No static placement needed.**

### Objectives (already handled by ObjectiveManager.gd)

Game.gd._setup_objectives() adds two objectives for every level:
- `"eat_food"` — "Eat to stay alive", target 3
- `"survive"` — "Survive the shift", target 1

**No additional static objectives needed for level 1.** The tutorial objectives are sufficient.

### Interactive props (already in the scene)

The current old_town_enhanced.tscn already has an `Interactive` section with:
- `HouseProp` — a house with an interactive door, wall, food crate, and stairs
- `OldCart` — an overturned cart with wheels and a door
- `FoodCrate` — a crate with an interaction zone

**Keep these.** They are the tutorial's interactive teaching props. The FoodCrate should be moved from its current position to the Plaza (Zone F) at (0, 0, 7) so it is visible from the spawn point.

### FoodSpawner nodes

The current scene has 5 FoodSpawner nodes under `Interactive/`. The game.tscn has its own FoodSpawner. **Remove the 5 from the level scene** — they are redundant and conflict with the game-level spawner.

---

## 5. Lighting / Atmosphere

### WorldEnvironment

The current WorldEnvironment in old_town_enhanced.tscn has:
- `background_mode = 1` (color)
- `background_color = Color(0.05, 0.06, 0.09)` — near-black blue
- `ambient_light_source = 0` (no ambient)
- `ambient_light_energy = 0.3`
- `fog_enabled = true`
- `fog_light_color = Color(0.08, 0.09, 0.12)` — dark blue-grey
- `fog_density = 0.018`
- `tonemap_mode = 2` (ACES)

**Recommended changes for dusk outbreak mood:**
- `background_color = Color(0.12, 0.10, 0.14)` — slightly warmer, purple-grey dusk
- `ambient_light_source = 2` (color) — use a flat ambient color instead of a sky gradient
- `ambient_light_color = Color(0.18, 0.16, 0.22)` — dim purple ambient
- `ambient_light_energy = 0.4`
- `fog_light_color = Color(0.15, 0.12, 0.18)` — warm-grey fog, dusk haze
- `fog_density = 0.022` — slightly thicker for atmosphere
- `tonemap_mode = 2` (ACES) — keep, it handles the warm/cool contrast well
- Add `glow_enabled = true`, `glow_intensity = 0.6`, `glow_bloom = 0.15` — for the ambulance lights, construction light, and any emissive windows

### Directional light (sun/moon)

The game.tscn has a DirectionalLight3D at (10, 15, 8) with:
- `light_color = Color(0.62, 0.68, 0.92)` — cool blue
- `light_energy = 2.35`
- `shadow_enabled = true`

**Recommended changes:**
- `light_color = Color(0.9, 0.7, 0.55)` — warm dusk sun, low angle
- `light_energy = 1.8` — dimmer, the sun is setting
- Rotate to come from the west (behind the player at spawn): transform rotation to face east, so shadows point toward the camera — dramatic backlighting

### Street lamps

Each `light-curved.glb` model placement gets an OmniLight3D child:
- `light_color = Color(1.0, 0.8, 0.5)` — warm sodium vapour
- `light_energy = 1.6`
- `omni_range = 7.0`
- Position at (0, 3.0, 0) relative to the lamp model

### Construction light

The `construction-light.glb` at (14, 0, −3) gets:
- OmniLight3D, `light_color = Color(1.0, 0.5, 0.1)` — amber
- `light_energy = 2.0`
- `omni_range = 8.0`
- Animate with a sin wave in `_process` for a flashing effect (if a script is attached)

### Ambulance

The `ambulance.glb` at (16, 0, −8) gets:
- Two OmniLight3D children: red (1.0, 0.1, 0.1) and blue (0.1, 0.2, 1.0)
- `light_energy = 1.2`, `omni_range = 5.0`
- Alternating flash pattern (red/blue strobe) — this is the level's focal point

### Fog sphere

The current scene has a fog sphere (SphereMesh radius 40, transparent material). **Remove it** — the WorldEnvironment fog is sufficient and the sphere creates a visible edge.

---

## 6. Build Order (Prioritised)

### Phase 1: Biggest visual win (do first)
1. **Replace all 6 primitive buildings with commercial building models** — this is the single biggest visual upgrade. The models are on disk, the placement is specified above.
2. **Replace the 3 primitive cars with real car models** — the sedan, taxi, and police car on Main Street.
3. **Replace the 5 primitive street lamps with light-curved.glb models** + add OmniLight3D children.
4. **Remove the flat Floor's brown material** — apply the cobblestone texture.
5. **Remove the fog sphere** from the scene.

### Phase 2: Street dressing
6. **Add road models** — tile road-straight.glb along Main Street and the cross road, add road-crossroad.glb at the intersection, road-end.glb at the termini.
7. **Add construction zone props** — barriers, cones, ambulance in the NE quadrant.
8. **Add parked cars** — delivery van at the Corner Store, SUV/van/sedan-sports in the Parking Lot.
9. **Add traffic light, stop sign, warning sign, electricity pole** at the intersection.
10. **Add backdrop ring** — 8–10 skyscraper/low-detail-building models around the arena edge.

### Phase 3: Detail & interactivity
11. **Add debris scattered props** — debris-door, debris-bumper, debris-tire, debris-plate-*, debris-bolt, debris-nut in the Back Alley and Construction Zone.
12. **Add dumpster, fences, trees** in the Back Alley and Residential Edge.
13. **Add suburban houses** at the Residential Edge (S strip).
14. **Add benches, planters, path stones** in the Plaza.
15. **Place 3 weapon pickups** (bat, axe, knife).
16. **Move FoodCrate** to the Plaza.
17. **Remove the 5 redundant FoodSpawner nodes** from the level scene.

### Phase 4: Atmosphere
18. **Update WorldEnvironment** — dusk fog, ambient color, glow settings.
19. **Update DirectionalLight3D** — warm dusk sun from the west.
20. **Add OmniLight3D children** to all street lamps, the construction light, and the ambulance.
21. **Add flashing animation** to the ambulance and construction light (simple sin-wave in _process, or a small script).

---

## 7. Out of Scope (This Pass)

Explicitly **NOT** doing in this pass:
- **Board-up storefront windows** — no plywood-board model exists on disk. The buildings have their own windows; boarding them requires a new asset (see §8).
- **Animated doors / opening shop fronts** — the InteractiveDoor.gd script exists but no building model has a separate door mesh. Doors are painted on the building textures.
- **Interior spaces** — all buildings are solid. No enterable interiors.
- **Dynamic weather** — the WeatherSystem.gd exists in game.tscn but level 1 uses clear dusk, not rain.
- **Day/night cycle progression** — level 1 starts at dusk and stays there. The DayNightCycle.gd exists but is not active for level 1.
- **Zombie spawn point markers** — the ZombieSpawner3D.gd handles spawning procedurally; no visual spawn indicators are placed.
- **Objective waypoint markers** — the ObjectiveManager tracks objectives in the HUD; no 3D waypoint beacons are placed.
- **Minimap** — does not exist in the project.
- **Destructible props** — no destructible prop system exists.
- **Blood decals** — the floor_blood.png texture exists in LevelDetail.gd but placing 3D blood decals in the level scene is not part of this pass.
- **Graveyard props** — gravestone models exist but level 1 is a town, not a cemetery. Those are for level 2.

---

## 8. Still Missing (Shopping List for Phase 2)

These assets do **not** exist on disk and are needed for a complete level 1. Each entry says what it is, why it is needed, and a suggested open-licence source.

### 8.1 Boarded storefront windows (plywood boards)
- **What:** Thin box meshes or textured planes that overlay building windows to read as "boarded up."
- **Why:** The art direction calls for "boarded storefronts." The commercial building models have clean windows; boarding them is essential to the "people fled in a hurry" story.
- **Suggested source:** Kenney's "City Kit Commercial" has `detail-awning.glb` and `detail-overhang.glb` (already on disk), but no board model. A simple plywood-board plane can be generated procedurally as a BoxMesh with a wood texture (the project already has `res://assets/textures/wood_planks.jpg`). **No download needed** — make it from existing assets.
- **Priority:** High. Biggest remaining visual gap.

### 8.2 Bench model
- **What:** A park bench 3D model.
- **Why:** The current benches are procedural box+cylinder assemblies. A real bench model with slats, armrests, and legs would read much better in the Plaza.
- **Suggested source:** Kenney's "City Kit Roads" or "City Kit Suburban" may have a bench in a future pack. Alternatively, Kenney's "Nature Kit" has park benches. **CC0 licence.** Check https://kenney.nl/assets for "Park Kit" or "City Kit."
- **Priority:** Medium. The procedural benches are functional but plain.

### 8.3 Fire hydrant model
- **What:** A small fire hydrant 3D model.
- **Why:** The current hydrant is a procedural cylinder+sphere assembly at NearStreetHydrant. A real hydrant model would be a nice street-level detail.
- **Suggested source:** Kenney's "City Kit Roads" has `road-sign-*` and `construction-*` but no hydrant. Check Kenney's "City Kit Commercial" or generate from primitives. **CC0 licence.**
- **Priority:** Low. The procedural hydrant is adequate.

### 8.4 Mailbox model
- **What:** A USPS-style mailbox 3D model.
- **Why:** The current mailbox is a procedural box+post at NearStreetMailbox. A real mailbox model would add street-level authenticity.
- **Suggested source:** Kenney's "City Kit Roads" or "City Kit Suburban." Check https://kenney.nl/assets. **CC0 licence.**
- **Priority:** Low. The procedural mailbox is adequate.

### 8.5 "Muakbank" sign / billboard
- **What:** A textured plane or extruded text reading "MUAKBANK" for the largest building.
- **Why:** The game is called "Muakbank Zombie" — the bank is the fictional institution the zombies are trying to break into (per LevelDetail.gd, "the Muakbank counter — the bank the horde wants to break into"). A visible sign on the largest building (Building5, the 16×14×16 block) would reinforce the fiction.
- **Suggested source:** Generate with Godot's `Label3D` or a `TextMesh` — no download needed. Use the SpecialElite font already in the project.
- **Priority:** Medium. Strong narrative payoff for zero asset cost.

### 8.6 Open car door (for the taxi)
- **What:** A car door mesh posed open, attached to the taxi model.
- **Why:** The art direction calls for "a car door left open." The car models have closed doors. An open door would sell the "fled in a hurry" story.
- **Suggested source:** Use `debris-door.glb` (already on disk) — it is a car door mesh. Attach it to the taxi at an angle. **No download needed.**
- **Priority:** High. Cheap to do with existing assets.

### 8.7 Wrecked / burnt car variant
- **What:** A car model with a burnt or damaged material override.
- **Why:** The art direction mentions "abandoned cars at odd angles." A burnt-out car husk would add variety beyond clean parked cars.
- **Suggested source:** Take any car model on disk (e.g., `sedan.glb`) and apply a dark, charred StandardMaterial3D override (albedo near-black, roughness 1.0). **No download needed.**
- **Priority:** Medium. Adds visual variety.

### 8.8 Street blood splatter decals
- **What:** 3D quad decals with the floor_blood.png texture, placed at key story points.
- **Why:** LevelDetail.gd already uses floor_blood.png for the cemetery. Placing a few in Old Town — at the ambulance, the Corner Store door, the Construction Zone — would sell the outbreak story.
- **Suggested source:** The texture already exists at `res://assets/textures/floor_blood.png`. Place as QuadMesh instances rotated flat on the ground. **No download needed.**
- **Priority:** High. Cheap, high narrative impact.

### 8.9 Trash / litter scatter models
- **What:** Small paper, can, and trash bag models.
- **Why:** The Back Alley and Construction Zone need fine-grained debris to read as "littered." The current debris plates and panels are car parts, not household trash.
- **Suggested source:** Kenney's "City Kit Roads" has `dumpster.glb` (already on disk) but no loose trash. Use PropScatter.gd with a small box mesh and a paper-like material for scatter. **No download needed** — generate procedurally.
- **Priority:** Medium. The car debris is sufficient for the main areas; trash scatter is a finishing touch.

### 8.10 Awning collapse variant
- **What:** An awning model posed as partially collapsed or torn.
- **Why:** The Corner Store's awning should read as "torn" (per the story). The `detail-awning.glb` model is a clean awning. A collapsed variant would sell the damage.
- **Suggested source:** Use `detail-awning.glb` with a rotation.z tilt of ~0.3 and a scale.y of 0.7 to fake a sag. **No download needed.**
- **Priority:** Low. A tilted clean awning reads as damaged enough at gameplay distance.

---

## 9. Distinct Model Count

The plan uses **66 distinct .glb model files** from the asset tree:

**Commercial buildings (6):** building-a, building-b, building-c, building-d, building-e, building-f
**Skyscrapers / backdrop (5):** building-skyscraper-a, building-skyscraper-b, building-skyscraper-c, low-detail-building-a, low-detail-building-b
**Awnings / details (3):** detail-awning, detail-overhang, detail-parasol-a
**Roads (3):** road-straight, road-crossroad, road-end
**Driveways (2):** road-driveway-single, road-driveway-double
**Cars (11):** sedan, taxi, police, delivery, ambulance, hatchback-sports, suv, van, sedan-sports, firetruck, garbage-truck
**Construction (4):** construction-barrier, construction-cone, construction-fence, construction-light
**Cones (2):** cone, cone-flat
**Street props (6):** light-curved, traffic-light, road-sign-stop, road-sign-warning, electricity-pole, electricity-wires
**Suburban (10):** building-type-a, building-type-b, building-type-c, driveway-long, driveway-short, fence, fence-1x4, tree-large, tree-small, planter
**Debris (10):** debris-door, debris-bumper, debris-tire, debris-plate-a, debris-plate-b, debris-plate-small-a, debris-plate-small-b, debris-bolt, debris-nut, debris-drivetrain
**Paths (1):** path-stones-messy
**Weapon pickups (3):** weapon_bat, weapon_axe, weapon_knife

**Total: 66 distinct .glb files** (some used in multiple instances).

---

## 10. Summary

- **Zones:** 8 named zones (Main Street, Corner Store, Construction Zone, Back Alley, Parking Lot, Town Plaza, Residential Edge, West End/Spawn)
- **Distinct models:** 66 .glb files from the existing asset tree
- **Missing assets:** 10 items on the shopping list, of which 7 can be built from existing project assets with no download needed
- **Build phases:** 4 phases, ordered by visual impact
- **Out of scope:** 10 explicit exclusions to keep the pass focused
