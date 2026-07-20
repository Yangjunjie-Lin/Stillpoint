extends Control
## Main menu: Adventure (2.5D) + legacy Survival prototype.

@onready var name_edit: LineEdit = %NameEdit
@onready var leaderboard_list: ItemList = %LeaderboardList
@onready var continue_button: Button = %ContinueButton
@onready var continue_summary: Label = %ContinueSummary
@onready var confirm_panel: Control = %ConfirmPanel
@onready var settings_panel: Control = %SettingsPanel
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var fullscreen_check: CheckBox = %FullscreenCheck


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_panel.visible = false
	settings_panel.visible = false
	name_edit.text = GameManager.player_name
	_load_settings_widgets()
	_refresh_leaderboard()
	_refresh_continue()


func _load_settings_widgets() -> void:
	master_slider.value = float(SaveService.settings.get("master_volume_db", 0.0))
	music_slider.value = float(SaveService.settings.get("music_volume_db", -6.0))
	sfx_slider.value = float(SaveService.settings.get("sfx_volume_db", -3.0))
	fullscreen_check.button_pressed = bool(SaveService.settings.get("fullscreen", true))


func _refresh_continue() -> void:
	if GameManager.has_resumable_adventure():
		continue_button.disabled = false
		continue_summary.text = "Continue adventure as %s" % GameManager.player_name
		return
	var summary := GameManager.inspect_resumable_run()
	continue_button.disabled = not summary.valid
	if summary.valid:
		var minutes := int(summary.survival_seconds) / 60
		var seconds := int(summary.survival_seconds) % 60
		continue_summary.text = "Continue survival as %s\nLevel %d · Score %s · %02d:%02d" % [
			summary.player_name,
			summary.combat_level,
			_format_int(summary.score),
			minutes,
			seconds,
		]
	else:
		continue_summary.text = _continue_unavailable_text(summary.reason)


func _continue_unavailable_text(reason: String) -> String:
	match reason:
		"future_version":
			return "Save created by a newer version"
		"unknown_level":
			return "Save level is no longer available"
		"game_over":
			return "Previous run ended"
		"expired":
			return "Save expired"
		"missing":
			return "No resumable save"
		_:
			return "No resumable save"


func _on_continue_pressed() -> void:
	if GameManager.has_resumable_adventure():
		GameManager.continue_adventure()
	else:
		GameManager.continue_run()


func _on_start_pressed() -> void:
	if GameManager.has_resumable_adventure() or GameManager.has_resumable_run():
		confirm_panel.visible = true
		return
	_begin_new_adventure()


func _on_survival_pressed() -> void:
	GameManager.start_new_run(name_edit.text)


func _on_confirm_new_game() -> void:
	confirm_panel.visible = false
	_begin_new_adventure()


func _on_cancel_new_game() -> void:
	confirm_panel.visible = false


func _begin_new_adventure() -> void:
	GameManager.start_new_adventure(name_edit.text)


func _on_settings_pressed() -> void:
	_load_settings_widgets()
	settings_panel.visible = true


func _on_settings_close() -> void:
	SaveService.settings["master_volume_db"] = master_slider.value
	SaveService.settings["music_volume_db"] = music_slider.value
	SaveService.settings["sfx_volume_db"] = sfx_slider.value
	SaveService.settings["fullscreen"] = fullscreen_check.button_pressed
	SaveService.save_settings()
	settings_panel.visible = false


func _on_quit_pressed() -> void:
	get_tree().quit()


func _refresh_leaderboard() -> void:
	leaderboard_list.clear()
	for entry in SaveService.load_leaderboard():
		if entry is Dictionary:
			leaderboard_list.add_item("%s — %s" % [str(entry.get("name", "?")), str(entry.get("score", 0))])


func _format_int(value: int) -> String:
	var s := str(value)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return out
