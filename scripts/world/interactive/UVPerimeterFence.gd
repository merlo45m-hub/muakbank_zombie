extends Node3D
class_name UVPerimeterFence

const SHOCK_DAMAGE_PER_SECOND := 30.0
const SLOW_MULTIPLIER := 0.5

var powered: bool = false
var _damage_carry: Dictionary = {}
var _original_speeds: Dictionary = {}

func _ready() -> void:
	for side in range(4):
		var fence_area := Area3D.new()
		fence_area.name = "FenceSide%d" % side
		fence_area.collision_layer = 0
		fence_area.collision_mask = 8
		fence_area.monitoring = true
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(14.0, 2.0, 0.3) if side % 2 == 0 else Vector3(0.3, 2.0, 14.0)
		collision.shape = shape
		fence_area.add_child(collision)
		add_child(fence_area)
		if side == 0:
			fence_area.position.z = -7.0
		elif side == 1:
			fence_area.position.x = 7.0
		elif side == 2:
			fence_area.position.z = 7.0
		else:
			fence_area.position.x = -7.0
		fence_area.body_exited.connect(_on_body_exited)

func set_powered(value: bool) -> void:
	if powered == value:
		return
	powered = value
	if not powered:
		_restore_all_speeds()

func _physics_process(delta: float) -> void:
	if not powered:
		return
	for fence_area in get_children():
		if not fence_area is Area3D:
			continue
		for body in fence_area.get_overlapping_bodies():
			if not body.is_in_group("enemies") or not is_instance_valid(body) or bool(body.get("is_dead")):
				continue
			var instance_id := body.get_instance_id()
			var speed: Variant = body.get("move_speed")
			if speed != null and not _original_speeds.has(instance_id):
				_original_speeds[instance_id] = float(speed)
				body.set("move_speed", float(speed) * SLOW_MULTIPLIER)
			var carry := float(_damage_carry.get(instance_id, 0.0)) + SHOCK_DAMAGE_PER_SECOND * delta
			var damage := int(carry)
			_damage_carry[instance_id] = carry - float(damage)
			if damage > 0 and body.has_method("take_damage"):
				body.take_damage(damage)

func _on_body_exited(body: Node3D) -> void:
	_restore_speed(body)

func _restore_all_speeds() -> void:
	for fence_area in get_children():
		if fence_area is Area3D:
			for body in fence_area.get_overlapping_bodies():
				_restore_speed(body)
	_damage_carry.clear()

func _restore_speed(body: Node3D) -> void:
	if not is_instance_valid(body):
		return
	var instance_id := body.get_instance_id()
	if _original_speeds.has(instance_id):
		body.set("move_speed", _original_speeds[instance_id])
		_original_speeds.erase(instance_id)
	_damage_carry.erase(instance_id)
