extends SceneTree
# Do the two hand-edited .tres resources actually LOAD? The text resource parser is
# unforgiving and unknown properties fail silently - and .tscn is already known to reject
# '#' comments outright. Ask the engine instead of waiting 10 minutes for a render to fail.

func _init() -> void:
	for path in [
		"res://resources/environments/night_blood_moon.tres",
		"res://default_env.tres",
	]:
		var r: Resource = load(path)
		if r == null:
			print("RESOURCE %s -> FAILED TO LOAD" % path)
			continue
		var e := r as Environment
		if e == null:
			print("RESOURCE %s -> loaded but not an Environment (%s)" % [path, r.get_class()])
			continue
		print("RESOURCE %s -> OK bg=%d ambient=%.2f fog=%s dens=%.3f bright=%.2f" % [
			path, e.background_mode, e.ambient_light_energy,
			str(e.fog_enabled), e.fog_density, e.adjustment_brightness])
	quit()
