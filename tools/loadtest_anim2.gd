## loadtest_anim2.gd — proves an animation glb's clip drives the model glb's
## skeleton: merges the run clip onto an AnimationPlayer on the model and
## samples bone poses over time.
extends Node


func _ready() -> void:
	# Watchdog: never let a script error hang the engine.
	get_tree().create_timer(45.0).timeout.connect(func() -> void:
		print("LT2 WATCHDOG — forcing quit")
		get_tree().quit(2))
	var model: Node3D = load("res://assets/models/cc0/kenney_anim/model.glb").instantiate()
	add_child(model)
	var names: Array = []
	for c in model.get_children():
		names.append(String(c.name))
	print("LT2 model root=", model.name, " children=", names)

	var anim_root: Node3D = load("res://assets/models/cc0/kenney_anim/run.glb").instantiate()
	var anames: Array = []
	for c in anim_root.get_children():
		anames.append(String(c.name))
	print("LT2 run root=", anim_root.name, " children=", anames)
	add_child(anim_root)

	var src_ap: AnimationPlayer = null
	for a in anim_root.find_children("*", "AnimationPlayer", true, false):
		src_ap = a
		break
	if src_ap == null:
		print("LT2 FAIL no source AnimationPlayer")
		get_tree().quit(1)
		return
	print("LT2 src clips=", src_ap.get_animation_list(), " src root_node=", src_ap.root_node)

	var run_anim: Animation = null
	for c in src_ap.get_animation_list():
		if String(c).contains("Run"):
			run_anim = src_ap.get_animation(c)
	if run_anim == null:
		print("LT2 FAIL no Run clip")
		get_tree().quit(1)
		return

	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	model.add_child(ap)
	ap.root_node = ap.get_path_to(model)
	var lib := AnimationLibrary.new()
	lib.add_animation("run", run_anim)
	ap.add_animation_library("", lib)
	print("LT2 merged clips=", ap.get_animation_list())

	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		print("LT2 FAIL no skeleton")
		get_tree().quit(1)
		return
	var sk: Skeleton3D = skels[0]

	ap.play("run")
	await get_tree().create_timer(0.15).timeout
	var b0a: Vector3 = sk.get_bone_global_pose(0).origin
	var b10a: Vector3 = sk.get_bone_global_pose(10).origin
	await get_tree().create_timer(0.22).timeout
	var b0b: Vector3 = sk.get_bone_global_pose(0).origin
	var b10b: Vector3 = sk.get_bone_global_pose(10).origin
	print("LT2 bone0 a=", b0a.snappedf(0.001), " b=", b0b.snappedf(0.001), " moved=", b0a.distance_to(b0b) > 0.001)
	print("LT2 bone10 a=", b10a.snappedf(0.001), " b=", b10b.snappedf(0.001), " moved=", b10a.distance_to(b10b) > 0.001)
	var ok: bool = b0a.distance_to(b0b) > 0.001 or b10a.distance_to(b10b) > 0.001
	print("LT2 RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)