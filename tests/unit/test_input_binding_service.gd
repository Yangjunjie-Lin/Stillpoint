extends RefCounted


func run() -> bool:
	for action in InputBindingService.DEFAULT_ACTIONS:
		if not InputMap.has_action(action):
			push_error("Missing action: %s" % String(action))
			return false
	var before := InputBindingService.get_display_text(&"interact")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_G
	if not InputBindingService.rebind_action(&"interact", event):
		return false
	var after := InputBindingService.get_display_text(&"interact")
	InputBindingService.reset_action(&"interact")
	return before != after or InputBindingService.save_bindings()
