extends Node3D
class_name FoodCrate

## Food Crate — One-shot open: spawns a single food item at the opening, plays
## rummage sound, then the crate is a static opened prop until reset.
## The spawned food uses the existing FoodItem3D system so the player collects
## it by walking over (same as FoodSpawner-spawned food).
##
## Food selection: picks the nearest registered food scene by type priority —
## tries to spawn medkit or battery for gameplay variety, falling back to burger.

@export var food_to_spawn: String = "medkit"               # default food type to spawn
@export var spawn_height_above_ground: float = 0.5         # Y offset when spawning food
@export var open_animation_duration: float = 0.35           # lid open tween seconds
@export var rummage_sound: StringName = "crate_rummage"
@export var reset_on_player_away: bool = true               # auto-close when player leaves
@export var reset_delay: float = 5.0                        # seconds before reset

# Runtime state
var is_open: bool = false
var lid_node: MeshInstance3D = null
var interaction_zone: Area3D = null
var body_node: StaticBody3D = null
var spawned_food: Node3D = null
var player_near: bool = false
var reset_timer: float = 0.0
var reset_pending: bool = false

# Food scene registry (mirrors FoodSpawner.gd)
var food_burger_scene = preload("res://scenes/world/food_burger.tscn")
var food_soda_scene = preload("res://scenes/world/food_soda.tscn")
var food_medkit_scene = preload("res://scenes/world/food_medkit.tscn")
var food_battery_scene = preload("res://scenes/world/food_battery.tscn")
var food_pizza_scene = preload("res://scenes/world/food_pizza.tscn")
var food_fries_scene = preload("res://scenes/world/food_fries.tscn")
var food_sushi_scene = preload("res://scenes/world/food_sushi.tscn")
var food_takis_scene = preload("res://scenes/world/food_takis.tscn")
var food_coffee_scene = preload("res://scenes/world/food_coffee.tscn")
var food_ammo_scene = preload("res://scenes/world/food_ammo.tscn")

func _ready() -> void:
	add_to_group("interactive_prop")
	lid_node = get_node_or_null("Lid")
	interaction_zone = get_node_or_null("InteractionZone")
	body_node = get_node_or_null("Collision") or get_node_or_null("Body")

	if interaction_zone:
		interaction_zone.body_entered.connect(_on_zone_body_entered)
		interaction_zone.body_exited.connect(_on_zone_body_exited)

	# Resolve rummage sound
	if Audio:
		rummage_sound = "crate_rummage" if Audio.has_sound("crate_rummage") else ""

	# Start closed
	is_open = false

# ── ZONE CALLBACKS ──────────────────────────────────────────────────────────────

func _on_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true

func _on_zone_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false
		if is_open and reset_on_player_away:
			reset_pending = true
			reset_timer = reset_delay

# ── INTERACTION ─────────────────────────────────────────────────────────────────

## Call from player interaction or zone input. Opens crate once, spawns food.
func interact() -> void:
	open_crate()

func open_crate() -> void:
	if is_open:
		return
	is_open = true
	_play_rummage_sound()
	_animate_lid_open()
	_spawn_food_item()

# ── LID ANIMATION ────────────────────────────────────────────────────────────────

func _animate_lid_open() -> void:
	if not lid_node:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Lid rotates up on local X axis (typical crate lid hinge)
	tween.tween_property(lid_node, "rotation:x", deg_to_rad(75.0), open_animation_duration)

# ── FOOD SPAWN ───────────────────────────────────────────────────────────────────

func _spawn_food_item() -> void:
	# Find ground height via raycast (same pattern as FoodSpawner._spawn_random_food)
	var spawn_pos := global_transform.origin + Vector3(0, 0.5, 0)  # 0.5m above crate center
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		spawn_pos + Vector3(0, 2.0, 0),
		spawn_pos + Vector3(0, -30.0, 0)
	)
	var result = space_state.intersect_ray(query)
	if result:
		spawn_pos.y = result.position.y + spawn_height_above_ground
	else:
		spawn_pos.y = spawn_height_above_ground

	# Select food scene by type
	var food_scene = _select_food_scene(food_to_spawn)
	if not food_scene:
		print("[FoodCrate] No food scene for type: " + food_to_spawn)
		return

	# Instantiate and place
	var food_item := food_scene.instantiate() as FoodItem3D
	if not food_item:
		return
	add_child(food_item)
	food_item.global_position = spawn_pos
	spawned_food = food_item

	# Set food type on the item
	food_item.food_type = food_to_spawn
	# Set health_amount from the food type's known heal value
	food_item.health_amount = _food_heal_value(food_to_spawn)

	# Bind collected signal to cleanup
	food_item.collected.connect(_on_food_collected.bind(food_item))

	# Pickup feedback on the player near the crate
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var hf := player.get_node_or_null("HitFeedback")
		if hf and hf.has_method("emit_pickup"):
			hf.emit_pickup(spawn_pos)
		Input.vibrate_handheld(15)

# ── FOOD SELECTION ───────────────────────────────────────────────────────────────

func _select_food_scene(food_type: String) -> PackedScene:
	match food_type:
		"burger":   return food_burger_scene
		"soda":     return food_soda_scene
		"medkit":   return food_medkit_scene
		"battery":  return food_battery_scene
		"pizza":    return food_pizza_scene
		"fries":    return food_fries_scene
		"sushi":    return food_sushi_scene
		"takis":    return food_takis_scene
		"coffee":   return food_coffee_scene
		"ammo":     return food_ammo_scene
		_:
			# Default to burger
			return food_burger_scene

func _food_heal_value(food_type: String) -> int:
	# Heal values match the food scene health_amount defaults.
	# These are the scene-declared values; the player's inventory records them
	# at pickup time so consume_food uses the same number.
	match food_type:
		"burger":   return 35
		"soda":     return 15
		"medkit":   return 50
		"battery":  return 0   # battery is for the weapon, not healing
		"pizza":    return 25
		"fries":    return 20
		"sushi":    return 30
		"takis":    return 10
		"coffee":   return 20
		"ammo":     return 0
		_:
			return 20

# ── FOOD COLLECTED CALLBACK ──────────────────────────────────────────────────────

func _on_food_collected(_player: Node3D, food: Node3D) -> void:
	# Food item self-destroys in collect(). This handler just notes it.
	if spawned_food == food:
		spawned_food = null

# ── RESET ────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if reset_pending:
		reset_timer -= delta
		if reset_timer <= 0.0:
			reset_pending = false
			_reset_crate()

func _reset_crate() -> void:
	# Close the crate: remove spawned food, reset lid, re-enable interaction.
	if spawned_food and is_instance_valid(spawned_food):
		spawned_food.queue_free()
		spawned_food = null
	is_open = false
	if lid_node:
		lid_node.rotation.x = 0.0
	# Re-enable zone
	if interaction_zone:
		interaction_zone.monitoring = true

# ── AUDIO ────────────────────────────────────────────────────────────────────────

func _play_rummage_sound() -> void:
	if Audio and rummage_sound != "":
		Audio.play_sound(rummage_sound)
