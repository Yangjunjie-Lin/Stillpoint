extends RefCounted


func run() -> bool:
	var ragdoll := RagdollController.new()
	var body := CharacterController.new()
	body.add_child(ragdoll)
	var ok := not ragdoll.is_active()
	ragdoll.activate_ragdoll(Vector3.UP)
	ok = ok and (not ragdoll.is_available() or ragdoll.is_active())
	body.free()
	return ok
