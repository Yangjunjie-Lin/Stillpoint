extends Control
## Keyboard rebind panel for InputBindingService.

@onready var rows: VBoxContainer = %ActionRows
@onready var status_label: Label = %StatusLabel

var _listening_action: StringName = &""
var _actions: Array[StringName] = [
	&"move_forward", &"move_backward", &"move_left", &"move_right",
	&"interact", &"toggle_walk_run", &"normal_attack", &"jump", &"guard", &"crouch",
	&"hotbar_previous", &"hotbar_next", &"pause", &"open_menu", &"open_map",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if _listening_action == &"":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			_listening_action = &""
			status_label.text = "Cancelled"
			_rebuild()
			get_viewport().set_input_as_handled()
			return
		_apply_rebind(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		_apply_rebind(event)
		get_viewport().set_input_as_handled()


func _apply_rebind(event: InputEvent) -> void:
	var conflict := _find_conflict(_listening_action, event)
	if conflict != &"":
		status_label.text = "Conflict with %s — swapped" % String(conflict)
		var existing := InputBindingService.get_action_events(_listening_action)
		InputBindingService.rebind_action(conflict, existing[0] if not existing.is_empty() else event)
	InputBindingService.rebind_action(_listening_action, event)
	InputBindingService.save_bindings()
	_listening_action = &""
	status_label.text = "Saved"
	_rebuild()


func _find_conflict(action: StringName, event: InputEvent) -> StringName:
	for other in _actions:
		if other == action:
			continue
		for existing in InputBindingService.get_action_events(other):
			if existing.as_text() == event.as_text():
				return other
	return &""


func _rebuild() -> void:
	for child in rows.get_children():
		child.queue_free()
	for action in _actions:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = String(action)
		name_label.custom_minimum_size = Vector2(180, 0)
		var bind_label := Label.new()
		bind_label.text = InputBindingService.get_display_text(action)
		bind_label.custom_minimum_size = Vector2(100, 0)
		var button := Button.new()
		button.text = "Rebind"
		var captured := action
		button.pressed.connect(func() -> void:
			_listening_action = captured
			status_label.text = "Press a key for %s (Esc cancel)" % String(captured)
		)
		row.add_child(name_label)
		row.add_child(bind_label)
		row.add_child(button)
		rows.add_child(row)


func _on_reset_all() -> void:
	InputBindingService.reset_all()
	InputBindingService.save_bindings()
	status_label.text = "Reset all"
	_rebuild()


func _on_close() -> void:
	visible = false
