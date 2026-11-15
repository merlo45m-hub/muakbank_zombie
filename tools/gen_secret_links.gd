extends SceneTree
## Regenerates res://resources/world/secret_links.tres via Godot ResourceSaver.
const OUT := "res://resources/world/secret_links.tres"
func _initialize() -> void:
	var c := SecretLinkCatalog.new()
	# GDD section 3 + Figure 2: bidirectional secret transport, W3 return chute.
	var rows := [
		{"from": 1, "to": 2, "requires_repair": true,  "label": "Hidden graveyard crypt / utility tunnel"},
		{"from": 2, "to": 1, "requires_repair": false, "label": "Return conduit to Suburban"},
		{"from": 2, "to": 3, "requires_repair": true,  "label": "Sub-level freight conduit / hazmat rail"},
		{"from": 3, "to": 2, "requires_repair": false, "label": "Return conduit to Industrial"},
		{"from": 3, "to": 1, "requires_repair": false, "label": "Emergency decontamination chute to Suburban"},
	]
	var typed: Array[Dictionary] = []
	typed.assign(rows)
	c.edges = typed
	var err := ResourceSaver.save(c, OUT)
	var back := load(OUT) as SecretLinkCatalog
	print("GEN_ERR=", err, " EDGES=", back.edges.size() if back else -1)
	print("FROM1=", back.targets_from(1) if back else [], " FROM3=", back.targets_from(3) if back else [])
	quit(0 if err == OK and back != null and back.edges.size() == 5 else 1)
