---
title: Asset Pipeline — Folder Contract
tags: [muakbank-zombie, pipeline, blender, assets, contract]
date: 2026-11-15
---

# Asset Pipeline — Folder Contract

This is the single source of truth for **which folder each stage reads and
writes**. The pipeline described in the vault protocol
(`muakbank-pipeline-protocol.md`, 4 stages) is:

```
2D concept / exploded diagram  ->  JSON payload  ->  Blender refine / bake  ->  game
        (01)                         (02)                  (03)              (04 / repo assets)
```

## Stage map

| # | Stage | Produces | Folder (repo-relative) | Consumed by |
|---:|---|---|---|---|
| 1 | Exploded diagrams / 2D concept | part tables, dimension specs, reference sheets (`.md`, `.png`) | `assets/sources/01-exploded-diagrams/` | stage 2 |
| 2 | JSON payload (SOP schema) | `asset_id`, `category`, `dimensions_m`, `materials`, `export_target` | `assets/sources/02-payloads/` | stage 3 (`--payload`) |
| 3 | Blender refine / bake / render verify | `.blend` sources, PBR bakes | `assets/sources/03-blender/` | stage 4 |
| 4 | Downloaded CC0 source packs | `.zip` (Kenney kits), licenses | `assets/sources/04-downloaded-packs/` | stage 3 (input geometry) |
| 4→game | `tools/aggy_blender_pipeline.py` | `.glb`, `.png`, `.png.import`, `.tres` | see below | Godot project |

## The Blender → game delivery contract (stage 4 output)

`blender -b -P tools/aggy_blender_pipeline.py -- --payload <payload.json>` writes:

| Artifact | Destination | Notes |
|---|---|---|
| `<asset_id>.glb` | `assets/models/` | `export_target` in the payload (default `assets/models`) |
| `<asset_id>.png` (albedo) | `assets/textures/` | plus `<asset_id>.png.import` Godot metadata |
| `<asset_id>_preview.png` + multi-angle renders | `assets/textures/` | render verification |
| `<asset_id>_<slot>.tres` | `assets/materials/` | StandardMaterial3D |

The script ends by printing `DIR_MAPPING_OK=True/False` — a per-artifact
existence check across all three folders. A run is only accepted when it is
`True`.

## Folder root rule (fixed 2026-11-15)

`REPO_ROOT` is derived from `tools/aggy_blender_pipeline.py`'s own location
(`os.path.dirname(os.path.dirname(os.path.abspath(__file__)))`), NOT hardcoded.
Previously `main()` used a script-derived root while `write_tres()` /
`write_import()` used a hardcoded `/root/muakbank_zombie` constant; moving the
checkout (CI, another host, git worktree) would silently split GLBs from their
materials. One root, one folder contract now.

## Where things are NOT

- **Obsidian vault** = review surface only: PNG previews + asset sheets. No
  `.glb`, `.blend`, `.zip`. See `muakbank_zombie/GLB_ASSET_LIBRARY/`.
- **Repo `assets/sources/`** = working sources for created + downloaded assets.
  It carries a `.gdignore` so Godot's filesystem scan skips the whole tree.
  WITHOUT it, Godot tries to import the `.blend` sources and fails headless
  ("Blender path is invalid or not set... Cannot configure blender path in
  headless mode"), which breaks `regression_smoke.sh`'s fresh-import gate.
  These are pipeline INPUTS, never game assets.
- **Repo `assets/models|textures|materials/`** = the game-facing outputs Godot
  actually loads. These are the "appropriate folder" the pipeline delivers to.

## Verification (2026-11-15)
- Ran `blender -b -P tools/aggy_blender_pipeline.py -- --payload
  assets/sources/02-payloads/aggy_final_payload.json`: `DIR_MAPPING_OK=True`,
  all four artifacts present in `assets/models/`, `assets/textures/` (incl.
  `.png.import`), `assets/materials/`.
- `regression_smoke.sh` PASS 5/5; `validate_project.py` ISSUES 0.
- Fixed: hardcoded `REPO_ROOT`; `.import` -> `.png.import` filename contract
  (matching Godot + shipped files); `.gdignore` for the source tree.

## Scale / type invariants carried through the pipeline
- 1 Blender unit = 1 metre; `scene.unit_settings` METRIC + `scale_length=1.0`.
- Godot imports `.glb` with `nodes/root_scale=1.0`; never add a compensating scale.
- `export_yup=True`; dimension-exact categories assert `obj.dimensions == dimensions_m`.
- glTF params pinned to Blender 4.0.2 RNA (`global_scale` / `apply_unit_scale`
  do not exist in that build).
