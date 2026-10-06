## loadtest_zombie.gd — inspects the existing zombie_rigged.gltf: meshes,
## skeleton, clips, track paths. Decides whether it can carry real animation.
extends Node


func _ready() -> void:
	get_tree().create_timer(45.0).timeout.connect(func() -> void:
		print("LTZ WATCHDOG — forcing quit")
		get_tree().quit(2))
	var path := "res://assets/models/zombie_rigged/zombie_rigged.gltf"
	print("LTZ exists=", ResourceLoader.exists(path))
	if not ResourceLoader.exists(path):
		get_tree().quit(0)
		return
	var scene := load(path) as PackedScene
	if scene == null:
		print("LTZ FAIL load")
		get_tree().quit(1)
		return
	var inst: Node3D = scene.instantiate()
	add_child(inst)
	var meshes := 0
	var aabb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		meshes += 1
		var b: AABB = m.transform * m.mesh.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	print("LTZ meshes=", meshes, " aabb_pos=", aabb.position, " aabb_size=", aabb.size)
	var skels := inst.find_children("*", "Skeleton3D", true, false)
	print("LTZ skeletons=", skels.size())
	for s in skels:
		var sk: Skeleton3D = s
		print("LTZ   sk path=", String(inst.get_path_to(sk)), " bones=", sk.get_bone_count())
	var aps := inst.find_children("*", "AnimationPlayer", true, false)
	print("LTZ anim_players=", aps.size())
	for a in aps:
		var p: AnimationPlayer = a
		print("LTZ   clips=", p.get_animation_list(), " root=", p.root_node)
		for c in p.get_animation_list():
			var an: Animation = p.get_animation(c)
			if an.get_track_count() > 0:
				print("LTZ     ", c, " len=", snappedf(an.length, 0.01), " tracks=", an.get_track_count(),
					" t0=", String(an.track_get_path(0)))
	get_tree().quit(0)