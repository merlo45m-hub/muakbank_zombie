extends Node3D
## Minimal player stub for the minigame winnability probe. Mirrors the exact
## API surface the 3 controllers call on the real Player.gd so the probe drives
## the REAL controller code paths, not fake constants.

var health: int = 100
var max_health: int = 100
var is_dead: bool = false
var move_speed: float = 4.5
var sprint_speed: float = 7.5
var weapon_system: Node
var _inventory: Dictionary = {}
var velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("player")
	weapon_system = load("res://scripts/gameplay/WeaponSystem.gd").new()
	weapon_system.name = "WeaponSystem"
	add_child(weapon_system)

func get_food_count(food_type: String) -> int:
	var entry = _inventory.get(food_type)
	return int(entry.get("count", 0)) if entry is Dictionary else 0

func has_food(food_type: String) -> bool:
	return get_food_count(food_type) > 0

func add_food(food_type: String, heal: int) -> void:
	var entry = _inventory.get(food_type)
	if entry is Dictionary:
		entry["count"] = int(entry["count"]) + 1
		entry["heal"] = heal
	else:
		_inventory[food_type] = {"count": 1, "heal": heal}

func consume_food_type(food_type: String) -> bool:
	var entry = _inventory.get(food_type)
	if not entry is Dictionary or int(entry.get("count", 0)) <= 0:
		return false
	var remaining: int = int(entry["count"]) - 1
	if remaining > 0:
		entry["count"] = remaining
	else:
		_inventory.erase(food_type)
	return true

func take_damage(_amount: int) -> void:
	if is_dead:
		return
	health = max(0, health - _amount)
	if health <= 0:
		is_dead = true

func heal(_amount: int) -> void:
	health = min(max_health, health + _amount)

func equip(_w: String) -> void:
	pass
