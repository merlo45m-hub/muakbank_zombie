## RegionDef.gd — data for one world region (Issue #11 world-hopping progression).
## A region is one of the 3 existing environments (LevelManager.environments keys 1..3).
class_name RegionDef
extends Resource

@export var id: int = 0
@export var display_name: String = ""
@export var scene_path: String = ""
@export var loot_tier: int = 1
@export var tech_required: int = 0
@export var transport_parts_required: int = 0
@export var milestones_required: Array[StringName] = []
@export var prerequisite_region: int = 0  # 0 = none (region 1)
@export var spawn_point: Vector3 = Vector3.ZERO
