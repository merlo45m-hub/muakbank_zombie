extends Resource
class_name CharacterStats

## Character Stats — Defines unique gameplay attributes per character
## Attach to each character scene or save as .tres resources

@export var character_id: String = "gamer"
@export var display_name: String = "Gamer"
@export var description: String = "Balanced fighter with quick reflexes"

# === CORE STATS ===
@export var max_health: int = 100
@export var max_stamina: int = 100
@export var move_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var stamina_regen: float = 15.0

# === COMBAT STATS ===
@export var attack_damage: int = 20
@export var attack_speed: float = 0.8  # multiplier (lower = faster)
@export var attack_range: float = 2.0
@export var critical_chance: float = 0.1
@export var critical_multiplier: float = 1.5

# === DEFENSE STATS ===
@export var damage_reduction: float = 0.0  # 0.0 to 0.5
@export var dodge_chance: float = 0.05
@export var knockback_resistance: float = 0.0

# === SPECIAL ABILITIES ===
@export var special_ability: String = ""  # "heal", "rage", "stealth", "shield"
@export var special_cooldown: float = 10.0
@export var special_duration: float = 3.0

# === BONUSES ===
@export var food_healing_multiplier: float = 1.0
@export var weapon_damage_multiplier: float = 1.0
@export var ammo_efficiency: float = 1.0  # higher = less ammo used

# === VISUAL ===
@export var character_color: Color = Color(1, 1, 1, 1)
