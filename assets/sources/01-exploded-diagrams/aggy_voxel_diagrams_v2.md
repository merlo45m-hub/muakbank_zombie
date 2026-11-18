# Canonical Character Roster — Phase 1b (VOXEL, verified species)

Supersedes aggy_exploding_diagrams.md (all identities there were [SPEC] guesses,
only 4 heroes, smooth primitives). All 10 below are BLOCKY VOXEL low-poly.

## HEROES (5 survivor humans) — pedestal lane colors
| asset_id | lane | pedestal token | hex | distinguishing props |
|---|---|---|---|---|
| hero_gamer | Gamer | accent-pink | #ff2d7b | headphones, red controller |
| hero_doctor | Doctor | clinical-blue | #6fa8ff | white lab coat, stethoscope |
| hero_nurse | Nurse | neon-cyan | #2de0ff | teal scrubs, surgical cap, syringe |
| hero_streamer | Streamer | neon-purple | #a05cff | hoodie, ring light, phone |
| hero_hunter | Hunter | accent-yellow | #ffd60a | brown jacket, baseball bat |

## ANTAGONISTS (5 voxel zombie animals)
| asset_id | species | distinguishing features |
|---|---|---|
| zombie_skeleton_dog | canine | skeletal, exposed ribs, red glowing eyes |
| zombie_dark_cat | feline | dark grey/black, green glowing eyes, curved tail |
| zombie_bear | ursine | large bipedal dark brown, glowing orange chest wound |
| zombie_skeleton_rabbit | lagomorph | bone-white, long upright ears, red eyes |
| zombie_rooster | galliform | yellow feathers, red comb, yellow eyes |

## Parts-exploded convention (all 10)
Separated cube primitives offset along +X, one mesh per part, per-part Principled
material from the palette above. Reference build verified in Blender 4.0.2:
  aggy_voxel_hero_hunter.glb  -> 10 parts (VXH_Legs/Pelvis/Torso/Arms/Hands/
     Head/Cap/Eyes/Belt/Prop_Bat)
  aggy_voxel_zombie_skeleton_dog.glb -> 10 parts (VXZ_Legs_Four/Pelvis/Torso/
     Ribcage/Head/Muzzle/Eyes_Red/Ears/Tail/Wound)
Both glTF v2, 17032 / 17196 bytes, valid glTF magic.

## Assembly order
Legs -> Pelvis -> Torso -> Arms/Hands (or Ribcage/Muzzle for animals) -> Head ->
Eyes -> accessory/prop last. Export with export_yup=True, global_scale=1.0,
apply_unit_scale=True, root_scale pinned 1.0 in .glb.import.

## Remaining
8 of 10 characters still need full Blender blockouts; only the two
representative category exemplars exist as .glb so far.
