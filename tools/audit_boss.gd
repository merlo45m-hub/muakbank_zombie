extends Node
## AUDIT-ONLY: proves the boss reward path end-to-end. Nests the real game scene,
## spawns the boss via WaveManager's own path, kills it, and asserts score/kills/
## achievement land and the wave counter decrements exactly ONCE.

var game: Node = null

func _ready() -> void:
	var gs: PackedScene = load("res://scenes/main/game.tscn")
	if gs == null:
		print("AUDITBOSS: load failed")
		get_tree().quit(1)
		return
	game = gs.instantiate()
	add_child(game)
	for i in 30:
		await get_tree().process_frame

	var wm: Node = game.get_node_or_null("WaveManager")
	var am: Node = game.get_node_or_null("AchievementManager")
	print("AUDITBOSS: wm=", wm != null, " am=", am != null)
	if wm == null:
		get_tree().quit(1)
		return

	wm._spawn_boss()
	for i in 30:
		await get_tree().process_frame

	var boss: Node = null
	for c in wm.get_children():
		if c.get("zombie_type") == "boss":
			boss = c
			break
	print("AUDITBOSS: boss=", boss, " zombie_type=", boss.get("zombie_type") if boss else "n/a")
	if boss == null:
		get_tree().quit(1)
		return

	var score_before: int = game.score
	var kills_before: int = game.zombies_killed
	var alive_before: int = wm.zombies_alive
	print("AUDITBOSS: before kill — score=", score_before, " kills=", kills_before, " alive=", alive_before)

	boss.take_damage(999999)
	await get_tree().create_timer(3.5).timeout
	await get_tree().process_frame

	var ok := true
	print("AUDITBOSS: score ", score_before, " -> ", game.score, " (expect +>=100)")
	print("AUDITBOSS: kills ", kills_before, " -> ", game.zombies_killed, " (expect +1)")
	print("AUDITBOSS: alive ", alive_before, " -> ", wm.zombies_alive, " (expect exactly -1)")
	if game.score <= score_before:
		ok = false
	if game.zombies_killed != kills_before + 1:
		ok = false
	if wm.zombies_alive != alive_before - 1:
		ok = false
	if am and am.has_method("is_unlocked"):
		var unl: bool = am.is_unlocked("boss_slayer")
		print("AUDITBOSS: boss_slayer unlocked=", unl)
		if not unl:
			ok = false
	print("AUDITBOSS: RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
