extends RefCounted


func run() -> bool:
	var dir := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	return dir.length() <= 1.01
