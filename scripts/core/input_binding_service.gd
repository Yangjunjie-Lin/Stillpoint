extends Node
## Rebindable InputMap actions persisted to user://input_bindings.json

const BINDINGS_PATH := "user://input_bindings.json"

const DEFAULT_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_backward", &"move_left", &"move_right",
	&"interact", &"toggle_walk_run", &"normal_attack", &"jump", &"guard", &"crouch",
	&"hotbar_previous", &"hotbar_next",
	&"action_u", &"action_i", &"action_o", &"action_l",
	&"pause", &"open_menu", &"open_map",
]

var _defaults: Dictionary = {}


func _ready() -> void:
	_capture_defaults()
	load_bindings()


func get_action_events(action: StringName) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if event is InputEvent:
			events.append(event as InputEvent)
	return events


func rebind_action(action: StringName, event: InputEvent) -> bool:
	if not InputMap.has_action(action):
		push_warning("InputBindingService: unknown action %s" % String(action))
		return false
	if event == null:
		return false
	InputMap.action_erase_events(action)
	var copy: InputEvent = event.duplicate()
	copy.device = -1
	InputMap.action_add_event(action, copy)
	return true


func reset_action(action: StringName) -> void:
	if not _defaults.has(action):
		return
	InputMap.action_erase_events(action)
	for event in _defaults[action] as Array:
		InputMap.action_add_event(action, event.duplicate())


func reset_all() -> void:
	for action in DEFAULT_ACTIONS:
		reset_action(action)


func save_bindings() -> bool:
	var payload: Dictionary = {"version": 1, "bindings": {}}
	for action in DEFAULT_ACTIONS:
		var entries: Array = []
		for event in get_action_events(action):
			entries.append(_serialize_event(event))
		payload["bindings"][String(action)] = entries
	var file := FileAccess.open(BINDINGS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	return true


func load_bindings() -> void:
	if not FileAccess.file_exists(BINDINGS_PATH):
		return
	var file := FileAccess.open(BINDINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var bindings: Dictionary = parsed.get("bindings", {})
	for action_key in bindings.keys():
		var action := StringName(str(action_key))
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for entry in bindings[action_key]:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var event := _deserialize_event(entry)
			if event != null:
				InputMap.action_add_event(action, event)


func get_display_text(action: StringName) -> String:
	var events := get_action_events(action)
	if events.is_empty():
		return "?"
	var event := events[0]
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return OS.get_keycode_string(key_event.physical_keycode)
	if event is InputEventMouseButton:
		var btn := event as InputEventMouseButton
		return "Mouse %d" % btn.button_index
	return event.as_text()


func _capture_defaults() -> void:
	for action in DEFAULT_ACTIONS:
		var events: Array = []
		for event in InputMap.action_get_events(action):
			events.append(event.duplicate())
		_defaults[action] = events


func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return {"type": "key", "physical_keycode": key_event.physical_keycode}
	if event is InputEventMouseButton:
		var btn := event as InputEventMouseButton
		return {"type": "mouse", "button_index": btn.button_index}
	return {}


func _deserialize_event(data: Dictionary) -> InputEvent:
	match str(data.get("type", "")):
		"key":
			var event := InputEventKey.new()
			event.physical_keycode = int(data.get("physical_keycode", 0))
			event.device = -1
			return event
		"mouse":
			var event := InputEventMouseButton.new()
			event.button_index = int(data.get("button_index", 1))
			event.device = -1
			return event
		_:
			return null
