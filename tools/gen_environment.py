#!/usr/bin/env python3
"""gen_environment.py — generate a valid Godot 4 environment .tscn.

Subagents repeatedly corrupt .tscn files (missing headers, [<node, >-instead-of-],
Godot 3 instancing), so new environments are generated deterministically here.

Usage: python3 gen_environment.py <kind>
  kind: sewer | mall
"""
import sys, os

PROJ = "/storage/emulated/0/Games/Muakbank_zombie"
OUT_DIR = f"{PROJ}/scenes/world/environment"


def box_mesh(name, size):
    return f'[sub_resource type="BoxMesh" id="{name}"]\nsize = Vector3({size[0]}, {size[1]}, {size[2]})\n'


def box_shape(name, size):
    return f'[sub_resource type="BoxShape3D" id="{name}"]\nsize = Vector3({size[0]}, {size[1]}, {size[2]})\n'


def cyl_mesh(name, radius, height):
    return f'[sub_resource type="CylinderMesh" id="{name}"]\nradius = {radius}\nheight = {height}\n'


def cyl_shape(name, radius, height):
    return f'[sub_resource type="CylinderShape3D" id="{name}"]\nradius = {radius}\nheight = {height}\n'


def sphere_mesh(name, radius):
    return f'[sub_resource type="SphereMesh" id="{name}"]\nradius = {radius}\nheight = {radius * 2}\n'


def mat(name, color, rough=0.8, metal=0.0):
    return (f'[sub_resource type="StandardMaterial3D" id="{name}"]\n'
            f'albedo_color = Color({color[0]}, {color[1]}, {color[2]}, 1.0)\n'
            f'roughness = {rough}\nmetallic = {metal}\n')


def omni(name, pos, color, energy, rng):
    return (f'[node name="{name}" type="OmniLight3D" parent="Lighting"]\n'
            f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {pos[0]}, {pos[1]}, {pos[2]})\n'
            f'light_color = Color({color[0]}, {color[1]}, {color[2]}, 1.0)\n'
            f'light_energy_multiplier = {energy}\n'
            f'omni_range = {rng}\n')


def static_box(name, parent, mesh_id, mat_id, shape_id, pos, size):
    return (f'[node name="{name}" type="StaticBody3D" parent="{parent}"]\n'
            f'collision_layer = 1\n'
            f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {pos[0]}, {pos[1]}, {pos[2]})\n\n'
            f'[node name="{name}Mesh" type="MeshInstance3D" parent="{parent}/{name}"]\n'
            f'mesh = SubResource("{mesh_id}")\n'
            f'material_override = SubResource("{mat_id}")\n\n'
            f'[node name="{name}Col" type="CollisionShape3D" parent="{parent}/{name}"]\n'
            f'shape = SubResource("{shape_id}")\n')


def build_sewer():
    """Sewer level — concrete tunnels, pipes, water channel, dripping."""
    name = "Sewer"
    floor = (110, 0.3, 110)
    subs = []
    subs.append(box_mesh("BoxMesh_floor", floor))
    subs.append(box_shape("BoxShape3D_floor", floor))
    subs.append(mat("GroundMaterial", (0.22, 0.24, 0.22), 0.95))
    subs.append(box_mesh("BoxMesh_wall", (110, 8, 1)))
    subs.append(box_shape("BoxShape3D_wall", (110, 8, 1)))
    subs.append(mat("WallMaterial", (0.3, 0.3, 0.28), 0.9))
    subs.append(cyl_mesh("CylinderMesh_pipe", 0.8, 40))
    subs.append(cyl_shape("CylinderShape3D_pipe", 0.8, 40))
    subs.append(mat("PipeMaterial", (0.4, 0.42, 0.4), 0.5, 0.6))
    subs.append(box_mesh("BoxMesh_crate", (1, 1, 1)))
    subs.append(box_shape("BoxShape3D_crate", (1, 1, 1)))
    subs.append(mat("CrateMaterial", (0.55, 0.42, 0.28), 0.85))
    subs.append(box_mesh("BoxMesh_walkway", (12, 0.4, 3)))
    subs.append(box_shape("BoxShape3D_walkway", (12, 0.4, 3)))
    subs.append(mat("WalkwayMaterial", (0.35, 0.35, 0.36), 0.8, 0.3))

    nodes = [f'[node name="{name}" type="Node3D"]\n',
             f'[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\n']
    nodes.append(f'[node name="Floor" type="StaticBody3D" parent="."]\ncollision_layer = 1\n\n'
                 f'[node name="FloorMesh" type="MeshInstance3D" parent="Floor"]\n'
                 f'mesh = SubResource("BoxMesh_floor")\nmaterial_override = SubResource("GroundMaterial")\n\n'
                 f'[node name="FloorCol" type="CollisionShape3D" parent="Floor"]\n'
                 f'shape = SubResource("BoxShape3D_floor")\n')
    # Perimeter walls
    walls = [("WallN", (0, 4, -55)), ("WallS", (0, 4, 55)), ("WallE", (55, 4, 0)), ("WallW", (-55, 4, 0))]
    nodes.append('[node name="Walls" type="Node3D" parent="."]\n')
    for wn, wp in walls:
        nodes.append(static_box(wn, "Walls", "BoxMesh_wall", "WallMaterial", "BoxShape3D_wall", wp, (110, 8, 1)))
    # Central water channel (visual, no collision so player can wade)
    nodes.append('[node name="Channel" type="Node3D" parent="."]\n')
    ch = box_mesh("BoxMesh_channel", (100, 0.1, 6))
    csh = box_shape("BoxShape3D_channel", (100, 0.1, 6))
    subs.append(ch); subs.append(csh)
    subs.append(mat("WaterMaterial", (0.08, 0.18, 0.22), 0.15, 0.4))
    nodes.append('[node name="Water" type="MeshInstance3D" parent="Channel"]\n'
                 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.15, 0)\n'
                 'mesh = SubResource("BoxMesh_channel")\n'
                 'material_override = SubResource("WaterMaterial")\n')
    # Pipes along the walls
    nodes.append('[node name="Pipes" type="Node3D" parent="."]\n')
    for i, y in enumerate([2.0, 3.2, 4.4]):
        nodes.append(f'[node name="Pipe{i}" type="StaticBody3D" parent="Pipes"]\n'
                     f'collision_layer = 1\n'
                     f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, {y}, 50)\n\n'
                     f'[node name="PipeMesh" type="MeshInstance3D" parent="Pipes/Pipe{i}"]\n'
                     f'mesh = SubResource("CylinderMesh_pipe")\n'
                     f'material_override = SubResource("PipeMaterial")\n\n'
                     f'[node name="PipeCol" type="CollisionShape3D" parent="Pipes/Pipe{i}"]\n'
                     f'shape = SubResource("CylinderShape3D_pipe")\n')
    # Raised walkways alongside the channel
    nodes.append('[node name="Walkways" type="Node3D" parent="."]\n')
    for i, (wx, wz) in enumerate([(-12, 0), (12, 0), (0, -14), (0, 14)]):
        nodes.append(static_box(f"Walkway{i}", "Walkways", "BoxMesh_walkway", "WalkwayMaterial",
                                "BoxShape3D_walkway", (wx, 0.6, wz), (12, 0.4, 3)))
    # Crates / debris as obstacles
    nodes.append('[node name="Crates" type="Node3D" parent="."]\n')
    import random
    random.seed(7)
    for i in range(12):
        x = random.uniform(-45, 45)
        z = random.uniform(-45, 45)
        if abs(z) < 5:  # keep the channel clear
            z += 12
        s = random.uniform(0.8, 1.3)
        nodes.append(static_box(f"Crate{i}", "Crates", "BoxMesh_crate", "CrateMaterial",
                                "BoxShape3D_crate", (round(x, 1), 0.5 * s, round(z, 1)), (1, 1, 1)))
    # Lighting — capped at 5 omnis
    nodes.append('[node name="Lighting" type="Node3D" parent="."]\n')
    nodes.append(omni("AmbientLight", (0, 8, 0), (0.3, 0.35, 0.32), 0.35, 90))
    for i, (lx, lz) in enumerate([(-25, -25), (25, 25), (-25, 25), (25, -25)]):
        nodes.append(omni(f"TunnelLight{i}", (lx, 6, lz), (0.6, 0.75, 0.7), 0.7, 22))
    return name, subs, nodes


def build_mall():
    """Mall level — tiled concourse, shop fronts, escalators, benches, plants."""
    name = "Mall"
    floor = (130, 0.3, 130)
    subs = []
    subs.append(box_mesh("BoxMesh_floor", floor))
    subs.append(box_shape("BoxShape3D_floor", floor))
    subs.append(mat("GroundMaterial", (0.42, 0.41, 0.4), 0.6))
    subs.append(box_mesh("BoxMesh_wall", (130, 12, 1)))
    subs.append(box_shape("BoxShape3D_wall", (130, 12, 1)))
    subs.append(mat("WallMaterial", (0.5, 0.5, 0.52), 0.5))
    subs.append(box_mesh("BoxMesh_shop", (16, 8, 10)))
    subs.append(box_shape("BoxShape3D_shop", (16, 8, 10)))
    subs.append(mat("ShopMaterial", (0.35, 0.33, 0.4), 0.7))
    subs.append(box_mesh("BoxMesh_bench", (3, 0.5, 0.8)))
    subs.append(box_shape("BoxShape3D_bench", (3, 0.5, 0.8)))
    subs.append(mat("BenchMaterial", (0.35, 0.25, 0.18), 0.8))
    subs.append(cyl_mesh("CylinderMesh_plant", 1.0, 1.2))
    subs.append(cyl_shape("CylinderShape3D_plant", 1.0, 1.2))
    subs.append(mat("PlantMaterial", (0.25, 0.45, 0.22), 0.9))
    subs.append(cyl_mesh("CylinderMesh_column", 1.2, 12))
    subs.append(cyl_shape("CylinderShape3D_column", 1.2, 12))
    subs.append(mat("ColumnMaterial", (0.55, 0.54, 0.5), 0.6))

    nodes = [f'[node name="{name}" type="Node3D"]\n',
             '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\n',
             '[node name="Floor" type="StaticBody3D" parent="."]\ncollision_layer = 1\n\n'
             '[node name="FloorMesh" type="MeshInstance3D" parent="Floor"]\n'
             'mesh = SubResource("BoxMesh_floor")\nmaterial_override = SubResource("GroundMaterial")\n\n'
             '[node name="FloorCol" type="CollisionShape3D" parent="Floor"]\n'
             'shape = SubResource("BoxShape3D_floor")\n']
    # Perimeter walls
    nodes.append('[node name="Walls" type="Node3D" parent="."]\n')
    for wn, wp, rot in [("WallN", (0, 6, -65), 0), ("WallS", (0, 6, 65), 0),
                        ("WallE", (65, 6, 0), 90), ("WallW", (-65, 6, 0), 90)]:
        nodes.append(f'[node name="{wn}" type="StaticBody3D" parent="Walls"]\n'
                     f'collision_layer = 1\n'
                     f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {wp[0]}, {wp[1]}, {wp[2]})\n\n'
                     f'[node name="WallMesh" type="MeshInstance3D" parent="Walls/{wn}"]\n'
                     f'mesh = SubResource("BoxMesh_wall")\n'
                     f'material_override = SubResource("WallMaterial")\n\n'
                     f'[node name="WallCol" type="CollisionShape3D" parent="Walls/{wn}"]\n'
                     f'shape = SubResource("BoxShape3D_wall")\n')
    # Shop fronts around the perimeter
    nodes.append('[node name="Shops" type="Node3D" parent="."]\n')
    shops = [(-45, -45), (0, -45), (45, -45), (-45, 45), (0, 45), (45, 45), (-45, 0), (45, 0)]
    for i, (sx, sz) in enumerate(shops):
        nodes.append(static_box(f"Shop{i}", "Shops", "BoxMesh_shop", "ShopMaterial",
                                "BoxShape3D_shop", (sx, 4, sz), (16, 8, 10)))
    # Support columns
    nodes.append('[node name="Columns" type="Node3D" parent="."]\n')
    for i, (cx, cz) in enumerate([(-25, -25), (25, -25), (-25, 25), (25, 25), (0, -25), (0, 25)]):
        nodes.append(f'[node name="Column{i}" type="StaticBody3D" parent="Columns"]\n'
                     f'collision_layer = 1\n'
                     f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {cx}, 6, {cz})\n\n'
                     f'[node name="ColumnMesh" type="MeshInstance3D" parent="Columns/Column{i}"]\n'
                     f'mesh = SubResource("CylinderMesh_column")\n'
                     f'material_override = SubResource("ColumnMaterial")\n\n'
                     f'[node name="ColumnCol" type="CollisionShape3D" parent="Columns/Column{i}"]\n'
                     f'shape = SubResource("CylinderShape3D_column")\n')
    # Benches + planters (scattered)
    nodes.append('[node name="Furniture" type="Node3D" parent="."]\n')
    import random
    random.seed(11)
    for i in range(10):
        bx = random.uniform(-50, 50)
        bz = random.uniform(-50, 50)
        nodes.append(static_box(f"Bench{i}", "Furniture", "BoxMesh_bench", "BenchMaterial",
                                "BoxShape3D_bench", (round(bx, 1), 0.25, round(bz, 1)), (3, 0.5, 0.8)))
    for i in range(8):
        px = random.uniform(-50, 50)
        pz = random.uniform(-50, 50)
        nodes.append(f'[node name="Planter{i}" type="StaticBody3D" parent="Furniture"]\n'
                     f'collision_layer = 1\n'
                     f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {round(px,1)}, 0.6, {round(pz,1)})\n\n'
                     f'[node name="PlanterMesh" type="MeshInstance3D" parent="Furniture/Planter{i}"]\n'
                     f'mesh = SubResource("CylinderMesh_plant")\n'
                     f'material_override = SubResource("PlantMaterial")\n\n'
                     f'[node name="PlanterCol" type="CollisionShape3D" parent="Furniture/Planter{i}"]\n'
                     f'shape = SubResource("CylinderShape3D_plant")\n')
    # Lighting — capped at 5
    nodes.append('[node name="Lighting" type="Node3D" parent="."]\n')
    nodes.append(omni("AmbientLight", (0, 10, 0), (0.75, 0.72, 0.65), 0.4, 100))
    for i, (lx, lz) in enumerate([(-30, -30), (30, 30), (-30, 30), (30, -30)]):
        nodes.append(omni(f"MallLight{i}", (lx, 9, lz), (0.85, 0.85, 0.9), 0.7, 28))
    return name, subs, nodes


def emit(kind):
    name, subs, nodes = build_sewer() if kind == "sewer" else build_mall()
    header = f'[gd_scene load_steps={len(subs) + 1} format=3]\n\n'
    body = "".join(s + "\n" for s in subs) + "\n" + "\n".join(n + "\n" for n in nodes)
    path = f"{OUT_DIR}/{kind}_enhanced.tscn"
    with open(path, "w") as f:
        f.write(header + body)
    # sanity checks
    c = open(path).read()
    assert c.count("[") == c.count("]"), f"unbalanced brackets in {path}"
    assert c.startswith("[gd_scene"), f"bad header in {path}"
    assert "scene = ExtResource" not in c, f"godot3 instancing in {path}"
    assert 'type=""' not in c, f"godot3 type in {path}"
    print(f"Wrote {path} ({len(c.splitlines())} lines, {c.count('[node')} nodes, "
          f"{c.count('OmniLight3D')} omni refs)")


if __name__ == "__main__":
    emit(sys.argv[1] if len(sys.argv) > 1 else "sewer")
