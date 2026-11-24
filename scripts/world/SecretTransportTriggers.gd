## SecretTransportTriggers.gd — Issue #83
## Deterministic Area3D triggers for secret transport links.
## Spawned by Game.gd in _load_environment; no .tscn edits required.
extends Node3D

# Trigger configuration: (region_id, to_region, local_position, label)
# Region 1 (Suburban) -> 2: hidden graveyard crypt / utility tunnel
# Region 2 (Industrial) -> 3: sub-level freight conduit / hazmat rail
# Region 3 (Bio-Lab) -> 1: emergency decontamination chute
# Region 3 (Bio-Lab) -> 2: return conduit to Industrial

const TRIGGER_DEFS := [
	{ "from": 1, "to": 2, "pos": Vector3(-34.0, 0.5, -34.0), "label": "secret_crypt_to_industrial" },
	{ "from": 2, "to": 3, "pos": Vector3(40.0, 0.5, 40.0), "label": "secret_freight_to_biolab" },
	{ "from": 3, "to": 1, "pos": Vector3(-30.0, 0.5, -30.0), "label": "secret_decon_to_suburban" },
	{ "from": 3, "to": 2, "pos": Vector3(30.0, 0.5, 30.0), "label": "secret_conduit_to_industrial" },
]

var _wp: Node = null
var _hop: Node = null
var _active_triggers: Array[Area3D] = []
var _fired: Dictionary = {}  # trigger_label -> bool

func _ready() -> void:
	_wp = get_node_or_null("/root/WorldProgression")
	_hop = get_node_or_null("/root/WorldHopManager")
	if _wp == null or _hop == null:
		push_warning("[SecretTransportTriggers] WorldProgression or WorldHopManager not found")
	set_process(false)

func spawn_triggers_for_region(region_id: int) -> void:
	# Clear any existing triggers from previous region
	clear_triggers()

	if _wp == null or _hop == null:
		return

	var current: int = int(_wp.current_region)
	if current != region_id:
		return

	for def in TRIGGER_DEFS:
		if def.from != region_id:
			continue
		if not _wp.is_secret_reachable(def.from, def.to):
			continue

		var trigger := Area3D.new()
		trigger.name = def.label
		trigger.global_position = def.pos

		var shape := SphereShape3D.new()
		shape.radius = 2.0
		var coll := CollisionShape3D.new()
		coll.shape = shape
		trigger.add_child(coll)

		trigger.set_collision_layer_value(1, false)
		trigger.set_collision_layer_value(2, true)  # Player layer
		trigger.set_collision_mask_value(1, false)
		trigger.set_collision_mask_value(2, true)

		trigger.body_entered.connect(_on_body_entered.bind(def))
		add_child(trigger)
		_active_triggers.append(trigger)
		_fired[def.label] = false

	set_process(true)
	print("[SecretTransportTriggers] Spawned ", _active_triggers.size(), " triggers for region ", region_id)

func clear_triggers() -> void:
	for t in _active_triggers:
		if is_instance_valid(t):
			t.queue_free()
	_active_triggers.clear()
	_fired.clear()

func _on_body_entered(body: Node3D, def: Dictionary) -> void:
	if not body.is_in_group("player"):
		return
	var label: String = def.label
	if _fired.get(label, false):
		return

	var current: int = int(_wp.current_region)
	if current != def.from:
		return
	if not _wp.is_secret_reachable(def.from, def.to):
		return

	_fired[label] = true
	print("[SecretTransportTriggers] Trigger fired: ", label, " -> region ", def.to)
	_hop.call("request_secret_hop", def.to)

func _process(_delta: float) -> void:
	# Clean up any queued-free triggers
	var i := _active_triggers.size() - 1
	while i >= 0:
		if not is_instance_valid(_active_triggers[i]):
			_active_triggers.remove_at(i)
		i -= 1
	if _active_triggers.is_empty():
		set_process(false)

func get_trigger_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for t in _active_triggers:
		if is_instance_valid(t):
			out.append(t.global_position)
	return out