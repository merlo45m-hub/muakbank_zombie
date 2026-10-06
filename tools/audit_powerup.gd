extends Node
## AUDIT-ONLY: proves the PowerUpManager arity fix end-to-end. Nests the real game
## scene, wires a powerup exactly like the manager's spawn path, triggers the
## collection, and asserts the manager's signal fires (old code dropped the call
## with "Method expected 1 argument(s), but called with 2") and the list is erased.

var game: Node = null
var fired: bool = false
var fired_type: String = ""

func _on_pu(t: String) -> void:
	fired = true
	fired_type = t

func _ready() -> void:
	var gs: PackedScene = load("res://scenes/main/game.tscn")
	if gs == null:
		print("AUDITPU: game.tscn load failed")
		get_tree().quit(1)
		return
	game = gs.instantiate()
	add_child(game)
	for i in 30:
		await get_tree().process_frame

	var manager: Node = game.get_node_or_null("PowerUpManager")
	var player: Node = get_tree().get_first_node_in_group("player")
	print("AUDITPU: manager=", manager != null, " player=", player != null)
	if manager == null or player == null:
		get_tree().quit(1)
		return
	manager.powerup_collected.connect(_on_pu)

	var scene: PackedScene = load("res://scenes/world/powerup.tscn")
	var p: Node = scene.instantiate()
	p.set("powerup_type", "health")
	manager.add_child(p)
	p.global_position = (player as Node3D).global_position
	manager.active_powerups.append(p)
	p.collected.connect(manager._on_powerup_collected.bind(p))
	print("AUDITPU: wired; active=", manager.active_powerups.size())

	p._on_body_entered(player)
	await get_tree().process_frame
	await get_tree().process_frame
	print("AUDITPU: fired=", fired, " type=", fired_type, " active_after=", manager.active_powerups.size())
	var active_after: int = manager.active_powerups.size()
	var ok: bool = fired and fired_type == "health" and active_after == 0
	print("AUDITPU: RESULT=", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
