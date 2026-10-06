## loadtest_anim.gd — verifies the Kenney animated character glbs:
## mesh/AABB for scaling, AnimationPlayer clips, and — critically — whether the
## animation glbs' track paths match the model's skeleton node paths.
extends Node


func _ready() -> void:
	var model: Node3D = load("res://assets/models/cc0/kenney_anim/model.glb").instantiate()
	add_child(model)
	var meshes := 0
	var aabb := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		meshes += 1
		var b: AABB = m.transform * m.mesh.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	print("LT model meshes=", meshes, " aabb_pos=", aabb.position, " aabb_size=", aabb.size)

	var skels := model.find_children("*", "Skeleton3D", true, false)
	print("LT model skeletons=", skels.size())
	if skels.size() > 0:
		var sk := skels[0] as Skeleton3D
		print("LT   skeleton name=", sk.name, " bones=", sk.get_bone_count())
		if sk.get_bone_count() > 0:
			print("LT   bone0=", sk.get_bone_name(0))

	var aps := model.find_children("*", "AnimationPlayer", true, false)
	print("LT model anim_players=", aps.size())
	for a in aps:
		print("LT   model clips=", (a as AnimationPlayer).get_animation_list())

	for nm in ["idle", "run", "jump"]:
		var s: Node3D = load("res://assets/models/cc0/kenney_anim/%s.glb" % nm).instantiate()
		add_child(s)
		var count := 0
		for a2 in s.find_children("*", "AnimationPlayer", true, false):
			var p := a2 as AnimationPlayer
			for clip in p.get_animation_list():
				count += 1
				var anim: Animation = p.get_animation(clip)
				var t0 := ""
				var t1 := ""
				if anim.get_track_count() > 0:
					t0 = str(anim.track_get_path(0))
				if anim.get_track_count() > 1:
					t1 = str(anim.track_get_path(1))
				print("LT ", nm, " clip=", clip, " len=", snappedf(anim.length, 0.01),
					" tracks=", anim.get_track_count())
				print("LT   t0=", t0, " | t1=", t1)
		if count == 0:
			print("LT ", nm, " NO CLIPS")
	get_tree().quit(0)