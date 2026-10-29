# Asset Inventory & License Registry

Registry of every third-party 3D asset pack staged under `assets/`. Written to
match the tone and table style of the project-root `CREDITS.md`, which remains
the authoritative public-facing credits file.

Scope: `assets/models/cc0/` (staged third-party packs) and `assets/models/`
(generated models). Audio and texture licenses are already tracked in
`CREDITS.md`; this file covers the model packs plus the download convention for
future assets.

> **Rule:** no asset with unclear or non-permissive licensing may be added to
> this project. If a pack's license cannot be verified from a license file kept
> in its own directory, it is listed here as **UNKNOWN** and must not be relied
> on for distribution until the license is confirmed and a license file is
> added.

## Summary

| Category | .glb count | License | Source pack | Directory |
|----------|-----------:|---------|-------------|-----------|
| City — commercial | 41 | CC0 | Kenney *City Kit Commercial (2.1)* | `assets/models/cc0/city/commercial/Models/` |
| City — suburban | 40 | CC0 | Kenney *City Kit Suburban (2.0)* | `assets/models/cc0/city/suburban/Models/` |
| City — roads | 95 | CC0 | Kenney *City Kit Roads (2.1)* | `assets/models/cc0/city/roads/Models/` |
| Vehicles | 50 | CC0 | Kenney *Car Kit (3.1)* | `assets/models/cc0/cars/Models/` |
| Animated survivors | 4 | CC0 | Kenney *Animated Characters Survivors (1.1)* | `assets/models/cc0/kenney_anim/` |
| Blocky characters | 18 | **UNKNOWN** | Kenney "blocky set" *(unverified — no license file)* | `assets/models/cc0/blocks/` |
| Mini characters + aids | 21 | **UNKNOWN** | unnamed mini-character pack *(no license file)* | `assets/models/cc0/minis/` |
| Graveyard stones | 2 | **UNKNOWN** | Kenney "graveyard kit" *(unverified — no license file)* | `assets/models/cc0/kenney/` |
| Animals | 4 | **UNKNOWN** | unnamed CC0 animal models *(no license file)* | `assets/models/cc0/animals/` |
| Graveyard (glTF) | 0 (24 .gltf) | **UNKNOWN** | KayKit *Halloween Bits* *(unverified — no license file)* | `assets/models/cc0/kaykit/` |
| **Total staged .glb** | **275** | | | `assets/models/cc0/` |

Generated in-project (no external license): `assets/models/*.glb` — 13 blocky
models (`character_*.glb` ×5, `weapon_*.glb` ×3, `zombie_*.glb` ×5), built with
trimesh. See `CREDITS.md` → "3D Models".

## Per-pack licenses

Packs with a license file verified in-tree:

| Pack | Version | Author | License | Source | Directory | License file |
|------|---------|--------|---------|--------|-----------|--------------|
| City Kit Commercial | 2.1 | Kenney | CC0 | [kenney.nl](https://kenney.nl/assets/city-kit-commercial) | `assets/models/cc0/city/commercial/` | `License.txt` |
| City Kit Suburban | 2.0 | Kenney | CC0 | [kenney.nl](https://kenney.nl/assets/city-kit-suburban) | `assets/models/cc0/city/suburban/` | `License.txt` |
| City Kit Roads | 2.1 | Kenney | CC0 | [kenney.nl](https://kenney.nl/assets/city-kit-roads) | `assets/models/cc0/city/roads/` | `License.txt` |
| Car Kit | 3.1 | Kenney | CC0 | [kenney.nl](https://kenney.nl/assets/car-kit) | `assets/models/cc0/cars/` | `License.txt` |
| Animated Characters Survivors | 1.1 | Kenney | CC0 | [kenney.nl](https://kenney.nl/assets/animated-characters-survivors) | `assets/models/cc0/kenney_anim/` | `License.txt` |

All five are CC0 (public domain, no attribution required); the license files
invite — but do not require — crediting `Kenney` / `www.kenney.nl`.

Packs **without** a license file — license **UNKNOWN**, not verifiable from the
repository. Provenance notes below are hints from commit history and script
comments only; they are **not** a license determination:

| Pack / directory | .glb | Provenance hint (unverified) | Status |
|------------------|-----:|------------------------------|--------|
| `assets/models/cc0/blocks/` | 18 | Commit `45b56ec`: "authored voxel models (Kenney blocky set)" | **UNKNOWN** |
| `assets/models/cc0/minis/` | 21 | Commit `45b56ec`; "12 minis + aids" character-cast probe | **UNKNOWN** |
| `assets/models/cc0/kenney/` | 2 | `TitleBackground.gd`: "Kenney's graveyard kit stones" | **UNKNOWN** |
| `assets/models/cc0/animals/` | 4 | Commit `ce48c20`: "real animal models (dequantized)" | **UNKNOWN** |
| `assets/models/cc0/kaykit/` | 0 (24 .gltf) | `TitleBackground.gd`: "KayKit Halloween Bits" | **UNKNOWN** |

Action needed before public release: locate the license file for each UNKNOWN
pack, drop it into the pack's own directory, then update this table and the
matching section in `CREDITS.md`.

## How to add a new asset pack

1. **Pick a license-vetted source.** Only CC0, CC-BY, MIT, or similarly
   permissive licenses are acceptable. No asset with unclear or non-permissive
   licensing may be added.
2. **Place it under the download convention:**
   `assets/models/downloaded/<source>/<pack-name>/`
   - `<source>` = the site or author slug, lowercase (e.g. `kenney`,
     `kaykit`, `quaternius`, `polyhaven`, `opengameart`).
   - `<pack-name>` = the pack's own name, lowercase, hyphenated (e.g.
     `city-kit-roads`, `halloween-bits`).
   - Example: `assets/models/downloaded/kenney/city-kit-roads/`.
   - Audio and textures follow the same idea under
     `assets/downloaded/audio/<source>/<pack-name>/` and
     `assets/downloaded/textures/<source>/<pack-name>/`.
3. **Keep the license file.** Copy the pack's `License.txt` / `LICENSE` /
   `readme` into the pack's own directory, unmodified. A pack without a
   license file must not be added (or is added as **UNKNOWN** and is not
   usable until the license is supplied).
4. **Record it in two places.** Add a row to **both** this file
   (`assets/models/ASSET_INVENTORY.md` — summary table, per-pack table, and a
   category row) **and** the project-root `CREDITS.md`. Keep them in sync.
5. **Do not rename or relocate existing packs.** New downloads go to
   `downloaded/`; the existing `cc0/` packs stay where they are so current
   `res://` references keep resolving.

### Directory layout created for this convention

```
assets/
  models/
    downloaded/              # NEW — all future model pack downloads
      .gitkeep
    cc0/                     # existing staged packs (unchanged)
  downloaded/                # NEW — non-model downloads
    audio/
      .gitkeep
    textures/
      .gitkeep
```

Empty directories are held in git with `.gitkeep`.
