extends SceneTree
func _init() -> void:
	for s in ["gamer", "doctor", "nurse", "streamer", "hunter"]:
		var p: String = "res://scenes/characters/character_" + s + ".tscn"
		var res: Resource = load(p)
		print("LOAD ", s, " -> ", res)
	var cs: Resource = load("res://scenes/ui/character_select.tscn")
	print("LOAD charselect -> ", cs)
	quit()
