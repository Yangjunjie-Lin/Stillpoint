extends RefCounted


func run() -> bool:
	var before := InputBindingService.get_display_text(&"interact")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_H
	InputBindingService.rebind_action(&"interact", event)
	var after := InputBindingService.get_display_text(&"interact")
	var ok := after != before or after == "H"
	InputBindingService.reset_action(&"interact")
	InputBindingService.save_bindings()
	return ok and InputMap.has_action(&"jump")
