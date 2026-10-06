extends Node
## AUDIT-ONLY (post-fix): the shake must NOT move the camera transform (the
## SpringArm owns it) — it drives h_offset/v_offset, which the arm never touches.

var game: Node = null
var cam: Camera3D = null
var cs: Node = null

func _ready() -> void:
	var gs: PackedScene = load("res://scenes/main/game.tscn")
	if gs == null:
		print("AUDITSHAKE: load failed")
		get_tree().quit(1)
		return
	game = gs.instantiate()
	add_child(game)
	for i in 60:
		await get_tree().process_frame

	cam = game.get_node_or_null("Player/Camera/Camera3D") as Camera3D
	cs = game.get_node_or_null("CameraShake")
	print("AUDITSHAKE: cam=", cam != null, " cs=", cs != null)
	if cam:
		print("AUDITSHAKE: rest local=", cam.position, " h=", cam.h_offset, " v=", cam.v_offset)
	if cs and cs.has_method("shake"):
		cs.shake(0.4)
		print("AUDITSHAKE: shake(0.4) called")

	var max_off := 0.0
	for i in 40:
		await get_tree().process_frame
		if cam:
			var off: float = maxf(absf(cam.h_offset), absf(cam.v_offset))
			max_off = maxf(max_off, off)
			if i % 2 == 0:
				print("AUDITSHAKE: f", i, " local=", cam.position, " h=", cam.h_offset, " v=", cam.v_offset)
	print("AUDITSHAKE: max offset seen=", max_off)
	var rest_ok := cam != null and absf(cam.position.z - 4.2) < 0.5
	var ok := max_off > 0.05 and rest_ok
	print("AUDITSHAKE: RESULT=", "PASS" if ok else "FAIL", " (rest z≈4.2 held=", rest_ok, ", offsets oscillate=", max_off > 0.05, ")")
	get_tree().quit(0 if ok else 1)
