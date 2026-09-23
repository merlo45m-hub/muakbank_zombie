extends SceneTree
# Engine-truth check for StandardMaterial3D property names. Memory has been wrong before
# (light_energy_multiplier, emissive_color, AABB.get_area) - ask the engine, not recall.

func _init() -> void:
	var props := [
		"albedo_color", "roughness", "metallic", "metallic_specular",
		"specular_mode", "shading_mode", "disable_receive_shadows",
		"emission_enabled", "emission",
	]
	for p in props:
		print("StandardMaterial3D.%-22s exists=%s" % [p, ClassDB.class_has_property("StandardMaterial3D", p)])
	print("---")
	for v in ["SPECULAR_SCHLICK_GGX", "SPECULAR_DISABLED", "SPECULAR_TOON"]:
		print("StandardMaterial3D.%s = %s" % [v, ClassDB.class_get_integer_constant("StandardMaterial3D", v)])
	quit()
