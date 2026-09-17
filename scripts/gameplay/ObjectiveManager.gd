extends Node
class_name ObjectiveManager

## ObjectiveManager — Tracks and displays objectives
## Attach to root game node. Manages a list of objectives.

signal objective_updated(objective_id, progress, target)
signal objective_completed(objective_id)
signal all_objectives_completed

var objectives: Dictionary = {}  # id -> {title, target, progress, completed}

func add_objective(id: String, title: String, target: int = 1) -> void:
	objectives[id] = {
		"title": title,
		"target": target,
		"progress": 0,
		"completed": false
	}
	objective_updated.emit(id, 0, target)

func update_progress(id: String, amount: int = 1) -> void:
	if not objectives.has(id) or objectives[id].completed:
		return
	objectives[id].progress += amount
	var obj = objectives[id]
	objective_updated.emit(id, obj.progress, obj.target)
	if obj.progress >= obj.target:
		obj.completed = true
		objective_completed.emit(id)
		_check_all_completed()

func _check_all_completed() -> void:
	for obj in objectives.values():
		if not obj.completed:
			return
	all_objectives_completed.emit()

func get_objective_text(id: String) -> String:
	if not objectives.has(id):
		return ""
	var obj = objectives[id]
	return "%s (%d/%d)" % [obj.title, obj.progress, obj.target]

func clear_objectives() -> void:
	objectives.clear()
