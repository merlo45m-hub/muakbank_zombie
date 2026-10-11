# Cemetery — design notes recovered from the scene file

These notes were written as `#` / `##` comment lines **inside** `scenes/world/environment/cemetery_enhanced.tscn`.
Godot's `.tscn` format does not support comments: a `#` line inside a node block silently drops that node
and every one of its children (they surface only as `Parent path '...' has vanished when instantiating`).
The comments were therefore removed from the scene and preserved here.

## Notes by original line number

**was line 7** — inside `[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]`

```
# This was size (100, 0.2, 100) - a 100-metre plate - and SEVENTY-NINE nodes shared it:
```

**was line 8** — inside `[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]`

```
# the floor plus 78 structures and props (walls, fences, gates, graves, the bell tower).
```

**was line 9** — inside `[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]`

```
# A 100x100 slab of collision hanging at each of those is what makes a world feel broken
```

**was line 10** — inside `[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]`

```
# to walk in. The floor has its own ground shape now; this is sized for the smallest
```

**was line 11** — inside `[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]`

```
# common case (a grave or prop) rather than the largest, because a slightly short collider
```

**was line 12** — inside `[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]`

```
# on a long wall is far less maddening than an invisible wall around a headstone.
```

**was line 87** — inside `[sub_resource type="Environment" id="CemeteryEnv"]`

```
# The fog colour was (0.3, 0.35, 0.4) - pale blue-grey - at density 0.03. With the camera
```

**was line 88** — inside `[sub_resource type="Environment" id="CemeteryEnv"]`

```
# looking nearly level, most of the frame IS ground 10-60 m away, and at 0.03 density the
```

**was line 89** — inside `[sub_resource type="Environment" id="CemeteryEnv"]`

```
# ground 30 m out is about 60% fog colour: the "over-lit featureless pale ground" that made
```

**was line 90** — inside `[sub_resource type="Environment" id="CemeteryEnv"]`

```
# this level look washed out was fog, not lights. Night fog should swallow detail into
```

**was line 91** — inside `[sub_resource type="Environment" id="CemeteryEnv"]`

```
# darkness, not into pastel.
```

**was line 1167** — inside `[node name="NearBandStructures" type="Node3D" parent="."]`

```
## Dense near-band content within 1-8m of spawn (0, 0.15, 0) — headstones,
```

**was line 1168** — inside `[node name="NearBandStructures" type="Node3D" parent="."]`

```
## broken walls, dead trunks, fence sections to fill mid/lower frame regions.
```

**was line 1236** — inside `[node name="FenceCol" type="CollisionShape3D" parent="NearBandStructures/NearFence"]`

```
## Player-proximal structures within 1-4m of player at (7.43, 2.08, -0.76)
```

**was line 1237** — inside `[node name="FenceCol" type="CollisionShape3D" parent="NearBandStructures/NearFence"]`

```
## to fill frame mid/lower regions
```
