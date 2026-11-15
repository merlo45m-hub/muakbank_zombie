class_name RegionStat
extends Resource

## RegionStat — derived progress readout for one region (1..3).
## Owned by ProgressTracker, read-only to the museum UI.

@export var region_id: int = 1
@export var milestones_total: int = 0
@export var milestones_done: int = 0
@export var transport_repaired: bool = false
@export var loot_tier_unlocked: int = 1
@export var scavenged_count: int = 0
@export var scavenged_total: int = 0
@export var kills: int = 0
@export var food_collected: int = 0
@export var first_entered_ts: int = 0


func completion_ratio() -> float:
	if milestones_total <= 0:
		return 0.0
	return clampf(float(milestones_done) / float(milestones_total), 0.0, 1.0)


func to_dict() -> Dictionary:
	var out := {}
	out["region_id"] = region_id
	out["milestones_total"] = milestones_total
	out["milestones_done"] = milestones_done
	out["transport_repaired"] = transport_repaired
	out["loot_tier_unlocked"] = loot_tier_unlocked
	out["scavenged_count"] = scavenged_count
	out["scavenged_total"] = scavenged_total
	out["kills"] = kills
	out["food_collected"] = food_collected
	out["first_entered_ts"] = first_entered_ts
	return out


static func from_dict(d: Dictionary) -> RegionStat:
	var s := RegionStat.new()
	s.region_id = int(d.get("region_id", 1))
	s.milestones_total = int(d.get("milestones_total", 0))
	s.milestones_done = int(d.get("milestones_done", 0))
	s.transport_repaired = bool(d.get("transport_repaired", false))
	s.loot_tier_unlocked = int(d.get("loot_tier_unlocked", 1))
	s.scavenged_count = int(d.get("scavenged_count", 0))
	s.scavenged_total = int(d.get("scavenged_total", 0))
	s.kills = int(d.get("kills", 0))
	s.food_collected = int(d.get("food_collected", 0))
	s.first_entered_ts = int(d.get("first_entered_ts", 0))
	return s
