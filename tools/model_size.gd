## model_size.gd — report the real bounding box of each zombie animal GLB.
## Guessing scale from a rendered frame is how you end up with a bear filling half of it.
## Run: Godot --headless --script res://tools/model_size.gd
extends SceneTree


func _initialize() -> void:
	var paths := [
		"res://assets/models/zombie_dog.glb",
		"res://assets/models/zombie_cat.glb",
		"res://assets/models/zombie_bear.glb",
	]
	for p in paths:
		var ps := load(p) as PackedScene
		if ps == null:
			print("MODEL MISSING: ", p)
			continue
		var n := ps.instantiate()
		var box := AABB()
		var first := true
		var stack: Array = [n]
		while not stack.is_empty():
			var x: Node = stack.pop_back()
			for c in x.get_children():
				stack.append(c)
			if x is MeshInstance3D:
				var m: AABB = (x as MeshInstance3D).get_aabb()
				box = m if first else box.merge(m)
				first = false
		print("MODEL ", p.get_file(), " size=", box.size, " base_y=", box.position.y)
		n.free()
	quit()
