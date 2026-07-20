class_name CharacterState
extends RefCounted

enum State {
	IDLE,
	WALK,
	RUN,
	CROUCH,
	JUMP,
	FALL,
	ATTACK,
	GUARD,
	INTERACT,
	MOUNTED,
	DOWNED,
	DISABLED,
}

var current: State = State.IDLE
var is_running: bool = false
var is_crouching: bool = false
var input_enabled: bool = true


func can_move() -> bool:
	return input_enabled and current not in [State.ATTACK, State.INTERACT, State.MOUNTED, State.DISABLED, State.DOWNED]


func can_attack() -> bool:
	return input_enabled and current not in [State.INTERACT, State.MOUNTED, State.DISABLED, State.DOWNED]
