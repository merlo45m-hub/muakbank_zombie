# Explorable Interior Modeling — Guidelines (Issue #8)

Captured from the game-refinement note on issue #8 and reconciled against the
current asset pipeline (`tools/aggy_blender_pipeline.py`, Godot 4.7 mobile).

## The four points

### 1. Separate manifold meshes for shell and rooms
Model the building's **outer shell** and **inner rooms** as separate, closed
(manifold) meshes, each with real wall thickness — not single-sided planes.

Why: a single inflated shell gives no interior collision or occlusion; separate
manifold volumes let Godot's physics and culling treat walls, floors and rooms
independently. Thin (zero-thickness) walls also break lightmap UVs and shadows.

### 2. Face normals must point inward for the interior
For the room meshes, flip normals so they face **into** the room. Blender's
backface culling and Godot's default single-sided material will otherwise render
the interior as invisible from inside.

Practical check: in Blender, `Mesh > Normals > Recalculate Outside` gives outward
normals for the shell; for interior room meshes use **Recalculate Inside** (or flip
the shell result). Verify in Godot by standing inside the room with a camera —
if walls vanish, normals are still outward.

### 3. Balance detail against polygon count
This is a **mobile** target (Android, mobile renderer). Do not spend triangles on
sub-1-pixel detail. Budget by screen coverage, then LOD.

- Block out rooms first with simple cubes to establish **player scale and movement**
  (below), before any bevels/trim.
- Use Godot's glTF import `meshes/generate_lods=true` (already set in the shipped
  `.glb.import` files) and `meshes/force_disable_compression=false`.
- Merge static detail into the shell where it is never seen from both sides.

### 4. Block out basic rooms with simple cubes to test player scale first
Before committing to a detailed interior, place cube volumes representing each
room and walk the player through them. Confirm door widths, ceiling height and
turn radius against the actual character dimensions. Only after that passes,
replace cubes with detailed meshes.

This connects to Issue #9.1: the pipeline now asserts `obj.dimensions ==
dimensions_m` for dimension-exact categories and pins 1 Blender unit = 1 metre,
so a cube blockout built at 2×2.5×4 m arrives in Godot at exactly 2×2.5×4 m
(verified by parsing the exported GLB bounds). Scale drift here would invalidate
the very player-scale test this guideline depends on.

## Pipeline notes (current state)
- `tools/aggy_blender_pipeline.py` builds `category` ∈ {block, building,
  structure, prop, vehicle, character}. `building`/`structure` are the categories
  to use for interior shells; they use the dimension-exact `_cube_mesh` builder.
- The pipeline exports with `export_yup=True` (glTF Y-up, Godot Y-up) and purges
  Blender's startup Cube, so no stray 2×2×2 mesh ships inside the GLB.
- Godot imports with `nodes/root_scale=1.0`; do not add a compensating scale in
  `.glb.import` — it would double-apply.

## Status
Guidance documented. This is a **design/technique note**, not a code change;
no scene or model was modified for issue #8. Detailed interior meshes (#9.2
asset replacement) are a separate, reference-driven art task.
