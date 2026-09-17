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
	_create_material("dissolve", "dissolve.gdshader", {
		"u_dissolve_progress": 0.0,
		"u_edge_width": 0.1,
		"u_edge_color": Color(1.0, 0.3, 0.05, 1.0),
		"u_base_color": Color(0.6, 0.55, 0.5, 1.0)
	})
	
	# Damage flash material
	_create_material("damage_flash", "damage_flash.gdshader", {
		"u_flash_intensity": 0.0
	})
	
	# Zombie glow material
	_create_material("zombie_glow", "zombie_glow.gdshader", {
		"u_threat_level": 0.5,
		"u_glow_color": Color(0.8, 0.2, 0.1, 1.0)
	})
	
	# Blood splatter material
	_create_material("blood_splatter", "blood_splatter.gdshader", {
		"u_blood_color": Color(0.6, 0.05, 0.05, 0.8),
		"u_splatter_intensity": 0.8
	})
	
	# Water puddle material
	_create_material("water_puddle", "water_puddle.gdshader", {
		"u_water_color": Color(0.1, 0.3, 0.5, 0.6),
		"u_fresnel_power": 2.5
	})
	
	# Volumetric fog material
	_create_material("volumetric_fog", "volumetric_fog.gdshader", {
		"u_fog_color": Color(0.4, 0.38, 0.35, 0.15),
		"u_fog_density": 0.4
	})
	
	# VesperaFX post-processing shaders
	_create_material("vignette", "vignette.gdshader", {
		"u_vignette_intensity": 0.0,
		"u_vignette_smoothness": 0.5
	})
	_create_material("grain", "grain.gdshader", {
		"u_grain_intensity": 0.0
	})
	_create_material("chromatic_aberration", "chromatic_aberration.gdshader", {
		"u_chromatic_offset": 0.0
	})
	_create_material("screen_shake", "screen_shake.gdshader", {
		"u_shake_intensity": 0.0,
		"u_shake_frequency": 15.0
	})
	
	# Toxic zone material
	_create_material("toxic_zone", "toxic_zone.gdshader", {
		"u_zone_color": Color(0.2, 0.8, 0.3, 0.4),
		"u_zone_density": 0.5
	})


func _create_material(name: String, shader_file: String, params: Dictionary) -> void:
	"""Create a shader material with null-safe shader loading."""
	var shader = load(SHADER_DIR + shader_file)
	if not shader:
		push_warning("[ShaderManager] Failed to load shader: ", shader_file)
		return
	var mat = ShaderMaterial.new()
	mat.shader = shader
	for key in params:
		mat.set_shader_parameter(key, params[key])
	materials[name] = mat


func get_material(name: String) -> ShaderMaterial:
	if materials.has(name):
		return materials[name]
	return null
