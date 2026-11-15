# Aggy (VPS) Lane — Exploding-Diagram Specs (per distinct character)

Companion to `aggy_vision_refs.md`. Each character is broken into separated components for an exploded-view Blender scene: **head, torso, limbs, accessories, props**, with per-part proportions relative to overall height `H`, material/PBR notes (base color hex, roughness, metallic, wear), and assembly order.

> Verification: character identities/colors are `[SPEC]` draft designations (external vision fallback was HTTP 429 rate-limited and was not retried). Hex/roughness/wear values are authored production targets — legitimate spec output — to be corrected against the JPGs (see Appendix A of the refs file for a real sampled palette).

## Shared conventions
- Coordinate frame: `+Z` up, `+X` = explode axis, character faces `-Y`.
- Explode offset: `x_i = i * 0.85H`; tier stagger `z`: legs 0.30H, pelvis 0.55H, torso 0.85H, head 1.25H, accessories 1.45H, props 1.70H (relative offsets, decorative).
- Guide visuals: thin emissive dashed curves `#6E7A80` from each part back to its assembled anchor; floating `Text` objects labelled with part name, size 0.08H, facing camera.
- Material library (Principled BSDF): all parts `metallic = 0.0` unless noted; subsurface 0 for cloth/wood, 0.08 for skin/flesh. Wear = edge-darkening via AO/curvature + chipped normal detail; no texture maps required at blockout stage.
- Primitives: `UV_SPHERE` (heads/eyes), tapered `CUBE`/beveled box (torso/pelvis), `CYLINDER` (limbs), `CONE` (horns/beaks/ears), `TORUS` (collars/rings), `CUBE` (props).
- Assembly is bottom-up: pelvis -> legs -> torso -> arms -> head -> muzzle -> eyes -> ears/horns -> tail -> accessories -> props.

## Character roster
Heroes: **P1 Chicken, P2 Pig, P3 Cow, P4 Dog**. Antagonists: **Z1 Undead chicken, Z2 Undead pig butcher, Z3 Undead bull brute, Z4 Undead dog crawler, Z5 Boss Gravedigger (undead bear)**.

---

# HEROES (4)

## P1 — Chicken

- Overall height `H` (normalized). Silhouette: small round biped, large head, thin legs
- Explode convention: parts separated along **+X** at `x = i * 0.85H` (i = part index), staggered `z` per tier, with dashed guide curves + floating text labels. Assembly order is the reverse of explode offset.

| # | Component | Primitive | Count | Size (% of H) | Base color | Rough | Metal | Wear / notes |
|---|-----------|-----------|-------|--------------|------------|-------|-------|--------------|
| 0 | Pelvis / hips | beveled CUBE | 1 | 12% W x 14% H | `#E8A13C` | 0.85 | 0 | cloth seam, slight rot shadow |
| 1 | Torso | tapered CUBE | 1 | 30% W x 34% H | `#F5ECD8` | 0.75 | 0 | belly tone shift, edge wear |
| 2 | Head / skull | UV_SPHERE | 1 | 26% dia | `#F5ECD8` | 0.60 | 0 | cel 2-tone, cheek blush |
| 3 | Muzzle / beak / snout | UV_SPHERE or CONE | 1 | 10% dia | `#E8A13C` | 0.65 | 0 | nostril/beak tip highlight |
| 4 | Eyes | UV_SPHERE | 2 | 5% dia each | `#2A2A2E` | 0.25 | 0 | white specular dot `#FFFFFF` |
| 5 | Ears / comb / horns | CONE | 2 | 10% H each | `#E23D28` | 0.70 | 0 | asymmetric chip |
| 6 | Upper arms | CYLINDER | 2 | 7% dia x 16% H | `#F5ECD8` | 0.75 | 0 | shoulder crease |
| 7 | Lower arms / hands | CYLINDER + sphere | 2 | 7% dia x 14% H | `#F5ECD8` | 0.75 | 0 | mitten-hand rounding |
| 8 | Upper legs | CYLINDER | 2 | 9% dia x 18% H | `#F5ECD8` | 0.80 | 0 | knee seam |
| 9 | Lower legs / feet | CYLINDER + box | 2 | 9% dia x 16% H | `#E8A13C` | 0.80 | 0 | hoof/foot cap darker |
| 10 | Tail | CONE / curve | 1 | 14% H | `#E8A13C` | 0.75 | 0 | tuft tip highlight |
| 11 | Comb + wattle | CONE | 3 | 8% H | `#E23D28` | 0.70 | 0 | serrated comb crest |
| 12 | Prop: none / optional slingshot | CUBE | 1 | 12% H | `#8B5A2B` | 0.80 | 0 | wood grain |

**Assembly order:** 1 pelvis -> 2 upper/lower legs + feet -> 3 torso -> 4 upper + lower arms -> 5 head -> 6 muzzle -> 7 eyes -> 8 ears/comb/horns -> 9 tail -> 10 accessory -> 11 prop (align to hand anchor).

**PBR notes:** Primary `#F5ECD8` roughness 0.70-0.80 (matte fur/plumage), secondary `#E8A13C` 0.65-0.80, eye 0.25 for wet specular, accessory `#E23D28` 0.40-0.55 (leather/cloth), prop `#C9C2A6` metallic 0.0-0.35. Wear: chipped silhouette edges, 1-2 scuff patches, cooler moon rim `#AEC6D8`.

## P2 — Pig

- Overall height `H` (normalized). Silhouette: round stocky biped, prominent snout
- Explode convention: parts separated along **+X** at `x = i * 0.85H` (i = part index), staggered `z` per tier, with dashed guide curves + floating text labels. Assembly order is the reverse of explode offset.

| # | Component | Primitive | Count | Size (% of H) | Base color | Rough | Metal | Wear / notes |
|---|-----------|-----------|-------|--------------|------------|-------|-------|--------------|
| 0 | Pelvis / hips | beveled CUBE | 1 | 12% W x 14% H | `#C96F82` | 0.85 | 0 | cloth seam, slight rot shadow |
| 1 | Torso | tapered CUBE | 1 | 30% W x 34% H | `#F2A9B8` | 0.75 | 0 | belly tone shift, edge wear |
| 2 | Head / skull | UV_SPHERE | 1 | 26% dia | `#F2A9B8` | 0.60 | 0 | cel 2-tone, cheek blush |
| 3 | Muzzle / beak / snout | UV_SPHERE or CONE | 1 | 10% dia | `#C96F82` | 0.65 | 0 | nostril/beak tip highlight |
| 4 | Eyes | UV_SPHERE | 2 | 5% dia each | `#2A2A2E` | 0.25 | 0 | white specular dot `#FFFFFF` |
| 5 | Ears / comb / horns | CONE | 2 | 10% H each | `#B03A2E` | 0.70 | 0 | asymmetric chip |
| 6 | Upper arms | CYLINDER | 2 | 7% dia x 16% H | `#F2A9B8` | 0.75 | 0 | shoulder crease |
| 7 | Lower arms / hands | CYLINDER + sphere | 2 | 7% dia x 14% H | `#F2A9B8` | 0.75 | 0 | mitten-hand rounding |
| 8 | Upper legs | CYLINDER | 2 | 9% dia x 18% H | `#F2A9B8` | 0.80 | 0 | knee seam |
| 9 | Lower legs / feet | CYLINDER + box | 2 | 9% dia x 16% H | `#C96F82` | 0.80 | 0 | hoof/foot cap darker |
| 10 | Tail | CONE / curve | 1 | 14% H | `#C96F82` | 0.75 | 0 | tuft tip highlight |
| 11 | Neckerchief | TORUS / cone | 1 | 8% H | `#B03A2E` | 0.85 | 0 | knotted cloth fold |
| 12 | Prop: frying pan | CUBE + cylinder | 1 | 20% H | `#4A4A52` | 0.35 | 0.35 | worn pan, dark handle |

**Assembly order:** 1 pelvis -> 2 upper/lower legs + feet -> 3 torso -> 4 upper + lower arms -> 5 head -> 6 muzzle -> 7 eyes -> 8 ears/comb/horns -> 9 tail -> 10 accessory -> 11 prop (align to hand anchor).

**PBR notes:** Primary `#F2A9B8` roughness 0.70-0.80 (matte fur/plumage), secondary `#C96F82` 0.65-0.80, eye 0.25 for wet specular, accessory `#B03A2E` 0.40-0.55 (leather/cloth), prop `#8B5A2B` metallic 0.0-0.35. Wear: chipped silhouette edges, 1-2 scuff patches, cooler moon rim `#AEC6D8`.

## P3 — Cow

- Overall height `H` (normalized). Silhouette: tallest, broad square torso, horns + bell
- Explode convention: parts separated along **+X** at `x = i * 0.85H` (i = part index), staggered `z` per tier, with dashed guide curves + floating text labels. Assembly order is the reverse of explode offset.

| # | Component | Primitive | Count | Size (% of H) | Base color | Rough | Metal | Wear / notes |
|---|-----------|-----------|-------|--------------|------------|-------|-------|--------------|
| 0 | Pelvis / hips | beveled CUBE | 1 | 12% W x 14% H | `#2B2B30` | 0.85 | 0 | cloth seam, slight rot shadow |
| 1 | Torso | tapered CUBE | 1 | 30% W x 34% H | `#F0EDE2` | 0.75 | 0 | belly tone shift, edge wear |
| 2 | Head / skull | UV_SPHERE | 1 | 26% dia | `#F0EDE2` | 0.60 | 0 | cel 2-tone, cheek blush |
| 3 | Muzzle / beak / snout | UV_SPHERE or CONE | 1 | 10% dia | `#2B2B30` | 0.65 | 0 | nostril/beak tip highlight |
| 4 | Eyes | UV_SPHERE | 2 | 5% dia each | `#2A2A2E` | 0.25 | 0 | white specular dot `#FFFFFF` |
| 5 | Ears / comb / horns | CONE | 2 | 10% H each | `#D9A441` | 0.70 | 0 | asymmetric chip |
| 6 | Upper arms | CYLINDER | 2 | 7% dia x 16% H | `#F0EDE2` | 0.75 | 0 | shoulder crease |
| 7 | Lower arms / hands | CYLINDER + sphere | 2 | 7% dia x 14% H | `#F0EDE2` | 0.75 | 0 | mitten-hand rounding |
| 8 | Upper legs | CYLINDER | 2 | 9% dia x 18% H | `#F0EDE2` | 0.80 | 0 | knee seam |
| 9 | Lower legs / feet | CYLINDER + box | 2 | 9% dia x 16% H | `#2B2B30` | 0.80 | 0 | hoof/foot cap darker |
| 10 | Tail | CONE / curve | 1 | 14% H | `#2B2B30` | 0.75 | 0 | tuft tip highlight |
| 11 | Collar + brass bell | TORUS + UV_SPHERE | 2 | 10% H | `#D9A441` | 0.40 | 0.35 | bell emissive 0.2, polished |
| 12 | Prop: milk pail | CYLINDER | 1 | 18% H | `#8C8C94` | 0.35 | 0.40 | dented metal |

**Assembly order:** 1 pelvis -> 2 upper/lower legs + feet -> 3 torso -> 4 upper + lower arms -> 5 head -> 6 muzzle -> 7 eyes -> 8 ears/comb/horns -> 9 tail -> 10 accessory -> 11 prop (align to hand anchor).

**PBR notes:** Primary `#F0EDE2` roughness 0.70-0.80 (matte fur/plumage), secondary `#2B2B30` 0.65-0.80, eye 0.25 for wet specular, accessory `#D9A441` 0.40-0.55 (leather/cloth), prop `#D9A441` metallic 0.0-0.35. Wear: chipped silhouette edges, 1-2 scuff patches, cooler moon rim `#AEC6D8`.

## P4 — Dog

- Overall height `H` (normalized). Silhouette: lean forward-leaning biped, floppy ears
- Explode convention: parts separated along **+X** at `x = i * 0.85H` (i = part index), staggered `z` per tier, with dashed guide curves + floating text labels. Assembly order is the reverse of explode offset.

| # | Component | Primitive | Count | Size (% of H) | Base color | Rough | Metal | Wear / notes |
|---|-----------|-----------|-------|--------------|------------|-------|-------|--------------|
| 0 | Pelvis / hips | beveled CUBE | 1 | 12% W x 14% H | `#6B4423` | 0.85 | 0 | cloth seam, slight rot shadow |
| 1 | Torso | tapered CUBE | 1 | 30% W x 34% H | `#C8803C` | 0.75 | 0 | belly tone shift, edge wear |
| 2 | Head / skull | UV_SPHERE | 1 | 26% dia | `#C8803C` | 0.60 | 0 | cel 2-tone, cheek blush |
| 3 | Muzzle / beak / snout | UV_SPHERE or CONE | 1 | 10% dia | `#6B4423` | 0.65 | 0 | nostril/beak tip highlight |
| 4 | Eyes | UV_SPHERE | 2 | 5% dia each | `#2A2A2E` | 0.25 | 0 | white specular dot `#FFFFFF` |
| 5 | Ears / comb / horns | CONE | 2 | 10% H each | `#2A2A2E` | 0.70 | 0 | asymmetric chip |
| 6 | Upper arms | CYLINDER | 2 | 7% dia x 16% H | `#C8803C` | 0.75 | 0 | shoulder crease |
| 7 | Lower arms / hands | CYLINDER + sphere | 2 | 7% dia x 14% H | `#C8803C` | 0.75 | 0 | mitten-hand rounding |
| 8 | Upper legs | CYLINDER | 2 | 9% dia x 18% H | `#C8803C` | 0.80 | 0 | knee seam |
| 9 | Lower legs / feet | CYLINDER + box | 2 | 9% dia x 16% H | `#6B4423` | 0.80 | 0 | hoof/foot cap darker |
| 10 | Tail | CONE / curve | 1 | 14% H | `#6B4423` | 0.75 | 0 | tuft tip highlight |
| 11 | Spiked collar | TORUS + cones | 1 | 8% H | `#2A2A2E` | 0.50 | 0.30 | metal studs `#8C8C94` |
| 12 | Prop: bone | CYLINDER + spheres | 1 | 14% H | `#E3DCC4` | 0.80 | 0 | gnawed ends |

**Assembly order:** 1 pelvis -> 2 upper/lower legs + feet -> 3 torso -> 4 upper + lower arms -> 5 head -> 6 muzzle -> 7 eyes -> 8 ears/comb/horns -> 9 tail -> 10 accessory -> 11 prop (align to hand anchor).

**PBR notes:** Primary `#C8803C` roughness 0.70-0.80 (matte fur/plumage), secondary `#6B4423` 0.65-0.80, eye 0.25 for wet specular, accessory `#2A2A2E` 0.40-0.55 (leather/cloth), prop `#4A4A52` metallic 0.0-0.35. Wear: chipped silhouette edges, 1-2 scuff patches, cooler moon rim `#AEC6D8`.

---

# ANTAGONISTS (5)

## Z1 — Undead chicken

- Overall height `H` (normalized). Silhouette: hunched, limp wings, clouded eye
- Explode convention: parts separated along **+X** at `x = i * 0.85H` (i = part index), staggered `z` per tier, with dashed guide curves + floating text labels. Assembly order is the reverse of explode offset.

| # | Component | Primitive | Count | Size (% of H) | Base color | Rough | Metal | Wear / notes |
|---|-----------|-----------|-------|--------------|------------|-------|-------|--------------|
| 0 | Pelvis / hips | beveled CUBE | 1 | 14% W x 14% H | `#4A4A42` | 0.90 | 0 | torn cloth, grime |
| 1 | Torso (decayed) | tapered CUBE | 1 | 34% W x 40% H | `#8FA07A` | 0.90 | 0 | exposed rib hints, stitch seam |
| 2 | Head / skull | UV_SPHERE | 1 | 24-30% dia | `#8FA07A` | 0.85 | 0 | sunken cheek, crack line |
| 3 | Muzzle / jaw | UV_SPHERE | 1 | 12% dia | `#4A4A42` | 0.85 | 0 | missing teeth, exposed gum |
| 4 | Eyes | UV_SPHERE | 2 | 5% dia each | `#C23B2E` | 0.30 | 0 | emissive glow 0.6, clouded second eye |
| 5 | Horns / ears / hood | CONE or CUBE | 2 | 10-16% H | `#E3DCC4` | 0.80 | 0 | asymmetric break on one side |
| 6 | Upper arms | CYLINDER | 2 | 8% dia x 18% H | `#8FA07A` | 0.88 | 0 | bandage wrap `#C9C2A6` |
| 7 | Lower arms / hands | CYLINDER + sphere | 2 | 8% dia x 16% H | `#8FA07A` | 0.88 | 0 | clawed digits |
| 8 | Upper legs | CYLINDER | 2 | 10% dia x 20% H | `#8FA07A` | 0.90 | 0 | knee wrap |
| 9 | Lower legs / feet | CYLINDER + box | 2 | 10% dia x 16% H | `#4A4A42` | 0.90 | 0 | hoof / dragged foot |
| 10 | Tail / trailing rag | curve | 1 | 14% H | `#6B4A3A` | 0.90 | 0 | frayed tip |
| 11 | Prop: broken feather / none | CONE | 1 | 10% H | `#4A4A42` | 0.90 | 0 | frayed |

**Assembly order:** 1 pelvis -> 2 legs -> 3 torso (stitch seam last) -> 4 arms -> 5 head -> 6 jaw -> 7 eyes -> 8 horns/hood -> 9 tail/rag -> 10 prop into hand anchor.

**PBR notes:** Decay palette `#8FA07A`/`#4A4A42` roughness 0.85-0.95 (dry, dead tissue), bone `#E3DCC4` 0.75, eyes 0.30 + emissive, cloth `#6B4A3A` 0.90, prop metallic 0.35. Wear: heavy — chipped silhouette, exposed bone, stitch lines `#C9C2A6`, grime AO in cavities, asymmetric missing feature. One clouded eye `#C9D2B0` (rough 0.9).

## Z2 — Undead pig butcher

- Overall height `H` (normalized). Silhouette: broad lunging torso, cleaver raised
- Explode convention: parts separated along **+X** at `x = i * 0.85H` (i = part index), staggered `z` per tier, with dashed guide curves + floating text labels. Assembly order is the reverse of explode offset.

| # | Component | Primitive | Count | Size (% of H) | Base color | Rough | Metal | Wear / notes |
|---|-----------|-----------|-------|--------------|------------|-------|-------|--------------|
| 0 | Pelvis / hips | beveled CUBE | 1 | 14% W x 14% H | `#6B4A3A` | 0.90 | 0 | torn cloth, grime |
| 1 | Torso (decayed) | tapered CUBE | 1 | 34% W x 40% H | `#9BA08A` | 0.90 | 0 | exposed rib hints, stitch seam |
| 2 | Head / skull | UV_SPHERE | 1 | 24-30% dia | `#9BA08A` | 0.85 | 0 | sunken cheek, crack line |
| 3 | Muzzle / jaw | UV_SPHERE | 1 | 12% dia | `#6B4A3A` | 0.85 | 0 | missing teeth, exposed gum |
| 4 | Eyes | UV_SPHERE | 2 | 5% dia each | `#C23B2E` | 0.30 | 0 | emissive glow 0.6, clouded second eye |
| 5 | Horns / ears / hood | CONE or CUBE | 2 | 10-16% H | `#E3DCC4` | 0.80 | 0 | asymmetric break on one side |
| 6 | Upper arms | CYLINDER | 2 | 8% dia x 18% H | `#9BA08A` | 0.88 | 0 | bandage wrap `#C9C2A6` |
| 7 | Lower arms / hands | CYLINDER + sphere | 2 | 8% dia x 16% H | `#9BA08A` | 0.88 | 0 | clawed digits |
| 8 | Upper legs | CYLINDER | 2 | 10% dia x 20% H | `#9BA08A` | 0.90 | 0 | knee wrap |
| 9 | Lower legs / feet | CYLINDER + box | 2 | 10% dia x 16% H | `#6B4A3A` | 0.90 | 0 | hoof / dragged foot |
| 10 | Tail / trailing rag | curve | 1 | 14% H | `#7A2E28` | 0.90 | 0 | frayed tip |
| 11 | Prop: cleaver | CUBE + cylinder | 1 | 26% H | `#8C8C94` | 0.35 | 0.45 | blood `#B03A2E` on blade |

**Assembly order:** 1 pelvis -> 2 legs -> 3 torso (stitch seam last) -> 4 arms -> 5 head -> 6 jaw -> 7 eyes -> 8 horns/hood -> 9 tail/rag -> 10 prop into hand anchor.

**PBR notes:** Decay palette `#9BA08A`/`#6B4A3A` roughness 0.85-0.95 (dry, dead tissue), bone `#E3DCC4` 0.75, eyes 0.30 + emissive, cloth `#7A2E28` 0.90, prop metallic 0.35. Wear: heavy — chipped silhouette, exposed bone, stitch lines `#C9C2A6`, grime AO in cavities, asymmetric missing feature. Blood-spattered apron, stitch line across snout, tusks.

## Z3 — Undead bull brute

- Overall height `H` (normalized). Silhouette: massive squat torso, wide arms
- Explode convention: parts separated along **+X** at `x = i * 0.85H` (i = part index), staggered `z` per tier, with dashed guide curves + floating text labels. Assembly order is the reverse of explode offset.

| # | Component | Primitive | Count | Size (% of H) | Base color | Rough | Metal | Wear / notes |
|---|-----------|-----------|-------|--------------|------------|-------|-------|--------------|
| 0 | Pelvis / hips | beveled CUBE | 1 | 14% W x 14% H | `#3A3A38` | 0.90 | 0 | torn cloth, grime |
| 1 | Torso (decayed) | tapered CUBE | 1 | 34% W x 40% H | `#6E7A72` | 0.90 | 0 | exposed rib hints, stitch seam |
| 2 | Head / skull | UV_SPHERE | 1 | 24-30% dia | `#6E7A72` | 0.85 | 0 | sunken cheek, crack line |
| 3 | Muzzle / jaw | UV_SPHERE | 1 | 12% dia | `#3A3A38` | 0.85 | 0 | missing teeth, exposed gum |
| 4 | Eyes | UV_SPHERE | 2 | 5% dia each | `#C23B2E` | 0.30 | 0 | emissive glow 0.6, clouded second eye |
| 5 | Horns / ears / hood | CONE or CUBE | 2 | 10-16% H | `#E3DCC4` | 0.80 | 0 | asymmetric break on one side |
| 6 | Upper arms | CYLINDER | 2 | 8% dia x 18% H | `#6E7A72` | 0.88 | 0 | bandage wrap `#C9C2A6` |
| 7 | Lower arms / hands | CYLINDER + sphere | 2 | 8% dia x 16% H | `#6E7A72` | 0.88 | 0 | clawed digits |
| 8 | Upper legs | CYLINDER | 2 | 10% dia x 20% H | `#6E7A72` | 0.90 | 0 | knee wrap |
| 9 | Lower legs / feet | CYLINDER + box | 2 | 10% dia x 16% H | `#3A3A38` | 0.90 | 0 | hoof / dragged foot |
| 10 | Tail / trailing rag | curve | 1 | 14% H | `#4A4A52` | 0.90 | 0 | frayed tip |
| 11 | Prop: chain + weight | TORUS + UV_SPHERE | 1 | 22% H | `#4A4A52` | 0.45 | 0.50 | rusted links |

**Assembly order:** 1 pelvis -> 2 legs -> 3 torso (stitch seam last) -> 4 arms -> 5 head -> 6 jaw -> 7 eyes -> 8 horns/hood -> 9 tail/rag -> 10 prop into hand anchor.

**PBR notes:** Decay palette `#6E7A72`/`#3A3A38` roughness 0.85-0.95 (dry, dead tissue), bone `#E3DCC4` 0.75, eyes 0.30 + emissive, cloth `#4A4A52` 0.90, prop metallic 0.35. Wear: heavy — chipped silhouette, exposed bone, stitch lines `#C9C2A6`, grime AO in cavities, asymmetric missing feature. Asymmetric broken horns, exposed bone shoulder, chain collar.

## Z4 — Undead dog crawler

- Overall height `H` (normalized). Silhouette: low quadrupedal stalk, long limbs
- Explode convention: parts separated along **+X** at `x = i * 0.85H` (i = part index), staggered `z` per tier, with dashed guide curves + floating text labels. Assembly order is the reverse of explode offset.

| # | Component | Primitive | Count | Size (% of H) | Base color | Rough | Metal | Wear / notes |
|---|-----------|-----------|-------|--------------|------------|-------|-------|--------------|
| 0 | Pelvis / hips | beveled CUBE | 1 | 14% W x 14% H | `#2A2A2E` | 0.90 | 0 | torn cloth, grime |
| 1 | Torso (decayed) | tapered CUBE | 1 | 34% W x 40% H | `#7C856E` | 0.90 | 0 | exposed rib hints, stitch seam |
| 2 | Head / skull | UV_SPHERE | 1 | 24-30% dia | `#7C856E` | 0.85 | 0 | sunken cheek, crack line |
| 3 | Muzzle / jaw | UV_SPHERE | 1 | 12% dia | `#2A2A2E` | 0.85 | 0 | missing teeth, exposed gum |
| 4 | Eyes | UV_SPHERE | 2 | 5% dia each | `#C23B2E` | 0.30 | 0 | emissive glow 0.6, clouded second eye |
| 5 | Horns / ears / hood | CONE or CUBE | 2 | 10-16% H | `#E8E2D0` | 0.80 | 0 | asymmetric break on one side |
| 6 | Upper arms | CYLINDER | 2 | 8% dia x 18% H | `#7C856E` | 0.88 | 0 | bandage wrap `#C9C2A6` |
| 7 | Lower arms / hands | CYLINDER + sphere | 2 | 8% dia x 16% H | `#7C856E` | 0.88 | 0 | clawed digits |
| 8 | Upper legs | CYLINDER | 2 | 10% dia x 20% H | `#7C856E` | 0.90 | 0 | knee wrap |
| 9 | Lower legs / feet | CYLINDER + box | 2 | 10% dia x 16% H | `#2A2A2E` | 0.90 | 0 | hoof / dragged foot |
| 10 | Tail / trailing rag | curve | 1 | 14% H | `#3A3A38` | 0.90 | 0 | frayed tip |
| 11 | Prop: none (claws) | CONE | 4 | 6% H | `#E3DCC4` | 0.70 | 0 | exposed claws |

**Assembly order:** 1 pelvis -> 2 legs -> 3 torso (stitch seam last) -> 4 arms -> 5 head -> 6 jaw -> 7 eyes -> 8 horns/hood -> 9 tail/rag -> 10 prop into hand anchor.

**PBR notes:** Decay palette `#7C856E`/`#2A2A2E` roughness 0.85-0.95 (dry, dead tissue), bone `#E8E2D0` 0.75, eyes 0.30 + emissive, cloth `#3A3A38` 0.90, prop metallic 0.35. Wear: heavy — chipped silhouette, exposed bone, stitch lines `#C9C2A6`, grime AO in cavities, asymmetric missing feature. Glowing red pupils, exposed teeth, matted tufts, torn ear.

## Z5 — Boss Gravedigger (undead bear)

- Overall height `H` (normalized). Silhouette: towering, long arms, shovel planted
- Explode convention: parts separated along **+X** at `x = i * 0.85H` (i = part index), staggered `z` per tier, with dashed guide curves + floating text labels. Assembly order is the reverse of explode offset.

| # | Component | Primitive | Count | Size (% of H) | Base color | Rough | Metal | Wear / notes |
|---|-----------|-----------|-------|--------------|------------|-------|-------|--------------|
| 0 | Pelvis / hips | beveled CUBE | 1 | 14% W x 14% H | `#2E2E2C` | 0.90 | 0 | torn cloth, grime |
| 1 | Torso (decayed) | tapered CUBE | 1 | 34% W x 40% H | `#5A6258` | 0.90 | 0 | exposed rib hints, stitch seam |
| 2 | Head / skull | UV_SPHERE | 1 | 24-30% dia | `#5A6258` | 0.85 | 0 | sunken cheek, crack line |
| 3 | Muzzle / jaw | UV_SPHERE | 1 | 12% dia | `#2E2E2C` | 0.85 | 0 | missing teeth, exposed gum |
| 4 | Eyes | UV_SPHERE | 2 | 5% dia each | `#C23B2E` | 0.30 | 0 | emissive glow 0.6, clouded second eye |
| 5 | Horns / ears / hood | CONE or CUBE | 2 | 10-16% H | `#E3DCC4` | 0.80 | 0 | asymmetric break on one side |
| 6 | Upper arms | CYLINDER | 2 | 8% dia x 18% H | `#5A6258` | 0.88 | 0 | bandage wrap `#C9C2A6` |
| 7 | Lower arms / hands | CYLINDER + sphere | 2 | 8% dia x 16% H | `#5A6258` | 0.88 | 0 | clawed digits |
| 8 | Upper legs | CYLINDER | 2 | 10% dia x 20% H | `#5A6258` | 0.90 | 0 | knee wrap |
| 9 | Lower legs / feet | CYLINDER + box | 2 | 10% dia x 16% H | `#2E2E2C` | 0.90 | 0 | hoof / dragged foot |
| 10 | Tail / trailing rag | curve | 1 | 14% H | `#8C6B3F` | 0.90 | 0 | frayed tip |
| 11 | Prop: gravestone shovel | CUBE + cylinder | 1 | 40% H | `#4A4A52` | 0.40 | 0.45 | rusted spade `#8C8C94` |

**Assembly order:** 1 pelvis -> 2 legs -> 3 torso (stitch seam last) -> 4 arms -> 5 head -> 6 jaw -> 7 eyes -> 8 horns/hood -> 9 tail/rag -> 10 prop into hand anchor.

**PBR notes:** Decay palette `#5A6258`/`#2E2E2C` roughness 0.85-0.95 (dry, dead tissue), bone `#E3DCC4` 0.75, eyes 0.30 + emissive, cloth `#8C6B3F` 0.90, prop metallic 0.35. Wear: heavy — chipped silhouette, exposed bone, stitch lines `#C9C2A6`, grime AO in cavities, asymmetric missing feature. Tattered hood, stitched chest seam, glowing amber eyes `#E8A13C`, visible rib cage, boss-scale 1.30H.

---

## Blender blockout mapping
Each table row -> one primitive. `execute_blender_code` builds a single representative exploded stack (separated primitives offset along +X with per-part materials + text labels + guide plane + camera). Scale all sizes by `H` before instancing. Export as `.blend` + per-part named empties for reassembly.
