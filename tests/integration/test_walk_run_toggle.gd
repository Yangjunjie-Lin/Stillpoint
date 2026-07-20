extends RefCounted


func run() -> bool:
	var state := CharacterState.new()
	state.is_running = false
	state.is_running = not state.is_running
	return state.is_running
