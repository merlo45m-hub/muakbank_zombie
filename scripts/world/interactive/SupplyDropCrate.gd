extends Node3D
class_name SupplyDropCrate

@export var controller_path: NodePath = ^"../Controller"
@export var open_sound: StringName = &"crate_rummage"

var controller: Node
var available: bool = false
var is_open: bool = false
var player_near: bool = false
var prompt: Label3D
var lid: Node3D

func _ready() -> void:
	controller = get_node_or_null(controller_path)
	prompt = get_node_or_null("Prompt") as Label3D
	lid = get_node_or_null("Lid") as Node3D
	var zone := get_node_or_null("InteractionZone") as Area3D
	if zone:
		zone.body_entered.connect(_on_zone_body_entered)
		zone.body_exited.connect(_on_zone_body_exited)
	if Audio and Audio.has_method("play_sfx"):
		open_sound = &"crate_rummage"
	_refresh_prompt()

func set_available(value: bool) -> void:
	available = value
	is_open = false
	if available:
		add_to_group("interactive_prop")
	else:
		remove_from_group("interactive_prop")
	if lid:
		lid.rotation.x = 0.0
	_refresh_prompt()

func interact() -> void:
	if not available or is_open or not player_near:
		return
	if controller and controller.has_method("claim_supply_drop") and controller.claim_supply_drop():
		is_open = true
		remove_from_group("interactive_prop")
		if Audio and Audio.has_method("play_sfx"):
			Audio.play_sfx(open_sound)
		if lid:
			var tween := create_tween()
			tween.tween_property(lid, "rotation:x", deg_to_rad(-70.0), 0.3)
		_refresh_prompt()

func _on_zone_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = true
		_refresh_prompt()

func _on_zone_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_near = false
		_refresh_prompt()

func _refresh_prompt() -> void:
	if prompt:
		prompt.visible = available and player_near and not is_open
		prompt.text = "OPEN SUPPLY DROP [ATTACK]"
