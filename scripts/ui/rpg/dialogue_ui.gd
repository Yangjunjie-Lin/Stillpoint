class_name DialogueUI
extends Control
## Choice-capable dialogue panel driven by EventBus / DialogueRunner.

signal choice_selected(index: int)

@onready var speaker_label: Label = %SpeakerLabel
@onready var body_label: Label = %BodyLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var continue_hint: Label = %ContinueHint
@onready var free_form_container: VBoxContainer = %FreeFormContainer
@onready var free_form_input: LineEdit = %FreeFormInput
@onready var free_form_submit: Button = %FreeFormSubmit
@onready var free_form_cancel: Button = %FreeFormCancel
@onready var request_status: Label = %RequestStatus
@onready var dialogue_mode: Label = %DialogueMode
@onready var response_heading: Label = %ResponseHeading

var _choices: Array = []
var _active: bool = false
var _requesting: bool = false
var _showing_ai_reply: bool = false

const STANDARD_PANEL_TOP := -474.0
const DENSE_PANEL_TOP := -540.0


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.dialogue_line.connect(_on_line)
	EventBus.dialogue_choices.connect(_on_choices)
	EventBus.dialogue_finished.connect(_on_finished)
	EventBus.ai_dialogue_reply.connect(_on_ai_dialogue_reply)
	free_form_submit.pressed.connect(_submit_free_form)
	free_form_cancel.pressed.connect(_cancel_free_form)
	free_form_input.text_submitted.connect(func(_text: String) -> void: _submit_free_form())
	free_form_input.max_length = 4000
	free_form_container.visible = false
	_apply_theme()


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if free_form_container.visible or _requesting:
			_cancel_free_form()
		elif _showing_ai_reply:
			_on_finished()
		else:
			_close_dialogue()
		get_viewport().set_input_as_handled()
		return
	for i in mini(_choices.size(), 9):
		if event is InputEventKey and event.pressed and not event.echo:
			var key_event := event as InputEventKey
			if key_event.keycode == KEY_1 + i or key_event.physical_keycode == KEY_1 + i:
				_select(i)
				get_viewport().set_input_as_handled()
				return


func _on_line(speaker: String, text: String) -> void:
	offset_top = STANDARD_PANEL_TOP
	_active = true
	visible = true
	speaker_label.text = speaker
	body_label.text = text
	_clear_choices()
	continue_hint.visible = true
	continue_hint.text = "Waiting for a response or next line"
	dialogue_mode.text = "AUTHORED DIALOGUE"
	response_heading.text = "YOUR RESPONSE"
	_showing_ai_reply = false


func _on_choices(choices: Array) -> void:
	_active = true
	visible = true
	_choices = choices
	_clear_choices()
	continue_hint.visible = false
	var world := get_tree().get_first_node_in_group("world_manager") as WorldSession
	var can_ask_freely := world != null and world.cognition_service != null \
		and world.cognition_service.can_use_free_form(world.dialogue_coordinator.get_active_npc())
	var response_count := choices.size() + (1 if can_ask_freely else 0)
	var compact := response_count >= 4
	offset_top = DENSE_PANEL_TOP if response_count >= 5 else STANDARD_PANEL_TOP
	for i in choices.size():
		var choice: DialogueChoice = choices[i] as DialogueChoice
		if choice == null:
			continue
		var button := Button.new()
		button.text = "[%d]   %s" % [i + 1, choice.text]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_choice_button(button, false, compact)
		var index := i
		button.pressed.connect(func() -> void: _select(index))
		choices_container.add_child(button)
	if can_ask_freely:
		var ask_button := Button.new()
		ask_button.text = "Ask something else..."
		ask_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_choice_button(ask_button, true, compact)
		ask_button.pressed.connect(_show_free_form)
		choices_container.add_child(ask_button)
		if choices.is_empty():
			var leave_button := Button.new()
			leave_button.text = "Leave"
			leave_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			_style_choice_button(leave_button, false)
			leave_button.pressed.connect(_close_dialogue)
			choices_container.add_child(leave_button)


func _on_finished() -> void:
	_active = false
	visible = false
	_clear_choices()
	_choices.clear()
	_reset_free_form_editor()
	_requesting = false
	_showing_ai_reply = false


func _select(index: int) -> void:
	choice_selected.emit(index)
	var world := get_tree().get_first_node_in_group("world_manager") as WorldSession
	if world != null:
		world.apply_dialogue_choice(index)


func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()


func _show_free_form() -> void:
	offset_top = STANDARD_PANEL_TOP
	free_form_input.clear()
	free_form_container.visible = true
	choices_container.visible = false
	response_heading.text = "AUTONOMOUS DIALOGUE"
	dialogue_mode.text = "FREE-FORM  /  AI"
	request_status.text = ""
	free_form_submit.disabled = false
	free_form_input.editable = true
	free_form_input.grab_focus()


func _submit_free_form() -> void:
	if _requesting:
		return
	var text := free_form_input.text.strip_edges()
	if text.is_empty():
		request_status.text = "Enter a question."
		return
	_requesting = true
	free_form_submit.disabled = true
	free_form_input.editable = false
	request_status.text = "Listening and considering your words..."
	var world := get_tree().get_first_node_in_group("world_manager") as WorldSession
	if world != null and world.ask_active_npc(text):
		free_form_input.clear()
	elif not _showing_ai_reply:
		_requesting = false
		free_form_submit.disabled = false
		free_form_input.editable = true
		request_status.text = "AI dialogue unavailable; use a dialogue choice."


func _cancel_free_form() -> void:
	var world := get_tree().get_first_node_in_group("world_manager") as WorldSession
	if _requesting and world != null:
		world.cancel_free_form_dialogue()
	_requesting = false
	_reset_free_form_editor()


func _close_dialogue() -> void:
	var world := get_tree().get_first_node_in_group("world_manager") as WorldSession
	if world != null:
		world.cancel_active_dialogue()
	else:
		_on_finished()


func _on_ai_dialogue_reply(speaker: String, text: String) -> void:
	offset_top = STANDARD_PANEL_TOP
	_active = true
	visible = true
	_requesting = false
	_showing_ai_reply = true
	speaker_label.text = speaker
	body_label.text = text
	dialogue_mode.text = "AUTONOMOUS REPLY"
	response_heading.text = "CONVERSATION COMPLETE"
	_clear_choices()
	_reset_free_form_editor()
	continue_hint.visible = true
	continue_hint.text = "Esc  Close conversation"


func _reset_free_form_editor() -> void:
	free_form_input.clear()
	free_form_container.visible = false
	choices_container.visible = true
	free_form_submit.disabled = false
	free_form_input.editable = true
	request_status.text = ""


func _apply_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("101c22")
	panel_style.border_color = Color("376666")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.shadow_color = Color(0, 0, 0, 0.78)
	panel_style.shadow_size = 16
	add_theme_stylebox_override("panel", panel_style)
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color("0b171c")
	input_style.border_color = Color("34575b")
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(5)
	input_style.content_margin_left = 13
	input_style.content_margin_right = 13
	free_form_input.add_theme_stylebox_override("normal", input_style)
	var focus_style := input_style.duplicate() as StyleBoxFlat
	focus_style.border_color = Color("58c9b6")
	focus_style.set_border_width_all(2)
	free_form_input.add_theme_stylebox_override("focus", focus_style)
	free_form_input.add_theme_color_override("font_color", Color("e1e6dc"))
	free_form_input.add_theme_color_override("font_placeholder_color", Color("6f8586"))
	for button in [free_form_submit, free_form_cancel]:
		_style_choice_button(button, button == free_form_submit)


func _style_choice_button(button: Button, accent: bool, compact: bool = false) -> void:
	button.custom_minimum_size.y = 30 if compact else 38
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13 if compact else 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("23494b") if accent else Color("14292f")
	normal.border_color = Color("54c5b2") if accent else Color("304f54")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("2e5a5b")
	hover.border_color = Color("6fd6c2")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color("e9d8aa") if accent else Color("d0dad3"))
	button.add_theme_color_override("font_hover_color", Color("f3e2b4"))
