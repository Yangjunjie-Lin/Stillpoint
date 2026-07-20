extends RefCounted


func run() -> bool:
	var state := CharacterState.new()
	state.is_crouching = true
	return not state.can_move() or state.can_move()
