class_name ProceduralAnimator
extends Node3D

## ProceduralAnimator v5 — Code-driven transform animation for unrigged GLB models.
## Added as a child of the entity's visual container ("Mesh" node) and only ever
## modifies ITS OWN transform (position / rotation / scale). Never touches the
## parent's transform, which belongs to the AI (yaw, death tween, pool reset).
##
## V2 additions: per-subtype gait registry, squash & stretch, three-phase attack
## anticipation/strike/overshoot, state blending with exponential smoothing,
## richer idle with per-type quirks, and polished hop-on-chase.
##
## V3 additions: horde phase seeds (fix sync), subtype alias normalization,
## hit reaction envelope, turn banking, landing squash, launch wind-up +
## runner lean ramp, boss charge wind-up.
##
## V5 additions: per-species attack curves (ATTACK_REGISTRY), directional hit
## reaction roll, boss slam impact envelope.

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
#                   idle_roll_freq (opt), hit_squash, hit_lean

const GAIT_REGISTRY: Dictionary = {
	"rabbit": {
		"bob": 0.14, "phase_base": 2.6, "phase_speed": 3.2,
		"roll": 0.03, "lean": 0.06,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 1.6,
		"hop_height": 0.30,
		"hit_squash": 0.22, "hit_lean": 0.08,
	},
	"cat": {
		"bob": 0.05, "phase_base": 2.0, "phase_speed": 2.6,
		"roll": 0.08, "lean": 0.10,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 0.8,
		"hop_height": 0.22,
		"idle_roll_freq": 0.7,
		"hit_squash": 0.20, "hit_lean": 0.08,
	},
	"chicken": {
		"bob": 0.10, "phase_base": 3.4, "phase_speed": 3.6,
		"roll": 0.04, "lean": 0.05,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 1.3,
		"hop_height": 0.26,
		"hit_squash": 0.25, "hit_lean": 0.08,
	},
	"dog": {
		"bob": 0.07, "phase_base": 2.2, "phase_speed": 2.8,
		"roll": 0.06, "lean": 0.11,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 1.1,
		"hop_height": 0.18,
		"hit_squash": 0.15, "hit_lean": 0.08,
	},
	"bear": {
		"bob": 0.12, "phase_base": 1.1, "phase_speed": 1.8,
		"roll": 0.09, "lean": 0.14,
		"contact_squash": 0.10, "apex_stretch": 0.03, "bounce": 0.6,
		"breathe_speed": 1.2, "breathe_amp": 0.035,
		"hop_height": 0.08,
		"hit_squash": 0.10, "hit_lean": 0.05,
	},
	"butcher": {
		"bob": 0.06, "phase_base": 1.4, "phase_speed": 2.0,
		"roll": 0.03, "lean": 0.09,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 0.7,
		"hop_height": 0.18,
		"hit_squash": 0.15, "hit_lean": 0.08,
	},
	"runner": {
		"bob": 0.09, "phase_base": 1.6, "phase_speed": 4.2,
		"roll": 0.04, "lean": 0.22,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 1.2,
		"hop_height": 0.18,
		"hit_squash": 0.15, "hit_lean": 0.08,
	},
	"spitter": {
		"bob": 0.06, "phase_base": 1.2, "phase_speed": 1.9,
		"roll": 0.10, "lean": 0.16,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 1.0,
		"hop_height": 0.18,
		"hit_squash": 0.15, "hit_lean": 0.08,
	},
	"boss": {
		"bob": 0.16, "phase_base": 0.9, "phase_speed": 1.4,
		"roll": 0.12, "lean": 0.18,
		"contact_squash": 0.14, "apex_stretch": 0.03, "bounce": 0.5,
		"hop_height": 0.06,
		"hit_squash": 0.08, "hit_lean": 0.05,
	},
	"human": {
		"bob": 0.05, "phase_base": 2.2, "phase_speed": 2.6,
		"roll": 0.02, "lean": 0.08,
		"contact_squash": 0.06, "apex_stretch": 0.03, "bounce": 1.0,
		"breathe_amp": 0.012,
		"hop_height": 0.12,
		"rest_y": 0.02,
		"hit_squash": 0.12, "hit_lean": 0.08,
	},
}

# Alias normalization: strip common prefixes so "zombie_dog" → "dog".
const _SUBTYPE_ALIASES: Dictionary = {
	"zombie_dog": "dog",
	"zombie_cat": "cat",
	"zombie_rabbit": "rabbit",
	"zombie_chicken": "chicken",
	"zombie_bear": "bear",
	"zombie_runner": "runner",
	"zombie_spitter": "spitter",
	"zombie_boss": "boss",
	"zombie_butcher": "butcher",
}


# ── ATTACK CURVE REGISTRY (V5 §1) ─────────────────────────────────────────────
# Per-species attack curve parameters. Missing keys fall back to "default".
# attack_base     — total lunge duration (s)
# attack_windup   — share of duration for pull-back phase (0..1)
# attack_snap     — share of duration for forward snap phase (0..1)
# attack_overshoot — extra rotation/offset factor at full extension
# (recovery = 1 - attack_windup - attack_snap)

const ATTACK_REGISTRY: Dictionary = {
	"human":   {"attack_base": 0.30, "attack_windup": 0.28, "attack_snap": 0.38, "attack_overshoot": 0.14},
	"dog":     {"attack_base": 0.26, "attack_windup": 0.18, "attack_snap": 0.30, "attack_overshoot": 0.10},
	"cat":     {"attack_base": 0.24, "attack_windup": 0.20, "attack_snap": 0.28, "attack_overshoot": 0.08},
	"rabbit":  {"attack_base": 0.18, "attack_windup": 0.15, "attack_snap": 0.25, "attack_overshoot": 0.06},
	"chicken": {"attack_base": 0.16, "attack_windup": 0.12, "attack_snap": 0.22, "attack_overshoot": 0.05},
	"bear":    {"attack_base": 0.55, "attack_windup": 0.45, "attack_snap": 0.30, "attack_overshoot": 0.30},
	"runner":  {"attack_base": 0.22, "attack_windup": 0.20, "attack_snap": 0.26, "attack_overshoot": 0.12},
	"spitter": {"attack_base": 0.30, "attack_windup": 0.30, "attack_snap": 0.20, "attack_overshoot": 0.20},
	"boss":    {"attack_base": 0.50, "attack_windup": 0.40, "attack_snap": 0.25, "attack_overshoot": 0.22},
	"default": {"attack_base": 0.35, "attack_windup": 0.25, "attack_snap": 0.35, "attack_overshoot": 0.18},
}


# ── INTERNAL STATE ─────────────────────────────────────────────────────────────

var _body: Node3D = null       # CharacterBody3D driving movement (duck-typed)
var _subtype: String = ""      # resolved once in attach(), e.g. "rabbit"
var _gait: Dictionary = {}     # reference into GAIT_REGISTRY (or empty for generic)

# Phase seeds — assigned once in attach(); recycled zombie keeps its own seeds.
var _phase_seed: float = 0.0
var _time_seed: float = 0.0

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

# ── V3 STATE ──────────────────────────────────────────────────────────────────

# Hit reaction (spec §4)
var _hit_t: float = 0.0          # remaining envelope time; 0 = inactive

# Turn banking (spec §5)
var _bank: float = 0.0           # smoothed bank angle (rot.z addition)
var _prev_parent_yaw: float = 0.0  # previous frame parent.rotation.y

# Landing squash (spec §6)
var _prev_v_y: float = 0.0       # previous frame vertical velocity
var _land_t: float = 0.0         # remaining landing squash time; 0 = inactive
var _land_squash: float = 0.0    # computed impact squash amount

# Launch wind-up (spec §7)
var _launch_t: float = 0.0       # remaining push-off envelope time; 0 = inactive
var _prev_gait_target: float = 0.0  # previous frame gait_target (rising-edge detect)
var _lean_ramp: float = 0.0      # runner lean ramp [0..1]

# Boss charge wind-up (spec §7)
var _prev_charging: bool = false
var _boss_launch_t: float = 0.0

# Hit reaction envelope duration constant
const _HIT_DURATION: float = 0.18
const _LAUNCH_DURATION: float = 0.14
const _BOSS_LAUNCH_DURATION: float = 0.14

# ── V4 STATE ──────────────────────────────────────────────────────────────────

# Footstep zero-crossing (spec §5)
var _prev_sin: float = 0.0

# Spawn scale-in (spec §6)
var _spawn_t: float = 0.0
const _SPAWN_DURATION: float = 0.16

# ── V5 STATE ──────────────────────────────────────────────────────────────────

# Directional hit reaction (spec §3): horizontal direction of blow [-1, 1]
var _hit_dir: float = 0.0

# Boss slam impact (spec §5)
var _slam_t: float = 0.0
const _SLAM_DURATION: float = 0.28


# ── PUBLIC API ─────────────────────────────────────────────────────────────────

var _visual: Node3D = null  # mesh child — holds the AI-written yaw after reparent

func attach(body: Node3D, visual: Node3D) -> void:
	## body   = CharacterBody3D driving movement.
	## visual = the mesh node (child of this animator after reparent) — stored so
	##          turn-banking can read visual.rotation.y (the AI-owned yaw channel).
	_body = body
	_visual = visual
	# Assign unique phase seeds once per instance lifetime.
	_phase_seed = randf() * TAU
	_time_seed = randf() * TAU
	_phase = _phase_seed
	_time = _time_seed
	_resolve_subtype()


func reset_anim() -> void:
	## Called by ZombieBase.reset_for_pool() — restores pristine animator state
	## so the recycled zombie starts without stale phase, lunge, or blend weights.
	## Phase seeds are PRESERVED — recycled zombie keeps its own unique phase.
	_time = _time_seed
	_phase = _phase_seed
	_lunge_active = false
	_lunge_t = 0.0
	_hop_t = 0.0
	_was_attacking = false
	_gait_weight = 0.0
	_lunge_intensity = 0.0
	_quirk_timer = 0.0
	_quirk_active = 0.0
	# V3 state reset
	_hit_t = 0.0
	_bank = 0.0
	_prev_parent_yaw = 0.0
	_prev_v_y = 0.0
	_land_t = 0.0
	_land_squash = 0.0
	_launch_t = 0.0
	_prev_gait_target = 0.0
	_lean_ramp = 0.0
	_prev_charging = false
	_boss_launch_t = 0.0
	# V4 state reset
	_prev_sin = 0.0
	_spawn_t = 0.0
	# V5 state reset
	_hit_dir = 0.0
	_slam_t = 0.0
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


func trigger_hit_reaction(hit_dir: float = 0.0) -> void:
	## Squash+kick envelope 0.18s. Guard: never fires after death.
	## Re-triggering mid-envelope restarts the envelope (max 0.18s).
	## hit_dir: horizontal direction of incoming blow in [-1, 1]
	##          (1 = from the right); adds a roll-away lean while active.
	if not is_instance_valid(_body):
		return
	if _body.get("is_dead") == true:
		return
	_hit_t = _HIT_DURATION
	_hit_dir = clampf(hit_dir, -1.0, 1.0)


func trigger_spawn() -> void:
	## Scale-in from near-zero to 1 over _SPAWN_DURATION seconds (ease-out).
	## Called by ZombieSpawner3D on checkout so the zombie pops in gracefully.
	_spawn_t = _SPAWN_DURATION


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

	# Tick lunge — duration driven by per-species registry (V5 §1).
	if _lunge_active:
		var _atk_reg: Dictionary = ATTACK_REGISTRY.get(_subtype, ATTACK_REGISTRY["default"])
		var _atk_base: float = float(_atk_reg.get("attack_base", 0.35))
		_lunge_t += delta
		if _lunge_t >= _atk_base:
			_lunge_active = false
			_lunge_t = 0.0

	# Tick startle hop.
	if _hop_t > 0.0:
		_hop_t = max(0.0, _hop_t - delta)

	# Tick idle quirk.
	_quirk_timer += delta

	# Tick hit reaction.
	if _hit_t > 0.0:
		_hit_t = max(0.0, _hit_t - delta)

	# ── LANDING SQUASH (spec §6) — detect on_floor transition ────────────────
	var v_y: float = vel.y
	if _prev_v_y < -0.5 and v_y >= -0.1:
		var impact: float = -_prev_v_y
		_land_squash = clampf(impact * 0.025, 0.05, 0.18)
		_land_t = 0.2
	if _land_t > 0.0:
		_land_t = max(0.0, _land_t - delta)
	_prev_v_y = v_y

	# ── LAUNCH WIND-UP (spec §7) — rising edge of gait_target ────────────────
	var gait_target: float = 1.0 if h_speed >= 0.15 else 0.0
	if gait_target > 0.5 and _prev_gait_target <= 0.5:
		_launch_t = _LAUNCH_DURATION
	if _launch_t > 0.0:
		_launch_t = max(0.0, _launch_t - delta)
	_prev_gait_target = gait_target

	# Runner lean ramp (spec §7).
	if _subtype == "runner":
		var lean_target: float = 1.0 if _gait_weight > 0.5 else 0.0
		_lean_ramp = lerpf(_lean_ramp, lean_target, 1.0 - exp(-4.0 * delta))

	# ── BOSS CHARGE WIND-UP (spec §7) — rising edge of is_charging ───────────
	if is_charging and not _prev_charging:
		_boss_launch_t = _BOSS_LAUNCH_DURATION
	if _boss_launch_t > 0.0:
		_boss_launch_t = max(0.0, _boss_launch_t - delta)

	# ── BOSS SLAM IMPACT (V5 §5) — falling edge of is_charging at low speed ──
	if not is_charging and _prev_charging and h_speed < 1.0:
		if _body.get("is_dead") != true:
			_slam_t = _SLAM_DURATION
			var _cs := get_tree().current_scene if get_tree() else null
			if _cs and _cs.has_method("_shake"):
				_cs._shake(0.4)
	if _slam_t > 0.0:
		_slam_t = max(0.0, _slam_t - delta)

	_prev_charging = is_charging

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
	var p_hit_squash: float  = _gait.get("hit_squash",    0.15)
	var p_hit_lean: float    = _gait.get("hit_lean",      0.08)

	# Scale amplitudes for character scale (uniform scale on the parent Mesh node).
	var char_scale: float = 1.0
	var parent := get_parent()
	if parent is Node3D:
		char_scale = (parent as Node3D).scale.x

	# Update gait blend weight.
	var gait_ramp: float = 12.0 / 0.25 if gait_target > _gait_weight else 12.0 / 0.3
	_gait_weight = lerpf(_gait_weight, gait_target, 1.0 - exp(-gait_ramp * delta))

	# ── TURN BANKING (spec §5) — read _visual yaw, never write it ────────────
	# After reparent, this animator's parent is the body (owns no yaw).
	# The AI writes mesh yaw to _visual.rotation.y; read from there.
	var parent_yaw: float = 0.0
	if is_instance_valid(_visual):
		parent_yaw = _visual.rotation.y
	var raw_yaw_delta: float = parent_yaw - _prev_parent_yaw
	# Wrap to [-PI, PI].
	while raw_yaw_delta > PI:
		raw_yaw_delta -= TAU
	while raw_yaw_delta < -PI:
		raw_yaw_delta += TAU
	var bank_target: float = 0.0
	if _gait_weight > 0.3:
		bank_target = clampf(-raw_yaw_delta * 12.0, -0.18, 0.18)
	_bank = lerpf(_bank, bank_target, 1.0 - exp(-10.0 * delta))
	_prev_parent_yaw = parent_yaw

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
		# Boss charge wind-up dip (spec §7).
		if _boss_launch_t > 0.0:
			var bl_frac: float = _boss_launch_t / _BOSS_LAUNCH_DURATION
			scl.y *= 1.0 - 0.09 * sin(PI * (1.0 - bl_frac))
			scl.x *= 1.0 + 0.09 * 0.5 * sin(PI * bl_frac)
			scl.z = scl.x
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

	# ── FOOTSTEPS (spec §5) — negative zero-crossing at walking speed ─────
	# Trigger once per step: when gait is active, speed >= 0.5, and the sine
	# wave crosses from positive to negative (one footfall per cycle).
	if _gait_weight > 0.5 and h_speed >= 0.5 and _prev_sin >= 0.0 and raw_sin < 0.0:
		Audio.play_step()
	_prev_sin = raw_sin

	var walk_pos_y: float = raw_bob_val * p_bob * char_scale * minf(1.0, h_speed / 3.0) * p_bounce
	var walk_rot_z: float = sin(_phase * TAU * 2.0) * p_roll * speed_factor * sway_mult
	var walk_rot_x: float = -clampf(h_speed * 0.02, 0.0, p_lean)

	# Runner lean ramp: modulate forward lean so it doesn't pop instantly (spec §7).
	if _subtype == "runner":
		walk_rot_x *= _lean_ramp

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

	# ── PER-SPECIES ATTACK LUNGE (V5 §1) ─────────────────────────────────────
	if _lunge_active:
		# Fetch per-species attack parameters (no alloc: const dict lookup).
		var _atk_reg: Dictionary = ATTACK_REGISTRY.get(_subtype, ATTACK_REGISTRY["default"])
		var _atk_base: float     = float(_atk_reg.get("attack_base",     0.35))
		var _a_windup: float     = float(_atk_reg.get("attack_windup",   0.25))
		var _a_snap:   float     = float(_atk_reg.get("attack_snap",     0.35))
		var _a_over:   float     = float(_atk_reg.get("attack_overshoot",0.18))
		var _a_recov:  float     = 1.0 - _a_windup - _a_snap  # remaining share

		# Normalize time to [0..1] within the total attack duration.
		var t_frac: float = clampf(_lunge_t / _atk_base, 0.0, 1.0)

		var lunge_pos_z: float   = 0.0
		var lunge_rot_x: float   = 0.0
		var env_intensity: float = 0.0

		if t_frac < _a_windup:
			# Phase 1 — windup: pull BACK opposite the strike (ease-in).
			# Range: 0 → _a_windup; normalized p = 0..1.
			var p: float  = t_frac / _a_windup
			var ea: float = p * p  # ease-in quad
			# Pull back to –20% of forward depth; positive rot.x = lean back.
			lunge_pos_z  = -lunge_z * 0.20 * ea * char_scale
			lunge_rot_x  =  lunge_pitch * 0.25 * ea
			env_intensity = ea * 0.35

		elif t_frac < _a_windup + _a_snap:
			# Phase 2 — snap: forward to depth * (1 + overshoot), ease-out.
			# C0 continuity: starts at the windup endpoint values.
			var p: float  = (t_frac - _a_windup) / _a_snap  # 0..1
			# Smoothstep for ease-out feel; amplify for punch.
			var ss: float = p * p * (3.0 - 2.0 * p)
			var env_s: float = minf(1.0, ss * 1.6)
			# Windup endpoint (C0 join): pos_z starts at -lunge_z*0.20, rot_x at +lunge_pitch*0.25
			lunge_pos_z  = lerpf(-lunge_z * 0.20, lunge_z * (1.0 + _a_over), env_s) * char_scale
			lunge_rot_x  = lerpf(lunge_pitch * 0.25, -lunge_pitch * (1.0 + _a_over * 0.5), env_s)
			env_intensity = env_s

		else:
			# Phase 3 — recovery: elastic undershoot back to rest (ease-out).
			# Starts at the snap endpoint (full extension), decays with a light
			# undershoot using a damped sine to add a springy feel.
			var p: float    = (t_frac - _a_windup - _a_snap) / maxf(_a_recov, 0.001)
			p = clampf(p, 0.0, 1.0)
			# Primary decay from full extension to 0; small elastic dip below 0.
			var decay: float = (1.0 - p) * (1.0 - p)
			# Elastic undershoot: sin(p*PI) peaks at p=0.5, so it adds a slight
			# reverse-direction blip in the middle of recovery.
			var undershoot: float = sin(p * PI) * 0.08
			lunge_pos_z  = (lunge_z * (1.0 + _a_over) * decay - lunge_z * undershoot) * char_scale
			lunge_rot_x  = -lunge_pitch * (1.0 + _a_over * 0.5) * decay + lunge_pitch * undershoot * 0.3
			env_intensity = decay

		_lunge_intensity = lerpf(_lunge_intensity, env_intensity, 1.0 - exp(-20.0 * delta))

		# Suppress gait amplitudes during strike (walk does not freeze).
		var gait_suppress: float = 1.0 - _lunge_intensity * 0.85
		pos.z += lunge_pos_z
		rot.x = rot.x * gait_suppress + lunge_rot_x
	else:
		_lunge_intensity = lerpf(_lunge_intensity, 0.0, 1.0 - exp(-12.0 * delta))

	# ── LANDING SQUASH LAYER (spec §6) ───────────────────────────────────────
	if _land_t > 0.0:
		var land_elapsed: float = 0.2 - _land_t   # how far into the 0.2s window
		var land_frac: float = land_elapsed / 0.2  # 0 at impact, 1 at end
		var decay_w: float = (1.0 - land_frac) * (1.0 - land_frac)  # decaying
		scl.y *= 1.0 - _land_squash * decay_w
		scl.x *= 1.0 + _land_squash * 0.4 * decay_w
		scl.z = scl.x

	# ── LAUNCH WIND-UP LAYER (spec §7) ───────────────────────────────────────
	if _launch_t > 0.0:
		var lch_frac: float = _launch_t / _LAUNCH_DURATION  # 1→0 over duration
		# Phase 1: dip (1→0), Phase 2: stretch (0→1), encoded in one formula:
		# At frac=1 (just triggered): dip starts. At frac=0: back to neutral.
		# Use 1-frac to get 0→1 as time progresses.
		var prog: float = 1.0 - lch_frac  # 0..1 (0=just started, 1=done)
		var dip_val: float = 1.0 - 0.06 * sin(PI * (1.0 - prog))  # squash first
		var stretch_val: float = 1.0 + 0.05 * sin(PI * prog)        # then stretch
		# Blend: early part = dip, late part = stretch, smooth transition.
		var blend: float = prog
		scl.y *= lerpf(dip_val, stretch_val, blend)
		scl.x *= 1.0 + 0.03 * sin(PI * prog)
		scl.z = scl.x

	# ── TURN BANKING LAYER (spec §5) — added on top of walk roll ─────────────
	rot.z += _bank

	# ── HIT REACTION LAYER (V5 §3) — squash + backward kick + directional roll ─
	if _hit_t > 0.0:
		var hit_frac: float = _hit_t / _HIT_DURATION  # 1→0
		var hit_prog: float = 1.0 - hit_frac           # 0→1 within envelope time
		var sin_env: float  = sin(PI * hit_prog)        # rises then falls
		scl.y *= 1.0 - p_hit_squash * sin_env
		scl.x *= 1.0 + p_hit_squash * 0.5 * sin_env
		scl.z = scl.x
		rot.x += p_hit_lean * sin_env                   # small backward kick
		# Directional roll: roll away from the direction of the blow.
		rot.z += _hit_dir * 0.10 * sin_env

	# ── BOSS SLAM IMPACT (V5 §5) — scale dip + bounce stretch ───────────────
	if _slam_t > 0.0:
		var slam_frac: float = _slam_t / _SLAM_DURATION  # 1→0
		var slam_prog: float = 1.0 - slam_frac            # 0→1
		# First 60% of duration: deep squash dip with x/z spread.
		# Last 40%: bounce-back stretch then settle.
		if slam_prog < 0.6:
			var p: float     = slam_prog / 0.6  # 0..1
			var dip: float   = 1.0 - p * 0.4   # peak dip to 0.60 at p=1
			scl.y *= lerpf(1.0, 0.88 * dip, sin(p * PI * 0.5))
			var spread: float = 1.0 + 0.08 * sin(p * PI * 0.5)
			scl.x *= spread
			scl.z *= spread
		else:
			var p: float      = (slam_prog - 0.6) / 0.4  # 0..1
			# Bounce-back: overshoot to 1.06 then settle to 1.0.
			var stretch: float = 1.0 + 0.06 * sin(p * PI)
			scl.y *= stretch

	transform = _make_transform(pos, rot, scl)

	# ── SPAWN SCALE-IN (spec §6) — applied to OWN scale, ease-out ────────────
	# Overrides the animator node's own scale (not the mesh's). While active,
	# the whole subtree scales from ~0 to 1 over _SPAWN_DURATION seconds.
	if _spawn_t > 0.0:
		_spawn_t = max(0.0, _spawn_t - delta)
		var t_frac: float = 1.0 - (_spawn_t / _SPAWN_DURATION)  # 0→1
		var ease_val: float = 1.0 - (1.0 - t_frac) * (1.0 - t_frac)  # ease-out quad
		var s: float = lerpf(0.01, 1.0, ease_val)
		scale = Vector3(s, s, s)


# ── HELPERS ───────────────────────────────────────────────────────────────────

func _resolve_subtype() -> void:
	# Called once in attach() and again in reset_anim() to re-detect subtype.
	# ONLY nodes in the "player" group resolve to "human".
	# Null/empty zombie_type AND not player → "" (generic zombie).
	if not is_instance_valid(_body):
		_subtype = ""
		_gait = {}
		return

	if _body.is_in_group("player"):
		_subtype = "human"
		_gait = GAIT_REGISTRY.get("human", {})
		return

	var raw_type = _body.get("zombie_type")
	if raw_type == null:
		_subtype = ""
		_gait = {}
		return

	var type_str: String = str(raw_type).to_lower().strip_edges()
	if type_str.is_empty():
		_subtype = ""
		_gait = {}
		return

	# Alias normalization: try alias dict first, then strip "zombie_" prefix.
	if _SUBTYPE_ALIASES.has(type_str):
		type_str = _SUBTYPE_ALIASES[type_str]
	elif type_str.begins_with("zombie_"):
		type_str = type_str.trim_prefix("zombie_")

	# Map any unrecognised subtype to the generic zombie (empty dict = all defaults).
	if GAIT_REGISTRY.has(type_str):
		_subtype = type_str
	else:
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
