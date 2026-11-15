# Wooden Crate - Modular Exploded View

Created 2026-11-14 to verify the Muakbang asset pipeline: a plain-language concept should
translate into discrete, correctly counted modular components before scaling up.

![[crate_exploded_labeled.png]]

## What it proves
A one-line brief ("a wooden crate") produced 32 separately named parts that separate cleanly
and reassemble:

| Component | Count | Notes |
|---|---|---|
| Corner posts | 4 | vertical structure, dark wood |
| Side planks | 12 | 3 per face, light wood |
| Top planks | 4 | lid |
| Bottom planks | 4 | base |
| Bolts | 8 | 2 per post, metallic |

Each part is an independent object with its own name and material, so the same breakdown can be
reused as a Godot scene hierarchy or a Kenney/CC0 asset substitution list.

## How it was made
- Blender MCP on the VPS. Note: the addon refuses `blender -b`; it runs under
  `xvfb-run -a blender --python /root/blender_mcp_boot.py`, listening on 127.0.0.1:9876.
- Parts built with bpy primitives (object scale, not applied transforms - applying bakes the
  location to zero and silently collapses an explode).
- Explode: each part offset along its vector from the assembly centre.
- Callouts drawn as a 2D overlay (PIL) using `world_to_camera_view` projections, because in-scene
  3D text gets occluded and clipped at some angles.

## Verification
Vision check confirmed all five callouts are legible, inside the frame, and their leaders land on
the correct distinct parts (including the bolt callout on an actual fastener).

## Files
- Labeled diagram: `projects/assets/crate_exploded_labeled.png`
- Clean render: `projects/assets/crate_exploded_clean.png`
- Local copies: `/data/data/com.termux/files/home/assets/`
- Blender scene: `/root/crate_exploded.blend` (VPS)
