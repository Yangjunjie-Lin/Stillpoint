extends RefCounted


func run() -> bool:
	var result: Interactable = InteractionResolver.find_best(null, [])
	return result == null
