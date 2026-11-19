extends Node3D
class_name TriageCryoBay

## TriageCryoRecovery bay — one bay per pod type. A matching-type pod that
## stays inside the bay for STABLE_DWELL seconds is delivered; a wrong-type
## pod is bounced back out immediately and the HUD flashes the required type.

signal pod_delivered(pod_type: String, bay: Node)

const STABLE_DWELL := 1.25
const CAPTURE_RADIUS := 1.8
const WRONG_TYPE_BOUNCE := 9.0

const TYPE_COLORS := {
	"cryo_alpha": Color(0.85, 0.15, 0.15),
	"cryo_beta": Color(0.2, 0.35, 0.9),
	"cryo_gamma": Color(0.95, 0.8, 0.15),
	"cryo_delta": Color(0.35, 0.75, 0.3),
	"crate": Color(0.85, 0.15, 0.15),
	"cell": Color(0.2, 0.35, 0.9),
	"module": Color(0.95, 0.8, 0.15),
	"bundle": Color(0.35, 0.75, 0.3),
}

@export var required_pod_type: String = "cryo_alpha"
@export var controller_path: NodePath = ^"../../Controller"
@export var lamp_path: NodePath = ^"Lamp"

var delivered: bool = false
var dwell: float = 0.0
var current_guest: Node3D = null

var _controller: Node = null
var _lamp: MeshInstance3D = null

func _ready() -> void:
	add_to_group("triage_pen")
	_controller = get_node_or_null(controller_path)
	_lamp = get_node_or_null(lamp_path) as MeshInstance3D

func reset_pen() -> void:
	delivered = false
	dwell = 0.0
	current_guest = null
	_update_lamp(false)

func process_capture(delta: float) -> bool:
	if delivered:
		return false
	var guest: Node3D = _find_guest()
	if guest == null:
		dwell = 0.0
		current_guest = null
		return false
	if _guest_type(guest) != required_pod_type or bool(guest.get("delivered")):
		_bounce(guest)
		dwell = 0.0
		current_guest = null
		return false
	current_guest = guest
	dwell += delta
	if dwell >= STABLE_DWELL:
		delivered = true
		current_guest = null
		_update_lamp(true)
		pod_delivered.emit(required_pod_type, self)
		return true
	return false

func _find_guest() -> Node3D:
	var best: Node3D = null
	var best_d := CAPTURE_RADIUS
	for a in get_tree().get_nodes_in_group("triage_animal"):
		if not is_instance_valid(a) or bool(a.get("delivered")):
			continue
		var d: float = global_position.distance_to(a.global_position)
		if d <= best_d:
			best_d = d
			best = a
	return best

func _bounce(guest: Node3D) -> void:
	if guest.has_method("apply_shove"):
		var away := (guest.global_position - global_position)
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3(1, 0, 0)
		guest.call("apply_shove", away.normalized() * WRONG_TYPE_BOUNCE)

func _update_lamp(on: bool) -> void:
	if _lamp == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TYPE_COLORS.get(required_pod_type, Color.WHITE) if on else Color(0.15, 0.15, 0.16)
	mat.emission_enabled = on
	mat.emission = TYPE_COLORS.get(required_pod_type, Color.WHITE) if on else Color.BLACK
	mat.emission_energy_multiplier = 2.2 if on else 0.0
	_lamp.material_override = mat

func _guest_type(guest: Node) -> String:
	var v: Variant = guest.get("pod_type")
	if v == null:
		v = guest.get("unit_type")
	if v == null:
		v = guest.get("animal_type")
	return String(v) if v != null else ""