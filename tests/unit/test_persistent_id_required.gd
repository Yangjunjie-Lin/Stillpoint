extends RefCounted


func run() -> bool:
	var identity := WorldEntityIdentity.new()
	return not identity.is_valid()
