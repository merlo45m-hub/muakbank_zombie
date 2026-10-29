extends Node3D
## LampGate.gd — DESIGN.md §6 real-time-light budget enforcement.
##
## The doc budgets 3 real-time lights on screen (1 directional + the player's
## 2 omnis, hard ceiling 4) and states "Street lamps must not all be live at
## once". The booted game scene carries ~50 always-on OmniLight3D nodes: the
## two static lamps in game.tscn, the two redundant big "ambient fill" omnis
## (game.tscn's range-50 and the level asset's range-45 — the environment
## already provides a real ambient term via the sky), LevelDetail lanterns /
## street lamps / jack-o'-lanterns, StreetDetail's ring and near-band lamps,
## and the mini-game podium beacons.
##
## This node keeps every OmniLight3D in the world OFF unless the player is
## within GATE_DIST of it (a cheap 4 Hz distance check), and disables any
## duplicate DirectionalLight3D the level asset layers on top of the scene's
## own key light (DESIGN §6: exactly 1 directional / 1 shadow caster). The
## player's own two omnis are exempt. No light node is deleted and no light
## property (energy, color, range, shadow) is modified — lights simply toggle
## visible, so the authored look is unchanged whenever a light IS active.

const GATE_DIST := 18.0
const TICK := 0.25          # 4 Hz check: ~50 lights x squared distance = negligible
const SWEEP_TICKS := 240    # keep registering late-spawned omnis (level env, podiums) for 60 s of game time

var _player: Node3D = null
var _accum := 0.0
var _sweep_left := SWEEP_TICKS
var _gated: Array[OmniLight3D] = []
var _main_dir: Node = null


func _ready() -> void:
	# Enforce the DESIGN §6 "exactly one directional" rule: keep the scene's own
	# key light (a child of this node — game.tscn's shadowed DirectionalLight
	# under Environment/Lighting) and hide duplicate directionals layered in by
	# the instanced level environment asset. The main directional itself is never
	# modified; a duplicate key light just stops being rendered.
	for sib in get_children():
		if sib is DirectionalLight3D:
			_main_dir = sib
	_suppress_duplicate_directionals()

	# Register everything present at boot (static lamps + LevelDetail/StreetDetail
	# procedural lamps already spawned — their _ready ran before this one) and
	# run the first gate pass immediately so boot never shows a dark flash.
	_register()
	_gate()


func _process(delta: float) -> void:
	_accum += delta
	if _accum < TICK:
		return
	_accum = 0.0
	_gate()
	if _sweep_left > 0:
		_sweep_left -= 1
		_register()
		_suppress_duplicate_directionals()


## The level environment is instanced by Game._ready — AFTER this node's _ready —
## so its duplicate directional shows up late; the sweep keeps hiding it.
func _suppress_duplicate_directionals() -> void:
	for n in _walk(get_tree().root):
		if n is DirectionalLight3D and n != _main_dir:
			n.visible = false


func _gate() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return  # player not in tree yet; next tick re-checks
	var pp := _player.global_position
	var d2 := GATE_DIST * GATE_DIST
	for l in _gated:
		if not is_instance_valid(l):
			continue
		if _player.is_ancestor_of(l):
			l.visible = true  # player-owned lights (fill/rim) are exempt: never gated, always on
			continue
		l.visible = (l as Node3D).global_position.distance_squared_to(pp) < d2


func _register() -> void:
	for n in _walk(get_tree().root):
		if n is OmniLight3D:
			var omni := n as OmniLight3D
			if _player != null and _player.is_ancestor_of(omni):
				omni.visible = true  # never gate the player's own lights
				continue
			if not _gated.has(omni):
				_gated.append(omni)
				omni.visible = false  # off by default; the gate decides


func _walk(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.push_back(c)
	return out
