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

var _choices: Array = []
var _active: bool = false
var _requesting: bool = false
var _showing_ai_reply: bool = false


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
	_active = true
	visible = true
	speaker_label.text = speaker
	body_label.text = text
	_clear_choices()
	continue_hint.visible = true
	continue_hint.text = "..."
	_showing_ai_reply = false


func _on_choices(choices: Array) -> void:
	_active = true
	visible = true
	_choices = choices
	_clear_choices()
	continue_hint.visible = false
	for i in choices.size():
		var choice: DialogueChoice = choices[i] as DialogueChoice
		if choice == null:
			continue
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, choice.text]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var index := i
		button.pressed.connect(func() -> void: _select(index))
		choices_container.add_child(button)
	var world := get_tree().get_first_node_in_group("world_manager") as WorldSession
	if world != null and world.cognition_service != null \
		and world.cognition_service.can_use_free_form(world.dialogue_coordinator.get_active_npc()):
		var ask_button := Button.new()
		ask_button.text = "Ask something else..."
		ask_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ask_button.pressed.connect(_show_free_form)
		choices_container.add_child(ask_button)
		if choices.is_empty():
			var leave_button := Button.new()
			leave_button.text = "Leave"
			leave_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	free_form_input.clear()
	free_form_container.visible = true
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
	request_status.text = "Thinking..."
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
	_active = true
	visible = true
	_requesting = false
	_showing_ai_reply = true
	speaker_label.text = speaker
	body_label.text = text
	_clear_choices()
	_reset_free_form_editor()
	continue_hint.visible = true
	continue_hint.text = "Esc to close"


func _reset_free_form_editor() -> void:
	free_form_input.clear()
	free_form_container.visible = false
	free_form_submit.disabled = false
	free_form_input.editable = true
	request_status.text = ""
