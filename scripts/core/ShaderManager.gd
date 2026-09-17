extends Node
class_name ShaderManager

## Shader Manager — Creates materials from shaders at runtime
## Place in scene as needed for shader effects

# === SHADER PATHS ===
const SHADER_DIR = "res://shaders/"

# === MATERIAL CACHE ===
var materials: Dictionary = {}

func _ready() -> void:
	_create_all_materials()
	print("[ShaderManager] All shader materials created")


func _create_all_materials() -> void:
	# Dissolve material (zombie death)
	var dissolve_mat = ShaderMaterial.new()
	dissolve_mat.shader = load(SHADER_DIR + "dissolve.gdshader")
	dissolve_mat.set_shader_parameter("u_dissolve_progress", 0.0)
	dissolve_mat.set_shader_parameter("u_edge_width", 0.1)
	dissolve_mat.set_shader_parameter("u_edge_color", Color(1.0, 0.3, 0.05, 1.0))
	dissolve_mat.set_shader_parameter("u_base_color", Color(0.6, 0.55, 0.5, 1.0))
	materials["dissolve"] = dissolve_mat
	
	# Damage flash material
	var flash_mat = ShaderMaterial.new()
	flash_mat.shader = load(SHADER_DIR + "damage_flash.gdshader")
	flash_mat.set_shader_parameter("u_flash_intensity", 0.0)
	materials["damage_flash"] = flash_mat
	
	# Zombie glow material
	var glow_mat = ShaderMaterial.new()
	glow_mat.shader = load(SHADER_DIR + "zombie_glow.gdshader")
	glow_mat.set_shader_parameter("u_threat_level", 0.5)
	glow_mat.set_shader_parameter("u_glow_color", Color(0.8, 0.2, 0.1, 1.0))
	materials["zombie_glow"] = glow_mat
	
	# Blood splatter material
	var blood_mat = ShaderMaterial.new()
	blood_mat.shader = load(SHADER_DIR + "blood_splatter.gdshader")
	blood_mat.set_shader_parameter("u_blood_color", Color(0.6, 0.05, 0.05, 0.8))
	blood_mat.set_shader_parameter("u_splatter_intensity", 0.8)
	materials["blood_splatter"] = blood_mat
	
	# Water puddle material
	var water_mat = ShaderMaterial.new()
	water_mat.shader = load(SHADER_DIR + "water_puddle.gdshader")
	water_mat.set_shader_parameter("u_water_color", Color(0.1, 0.3, 0.5, 0.6))
	water_mat.set_shader_parameter("u_fresnel_power", 2.5)
	materials["water_puddle"] = water_mat
	
	# Volumetric fog material
	var fog_mat = ShaderMaterial.new()
	fog_mat.shader = load(SHADER_DIR + "volumetric_fog.gdshader")
	fog_mat.set_shader_parameter("u_fog_color", Color(0.4, 0.38, 0.35, 0.15))
	fog_mat.set_shader_parameter("u_fog_density", 0.4)
	materials["volumetric_fog"] = fog_mat
	
	# Toxic zone material
	var toxic_mat = ShaderMaterial.new()
	toxic_mat.shader = load(SHADER_DIR + "toxic_zone.gdshader")
	toxic_mat.set_shader_parameter("u_zone_color", Color(0.2, 0.8, 0.3, 0.4))
	toxic_mat.set_shader_parameter("u_zone_density", 0.5)
	materials["toxic_zone"] = toxic_mat


func get_material(name: String) -> ShaderMaterial:
	if materials.has(name):
		return materials[name]
	return null
