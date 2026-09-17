extends Node
class_name GameAudioManager

## Game Audio Manager — Procedural + Dynamic Music System
## Autoload as "Audio" — handles adaptive music layers, SFX prioritization, and mixing

# === VOLUME (0.0 - 1.0) ===
var master_volume = 1.0:
	set(val): 
		master_volume = val
		AudioServer.set_bus_volume_db(0, _to_db(val))
		_save_settings()

var music_volume = 0.7:
	set(val): 
		music_volume = val
		AudioServer.set_bus_volume_db(1, _to_db(val))
		_save_settings()

var sfx_volume = 0.8:
	set(val): 
		sfx_volume = val
		AudioServer.set_bus_volume_db(2, _to_db(val))
		_save_settings()

var ambient_volume = 0.5:
	set(val): 
		ambient_volume = val
		if AudioServer.get_bus_index("Ambient") >= 0:
			AudioServer.set_bus_volume_db(4, _to_db(val))
		_save_settings()

var current_ambient_scene: String = ""  # Tracks active ambient layer
var ambient_wind_stream: AudioStreamWAV
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var sfx_players: Array = []
const MAX_SFX_PLAYERS = 12

# === AUDIO STREAMS ===
var menu_music_stream: AudioStream
var game_music_stream: AudioStream
var boss_music_stream: AudioStream
var menu_alt_music_stream: AudioStream
var click_stream: AudioStreamWAV
var zombie_reach_stream: AudioStreamWAV
var eat_stream: AudioStreamWAV
var frenzy_stream: AudioStreamWAV
var zombie_die_stream: AudioStreamWAV
var player_die_stream: AudioStreamWAV
var pickup_stream: AudioStreamWAV
var hurt_stream: AudioStreamWAV
var step_stream: AudioStreamWAV
var wave_hit_stream: AudioStreamWAV
var zombie_growl_stream: AudioStreamWAV
var zombie_hit_stream: AudioStreamWAV
var powerup_stream: AudioStreamWAV
var explosion_stream: AudioStreamWAV
var victory_stream: AudioStreamWAV
var defeat_stream: AudioStreamWAV

# === AMBIENT LAYER ===
var ambient_scenes: Dictionary = {}  # scene_name -> AudioStreamWAV
var ambient_player2: AudioStreamPlayer  # Second ambient for crossfade

# === DYNAMIC MUSIC ===
var current_intensity: float = 0.0
var target_intensity: float = 0.0
var intensity_decay: float = 0.3  # How fast intensity drops

func _ready() -> void:
	_setup_buses()
	_setup_players()
	_load_audio_streams()
	_load_settings()
	print("[GameAudioManager] Ready")


func _setup_buses() -> void:
	if AudioServer.get_bus_index("Master") == -1:
		AudioServer.add_bus(0)
		AudioServer.set_bus_name(0, "Master")
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, "Music")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus(2)
		AudioServer.set_bus_name(2, "SFX")
	if AudioServer.get_bus_index("Voice") == -1:
		AudioServer.add_bus(3)
		AudioServer.set_bus_name(3, "Voice")
	if AudioServer.get_bus_index("Ambient") == -1:
		AudioServer.add_bus(4)
		AudioServer.set_bus_name(4, "Ambient")
	
	AudioServer.set_bus_volume_db(0, _to_db(master_volume))
	AudioServer.set_bus_volume_db(1, _to_db(music_volume))
	AudioServer.set_bus_volume_db(2, _to_db(sfx_volume))
	AudioServer.set_bus_volume_db(4, _to_db(ambient_volume))


func _setup_players() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Ambient"
	add_child(ambient_player)
	
	# Second ambient player for crossfading between environments
	ambient_player2 = AudioStreamPlayer.new()
	ambient_player2.bus = "Ambient"
	add_child(ambient_player2)
	
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)


func _load_audio_streams() -> void:
	# Load from disk (fallback to procedural if missing)
	var dir = "res://audio/music/"
	menu_music_stream = _load_stream(dir + "menu_music.mp3")
	game_music_stream = _load_stream(dir + "game_music.mp3")
	boss_music_stream = _load_stream(dir + "music_boss.ogg")
	menu_alt_music_stream = _load_stream(dir + "music_menu_alt.ogg")
	
	dir = "res://audio/sfx/"
	click_stream = _load_stream(dir + "click.wav")
	zombie_reach_stream = _load_stream(dir + "zombie_reach.wav")
	eat_stream = _load_stream(dir + "eat.wav")
	frenzy_stream = _load_stream(dir + "frenzy.wav")
	zombie_die_stream = _load_stream(dir + "zombie_die.wav")
	player_die_stream = _load_stream(dir + "player_die.wav")
	pickup_stream = _load_stream(dir + "pickup.wav")
	hurt_stream = _load_stream(dir + "hurt.wav")
	step_stream = _load_stream(dir + "step.wav")
	wave_hit_stream = _load_stream(dir + "wave_hit.wav")
	
	# New SFX
	zombie_growl_stream = _load_stream(dir + "sfx_zombie_growl.wav")
	zombie_hit_stream = _load_stream(dir + "sfx_zombie_hit.wav")
	powerup_stream = _load_stream(dir + "sfx_powerup.wav")
	explosion_stream = _load_stream(dir + "sfx_explosion.wav")
	victory_stream = _load_stream(dir + "sfx_victory.wav")
	defeat_stream = _load_stream(dir + "sfx_defeat.wav")
	
	# Load ambient layer (8 env tracks)
	ambient_wind_stream = _load_stream("res://audio/ambient/wind.wav")
	ambient_scenes["hospital"] = _load_stream("res://audio/ambient/amb_hospital.wav")
	ambient_scenes["cemetery"] = _load_stream("res://audio/ambient/amb_cemetery.wav")
	ambient_scenes["town"] = _load_stream("res://audio/ambient/amb_town.wav")
	ambient_scenes["warehouse"] = _load_stream("res://audio/ambient/amb_warehouse.wav")
	ambient_scenes["subway"] = _load_stream("res://audio/ambient/amb_subway.wav")
	ambient_scenes["rooftop"] = _load_stream("res://audio/ambient/amb_rooftop.wav")


func _load_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	# Try procedural fallback
	return _generate_fallback(path)


func _generate_fallback(path: String) -> AudioStreamWAV:
	# Generate procedural audio for missing files
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	
	var data = PackedByteArray()
	var duration = 0.2
	var freq = 440.0
	
	if "click" in path:
		freq = 800.0
		duration = 0.08
	elif "eat" in path:
		freq = 200.0
		duration = 0.25
	elif "die" in path:
		freq = 600.0
		duration = 1.0
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif "step" in path:
		freq = 100.0
		duration = 0.1
	elif "pickup" in path:
		freq = 400.0
		duration = 0.15
	else:
		freq = 440.0
		duration = 0.2
	
	var sample_count = int(44100 * duration)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var sample = sin(t * freq * TAU) * 0.3
		var decay = 1.0 - (t / duration)
		sample *= decay
		var int_sample = int(clamp(sample, -1.0, 1.0) * 32767)
		data.append_array(_int16_to_bytes(int_sample))
	
	stream.data = data
	return stream


# ── PUBLIC API ─────────────────────────────────────────────────

func play_music(stream: AudioStreamWAV = null) -> void:
	if not stream:
		return
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.play()


func stop_music() -> void:
	music_player.stop()


func play_ambient(stream: AudioStreamWAV = null) -> void:
	if not stream:
		return
	ambient_player.stream = stream
	ambient_player.play()


func stop_ambient() -> void:
	ambient_player.stop()


func play_sfx(stream: AudioStreamWAV = null, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not stream:
		return
	
	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.pitch_scale = pitch_scale
			player.play()
			return
	
	# All busy — steal oldest with lowest volume
	sfx_players[0].stream = stream
	sfx_players[0].volume_db = volume_db
	sfx_players[0].pitch_scale = pitch_scale
	sfx_players[0].play()


func play_sfx_varied(stream: AudioStreamWAV = null, volume_range: float = 3.0, pitch_range: float = 0.1) -> void:
	var vol_db = randf_range(-volume_range, volume_range)
	var pitch = 1.0 + randf_range(-pitch_range, pitch_range)
	play_sfx(stream, vol_db, pitch)


# ── CONVENIENCE METHODS ───────────────────────────────────────

func play_menu_music() -> void:
	play_music(menu_music_stream)


func play_game_music() -> void:
	play_music(game_music_stream)


func play_click() -> void:
	play_sfx(click_stream, 0.0, 1.0 + randf_range(-0.1, 0.1))


func play_zombie_reach() -> void:
	play_sfx(zombie_reach_stream, -3.0, 0.9 + randf_range(-0.15, 0.15))


func play_eat() -> void:
	play_sfx(eat_stream)


func play_frenzy() -> void:
	play_sfx(frenzy_stream)


func play_zombie_die() -> void:
	play_sfx(zombie_die_stream, -2.0, 0.85 + randf_range(-0.1, 0.1))


func play_player_die() -> void:
	play_sfx(player_die_stream)


func play_pickup() -> void:
	play_sfx(pickup_stream, -1.0, 1.0 + randf_range(-0.05, 0.05))


func play_hurt() -> void:
	play_sfx(hurt_stream, -2.0, 1.0 + randf_range(-0.1, 0.1))


func play_step() -> void:
	play_sfx(step_stream, -12.0, 1.0 + randf_range(-0.2, 0.2))


func play_wave_hit() -> void:
	play_sfx(wave_hit_stream)


# ── NEW SFX ───────────────────────────────────────────────────

func play_zombie_growl() -> void:
	play_sfx(zombie_growl_stream, -4.0, 0.9 + randf_range(-0.1, 0.1))

func play_zombie_hit() -> void:
	play_sfx(zombie_hit_stream, -2.0, 0.85 + randf_range(-0.15, 0.15))

func play_powerup() -> void:
	play_sfx(powerup_stream, -1.0, 1.0 + randf_range(-0.05, 0.05))

func play_explosion() -> void:
	play_sfx(explosion_stream, 0.0, 0.95 + randf_range(-0.1, 0.1))

func play_victory() -> void:
	play_sfx(victory_stream, -2.0, 1.0)

func play_defeat() -> void:
	play_sfx(defeat_stream, -1.0, 0.95)


# ── AMBIENT LAYER SYSTEM ──────────────────────────────────────

func play_ambient_for(scene_name: String) -> void:
	"""Play ambient track for a specific environment scene.
	Call this when loading a new level to switch ambient layers."""
	if current_ambient_scene == scene_name:
		return
	current_ambient_scene = scene_name
	
	if ambient_scenes.has(scene_name):
		# Crossfade: swap which player is active
		var new_stream = ambient_scenes[scene_name]
		if ambient_player.playing and ambient_player.stream == new_stream:
			return
		if ambient_player2.playing and ambient_player2.stream == new_stream:
			return
		
		# Play on the inactive player, then crossfade
		var active_player = ambient_player
		var inactive_player = ambient_player2
		if ambient_player2.playing:
			active_player = ambient_player2
			inactive_player = ambient_player
		
		inactive_player.stream = new_stream
		inactive_player.volume_db = -80.0
		inactive_player.play()
		
		# Simple 1-second crossfade via tween would go here
		# For now, just swap immediately
		active_player.stop()
	else:
		# Fallback to generic wind ambient
		if ambient_player.stream != ambient_wind_stream:
			ambient_player.stream = ambient_wind_stream
			ambient_player.play()


# ── DYNAMIC MUSIC SYSTEM ──────────────────────────────────────

func set_intensity(value: float) -> void:
	target_intensity = clamp(value, 0.0, 1.0)


func _process(delta: float) -> void:
	# Smoothly interpolate music intensity
	current_intensity = lerp(current_intensity, target_intensity, delta * 2.0)
	
	# Decay target intensity over time (game gets calmer)
	target_intensity = max(0.0, target_intensity - intensity_decay * delta)
	
	# Could crossfade between calm/intense music layers here
	# music_player.volume_db = lerp(-80, 0, current_intensity)


# ── HELPERS ───────────────────────────────────────────────────

func _to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear)


func _int16_to_bytes(value: int) -> PackedByteArray:
	var bytes = PackedByteArray()
	bytes.append(value & 0xFF)
	bytes.append((value >> 8) & 0xFF)
	return bytes


func _load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://audio_settings.cfg") == OK:
		master_volume = config.get_value("audio", "master", 1.0)
		music_volume = config.get_value("audio", "music", 0.7)
		sfx_volume = config.get_value("audio", "sfx", 0.8)


func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save("user://audio_settings.cfg")
