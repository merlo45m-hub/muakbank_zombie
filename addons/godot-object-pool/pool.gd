#
# The design/intent of this object pool is to be as immutable as possible from the outside.
# With this in mind, I've attempted to not expose many internal to keep things as simple as possible,
# knowing that nothing actually prevents you from modifying the object.
#
# Ported to Godot 4: removed `setget` property syntax (Godot 3 only), signal/pause API updates.
#

# Signal emitted when an object managed by the pool is "killed".
# This is called after the pool has handled the killed signal from the object.
signal killed(target)

# Prefix to use when adding objects to the scene (becomes "undefined_1, undefined_2, etc")
var prefix: String = ""

# Pool size on initialization
var size: int = 0

# Preloaded scene resource
var scene = null

# Dictionary of "alive" objects currently in-use.
# Using a dictionary for fast lookup/deletion
var alive = {}

# Array of "dead" objects currently available for use
var dead = []

# Constructor accepting pool size, prefix and scene
func _init(size_, prefix_, scene_) -> void:
	size = int(size_)
	prefix = str(prefix_)
	scene = scene_
	init()

# Expand the total pool size by the number of size objects.
# For example, if passed 2, we will instantiate 2 new objects and add to the dead pool.
func init() -> void:
	# If scene has not been set, just return
	if scene == null:
		return

	for i in range(size):
		var s = scene.instantiate()
		s.set_name(prefix + "_" + str(i))
		s.connect("killed", _on_killed)
		dead.push_back(s)

func get_prefix() -> String:
	return prefix

func get_size() -> int:
	return size

func get_scene():
	return scene

func get_alive_size() -> int:
	return alive.size()

func get_dead_size() -> int:
	return dead.size()

# Get the first dead object and make it alive, adding the object to the alive pool and removing from dead pool
func get_first_dead():
	var ds = dead.size()
	if ds > 0:
		var o = dead[ds - 1]
		if !o.dead:
			return null

		var n = o.get_name()
		alive[n] = o
		dead.pop_back()
		o.dead = false
		o.process_mode = 0  # PROCESS_MODE_INHERIT
		return o

	return null

# Get the first alive object. Does not affect / change the object's dead value
func get_first_alive():
	if alive.size() > 0:
		return alive.values()[0]

	return null

# Convenience method to kill all ALIVE objects managed by the pool
func kill_all() -> void:
	for i in alive.values():
		i.kill()

# Attach all objects managed by the pool to the node passed
func add_to_node(node) -> void:
	for i in alive.values():
		node.add_child(i)

	for i in dead:
		node.add_child(i)

# Convenience method to show all objects managed by the pool
func show() -> void:
	for i in alive.values():
		i.show()

	for i in dead:
		i.show()

# Convenience method to hide all objects managed by the pool
func hide() -> void:
	for i in alive.values():
		i.hide()

	for i in dead:
		i.hide()

# Event that all objects should emit so that the pool can manage dead/alive pools
func _on_killed(target) -> void:
	# Get the name of the target object that was killed
	var name = target.get_name()

	# Remove the killed object from the alive pool
	alive.erase(name)

	# Add the killed object to the dead pool, now available for use
	dead.push_back(target)

	target.process_mode = 1  # PROCESS_MODE_PAUSABLE

	emit_signal("killed", target)
