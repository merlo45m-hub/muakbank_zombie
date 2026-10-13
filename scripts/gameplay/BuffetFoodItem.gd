extends FoodItem3D
class_name BuffetFoodItem

## BuffetFoodItem — Specialized food item for the Spoil & Survive buffet challenge.
## Extends FoodItem3D to reuse bobbing and food hierarchy, but replaces
## walkover inventory collection with diegetic in-world consumption.

signal consumed(player: Node3D, is_tainted: bool)

const TAINTED_COLOR := Color(0.35, 0.52, 0.22, 1.0)
const TAINTED_ROUGHNESS := 0.85
const FRESH_GLINT_COLOR := Color(1.0, 0.84, 0.3, 0.8)
const MOLD_SPORE_COLOR := Color(0.42, 0.65, 0.25, 0.75)

var is_tainted: bool = false
var is_eaten: bool = false

var glint_particles: CPUParticles3D = null
var mold_particles: CPUParticles3D = null
var fly_audio: AudioStreamPlayer3D = null

func _ready() -> void:
	# Keep FoodItem3D group for consistency, but disable walkover auto-pickup
	add_to_group("buffet_food")
	bob_height = 0.04
	bob_speed = 1.8
	start_y = position.y
	time_offset = randf() * 10.0
	collision_layer = 4
	collision_mask = 0

## Populates this buffet dish using an existing food scene template.
func setup_dish(template_scene: PackedScene, tainted: bool) -> void:
	is_tainted = tainted
	if template_scene == null:
		return
	
	var template = template_scene.instantiate()
	if template is FoodItem3D:
		food_type = template.food_type
		health_amount = template.health_amount
	
	var template_mesh = template.get_node_or_null("Mesh")
	if template_mesh:
		template.remove_child(template_mesh)
		add_child(template_mesh)
		mesh = template_mesh
	
	template.queue_free()
	
	if is_tainted:
		_apply_tainted_visuals()
		_setup_mold_particles()
		_setup_fly_audio()
	else:
		_setup_glint_particles()

func _apply_tainted_visuals() -> void:
	if not mesh:
		return
	
	var tainted_mat := StandardMaterial3D.new()
	tainted_mat.albedo_color = TAINTED_COLOR
	tainted_mat.roughness = TAINTED_ROUGHNESS
	tainted_mat.metallic = 0.0
	
	for child in mesh.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi:
			mi.material_override = tainted_mat
	
	if mesh is MeshInstance3D:
		(mesh as MeshInstance3D).material_override = tainted_mat

func _setup_glint_particles() -> void:
	glint_particles = CPUParticles3D.new()
	glint_particles.name = "GlintParticles"
	glint_particles.amount = 8
	glint_particles.lifetime = 1.2
	glint_particles.speed_scale = 1.0
	glint_particles.explosiveness = 0.1
	glint_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	glint_particles.emission_sphere_radius = 0.25
	glint_particles.direction = Vector3.UP
	glint_particles.spread = 45.0
	glint_particles.gravity = Vector3(0.0, 0.4, 0.0)
	glint_particles.initial_velocity_min = 0.1
	glint_particles.initial_velocity_max = 0.3
	glint_particles.scale_amount_min = 0.03
	glint_particles.scale_amount_max = 0.06
	glint_particles.color = FRESH_GLINT_COLOR
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glint_particles.material_override = mat
	
	add_child(glint_particles)

func _setup_mold_particles() -> void:
	mold_particles = CPUParticles3D.new()
	mold_particles.name = "MoldParticles"
	mold_particles.amount = 12
	mold_particles.lifetime = 1.8
	mold_particles.speed_scale = 0.8
	mold_particles.explosiveness = 0.05
	mold_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mold_particles.emission_sphere_radius = 0.22
	mold_particles.direction = Vector3.UP
	mold_particles.spread = 60.0
	mold_particles.gravity = Vector3(0.0, 0.25, 0.0)
	mold_particles.initial_velocity_min = 0.05
	mold_particles.initial_velocity_max = 0.2
	mold_particles.scale_amount_min = 0.04
	mold_particles.scale_amount_max = 0.09
	mold_particles.color = MOLD_SPORE_COLOR
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mold_particles.material_override = mat
	
	add_child(mold_particles)

func _setup_fly_audio() -> void:
	fly_audio = AudioStreamPlayer3D.new()
	fly_audio.name = "FlyBuzzAudio"
	fly_audio.max_distance = 2.0
	fly_audio.unit_size = 1.5
	fly_audio.volume_db = -8.0
	add_child(fly_audio)

## Consumes the dish and returns payload data.
func eat_dish(player: Node3D) -> Dictionary:
	if is_eaten:
		return {}
	is_eaten = true
	is_collected = true
	consumed.emit(player, is_tainted)
	
	var result := {
		"tainted": is_tainted,
		"food_type": food_type,
		"health_amount": health_amount
	}
	queue_free()
	return result

## Override FoodItem3D's walkover pickup so items aren't vacuumed up into inventory.
func _on_body_entered(_body: Node3D) -> void:
	pass
