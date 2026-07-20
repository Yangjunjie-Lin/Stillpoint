extends Control
## Main menu: start run, leaderboard, quit.

@onready var name_edit: LineEdit = %NameEdit
@onready var leaderboard_list: ItemList = %LeaderboardList


func _ready() -> void:
	_refresh_leaderboard()
	name_edit.text = GameManager.player_name


func _on_start_pressed() -> void:
	GameManager.start_new_run(name_edit.text)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _refresh_leaderboard() -> void:
	leaderboard_list.clear()
	for entry in SaveService.load_leaderboard():
		if entry is Dictionary:
			leaderboard_list.add_item("%s — %s" % [str(entry.get("name", "?")), str(entry.get("score", 0))])
