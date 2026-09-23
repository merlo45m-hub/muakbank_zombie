extends SceneTree

## Headless env probe: load the night environment resource and report the fog /
## sky properties Godot actually sees (a .tres property can silently not apply).

func _init() -> void:
	var path := "res://resources/environments/night_blood_moon.tres"
	var e: Environment = load(path)
	if not e:
		print("ENVTEST: FAILED to load ", path)
		quit(1)
		return
	print("ENVTEST: loaded %s" % path)
	print("ENVTEST: bg_mode=%d fog_enabled=%s fog_density=%.4f fog_light_energy=%.2f ambient=%.2f" % [
		e.background_mode, str(e.fog_enabled), e.fog_density, e.fog_light_energy, e.ambient_light_energy])
	print("ENVTEST: has fog_mode prop = %s" % str("fog_mode" in e))
	print("ENVTEST: has volumetric_fog_enabled prop = %s" % str("volumetric_fog_enabled" in e))
	# force it and re-read, to see whether the property is writable at all
	e.fog_enabled = true
	print("ENVTEST: after explicit set, fog_enabled=%s" % str(e.fog_enabled))
	quit(0)