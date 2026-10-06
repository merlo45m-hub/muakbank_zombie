## loadtest_anim3.gd — the fix test: retarget animation tracks from node paths
## ("RootNode/Root/HipsCtrl/...") onto skeleton bone tracks ("Skeleton3D:Hips")
## and prove the bones actually move.
extends Node


func _retarget(anim: Animation, skeleton: Skeleton3D, sk_path: String) -> int:
	var fixed := 0
	for i in range(anim.get_track_count()):
		var p: NodePath = anim.track_get_path(i)
		var last := String(p.get_name(p.get_name_count() - 1))
		if skeleton.find_bone(last) >= 0:
			anim.track_set_path(i, NodePath(sk_path + ":" + last))
			fixed += 1
	return fixed


func _ready() -> void:
	get_tree().create_timer(45.0).timeout.connect(func() -> void:
		print("LT3 WATCHDOG — forcing quit")
		get_tree().quit(2))

	var model: Node3D = load("res://assets/models/cc0/kenney_anim/model.glb").instantiate()
	add_child(model)
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		print("LT3 FAIL no skeleton")
		get_tree().quit(1)
		return
	var sk: Skeleton3D = skels[0]
	print("LT3 skeleton path=", String(model.get_path_to(sk)), " bones=", sk.get_bone_count())

	# Does a track path resolve to a real node in the model?
	var probe := model.get_node_or_null("RootNode/Root/HipsCtrl")
	print("LT3 node RootNode/Root/HipsCtrl exists=", probe != null)

	var anim_root: Node3D = load("res://assets/models/cc0/kenney_anim/run.glb").instantiate()
	add_child(anim_root)
	var src_ap: AnimationPlayer = null
	for a in anim_root.find_children("*", "AnimationPlayer", true, false):
		src_ap = a
		break
	var run_anim: Animation = null
	for c in src_ap.get_animation_list():
		if String(c).contains("Run"):
			run_anim = src_ap.get_animation(c)

	var sk_path := String(model.get_path_to(sk))
	var fixed := _retarget(run_anim, sk, sk_path)
	print("LT3 retargeted tracks=", fixed, "/", run_anim.get_track_count())
	if fixed > 0:
		print("LT3 t0 now=", String(run_anim.track_get_path(0)))

	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	model.add_child(ap)
	ap.root_node = ap.get_path_to(model)
	var lib := AnimationLibrary.new()
	lib.add_animation("run", run_anim)
	ap.add_animation_library("", lib)
	ap.play("run")

	await get_tree().create_timer(0.12).timeout
	var b0a: Vector3 = sk.get_bone_global_pose(0).origin
	var b10a: Vector3 = sk.get_bone_global_pose(10).origin
	await get_tree().create_timer(0.2).timeout
	var b0b: Vector3 = sk.get_bone_global_pose(0).origin
	var b10b: Vector3 = sk.get_bone_global_pose(10).origin
	print("LT3 bone0 a=", b0a.snappedf(0.001), " b=", b0b.snappedf(0.001), " moved=", b0a.distance_to(b0b) > 0.001)
	print("LT3 bone10 a=", b10a.snappedf(0.001), " b=", b10b.snappedf(0.001), " moved=", b10a.distance_to(b10b) > 0.001)
	var ok: bool = b0a.distance_to(b0b) > 0.001 or b10a.distance_to(b10b) > 0.001
	print("LT3 RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)