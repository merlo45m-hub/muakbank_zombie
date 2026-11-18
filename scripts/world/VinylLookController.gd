## VinylLookController.gd — Issue #9 Phase 2 / #21.
## Quality-tier controller for the "refined vinyl action figure" look.
##
## WHY A TIER: Godot volumetric fog is expensive on the mobile renderer. DESIGN.md
## section 6 hard-budgets <=3 real-time lights and 60 FPS on an S26 Ultra with no
## lightmaps. Phase 1 (1698ee8) deliberately left volumetric_fog_enabled=false
## and used cheap height fog. Phase 2 keeps MOBILE exactly there and exposes the
## calibrated volumetric look only on HIGH (high-end / desktop / preview).
##
## Rim lighting contributes ZERO new real-time lights: shaders/vinyl_rim.gdshader
## computes a view-dependent Fresnel rim in the fragment shader, so every figure
## gets a crisp silhouette highlight without touching the light budget.
extends Node

class_name VinylLookController

signal tier_changed(tier: int)

enum QualityTier { MOBILE = 0, HIGH = 1 }

# --- Calibrated volumetric fog (HIGH tier only) -----------------------------
# Values chosen to complement LOW-POLY geometry: keep the fog thin enough that
# faceted silhouettes stay readable, and short-range so it reads as ground mist
# rather than a uniform wash.
const FOG_DENSITY: float = 0.021          # just above Phase 1's 0.02 haze
const FOG_LENGTH: float = 42.0            # metres; short enough to preserve depth
const FOG_ANISOTROPY: float = 0.35        # mild forward scatter toward the moon
const FOG_DETAIL_SPREAD: float = 1.6      # coarse froxels = cheaper on mobile GPU
const FOG_AMBIENT_INJECT: float = 0.22    # keeps unlit facets from going black
const FOG_ALBEDO: Color = Color(0.30, 0.22, 0.24, 1.0)   # blood-moon grey/rose
const FOG_EMISSION: Color = Color(0.16, 0.09, 0.10, 1.0)
const FOG_EMISSION_ENERGY: float = 0.12
const FOG_TEMPORAL_REPROJECTION: bool = true
const FOG_TEMPORAL_AMOUNT: float = 0.85

@export var tier: int = QualityTier.MOBILE
@export var environment_path: NodePath

var _env: Environment = null


func _ready() -> void:
	call_deferred("_resolve_and_apply")


func _resolve_and_apply() -> void:
	_env = _find_environment()
	apply_tier(tier)


func _find_environment() -> Environment:
	if not environment_path.is_empty():
		var n := get_node_or_null(environment_path)
		if n is WorldEnvironment and (n as WorldEnvironment).environment != null:
			return (n as WorldEnvironment).environment
	var we := get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we != null and we.environment != null:
		return we.environment
	return null


func apply_tier(new_tier: int) -> void:
	tier = new_tier
	if _env == null:
		return
	if new_tier == QualityTier.HIGH:
		_env.volumetric_fog_enabled = true
		_env.volumetric_fog_density = FOG_DENSITY
		_env.volumetric_fog_length = FOG_LENGTH
		_env.volumetric_fog_anisotropy = FOG_ANISOTROPY
		_env.volumetric_fog_detail_spread = FOG_DETAIL_SPREAD
		_env.volumetric_fog_ambient_inject = FOG_AMBIENT_INJECT
		_env.volumetric_fog_albedo = FOG_ALBEDO
		_env.volumetric_fog_emission = FOG_EMISSION
		_env.volumetric_fog_emission_energy = FOG_EMISSION_ENERGY
		_env.volumetric_fog_temporal_reprojection_enabled = FOG_TEMPORAL_REPROJECTION
		_env.volumetric_fog_temporal_reprojection_amount = FOG_TEMPORAL_AMOUNT
	else:
		# MOBILE: restore the Phase 1 default exactly. No volumetric pass.
		_env.volumetric_fog_enabled = false
	tier_changed.emit(tier)


func is_high() -> bool:
	return tier == QualityTier.HIGH and _env != null and _env.volumetric_fog_enabled
