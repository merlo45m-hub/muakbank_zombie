class_name ProceduralAnimator
extends Node3D

## ProceduralAnimator v2 — Code-driven transform animation for unrigged GLB models.
## Added as a child of the entity's visual container ("Mesh" node) and only ever
## modifies ITS OWN transform (position / rotation / scale). Never touches the
## parent's transform, which belongs to the AI (yaw, death tween, pool reset).
##
## V2 additions: per-subtype gait registry, squash & stretch, three-phase attack
## anticipation/strike/overshoot, state blending with exponential smoothing,
## richer idle with per-type quirks, and polished hop-on-chase.

# ── EXPORTED DEFAULTS (fallback / generic zombie) ──────────────────────────────

@export_group("Breathing / Idle")
@export var breathe_scale_amp: float = 0.02     # scale.y sin amplitude
@export var breathe_speed: float = 2.0           # rad/s of breathe cycle
@export var idle_roll_amp: float = 0.02          # +-rad gentle side sway

@export_group("Walk Cycle")
@export var bob_height: float = 0.08             # max position.y bob (world units)
@export var walk_phase_base: float = 1.8         # phase rate at speed 0
@export var walk_phase_speed_scale: float = 2.4  # extra phase rate per unit speed
@export var roll_amp: float = 0.05               # rotation.z roll per unit speed
@export var lean_max: float = 0.12               # max forward lean (rotation.x, rad)
@export var contact_squash: float = 0.06         # scale.y squash at step contact
@export var apex_stretch: float = 0.03           # scale.y stretch at apex
@export var bounce: float = 1.0                  # vertical bob exaggeration multiplier

@export_group("Attack Lunge")
@export var lunge_z: float = 0.35               # local-Z lunge distance (forward)
@export var lunge_pitch: float = 0.45           # pitch-down angle (rad) at peak
@export var lunge_duration: float = 0.45        # total 3-phase lunge duration (s)

@export_group("Special / Boss")
@export var special_sway_mult: float = 1.6      # SPECIAL state sway multiplier
@export var special_bob_mult: float = 0.65      # SPECIAL state bob speed multiplier
@export var boss_lean: float = 0.3              # charging lean (rotation.x rad)
@export var boss_squash: float = 0.9            # charging scale.y


# ── GAIT REGISTRY ──────────────────────────────────────────────────────────────
# Keys map subtype strings to parameter overrides. Fields not present fall back to
# the exported defaults above. Read at _process time — no per-frame allocation.
# Layout per entry: bob, phase_base, phase_speed, roll, lean_max,
#                   contact_squash, apex_stretch, bounce,
#                   breathe_speed (opt), breathe_amp (opt), hop_height,
#                   idle_roll_freq (opt)

const GAIT_REGISTRY: Dictionary = {
	"rabbit": {
		"bob": 0.14, "phase_base": 2.6, "phase_speed": 3.2,
		"roll": 0.03, "lean": 0.06,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 1.6,
		"hop_height": 0.30,
	},
	"cat": {
		"bob": 0.05, "phase_base": 2.0, "phase_speed": 2.6,
		"roll": 0.08, "lean": 0.10,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 0.8,
		"hop_height": 0.22,
		"idle_roll_freq": 0.7,
	},
	"chicken": {
		"bob": 0.10, "phase_base": 3.4, "phase_speed": 3.6,
		"roll": 0.04, "lean": 0.05,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 1.3,
		"hop_height": 0.26,
	},
	"dog": {
		"bob": 0.07, "phase_base": 2.2, "phase_speed": 2.8,
		"roll": 0.06, "lean": 0.11,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 1.1,
		"hop_height": 0.18,
	},
	"bear": {
		"bob": 0.12, "phase_base": 1.1, "phase_speed": 1.8,
		"roll": 0.09, "lean": 0.14,
		"contact_squash": 0.10, "apex_stretch": 0.03, "bounce": 0.6,
		"breathe_speed": 1.2, "breathe_amp": 0.035,
		"hop_height": 0.08,
	},
	"butcher": {
		"bob": 0.06, "phase_base": 1.4, "phase_speed": 2.0,
		"roll": 0.03, "lean": 0.09,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 0.7,
		"hop_height": 0.18,
	},
	"runner": {
		"bob": 0.09, "phase_base": 1.6, "phase_speed": 4.2,
		"roll": 0.04, "lean": 0.22,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 1.2,
		"hop_height": 0.18,
	},
	"spitter": {
		"bob": 0.06, "phase_base": 1.2, "phase_speed": 1.9,
		"roll": 0.10, "lean": 0.16,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 1.0,
		"hop_height": 0.18,
	},
	"boss": {
		"bob": 0.16, "phase_base": 0.9, "phase_speed": 1.4,
		"roll": 0.12, "lean": 0.18,
		"contact_squash": 0.14, "apex_stretch": 0.03, "bounce": 0.5,
		"hop_height": 0.06,
	},
	"human": {
		"bob": 0.05, "phase_base": 2.2, "phase_speed": 2.6,
		"roll": 0.02, "lean": 0.08,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 1.0,
		"breathe_amp": 0.012,
		"hop_height": 0.12,
		"rest_y": 0.02,
	},
}


# ── INTERNAL STATE ─────────────────────────────────────────────────────────────

var _body: Node3D = null       # CharacterBody3D driving movement (duck-typed)
var _subtype: String = ""      # resolved once in attach(), e.g. "rabbit"
var _gait: Dictionary = {}     # reference into GAIT_REGISTRY (or empty for generic)

var _time: float = 0.0         # running clock (breathing, idle sway)
var _phase: float = 0.0        # walk-cycle phase (unbounded; use sin/cos)

# Lunge state (three-phase attack)
var _lunge_active: bool = false
var _lunge_t: float = 0.0      # elapsed within lunge

# Startle hop
var _hop_t: float = 0.0        # elapsed; 0 when inactive
var _hop_duration: float = 0.3

# Rising-edge detection for auto-trigger
var _was_attacking: bool = false

# State blending weights (exponential smoothing)
var _gait_weight: float = 0.0    # 0 = fully idle, 1 = fully walking
var _lunge_intensity: float = 0.0  # 0..1 derived from phase envelope each frame

# Per-type idle quirk timers (deterministic, no rng)
var _quirk_timer: float = 0.0    # seconds since last quirk fired
var _quirk_active: float = 0.0   # remaining seconds of active quirk display


# ── PUBLIC API ─────────────────────────────────────────────────────────────────

func attach(body: Node3D, _visual: Node3D) -> void:
	## body = CharacterBody3D driving movement.
	## _visual = the node we are a child of — stored for potential future use
	## but never modified (its transform belongs to the AI layer).
	_body = body
	_resolve_subtype()


func reset_anim() -> void:
	## Called by ZombieBase.reset_for_pool() — restores pristine animator state
	## so the recycled zombie starts without stale phase, lunge, or blend weights.
	_time = 0.0
	_phase = 0.0
	_lunge_active = false
	_lunge_t = 0.0
	_hop_t = 0.0
	_was_attacking = false
	_gait_weight = 0.0
	_lunge_intensity = 0.0
	_quirk_timer = 0.0
	_quirk_active = 0.0
	# Re-resolve subtype in case the recycled body changed type.
	if is_instance_valid(_body):
		_resolve_subtype()
	transform = Transform3D()  # zero out our own transform


func trigger_attack() -> void:
	## Immediately starts the 3-phase lunge envelope.
	## Ignored when a lunge is already in progress.
	if _lunge_active:
		return
	_lunge_active = true
	_lunge_t = 0.0


func on_start_chase() -> void:
	## Small startle hop — decaying position.y kick over _hop_duration seconds.
	_hop_t = _hop_duration


# ── PROCESS ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Guard: pooled zombies are parked out-of-tree; body may have been freed.
	if not is_inside_tree():
		return
	if not is_instance_valid(_body):
		return

	# Death tween owns the corpse — do not compete with it.
	if _body.get("is_dead") == true:
		return

	# Read duck-typed inputs from body (use get() so missing vars return null).
	var vel: Vector3 = _body.get("velocity") if _body.get("velocity") != null else Vector3.ZERO
	var h_speed: float = Vector2(vel.x, vel.z).length()
	var state: int = _body.get("current_state") if _body.get("current_state") != null else (1 if h_speed > 0.0 else 0)
	var is_attacking: bool = _body.get("is_attacking") if _body.get("is_attacking") != null else false
	var is_charging: bool = _body.get("is_charging") if _body.get("is_charging") != null else false

	# Detect rising edge on is_attacking to auto-start lunge.
	if is_attacking and not _was_attacking:
		if h_speed < 2.0:
			trigger_attack()
	_was_attacking = is_attacking

	# Advance global clock.
	_time += delta

	# Tick lunge.
	if _lunge_active:
		_lunge_t += delta
		if _lunge_t >= lunge_duration:
			_lunge_active = false
			_lunge_t = 0.0

	# Tick startle hop.
	if _hop_t > 0.0:
		_hop_t = max(0.0, _hop_t - delta)

	# Tick idle quirk.
	_quirk_timer += delta

	# Resolve per-type parameters from registry (reads const dict, no alloc).
	var p_bob: float         = _gait.get("bob",           bob_height)
	var p_phase_base: float  = _gait.get("phase_base",    walk_phase_base)
	var p_phase_spd: float   = _gait.get("phase_speed",   walk_phase_speed_scale)
	var p_roll: float        = _gait.get("roll",          roll_amp)
	var p_lean: float        = _gait.get("lean",          lean_max)
	var p_csquash: float     = _gait.get("contact_squash", contact_squash)
	var p_astretch: float    = _gait.get("apex_stretch",  apex_stretch)
	var p_bounce: float      = _gait.get("bounce",        bounce)
	var p_bspeed: float      = _gait.get("breathe_speed", breathe_speed)
	var p_bamp: float        = _gait.get("breathe_amp",   breathe_scale_amp)
	var p_hop: float         = _gait.get("hop_height",    0.18)
	var p_rest_y: float      = _gait.get("rest_y",        0.0)
	var p_roll_freq: float   = _gait.get("idle_roll_freq", 1.1)

	# Scale amplitudes for character scale (uniform scale on the parent Mesh node).
	var char_scale: float = 1.0
	var parent := get_parent()
	if parent is Node3D:
		char_scale = (parent as Node3D).scale.x

	# Update gait blend weight.
	var gait_target: float = 1.0 if h_speed >= 0.15 else 0.0
	var gait_ramp: float = 12.0 / 0.25 if gait_target > _gait_weight else 12.0 / 0.3
	_gait_weight = lerpf(_gait_weight, gait_target, 1.0 - exp(-gait_ramp * delta))

	# Build transform from scratch each frame (no drift accumulation).
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	var scl := Vector3.ONE

	# ── BOSS CHARGING ────────────────────────────────────────────────────────
	if is_charging:
		rot.x = -boss_lean
		scl.y = boss_squash
		var speed_factor: float = clampf(h_speed / 3.0, 0.0, 1.0)
		_phase += delta * (p_phase_base + h_speed * p_phase_spd) * 1.5
		pos.y = abs(sin(_phase * TAU)) * p_bob * char_scale * speed_factor
		transform = _make_transform(pos, rot, scl)
		return

	# ── BREATHING (always runs; amplitude scales with gait weight) ───────────
	var breathe_amp_eff: float = p_bamp * (1.0 - _gait_weight * 0.7)
	var breathe_scl: float = 1.0 + breathe_amp_eff * sin(_time * p_bspeed)

	# ── IDLE LAYER ───────────────────────────────────────────────────────────
	var is_idle_state: bool = (state == 0 and h_speed < 0.15)

	var idle_roll: float = sin(_time * p_roll_freq) * idle_roll_amp * char_scale
	var idle_shift_x: float = sin(_time * 0.8) * 0.01 * char_scale

	# Per-type idle quirks (deterministic timer, pool-safe).
	var quirk_scl_x: float = 0.0
	var quirk_bob: float = 0.0
	if _subtype == "rabbit":
		# Tiny fast twitch every ~1.2s, 0.1s duration.
		if _quirk_timer >= 1.2:
			_quirk_timer = 0.0
			_quirk_active = 0.1
		if _quirk_active > 0.0:
			_quirk_active = max(0.0, _quirk_active - delta)
			var qfrac: float = _quirk_active / 0.1
			quirk_scl_x = 0.02 * qfrac
	elif _subtype == "chicken":
		# Three rapid mini-bobs every ~1.5s, spread over 0.3s total.
		if _quirk_timer >= 1.5:
			_quirk_timer = 0.0
			_quirk_active = 0.3
		if _quirk_active > 0.0:
			_quirk_active = max(0.0, _quirk_active - delta)
			# Three pops at t=0.3, 0.2, 0.1 (counting down from 0.3)
			var qfrac: float = _quirk_active / 0.3
			quirk_bob = -0.02 * abs(sin(qfrac * PI * 3.0))

	# ── WALK CYCLE LAYER ─────────────────────────────────────────────────────
	# Advance walk phase.
	var phase_rate: float = p_phase_base + h_speed * p_phase_spd
	if state == 3:  # SPECIAL (spitter etc.) — slower bob
		phase_rate *= special_bob_mult
	_phase += delta * phase_rate

	var speed_factor: float = clampf(h_speed / 3.0, 0.0, 1.0)
	var sway_mult: float = special_sway_mult if state == 3 else 1.0

	# |sin(phase * TAU)| gives double-footed hop feel.
	var raw_sin: float = sin(_phase * TAU)
	var raw_bob_val: float = abs(raw_sin)

	var walk_pos_y: float = raw_bob_val * p_bob * char_scale * minf(1.0, h_speed / 3.0) * p_bounce
	var walk_rot_z: float = sin(_phase * TAU * 2.0) * p_roll * speed_factor * sway_mult
	var walk_rot_x: float = -clampf(h_speed * 0.02, 0.0, p_lean)

	# Chicken: extra fast tiny counter-roll (head-sync at 2x phase rate).
	var chicken_roll: float = 0.0
	if _subtype == "chicken":
		chicken_roll = sin(_phase * TAU * 4.0) * 0.02

	# ── SQUASH & STRETCH ─────────────────────────────────────────────────────
	# Phase-locked to step contact. Only when speed >= 0.15.
	var ss_scl_y: float = 1.0
	var ss_scl_xz: float = 1.0
	if h_speed >= 0.15:
		# raw_sin approaches 0 at contact, 1 at apex.
		# contact when |sin| near 0, apex when |sin| near 1.
		var contact_w: float = 1.0 - raw_bob_val  # 1 at contact, 0 at apex
		var apex_w: float = raw_bob_val            # 0 at contact, 1 at apex
		ss_scl_y = 1.0 - p_csquash * contact_w + p_astretch * apex_w
		ss_scl_xz = 1.0 + p_csquash * 0.6 * contact_w - p_astretch * 0.5 * apex_w

	# ── COMPOSE IDLE + WALK via gait_weight ──────────────────────────────────
	pos.y = p_rest_y + lerpf(
		0.0,
		walk_pos_y,
		_gait_weight
	)
	pos.x = idle_shift_x * (1.0 - _gait_weight)

	rot.z = lerpf(idle_roll, walk_rot_z + chicken_roll, _gait_weight)
	rot.x = lerpf(0.0, walk_rot_x, _gait_weight)

	# Breathing scale: multiply with S&S (never overwrite).
	scl.y = breathe_scl * lerpf(1.0, ss_scl_y, _gait_weight) + quirk_bob + quirk_scl_x
	scl.x = lerpf(1.0, ss_scl_xz, _gait_weight)
	scl.z = scl.x

	# Idle quirk: cat uses slow roll freq already baked into p_roll_freq above.
	# Human: nearly-static micro-breathe handled by low p_bamp already.

	# ── STARTLE HOP ──────────────────────────────────────────────────────────
	if _hop_t > 0.0:
		var hop_frac: float = _hop_t / _hop_duration
		# Quadratic decay upward kick.
		pos.y += p_hop * char_scale * hop_frac * hop_frac
		# Squash on landing (low hop_frac = near landing).
		var land_w: float = 1.0 - hop_frac
		scl.y *= 1.0 - p_csquash * land_w * land_w
		scl.x *= 1.0 + p_csquash * 0.4 * land_w * land_w
		scl.z = scl.x

	# ── THREE-PHASE ATTACK LUNGE ──────────────────────────────────────────────
	if _lunge_active:
		var t_frac: float = _lunge_t / lunge_duration

		# Compute piecewise envelope and lunge contribution.
		var lunge_pos_z: float = 0.0
		var lunge_rot_x: float = 0.0
		var env_intensity: float = 0.0  # 0..1 used for gait suppression

		if t_frac < 0.25:
			# Phase 1: anticipation — backward pull + wind-up pitch.
			var p: float = t_frac / 0.25  # 0..1
			var ea: float = p * p          # ease in
			lunge_pos_z = -lunge_z * 0.25 * ea * char_scale
			lunge_rot_x = lunge_pitch * 0.3 * ea
			env_intensity = ea * 0.4

		elif t_frac < 0.65:
			# Phase 2: strike — fast forward snap.
			var p: float = (t_frac - 0.25) / 0.40  # 0..1
			# smoothstep amplified to 1.8x for quick snap feel.
			var ss: float = p * p * (3.0 - 2.0 * p)
			var env_s: float = minf(1.0, ss * 1.8)
			lunge_pos_z = lunge_z * env_s * char_scale
			lunge_rot_x = -lunge_pitch * env_s
			env_intensity = env_s

		else:
			# Phase 3: overshoot + recover.
			var p: float = (t_frac - 0.65) / 0.35  # 0..1
			var decay: float = (1.0 - p) * (1.0 - p)
			lunge_pos_z = lunge_z * 1.15 * decay * char_scale
			lunge_rot_x = -lunge_pitch * decay
			env_intensity = decay

		_lunge_intensity = lerpf(_lunge_intensity, env_intensity, 1.0 - exp(-20.0 * delta))

		# Suppress gait amplitudes during strike (blend over; walk does not freeze).
		var gait_suppress: float = 1.0 - _lunge_intensity * 0.85
		pos.z += lunge_pos_z
		rot.x = rot.x * gait_suppress + lunge_rot_x
	else:
		_lunge_intensity = lerpf(_lunge_intensity, 0.0, 1.0 - exp(-12.0 * delta))

	transform = _make_transform(pos, rot, scl)


# ── HELPERS ───────────────────────────────────────────────────────────────────

func _resolve_subtype() -> void:
	# Called once in attach() and again in reset_anim() to re-detect subtype.
	if not is_instance_valid(_body):
		_subtype = "human"
		_gait = {}
		return

	if _body.is_in_group("player") or _body.get("zombie_type") == null:
		_subtype = "human"
	else:
		_subtype = str(_body.get("zombie_type") if _body.get("zombie_type") != null else "").to_lower()
		# Map any unrecognised subtype to the generic zombie (empty dict = all defaults).
		if not GAIT_REGISTRY.has(_subtype):
			_subtype = ""

	_gait = GAIT_REGISTRY.get(_subtype, {})


func _make_transform(pos: Vector3, euler_rot: Vector3, scl: Vector3) -> Transform3D:
	# Build a Transform3D from position, euler XYZ rotation, and scale.
	# Yaw (Y) is intentionally excluded — the parent AI owns mesh.rotation.y.
	var basis := Basis()
	basis = basis.rotated(Vector3.RIGHT, euler_rot.x)    # pitch
	basis = basis.rotated(Vector3.FORWARD, euler_rot.z)  # roll
	basis = basis.scaled(scl)
	return Transform3D(basis, pos)
