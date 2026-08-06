extends RefCounted


func run() -> bool:
	var identity := WorldEntityIdentity.new()
	var ok := not identity.is_valid()
	identity.free()
	return ok
