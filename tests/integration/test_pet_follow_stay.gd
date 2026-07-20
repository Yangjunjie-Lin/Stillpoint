extends RefCounted


func run() -> bool:
	var pet := PetController.new()
	pet.mode = PetController.Mode.FOLLOW
	pet.toggle_mode()
	return pet.mode == PetController.Mode.STAY
