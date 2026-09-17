extends Node
class_name GameStateManager

## GameStateManager — Central game state machine
## Autoload or attach to root. Manages PLAYING/PAUSED/GAMEOVER states.

signal state_changed(old_state, new_state)

enum GameState { MENU, PLAYING, PAUSED, GAMEOVER, LEVEL_COMPLETE }

var current_state: GameState = GameState.MENU

func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	var old = current_state
	current_state = new_state
	state_changed.emit(old, new_state)
	
	match new_state:
		GameState.PLAYING:
			get_tree().paused = false
		GameState.PAUSED:
			get_tree().paused = true
		GameState.GAMEOVER, GameState.LEVEL_COMPLETE:
			get_tree().paused = false

func is_playing() -> bool:
	return current_state == GameState.PLAYING

func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)
	elif current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)
