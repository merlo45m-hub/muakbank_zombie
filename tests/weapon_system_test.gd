extends GdUnitTestSuite

## Unit tests for WeaponSystem.gd — equipment rules and ammo gates.
## WeaponSystem is a plain logic node (scripts/gameplay/WeaponSystem.gd), so it
## is instantiated directly without a scene. Instances are freed in after_test
## so the suite leaves no orphan nodes behind.
##
## Run (Godot 4.7 headless on the VPS):
##   cd /root/muakbank_zombie
##   xvfb-run -a /root/Godot_v4.7-stable_linux.x86_64 --headless \
##       --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
##       -a res://tests --ignoreHeadlessMode

const WeaponSystemScript := preload("res://scripts/gameplay/WeaponSystem.gd")

var _ws: Node3D = null

func before_test() -> void:
	_ws = WeaponSystemScript.new()

func after_test() -> void:
	if _ws != null and is_instance_valid(_ws):
		_ws.free()
		_ws = null

func test_equip_weapon_swaps_stats_and_ammo() -> void:
	assert_that(_ws.current_weapon).is_equal("fists")

	_ws.equip_weapon("pistol")
	assert_that(_ws.current_weapon).is_equal("pistol")
	var data: Dictionary = _ws.get_current_weapon_data()
	assert_that(int(data["damage"])).is_equal(20)
	assert_that(_ws.current_ammo).is_equal(15)

	# Melee weapons are unlimited ammo (-1).
	_ws.equip_weapon("bat")
	assert_that(_ws.current_weapon).is_equal("bat")
	assert_that(_ws.current_ammo).is_equal(-1)

func test_unknown_weapon_is_ignored() -> void:
	_ws.equip_weapon("raygun")  # not in the WEAPONS table
	assert_that(_ws.current_weapon).is_equal("fists")

func test_can_fire_and_ammo_consumption() -> void:
	_ws.equip_weapon("pistol")
	assert_that(_ws.can_fire()).is_true()
	_ws.use_ammo()
	assert_that(_ws.current_ammo).is_equal(14)
	# Empty magazine blocks firing.
	_ws.current_ammo = 1
	_ws.use_ammo()
	assert_that(_ws.current_ammo).is_equal(0)
	assert_that(_ws.can_fire()).is_false()
	# Unlimited-ammo weapons never run dry.
	_ws.equip_weapon("fists")
	assert_that(_ws.can_fire()).is_true()

func test_weapon_inventory_add_and_cycle() -> void:
	_ws.add_weapon_to_inventory("pistol")
	_ws.add_weapon_to_inventory("shotgun")
	_ws.add_weapon_to_inventory("pistol")  # duplicates ignored
	assert_that(_ws.get_weapons_in_inventory().size()).is_equal(3)
	_ws.switch_to_next_weapon()
	assert_that(_ws.current_weapon).is_equal("pistol")
	_ws.switch_to_next_weapon()
	assert_that(_ws.current_weapon).is_equal("shotgun")
	_ws.switch_to_next_weapon()
	assert_that(_ws.current_weapon).is_equal("fists")  # wraps around
