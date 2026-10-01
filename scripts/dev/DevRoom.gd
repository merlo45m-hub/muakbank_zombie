extends Node3D

var spawned_nodes: Array[Node] = []
var spawn_parent: Node3D

func _ready() -> void:
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		return
		
	spawn_parent = Node3D.new()
	spawn_parent.name = "Spawned"
	add_child(spawn_parent)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if not (event is InputEventKey): return
	
	if event.physical_keycode == KEY_1:
		_spawn("res://scenes/characters/zombie_dog.tscn", "ZombieDog")
	elif event.physical_keycode == KEY_2:
		_spawn("res://scenes/characters/zombie_boss.tscn", "ZombieBoss")
	elif event.physical_keycode == KEY_3:
		_spawn("res://scenes/world/food_burger.tscn", "FoodBurger")
	elif event.physical_keycode == KEY_4:
		_spawn("res://scenes/world/weapon_pickup_bat.tscn", "WeaponPickup_bat")
	elif event.physical_keycode == KEY_5:
		_spawn("res://scenes/world/powerup.tscn", "PowerUp")
	elif event.physical_keycode == KEY_R:
		_clear_spawned()

func _spawn(path: String, debug_name: String) -> void:
	var scn = load(path)
	if not scn: return
	var inst = scn.instantiate()
	if not inst or not (inst is Node3D): return
	
	var p_pos = Vector3.ZERO
	var p_fwd = Vector3(0, 0, -1)
	
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]) and players[0] is Node3D:
		var player = players[0]
		p_pos = player.global_position
		p_fwd = -player.global_transform.basis.z.normalized()
		if p_fwd.length_squared() < 0.1: p_fwd = Vector3(0, 0, -1)
		
	var spawn_pos = p_pos + (p_fwd * 8.0)
	spawn_pos.y = p_pos.y
	
	inst.global_position = spawn_pos
	spawn_parent.add_child(inst)
	spawned_nodes.append(inst)
	print("[dev] spawned ", debug_name)

func _clear_spawned() -> void:
	for n in spawned_nodes:
		if is_instance_valid(n):
			n.queue_free()
	spawned_nodes.clear()
	print("[dev] cleared spawned nodes")

func _exit_tree() -> void:
	_clear_spawned()
