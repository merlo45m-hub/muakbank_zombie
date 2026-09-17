extends Node3D
class_name WeaponSystem

## Weapon System — Handles weapon equipping, switching, and stats
## Attach to player or game manager

signal weapon_equipped(weapon_data)
signal weapon_fired(weapon_data)
signal ammo_changed(current, max)

# === WEAPON DEFINITIONS ===

const WEAPONS = {
	"fists": {
		"name": "Fists",
		"damage": 10,
		"fire_rate": 0.3,
		"range": 1.5,
		"ammo": -1,
		"max_ammo": -1,
		"auto": false,
		"projectile": false,
		"spread": 0.0,
		"recoil": 0.0,
		"icon": "👊"
	},
	"bat": {
		"name": "Baseball Bat",
		"damage": 25,
		"fire_rate": 0.5,
		"range": 2.5,
		"ammo": -1,
		"max_ammo": -1,
		"auto": false,
		"projectile": false,
		"spread": 0.0,
		"recoil": 0.0,
		"icon": "🏏"
	},
	"knife": {
		"name": "Combat Knife",
		"damage": 15,
		"fire_rate": 0.2,
		"range": 1.2,
		"ammo": -1,
		"max_ammo": -1,
		"auto": false,
		"projectile": false,
		"spread": 0.0,
		"recoil": 0.0,
		"icon": "🔪"
	},
	"pistol": {
		"name": "Pistol",
		"damage": 20,
		"fire_rate": 0.4,
		"range": 15.0,
		"ammo": 15,
		"max_ammo": 15,
		"auto": false,
		"projectile": true,
		"spread": 0.02,
		"recoil": 0.1,
		"icon": "🔫"
	},
	"shotgun": {
		"name": "Shotgun",
		"damage": 60,
		"fire_rate": 1.0,
		"range": 8.0,
		"ammo": 8,
		"max_ammo": 8,
		"auto": false,
		"projectile": false,
		"spread": 0.15,
		"recoil": 0.3,
		"icon": "🔫"
	},
	"rifle": {
		"name": "Assault Rifle",
		"damage": 18,
		"fire_rate": 0.1,
		"range": 20.0,
		"ammo": 30,
		"max_ammo": 30,
		"auto": true,
		"projectile": true,
		"spread": 0.03,
		"recoil": 0.05,
		"icon": "🔫"
	},
	"medkit": {
		"name": "Medkit",
		"damage": 0,
		"fire_rate": 2.0,
		"range": 0.0,
		"ammo": 1,
		"max_ammo": 1,
		"auto": false,
		"projectile": false,
		"spread": 0.0,
		"recoil": 0.0,
		"icon": "🩹",
		"heals": 50
	}
}

# === STATE ===
var current_weapon: String = "fists"
var inventory: Array = ["fists"]
var fire_timer: float = 0.0
var current_ammo: int = -1

# === PUBLIC API ===

func equip_weapon(weapon_id: String) -> void:
	if not WEAPONS.has(weapon_id):
		return
	
	current_weapon = weapon_id
	var data = WEAPONS[weapon_id]
	current_ammo = data["ammo"]
	emit_signal("weapon_equipped", data)

func get_current_weapon_data() -> Dictionary:
	return WEAPONS.get(current_weapon, WEAPONS["fists"])

func add_weapon_to_inventory(weapon_id: String) -> void:
	if not inventory.has(weapon_id):
		inventory.append(weapon_id)

func switch_to_next_weapon() -> void:
	if inventory.size() <= 1:
		return
	
	var idx = inventory.find(current_weapon)
	idx = (idx + 1) % inventory.size()
	equip_weapon(inventory[idx])

func switch_to_previous_weapon() -> void:
	if inventory.size() <= 1:
		return
	
	var idx = inventory.find(current_weapon)
	idx = (idx - 1 + inventory.size()) % inventory.size()
	equip_weapon(inventory[idx])

func can_fire() -> bool:
	if fire_timer > 0:
		return false
	var data = get_current_weapon_data()
	if data["ammo"] == -1:
		return true
	return current_ammo > 0

func use_ammo() -> void:
	var data = get_current_weapon_data()
	if data["ammo"] == -1:
		return
	current_ammo -= 1
	emit_signal("ammo_changed", current_ammo, data["max_ammo"])

func fire() -> Dictionary:
	if not can_fire():
		return {}
	
	var data = get_current_weapon_data()
	fire_timer = data["fire_rate"]
	use_ammo()
	emit_signal("weapon_fired", data)
	return data

func add_ammo(amount: int) -> void:
	var data = get_current_weapon_data()
	if data["ammo"] == -1:
		return
	current_ammo = min(current_ammo + amount, data["max_ammo"])
	emit_signal("ammo_changed", current_ammo, data["max_ammo"])

func tick(delta: float) -> void:
	if fire_timer > 0:
		fire_timer -= delta
