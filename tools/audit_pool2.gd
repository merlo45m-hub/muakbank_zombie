extends Node
## AUDIT-ONLY probe — added by the audit on the scratch clone; NOT part of the repo.
## (1) Measures the real death -> died -> pool-return timeline (is test_pool.gd's
##     1.0s wait stale vs the ~1.1s death anim?).
## (2) Reuse cycle on a readied+returned instance (production flow).
## (3) Expansion sim: instance created by pool.init() after a size bump —
##     the spawner's "Pool exhausted ... expanding pool" path.

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var scene: PackedScene = load("res://scenes/characters/zombie_dog.tscn")
	if scene == null:
		print("AUDITPOOL: zombie scene FAILED to load")
		get_tree().quit(1)
		return

	# ---- (1) death timeline ----
	var pool = load("res://addons/godot-object-pool/pool.gd").new(3, "audit", scene)
	var z = pool.get_first_dead()
	z.set("pooled", true)
	z.set("pool_entry", {"pool": pool, "type": "zombie_dog"})
	print("AUDITPOOL: z health before add_child (never readied)=", z.get("health"))
	z.died.connect(func() -> void:
		print("AUDITPOOL: died fired at t+%dms" % (Time.get_ticks_msec() - t0))
		pool._on_killed(z)
		if z.get_parent():
			z.get_parent().remove_child(z)
	)
	add_child(z)
	print("AUDITPOOL: after add_child health=", z.get("health"), " max_health=", z.get("max_health"))
	z.take_damage(99999)
	print("AUDITPOOL: damaged at t+%dms is_dead=%s" % [Time.get_ticks_msec() - t0, str(z.is_dead)])
	for i in range(9):
		await get_tree().create_timer(0.25).timeout
		print("AUDITPOOL: t+%dms dead=%d alive=%d is_dead=%s parented=%s" % [
			Time.get_ticks_msec() - t0, pool.get_dead_size(), pool.get_alive_size(),
			str(z.is_dead), str(z.get_parent() != null)])

	# ---- (2) reuse cycle on the now-readied-and-returned instance ----
	var z2 = pool.get_first_dead()
	if z2 == null:
		print("AUDITPOOL: reuse checkout returned null")
	else:
		print("AUDITPOOL: reuse same_instance=%s" % str(z2 == z))
		if z2.has_method("reset_for_pool"):
			z2.reset_for_pool()
		add_child(z2)
		await get_tree().process_frame
		print("AUDITPOOL: reuse state is_dead=%s dead_flag=%s health=%s visible=%s" % [
			str(z2.is_dead), str(z2.get("dead")), str(z2.get("health")), str(z2.visible)])

	# ---- (3) expansion sim ----
	var pool3 = load("res://addons/godot-object-pool/pool.gd").new(1, "exp", scene)
	var e1 = pool3.get_first_dead()
	print("AUDITPOOL: expansion pool1 checkout=%s" % str(e1 != null))
	pool3.size += 2
	pool3.init()
	var e2 = pool3.get_first_dead()
	if e2 == null:
		print("AUDITPOOL: expansion checkout returned null")
	else:
		e2.set("pooled", true)
		e2.set("zombie_type", "dog")
		if e2.has_method("reset_for_pool"):
			e2.reset_for_pool()
		add_child(e2)
		e2.apply_difficulty(1.5)
		print("AUDITPOOL: expansion spawn health=%s max=%s dmg=%s speed=%s (healthy=45/45/15/6)" % [
			str(e2.get("health")), str(e2.get("max_health")),
			str(e2.get("damage")), str(e2.get("move_speed"))])
	get_tree().quit(0)