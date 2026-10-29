extends InteractiveDoor
class_name QuarantineSealDoor

## QuarantineBreach door — InteractiveDoor plus brace/socket seal semantics
## (spec: docs/specs/LEVEL1_MINIGAMES_B.md §2). A door is SEALED only when it is
## CLOSED and its assigned brace (supply case or laundry cart) has sat inside
## its BraceSocket for SEAL_DWELL seconds. A closed-but-unbraced door is a
## temporary hold and reopens after UNBRACED_HOLD seconds. During the activity
## the parent door's hold-reset behaviour is disabled.

signal door_sealed(step: String)

const SEAL_DWELL := 0.75
const UNBRACED_HOLD := 4.0
const SOCKET_RADIUS := 1.6

@export var seal_step: String = "A"
@export var assigned_brace: String = "case"  # "case" | "cart"
@export var socket_path: NodePath = ^"BraceSocket"

var sealed: bool = false
var brace_dwell: float = 0.0
var unbraced_timer: float = 0.0

var _socket: Area3D = null

func _ready() -> void:
	super()
	_socket = get_node_or_null(socket_path) as Area3D
	# The activity owns the seal rule; the generic door must not auto-reset or
	# hold-open on its own.
	hold_reset_delay = 9999.0
	lock_collision_when_open = false

func reset_door() -> void:
	sealed = false
	brace_dwell = 0.0
	unbraced_timer = 0.0
	toggle_to_closed()

## A brace is "in the socket" when a body in group quarantine_brace with the
## door's assigned brace_type overlaps the socket area (distance fallback keeps
## the seal deterministic headless without depending on physics sync frames).
func brace_in_socket() -> bool:
	if _socket == null:
		return false
	for body in _socket.get_overlapping_bodies():
		if is_instance_valid(body) and body.is_in_group("quarantine_brace") \
				and body.get("brace_type") == assigned_brace:
			return true
	for body in get_tree().get_nodes_in_group("quarantine_brace"):
		if not is_instance_valid(body) or body.get("brace_type") != assigned_brace:
			continue
		if _socket.global_position.distance_to(body.global_position) <= SOCKET_RADIUS:
			return true
	return false

## Driven by the controller every active frame. Runs the closed+braced seal
## dwell test; a sealed door emits door_sealed exactly once.
func seal_tick(delta: float) -> void:
	if sealed:
		return
	var closed := not is_open and not is_half_open
	var braced := brace_in_socket()
	if closed and braced:
		unbraced_timer = 0.0
		brace_dwell += delta
		if brace_dwell >= SEAL_DWELL:
			sealed = true
			door_sealed.emit(seal_step)
		return
	brace_dwell = 0.0
	if closed and not braced:
		unbraced_timer += delta
		if unbraced_timer >= UNBRACED_HOLD:
			unbraced_timer = 0.0
			open_fully()  # temporary hold expired — the breach stays open
	else:
		unbraced_timer = 0.0
