## TutorialDialogue.gd — self-contained Dialogue Manager controller.
## A reusable CanvasLayer balloon that loads a DialogueResource and steps through
## it with the DialogueManager runtime, rendering bilingual (EN/KYR) text and
## branching responses. Drop DialogueManager into any scene, call `start()`.
class_name TutorialDialogue
extends CanvasLayer

signal finished

## Path to the .dialogue resource to load when start() is called.
@export var dialogue_path: String = "res://resources/dialogue/tutorial_intro.dialogue"
@export var start_cue: String = "start"

## Cooldown so the first click doesn't immediately skip the opening line.
var _input_lockout: float = 0.25

var _resource: DialogueResource = null
var _line: DialogueLine = null
var _states: Array = []
var _running: bool = false

@onready var _balloon: Panel = $Balloon
@onready var _character: RichTextLabel = $Balloon/Character
@onready var _text: RichTextLabel = $Balloon/Text
@onready var _responses: VBoxContainer = $Balloon/Responses


func _ready() -> void:
	_balloon.hide()


## Start a dialogue. `resource` overrides the exported dialog path; `cue` overrides
## the starting cue. Returns normally; emits `finished` when the dialogue ends.
func start(resource: Resource = null, cue: String = "") -> void:
	if not cue.is_empty():
		start_cue = cue
	if resource != null and resource is DialogueResource:
		_resource = resource as DialogueResource
	else:
		_resource = load(dialogue_path) as DialogueResource
	if _resource == null:
		push_error("[TutorialDialogue] Failed to load dialogue resource: %s" % dialogue_path)
		finished.emit()
		return
	_running = true
	_input_lockout = 0.25
	_states = [self]
	_balloon.show()
	await _advance(start_cue)


## Advance to the given cue/id and render it.
func _advance(cue: String) -> void:
	if not _running:
		return
	_line = await _resource.get_next_dialogue_line(cue, _states)
	if _line == null:
		_end()
		return
	_render_line()


func _render_line() -> void:
	# Character name (EN + KYR kept plain in the resource; tr() makes it translatable).
	_character.visible = not _line.character.is_empty()
	_character.text = tr(_line.character, "dialogue")

	_text.text = tr(_line.text, "dialogue")

	# Rebuild the response buttons from this line's branches.
	for child in _responses.get_children():
		child.queue_free()
	for response in _line.responses:
		var btn := Button.new()
		btn.text = tr(response.text, "dialogue")
		btn.pressed.connect(_on_response.bind(response.next_id))
		_responses.add_child(btn)


func _on_response(next_id: String) -> void:
	_advance(next_id)


func _unhandled_input(event: InputEvent) -> void:
	if not _running or _line == null or _balloon == null or not _balloon.visible:
		return
	# Let the response buttons handle clicks themselves.
	if _line.responses.size() > 0:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		if _input_lockout > 0.0:
			_input_lockout -= get_process_delta_time()
			return
		_advance(_line.next_id)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _input_lockout > 0.0:
		_input_lockout -= delta


func _end() -> void:
	_running = false
	_balloon.hide()
	finished.emit()
