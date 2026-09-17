## GameOver.gd — Game Over / Results Screen
## Attach to root Control node

extends Control

signal restart_requested
signal menu_requested

@onready var title_label = $VBoxMain/TitleLabel
@onready var likes_label = $VBoxMain/StatsContainer/LikesLabel
@onready var zombies_label = $VBoxMain/StatsContainer/ZombiesLabel
@onready var high_score_label = $VBoxMain/StatsContainer/HighScoreLabel
@onready var new_record_label = $VBoxMain/StatsContainer/NewRecordLabel
@onready var restart_btn = $VBoxMain/ButtonContainer/RestartBtn
@onready var menu_btn = $VBoxMain/ButtonContainer/MenuBtn

var is_victory = false
var likes = 0
var zombies = 0


func _ready():
	restart_btn.pressed.connect(_on_restart)
	menu_btn.pressed.connect(_on_menu)
	
	# Check for pending results from the game controller (race condition fix)
	if not Save.pending_results.is_empty():
		var r = Save.pending_results
		set_results(r.survived, r.score, r.kills)
		Save.pending_results.clear()


func set_results(victory, likes_earned, zombies_fed):
	"""Called by Main.gd when shift ends."""
	is_victory = victory
	likes = likes_earned
	zombies = zombies_fed
	
	# Play result sound
	if victory:
		Audio.play_victory()
	else:
		Audio.play_defeat()

	# Update save
	Save.add_zombies_fed(zombies)
	Save.add_likes_earned(likes)
	if victory:
		Save.add_shifts_completed(1)
		var total_likes = Save.get_total_likes_earned()
		Save.update_high_score(total_likes)

	# Update UI
	if victory:
		title_label.text = "🎉 SHIFT COMPLETE! 🎉"
	else:
		title_label.text = "💀 GAME OVER 💀"

	likes_label.text = "❤ Likes: %d" % likes
	zombies_label.text = "🧟 Zombies Fed: %d" % zombies
	high_score_label.text = "🏆 High Score: %d" % Save.get_high_score()

	# New record check
	if likes >= Save.get_high_score():
		new_record_label.visible = true
		new_record_label.text = "🏆 NEW HIGH SCORE! 🏆"
	else:
		new_record_label.visible = false

	# Unlock next level
	if victory:
		var next_level = Save.get_current_level() + 1
		Save.unlock_level(next_level)


func _on_restart():
	Audio.play_click()
	emit_signal("restart_requested")
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")


func _on_menu():
	Audio.play_click()
	emit_signal("menu_requested")
	get_tree().change_scene_to_file("res://scenes/main/title_screen.tscn")
