extends Control
## Main menu: Adventure (2.5D) + legacy Survival prototype.

@onready var name_edit: LineEdit = %NameEdit
@onready var leaderboard_list: ItemList = %LeaderboardList
@onready var continue_button: Button = %ContinueButton
@onready var continue_summary: Label = %ContinueSummary
@onready var confirm_panel: Control = %ConfirmPanel
@onready var settings_panel: Control = %SettingsPanel
@onready var leaderboard_panel: Control = %LeaderboardPanel
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var ai_dialogue_check: CheckBox = %AIDialogueCheck
@onready var conversation_storage_check: CheckBox = %ConversationStorageCheck
@onready var memory_personalization_check: CheckBox = %MemoryPersonalizationCheck
@onready var start_button: Button = $Center/VBox/StartButton
@onready var survival_button: Button = $Center/VBox/SurvivalButton
@onready var combat_lab_button: Button = $Center/VBox/CombatLabButton
@onready var settings_button: Button = $Center/VBox/SettingsButton
@onready var quit_button: Button = $Center/VBox/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_open_world_theme()
	confirm_panel.visible = false
	settings_panel.visible = false
	leaderboard_panel.visible = false
	name_edit.text = GameManager.player_name
	_load_settings_widgets()
	_refresh_leaderboard()
	_refresh_continue()
	_apply_initial_focus()


func _apply_open_world_theme() -> void:
	_style_panel($MenuGlass, Color(0.025, 0.065, 0.07, 0.72), Color("8aa78d"), 18, 2)
	_style_panel($WorldStatus, Color(0.025, 0.06, 0.065, 0.74), Color("977b48"), 11, 1)
	for panel in [$WorldSignals/Explore, $WorldSignals/Build, $WorldSignals/Remember]:
		_style_panel(panel, Color(0.025, 0.06, 0.065, 0.7), Color("718c79"), 10, 1)
	_style_panel($ConfirmPanel/Card, Color(0.035, 0.075, 0.075, 0.97), Color("c8a95f"), 15, 2)
	_style_panel($SettingsPanel/Card, Color(0.035, 0.075, 0.075, 0.98), Color("c8a95f"), 15, 2)
	_style_panel($LeaderboardPanel/Card, Color(0.035, 0.075, 0.075, 0.98), Color("c8a95f"), 15, 2)

	_style_button(start_button, Color("d5b56c"), Color("f2d792"), Color("3a2b18"), true)
	_style_button(continue_button, Color("315c58"), Color("47756d"), Color("f3e5bc"), true)
	for button in [survival_button, combat_lab_button, settings_button, quit_button]:
		_style_button(button, Color(0.055, 0.105, 0.105, 0.92), Color("315651"), Color("d8dbc5"), false)
	_style_button($LeaderboardButton, Color(0.035, 0.075, 0.075, 0.9), Color("315651"), Color("d8dbc5"), false)
	_style_button($ConfirmPanel/Panel/ConfirmYes, Color("d5b56c"), Color("f2d792"), Color("3a2b18"), true)
	_style_button($ConfirmPanel/Panel/ConfirmNo, Color("315c58"), Color("47756d"), Color("f3e5bc"), false)
	_style_button($SettingsPanel/Panel/SettingsClose, Color("d5b56c"), Color("f2d792"), Color("3a2b18"), true)
	_style_button($LeaderboardPanel/Panel/LeaderboardClose, Color("315c58"), Color("47756d"), Color("f3e5bc"), false)

	var input_normal := StyleBoxFlat.new()
	input_normal.bg_color = Color(0.02, 0.045, 0.05, 0.92)
	input_normal.border_color = Color("6c8877")
	input_normal.set_border_width_all(1)
	input_normal.set_corner_radius_all(8)
	input_normal.content_margin_left = 14
	input_normal.content_margin_right = 14
	name_edit.add_theme_stylebox_override("normal", input_normal)
	var input_focus := input_normal.duplicate() as StyleBoxFlat
	input_focus.border_color = Color("d7ba70")
	input_focus.set_border_width_all(2)
	name_edit.add_theme_stylebox_override("focus", input_focus)
	name_edit.add_theme_color_override("font_color", Color("f0e6c8"))
	name_edit.add_theme_color_override("font_placeholder_color", Color("81968b"))
	name_edit.add_theme_font_size_override("font_size", 15)
	name_edit.custom_minimum_size.y = 42

	continue_summary.add_theme_color_override("font_color", Color("aebfb2"))
	continue_summary.add_theme_font_size_override("font_size", 12)
	$ConfirmPanel/Panel/ConfirmLabel.add_theme_color_override("font_color", Color("eee2bd"))
	$SettingsPanel/Panel/SettingsTitle.add_theme_color_override("font_color", Color("eed38b"))
	$SettingsPanel/Panel/SettingsTitle.add_theme_font_size_override("font_size", 28)
	$LeaderboardPanel/Panel/LeaderboardTitle.add_theme_color_override("font_color", Color("eed38b"))
	$LeaderboardPanel/Panel/LeaderboardTitle.add_theme_font_size_override("font_size", 28)
	for checkbox in [
		fullscreen_check, ai_dialogue_check,
		conversation_storage_check, memory_personalization_check,
	]:
		checkbox.add_theme_color_override("font_color", Color("d7dece"))


func _style_panel(
	panel: Control,
	background: Color,
	border: Color,
	radius: int,
	border_width: int,
) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)


func _style_button(
	button: Button,
	base_color: Color,
	hover_color: Color,
	font_color: Color,
	strong: bool,
) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = base_color
	normal.border_color = base_color.lightened(0.22)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.shadow_color = Color(0, 0, 0, 0.3)
	normal.shadow_size = 5 if strong else 2
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover_color
	hover.border_color = Color("f1d58d") if strong else Color("8ca794")
	hover.set_border_width_all(2)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = hover_color.darkened(0.14)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.08, 0.1, 0.1, 0.58)
	disabled.border_color = Color(0.23, 0.28, 0.27, 0.5)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	button.add_theme_color_override("font_disabled_color", Color("718079"))
	button.add_theme_font_size_override("font_size", 15 if strong else 14)
	button.custom_minimum_size.y = 46 if strong else 38
	button.focus_mode = Control.FOCUS_ALL


func _apply_initial_focus() -> void:
	if not continue_button.disabled:
		continue_button.grab_focus()
	else:
		start_button.grab_focus()


func _load_settings_widgets() -> void:
	master_slider.value = float(SaveService.settings.get("master_volume_db", 0.0))
	music_slider.value = float(SaveService.settings.get("music_volume_db", -6.0))
	sfx_slider.value = float(SaveService.settings.get("sfx_volume_db", -3.0))
	fullscreen_check.button_pressed = bool(SaveService.settings.get("fullscreen", true))
	ai_dialogue_check.button_pressed = bool(SaveService.settings.get("ai_dialogue_enabled", false))
	conversation_storage_check.button_pressed = bool(SaveService.settings.get("allow_conversation_storage", false))
	memory_personalization_check.button_pressed = bool(SaveService.settings.get("allow_memory_personalization", false))


func _on_continue_pressed() -> void:
	var adventure_summary := SaveSlotService.inspect_adventure_summary()
	if bool(adventure_summary.get("valid", false)):
		GameManager.continue_adventure()
	elif str(adventure_summary.get("reason", "missing")) == "missing":
		GameManager.continue_run()
	else:
		push_warning(
			"MainMenu: adventure continue rejected (%s)"
			% str(adventure_summary.get("reason", "invalid"))
		)


func _refresh_continue() -> void:
	var summary := SaveSlotService.inspect_adventure_summary()
	if bool(summary.get("valid", false)):
		continue_button.disabled = false
		continue_summary.text = "Continue adventure as %s\n%s · Day %d %02d:%02d" % [
			str(summary.get("player_name", "Traveler")),
			str(summary.get("region", "base:town")),
			int(summary.get("day", 1)),
			int(summary.get("hour", 8)),
			int(summary.get("minute", 0)),
		]
		if (
			bool(summary.get("used_player_backup", false))
			or bool(summary.get("used_manifest_backup", false))
		):
			continue_summary.text += "\nSave recovered from backup"
		return
	var adventure_reason := str(summary.get("reason", ""))
	if adventure_reason in [
		"future_version", "corrupt_manifest", "missing_player", "corrupt_player",
	]:
		continue_button.disabled = true
		continue_summary.text = _continue_unavailable_text(adventure_reason)
		return
	var run_summary := GameManager.inspect_resumable_run()
	continue_button.disabled = not run_summary.valid
	if run_summary.valid:
		var minutes := int(run_summary.survival_seconds) / 60
		var seconds := int(run_summary.survival_seconds) % 60
		continue_summary.text = "Continue survival as %s\nLevel %d · Score %s · %02d:%02d" % [
			run_summary.player_name,
			run_summary.combat_level,
			_format_int(run_summary.score),
			minutes,
			seconds,
		]
	else:
		continue_summary.text = _continue_unavailable_text(run_summary.reason)


func _continue_unavailable_text(reason: String) -> String:
	match reason:
		"future_version":
			return "Save created by a newer version"
		"corrupt_manifest":
			return "Adventure save is damaged"
		"missing_player":
			return "Player save is missing"
		"corrupt_player":
			return "Player save is damaged"
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


func _on_start_pressed() -> void:
	if GameManager.has_resumable_adventure() or GameManager.has_resumable_run():
		confirm_panel.visible = true
		return
	_begin_new_adventure()


func _on_survival_pressed() -> void:
	GameManager.start_new_run(name_edit.text)


func _on_combat_lab_pressed() -> void:
	GameManager.player_name = name_edit.text
	SceneRouter.go_to_combat_lab()


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
	_ensure_controls_section()


func _ensure_controls_section() -> void:
	var controls := settings_panel.get_node_or_null("Panel/SettingsColumns/InputRebindUI")
	if controls != null and controls.has_method("_rebuild"):
		controls.call("_rebuild")


func _on_settings_close() -> void:
	SaveService.settings["master_volume_db"] = master_slider.value
	SaveService.settings["music_volume_db"] = music_slider.value
	SaveService.settings["sfx_volume_db"] = sfx_slider.value
	SaveService.settings["fullscreen"] = fullscreen_check.button_pressed
	SaveService.settings["ai_dialogue_enabled"] = ai_dialogue_check.button_pressed
	SaveService.settings["allow_conversation_storage"] = conversation_storage_check.button_pressed
	SaveService.settings["allow_memory_personalization"] = memory_personalization_check.button_pressed
	SaveService.save_settings()
	settings_panel.visible = false


func _on_leaderboard_pressed() -> void:
	_refresh_leaderboard()
	leaderboard_panel.visible = true
	$LeaderboardPanel/Panel/LeaderboardClose.grab_focus()


func _on_leaderboard_close() -> void:
	leaderboard_panel.visible = false
	$LeaderboardButton.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _refresh_leaderboard() -> void:
	leaderboard_list.clear()
	var entries: Array = SaveService.load_leaderboard()
	if entries.is_empty():
		leaderboard_list.add_item("No completed survival runs yet")
		leaderboard_list.set_item_disabled(0, true)
		return
	for entry in entries:
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
