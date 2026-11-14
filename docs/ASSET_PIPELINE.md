# Asset Pipeline (Blender -> Godot)

Stage 3 and 4 of the Muakbank Zombie protocol: procedural generation in Blender, visual
verification, then transport to the repo as `.glb` + textures and registration as Godot resources.

## Where things live

| Path | Contents |
|---|---|
| `assets/models/<name>.glb` | exported model (generated in-project, no external licence) |
| `assets/models/<name>.manifest.json` | export manifest: part count, dimensions, origin convention |
| `assets/textures/<name>/` | baked maps (albedo / normal / ORM) |
| `assets/materials/<name>.tres` | Godot StandardMaterial3D linking the maps |
| `assets/models/ASSET_INVENTORY.md` | licence registry - every asset is recorded there |

Generated in-project models carry no external licence; third-party packs go to
`assets/models/downloaded/<source>/<pack>/` with their licence file (see `ASSET_INVENTORY.md`).

## Export stage

`tools/export_godot_asset.py` runs headless and does the whole stage:

```bash
blender --background --python tools/export_godot_asset.py -- \
    --blend /root/vending_machine_props.blend \
    --out  assets/models/vending_machine.glb \
    --name vending_machine
```

1. Keeps only the asset meshes (`KEEP_PREFIX`) and deletes presentation-only objects
   (annotation arrows, leader lines, floor, camera, lights) so they cannot leak into the export.
2. Applies rotation + scale, so the exported geometry is real-sized rather than carrying
   object-level scale that Godot would have to interpret.
3. Puts the origin at the bottom centre with the asset sitting on `z=0`.
4. Exports glTF with `+Y` up (Godot converts to `+Z`), materials and textures, no
   cameras/lights/animations.
5. Writes `<out>.manifest.json` with the part list and bounding box.

Verified for `vending_machine`: 57 parts, `1.134 x 2.128 x 0.835 m`, origin bottom-centre on z=0.

## Material caveat - read before adding wear

glTF only carries **image textures plugged into a Principled BSDF**. Procedural node graphs
(noise, wave, colour ramps, bump chains) are evaluated at render time in Blender and are **not
exported** - an asset using them arrives in Godot as flat base colours.

The Blender scene's wear materials (fingerprints, scratches, dust) are procedural, so:

- the `.glb` has the correct base colours, roughness and metallic values;
- the procedural wear detail is **not** in the exported model.

To carry wear into Godot, bake it first: Smart UV Project the asset meshes, then bake the
procedural result to image maps (base color, normal, roughness/ORM) with Cycles and rewire the
materials to those images before running the export script. The script exports whatever is
plugged into the Principled inputs, so baked maps flow through automatically.

## Registering a new asset

1. Run the export script; confirm the manifest's part count and dimensions.
2. Add a row to `assets/models/ASSET_INVENTORY.md` (generated in-project line for authored
   models; the pack tables for third-party downloads).
3. If the asset needs a Godot material, add `assets/materials/<name>.tres` as a
   `StandardMaterial3D` referencing the imported textures.
4. Run the pre-merge gates: `python3 tools/validate_project.py` (static) and
   `bash tools/regression_smoke.sh` (headless) before proposing a merge.
