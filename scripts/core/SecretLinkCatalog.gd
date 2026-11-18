## SecretLinkCatalog.gd — GDD-1 / #25. Directed secret-transport edges.
## The GDD Figure 2 graph: W1<->W2<->W3 bidirectional, plus a W3 return chute
## back to both W1 and W2. Loaded by WorldProgression as an ADDITIVE layer; the
## linear prerequisite_region chain in regions.tres is deliberately untouched.
class_name SecretLinkCatalog
extends Resource

@export var edges: Array[Dictionary] = []

func get_edge(from_region: int, to_region: int) -> Dictionary:
	for e in edges:
		if int(e.get("from", -1)) == from_region and int(e.get("to", -1)) == to_region:
			return e
	return {}

func targets_from(from_region: int) -> Array[int]:
	var out: Array[int] = []
	for e in edges:
		if int(e.get("from", -1)) == from_region:
			out.append(int(e.get("to", -1)))
	return out

func has_link(from_region: int, to_region: int) -> bool:
	return not get_edge(from_region, to_region).is_empty()
