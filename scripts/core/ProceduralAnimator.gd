class_name ProceduralAnimator
extends Node3D

## ProceduralAnimator — Code-driven transform animation for unrigged GLB models
## Added as a child of the entity's visual container ("Mesh" node) and only ever
## modifies ITS OWN transform (position / rotation / scale). Never touches the
## parent's transform, which belongs to the AI (yaw, death tween, pool reset).

# ── EXPORTED AMPLITUDES ────────────────────────────────────────────────────────

@export_group("Breathing / Idle")
@export var breathe_scale_amp: float = 0.02     # scale.y sin amplitude
@export var breathe_speed: float = 2.0           # rad/s of breathe cycle
@export var idle_roll_amp: float = 0.02          # ±rad gentle side sway

@export_group("Walk Cycle")
@export var bob_height: float = 0.08             # max position.y bob (world units)
@export var walk_phase_base: float = 1.8         # phase rate at speed 0
@export var walk_phase_speed_scale: float = 2.4  # extra phase rate per unit speed
@export var roll_amp: float = 0.05               # rotation.z roll per unit speed
@export var lean_max: float = 0.12               # max forward lean (rotation.x, rad)

@export_group("Attack Lunge")
@export var lunge_z: float = 0.35               # local-Z lunge distance (forward)
@export var lunge_pitch: float = 0.45           # pitch-down angle (rad) at peak
@export var lunge_duration: float = 0.35        # seconds for one lunge + recover

@export_group("Special / Boss")
@export var special_sway_mult: float = 1.6      # SPECIAL state sway multiplier
@export var special_bob_mult: float = 0.65      # SPECIAL state bob speed multiplier
@export var boss_lean: float = 0.3              # charging lean (rotation.x rad)
@export var boss_squash: float = 0.9            # charging scale.y

# ── INTERNAL STATE ─────────────────────────────────────────────────────────────

var _body: Node3D = null       # CharacterBody3D driving movement (duck-typed)
var _time: float = 0.0         # running clock (breathing, idle sway)
var _phase: float = 0.0        # walk-cycle phase [0..1)

# Lunge state
var _lunge_active: bool = false
var _lunge_t: float = 0.0      # elapsed within lunge

# Startle hop (on_start_chase)
var _hop_t: float = 0.0        # elapsed within hop decay (0 when inactive)
var _hop_duration: float = 0.3
var _hop_height: float = 0.18  # initial kick height (world units)

# Snapshot of previous is_attacking to detect rising edge
var _was_attacking: bool = false


# ── PUBLIC API ─────────────────────────────────────────────────────────────────

func attach(body: Node3D, _visual: Node3D) -> void:
	## body = CharacterBody3D driving movement.
	## _visual = the node we are a child of — stored for potential future use
	## but never modified (its transform belongs to the AI layer).
	_body = body


func reset_anim() -> void:
	## Called by ZombieBase.reset_for_pool() — restores pristine animator state
	## so the recycled zombie starts without stale phase or lunge.
	_time = 0.0
	_phase = 0.0
	_lunge_active = false
	_lunge_t = 0.0
	_hop_t = 0.0
	_was_attacking = false
	transform = Transform3D()  # zero out our own transform


func trigger_attack() -> void:
	## Immediately starts the lunge envelope (Player hook or external call).
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
		if h_speed < 2.0:  # only when standing to attack, not while running
			trigger_attack()
	_was_attacking = is_attacking

	# Advance timers.
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

	# Scale amplitudes for character scale (uniform scale on the parent Mesh node).
	var char_scale: float = 1.0
	var parent := get_parent()
	if parent is Node3D:
		char_scale = (parent as Node3D).scale.x  # assume uniform

	# Build our transform from scratch each frame (no drift accumulation).
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	var scl := Vector3.ONE

	# ── BOSS CHARGING ────────────────────────────────────────────────────────
	if is_charging:
		rot.x = -boss_lean
		scl.y = boss_squash
		# Fast bob while charging
		var speed_factor: float = clampf(h_speed / 3.0, 0.0, 1.0)
		_phase += delta * (walk_phase_base + h_speed * walk_phase_speed_scale) * 1.5
		pos.y = abs(sin(_phase * TAU)) * bob_height * char_scale * speed_factor
		transform = _make_transform(pos, rot, scl)
		return

	# ── IDLE STATE (speed < 0.15 or AIState.IDLE == 0) ──────────────────────
	var is_idle_state: bool = (state == 0 and h_speed < 0.15)
	if is_idle_state:
		# Breathing: gentle scale.y pulse
		scl.y = 1.0 + breathe_scale_amp * sin(_time * breathe_speed)
		# Gentle roll sway
		rot.z = sin(_time * 1.1) * idle_roll_amp * char_scale
		transform = _make_transform(pos, rot, scl)
		return

	# ── MOVING ───────────────────────────────────────────────────────────────
	# Advance walk phase (slower entities shamble, runners race).
	var phase_rate: float = walk_phase_base + h_speed * walk_phase_speed_scale
	# SPECIAL (spitter, state==3): slower bob
	if state == 3:
		phase_rate *= special_bob_mult
	_phase += delta * phase_rate

	var speed_factor: float = clampf(h_speed / 3.0, 0.0, 1.0)
	var sway_mult: float = special_sway_mult if state == 3 else 1.0

	# Double-footed hop feel: |sin(phase * TAU)|
	pos.y = abs(sin(_phase * TAU)) * bob_height * char_scale * minf(1.0, h_speed / 3.0)

	# Side roll: sin(phase * TAU * 2) × amplitude × speed_factor
	rot.z = sin(_phase * TAU * 2.0) * roll_amp * speed_factor * sway_mult

	# Forward lean: clamp(speed * 0.02, 0, lean_max)
	rot.x = -clampf(h_speed * 0.02, 0.0, lean_max)

	# Startle hop: add decaying Y kick on top of walk bob
	if _hop_t > 0.0:
		var hop_frac: float = _hop_t / _hop_duration
		pos.y += _hop_height * char_scale * hop_frac * hop_frac  # quadratic decay

	# ── ATTACK LUNGE ─────────────────────────────────────────────────────────
	if _lunge_active:
		var t_frac: float = _lunge_t / lunge_duration
		var env: float = sin(t_frac * PI)  # 0→1→0 over the duration
		pos.z += lunge_z * char_scale * env        # local forward lunge
		rot.x += -lunge_pitch * env                # pitch down into the bite

	transform = _make_transform(pos, rot, scl)


# ── HELPERS ──────────────────────────────────────────────────────────────────

func _make_transform(pos: Vector3, euler_rot: Vector3, scl: Vector3) -> Transform3D:
	# Build a Transform3D from position, euler XYZ rotation, and scale.
	# Yaw (Y) is intentionally excluded — the parent AI owns mesh.rotation.y.
	var basis := Basis()
	basis = basis.rotated(Vector3.RIGHT, euler_rot.x)  # pitch
	basis = basis.rotated(Vector3.FORWARD, euler_rot.z)  # roll
	basis = basis.scaled(scl)
	return Transform3D(basis, pos)
