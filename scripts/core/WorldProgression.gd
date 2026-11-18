## WorldProgression.gd — Issue #11 P1, autoload "WorldProgression".
## Single source of truth for world-hopping progression state.
## Emitters (TechPickup/TransportHub/RegionObjectiveTracker) only call report_*.
## Listeners (CollectionManager/UI/Audio/Achievement/Save) only subscribe.
## Canonical signal contract: docs/world_progression.md (approved in issue #16).
extends Node

signal region_unlocked(region_id: int, loot_tier: int)
signal tech_collected(region_id: int, tech_id: StringName, new_count: int, required: int)
signal transport_repaired(region_id: int)
signal milestone_reached(region_id: int, milestone_id: StringName)
signal max_loot_tier_changed(tier: int)
signal hop_started(from_region: int, to_region: int)
signal hop_completed(region_id: int)
signal hop_failed(reason: StringName)

const CATALOG_PATH: String = "res://resources/world/regions.tres"
const SECRET_LINKS_PATH: String = "res://resources/world/secret_links.tres"

var catalog: RegionCatalog = null
var current_region: int = 1
var unlocked_regions: Array[int] = [1]
var tech: Dictionary = {}                       # {region_id:int -> {tech_id:StringName -> count:int}}
var transport_done: Dictionary = {}             # {region_id:int -> bool} — named to avoid the signal `transport_repaired`
var milestones: Dictionary = {}                 # {region_id:int -> Array[StringName]}
var max_loot_tier: int = 1
# GDD-1 additive state (does NOT alter the monotonic progression ceiling).
var secret_catalog: SecretLinkCatalog = null
var visited_regions: Array[int] = [1]
var region_state: Dictionary = {}   # {region_id:int -> Dictionary} per-region world state


func _ready() -> void:
	catalog = load(CATALOG_PATH) as RegionCatalog
	if catalog == null:
		push_warning("[WorldProgression] regions.tres missing — progression disabled")
		return
	secret_catalog = load(SECRET_LINKS_PATH) as SecretLinkCatalog
	if secret_catalog == null:
		push_warning("[WorldProgression] secret_links.tres missing — non-linear hops disabled")
	hydrate(_read_save_world_state())


func _get_save() -> Node:
	return get_node_or_null("/root/Save")


func _read_save_world_state() -> Dictionary:
	var save := _get_save()
	if save != null and save.has_method("get_world_state"):
		return save.get_world_state()
	return {}


func _persist() -> void:
	var save := _get_save()
	if save == null or not save.has_method("set_world_state"):
		return
	save.set_world_state(serialize())
	# Keep the existing level-select UI in sync (unlocked_levels <-> world_unlocked_regions).
	if save.has_method("unlock_level"):
		for rid in unlocked_regions:
			save.unlock_level(rid)


# ── HYDRATE / SERIALIZE ───────────────────────────────────────

func hydrate(data: Dictionary) -> void:
	if data.is_empty():
		return
	current_region = int(data.get("world_current_region", current_region))
	var ur: Array[int] = []
	ur.assign(data.get("world_unlocked_regions", [1]))
	unlocked_regions = ur if not ur.is_empty() else [1]
	var t = data.get("world_tech", {})
	tech = t.duplicate(true) if t is Dictionary else {}
	var tr = data.get("world_transport_repaired", {})
	transport_done = tr.duplicate(true) if tr is Dictionary else {}
	var m = data.get("world_milestones", {})
	milestones = m.duplicate(true) if m is Dictionary else {}
	max_loot_tier = int(data.get("world_max_loot_tier", 1))
	# GDD-1 additive keys: absent in legacy saves -> safe defaults.
	var vr: Array[int] = []
	vr.assign(data.get("world_visited_regions", [1]))
	visited_regions = vr if not vr.is_empty() else [1]
	var rs = data.get("world_region_state", {})
	region_state = rs.duplicate(true) if rs is Dictionary else {}
	_recompute_max_loot_tier(false)


func serialize() -> Dictionary:
	return {
		"world_current_region": current_region,
		"world_unlocked_regions": unlocked_regions.duplicate(),
		"world_tech": tech.duplicate(true),
		"world_transport_repaired": transport_done.duplicate(true),
		"world_milestones": milestones.duplicate(true),
		"world_max_loot_tier": max_loot_tier,
		"world_visited_regions": visited_regions.duplicate(),
		"world_region_state": region_state.duplicate(true)
	}


# ── REPORT (emitters) ─────────────────────────────────────────

func get_def(region_id: int) -> RegionDef:
	return catalog.get_def(region_id) if catalog != null else null


func tech_required_for(region_id: int) -> int:
	var def := get_def(region_id)
	return def.tech_required if def != null else 0


func tech_count(region_id: int) -> int:
	var bucket: Dictionary = tech.get(region_id, {})
	var total := 0
	for v in bucket.values():
		total += int(v)
	return total


func report_tech(region_id: int, tech_id: StringName) -> void:
	var bucket: Dictionary = tech.get(region_id, {})
	bucket[tech_id] = int(bucket.get(tech_id, 0)) + 1
	tech[region_id] = bucket
	# Gate that consumes this tech is the NEXT region in the chain.
	var target := _next_region(region_id)
	var required := tech_required_for(target)
	tech_collected.emit(region_id, tech_id, tech_count(region_id), required)
	if target > 0:
		try_unlock(target)
	_persist()


func report_transport_repaired(region_id: int) -> void:
	transport_done[region_id] = true
	transport_repaired.emit(region_id)
	var target := _next_region(region_id)
	if target > 0:
		try_unlock(target)
	_persist()


func report_milestone(region_id: int, milestone_id: StringName) -> void:
	var done: Array = milestones.get(region_id, [])
	if not done.has(milestone_id):
		done.append(milestone_id)
		milestones[region_id] = done
	milestone_reached.emit(region_id, milestone_id)
	var target := _next_region(region_id)
	if target > 0:
		try_unlock(target)
	_persist()


func _next_region(from_region: int) -> int:
	if catalog == null:
		return 0
	for rid in catalog.ids():
		var def := catalog.get_def(rid)
		if def != null and def.prerequisite_region == from_region:
			return rid
	return 0


# ── GATES ─────────────────────────────────────────────────────

func evaluate_gates(region_id: int) -> Dictionary:
	var def := get_def(region_id)
	if def == null:
		return {"tech": false, "transport": false, "milestones": false,
			"prerequisite": false, "ready": false, "reason": &"unknown_region"}
	var prereq: int = def.prerequisite_region
	var tech_ok := tech_count(prereq) >= def.tech_required if prereq > 0 else true
	var transport_ok := bool(transport_done.get(prereq, false)) if prereq > 0 else true
	var done: Array = milestones.get(prereq, [])
	var milestones_ok := true
	for m in def.milestones_required:
		if not done.has(m):
			milestones_ok = false
			break
	var prereq_ok := prereq == 0 or unlocked_regions.has(prereq)
	var ready := tech_ok and transport_ok and milestones_ok and prereq_ok
	return {"tech": tech_ok, "transport": transport_ok,
		"milestones": milestones_ok, "prerequisite": prereq_ok, "ready": ready}


func can_hop(to_region: int) -> bool:
	# GDD-1: linear unlocked path preserved; secret transport adds a parallel
	# reachability path so players can jump ahead without 100% zone checklists.
	if not unlocked_regions.has(to_region) and not is_secret_reachable(current_region, to_region):
		return false
	return get_def(to_region) != null


func try_unlock(region_id: int) -> bool:
	if unlocked_regions.has(region_id):
		return false
	var gates := evaluate_gates(region_id)
	if not bool(gates.get("ready", false)):
		return false
	var def := get_def(region_id)
	unlocked_regions.append(region_id)
	unlocked_regions.sort()
	region_unlocked.emit(region_id, def.loot_tier)
	_recompute_max_loot_tier(true)
	_persist()
	return true


func _recompute_max_loot_tier(emit_changed: bool) -> void:
	var tier := 1
	for rid in unlocked_regions:
		var def := get_def(rid)
		if def != null:
			tier = maxi(tier, def.loot_tier)
	if tier != max_loot_tier:
		max_loot_tier = tier
		if emit_changed:
			max_loot_tier_changed.emit(tier)


func get_loot_tier_cap() -> int:
	return max_loot_tier


# ── HOP REPORT (called by WorldHopManager, P3) ────────────────

func report_hop_started(from_region: int, to_region: int) -> void:
	hop_started.emit(from_region, to_region)


func report_hop_completed(region_id: int) -> void:
	current_region = region_id
	if not visited_regions.has(region_id):
		visited_regions.append(region_id)
		visited_regions.sort()
	hop_completed.emit(region_id)
	_persist()


func report_hop_failed(reason: StringName) -> void:
	hop_failed.emit(reason)

# ── GDD-1: NON-LINEAR SECRET TRANSPORT (#25) ───────────────────

func is_secret_reachable(from_region: int, to_region: int) -> bool:
	"""True when a directed secret link exists AND its repair gate is met."""
	if secret_catalog == null or from_region == to_region:
		return false
	var edge := secret_catalog.get_edge(from_region, to_region)
	if edge.is_empty():
		return false
	if bool(edge.get("requires_repair", false)) and not bool(transport_done.get(from_region, false)):
		return false
	return true


func secret_targets(from_region: int) -> Array[int]:
	return secret_catalog.targets_from(from_region) if secret_catalog != null else []


func report_secret_hop(region_id: int) -> bool:
	"""Jump-ahead unlock that BYPASSES the 4 linear gates (GDD §3). Kept separate
	from try_unlock so the linear playtest's gate calls are unaffected."""
	if get_def(region_id) == null or unlocked_regions.has(region_id):
		return false
	unlocked_regions.append(region_id)
	unlocked_regions.sort()
	var def := get_def(region_id)
	region_unlocked.emit(region_id, def.loot_tier)
	_recompute_max_loot_tier(true)
	_persist()
	return true


func get_active_loot_tier() -> int:
	"""Location-aware tier (GDD: high-tier gear follows the player's world).
	Separate from the monotonic progression ceiling get_loot_tier_cap()."""
	var def := get_def(current_region)
	return def.loot_tier if def != null else 1


func store_region_state(region_id: int, data: Dictionary) -> void:
	region_state[region_id] = data.duplicate(true)


func get_region_state(region_id: int) -> Dictionary:
	var d = region_state.get(region_id, {})
	return d.duplicate(true) if d is Dictionary else {}


func is_bidirectional(from_region: int, to_region: int) -> bool:
	return is_secret_reachable(from_region, to_region) and is_secret_reachable(to_region, from_region)

