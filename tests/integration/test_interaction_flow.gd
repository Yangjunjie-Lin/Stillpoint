extends RefCounted


func run() -> bool:
	var ctx := InteractionContext.new()
	return ctx != null
