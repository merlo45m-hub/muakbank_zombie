## Tutorial.gd — autoload that exposes the Dialogue Manager tutorial.
## Single callable `start_tutorial()` shows the bilingual intro balloon once
## (first run only, tracked with the existing Save.is_tutorial_completed() flag).
## The balloon instantiates on top of whichever scene is current, so it can be
## launched from anywhere later without coupling to a specific scene.
extends Node

const TUTORIAL_SCENE := preload("res://scenes/ui/tutorial_dialogue.tscn")

var _active: TutorialDialogue = null


## Show the tutorial. Returns immediately; emits nothing. On first run it mounts
## the balloon over the current scene and, on finish, marks the tutorial complete
## so it never auto-shows again. `force` reveals it regardless of the first-run flag.
func start_tutorial(force: bool = false) -> void:
	if _active != null:
		return
	if not force and Save.is_tutorial_completed():
		return
	# Mount on the root so the balloon survives scene changes (title -> character
	# select -> gameplay) and the intro is not killed mid-transition.
	var parent: Node = get_tree().root
	var balloon: TutorialDialogue = TUTORIAL_SCENE.instantiate()
	parent.add_child(balloon)
	_active = balloon
	balloon.finished.connect(_on_tutorial_finished)
	await balloon.start()


func _on_tutorial_finished() -> void:
	Save.complete_tutorial()
	if is_instance_valid(_active):
		_active.queue_free()
	_active = null
