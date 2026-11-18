extends Node3D
## Procedural blockout dressing from the Kenney survival CC0 pack.
## Populates a world with scaled props; pure geometry, no gameplay logic.

const ASSETS := "res://assets/models/cc0/kenney_survival/"

@export var world_id: String = "OldTown"
@export var prop_count: int = 28
@export var seed_value: int = 20261118

const SUBURBAN := ["barrel", "box", "crate", "fence", "campfire-pit", "bucket", "bedroll"]
const INDUSTRIAL := ["barrel", "box-large", "metal-panel-narrow", "metal-panel-screws-half", "crate", "fence-fortified", "floor-old"]
const BIOLAB := ["barrel", "bottle-large", "chest", "floor", "metal-panel-narrow", "box-open", "grass"]

func _ready() -> void:
	var pool: Array = SUBURBAN
	match world_id:
		"IndustrialDistrict":
			pool = INDUSTRIAL
		"EndgameHeights":
			pool = BIOLAB
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var holder := Node3D.new()
	holder.name = "KenneySurvivalBlockout"
	add_child(holder)
	var placed := 0
	for i in range(prop_count):
		var base := str(pool[i % pool.size()])
		var path: String = ASSETS + base + ".glb"
		if not ResourceLoader.exists(path):
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var inst := packed.instantiate()
		if not (inst is Node3D):
			continue
		var prop := inst as Node3D
		var scale_factor := rng.randf_range(0.55, 1.15)
		prop.scale = Vector3(scale_factor, scale_factor, scale_factor)
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(12.0, 32.0)
		prop.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		prop.rotation.y = rng.randf_range(-PI, PI)
		holder.add_child(prop)
		placed += 1
	print("[KenneyBlockout] ", world_id, " placed ", placed, " props")
