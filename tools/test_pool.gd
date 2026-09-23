extends Node
## Pool lifecycle test: init -> checkout -> death -> return -> reuse.
## Prints POOLTEST: lines. Clean run ends with "POOLTEST: ALL PASS".


func _ready() -> void:
	var fails := 0

	var zombie_scene: PackedScene = load("res://scenes/characters/zombie_dog.tscn")
	if zombie_scene == null:
		print("POOLTEST: FAIL — zombie_dog.tscn did not load")
		get_tree().quit()
		return
	print("POOLTEST: zombie scene loaded")

	var pool_script = load("res://addons/godot-object-pool/pool.gd")
	var pool = pool_script.new(3, "testzombie", zombie_scene)
	print("POOLTEST: after init dead=%d alive=%d" % [pool.get_dead_size(), pool.get_alive_size()])
	if pool.get_dead_size() != 3:
		fails += 1

	# ---- checkout ----
	var z = pool.get_first_dead()
	if z == null:
		print("POOLTEST: FAIL — get_first_dead returned null on a fresh pool")
		get_tree().quit()
		return
	print("POOLTEST: checkout ok (dead=%d alive=%d dead_flag=%s)" % [pool.get_dead_size(), pool.get_alive_size(), str(z.dead)])
	if z.dead:
		fails += 1

	# mimic the spawner's checkout bookkeeping
	z.set("pooled", true)
	z.set("pool_entry", {"pool": pool, "type": "zombie_dog"})
	if z.get("pool_entry") == null:
		print("POOLTEST: FAIL — pool_entry property did not stick")
		fails += 1
	else:
		print("POOLTEST: pool_entry property round-trip ok")

	# mimic the spawner's _return_to_pool fallback on death (signal has no args)
	z.died.connect(func() -> void:
		print("POOLTEST-DBG: died handler fired for %s" % z.name)
		pool._on_killed(z)
		print("POOLTEST-DBG: after _on_killed dead=%d alive=%d" % [pool.get_dead_size(), pool.get_alive_size()])
		if z.get_parent():
			z.get_parent().remove_child(z)
			print("POOLTEST-DBG: removed from parent")
	)
	print("POOLTEST-DBG: pre-death pool dead=%d alive=%d" % [pool.get_dead_size(), pool.get_alive_size()])
	add_child(z)

	# ---- death ----
	z.take_damage(99999)
	await get_tree().create_timer(1.0).timeout
	print("POOLTEST: after death dead=%d alive=%d is_dead=%s visible=%s" % [pool.get_dead_size(), pool.get_alive_size(), str(z.is_dead), str(z.visible)])
	if pool.get_dead_size() != 3 or pool.get_alive_size() != 0:
		print("POOLTEST: FAIL — zombie did not return to the dead pool")
		fails += 1
	if z.get_parent() != null:
		print("POOLTEST: FAIL — zombie still parented after return")
		fails += 1

	# ---- reuse ----
	var z2 = pool.get_first_dead()
	if z2 == null:
		print("POOLTEST: FAIL — reuse checkout returned null")
		fails += 1
	else:
		if z2.has_method("reset_for_pool"):
			z2.reset_for_pool()
		add_child(z2)
		print("POOLTEST: reuse ok same_instance=%s is_dead=%s dead_flag=%s visible=%s health=%s" % [
			str(z2 == z), str(z2.is_dead), str(z2.get("dead")), str(z2.visible), str(z2.get("health"))])
		if z2 != z:
			print("POOLTEST: FAIL — reuse returned a different instance")
			fails += 1
		if z2.is_dead or not z2.visible or z2.get("health") <= 0:
			print("POOLTEST: FAIL — reset_for_pool did not restore state")
			fails += 1

	# ---- double-return guard ----
	pool._on_killed(z2)
	pool._on_killed(z2)
	print("POOLTEST: double-return guard dead=%d (expect 3)" % pool.get_dead_size())
	if pool.get_dead_size() != 3:
		print("POOLTEST: FAIL — duplicate pushed into dead pool")
		fails += 1

	print("POOLTEST: %s (%d failures)" % ["ALL PASS" if fails == 0 else "FAILURES", fails])
	get_tree().quit()
