## prop_check.gd — settles, against the actual engine, which of these property names exist.
## Run:  Godot_v4.7.2-stable_linux.arm64 --headless --script res://tools/prop_check.gd
extends SceneTree


func _initialize() -> void:
	var light := DirectionalLight3D.new()
	var omni := OmniLight3D.new()
	var mat := StandardMaterial3D.new()

	print("DirectionalLight3D has light_energy:          ", "light_energy" in light)
	print("DirectionalLight3D has light_energy_multiplier: ", "light_energy_multiplier" in light)
	print("OmniLight3D has light_energy:                 ", "light_energy" in omni)
	print("OmniLight3D has light_energy_multiplier:      ", "light_energy_multiplier" in omni)
	print("StandardMaterial3D has emission:              ", "emission" in mat)
	print("StandardMaterial3D has emission_enabled:      ", "emission_enabled" in mat)
	print("StandardMaterial3D has emissive_color:        ", "emissive_color" in mat)
	print("DirectionalLight3D default light_energy:      ", light.light_energy)
	quit()