class_name WorldCondition
extends Resource
## Base condition evaluated against world context without side effects.

func evaluate(_context: WorldSessionContext) -> bool:
	return true
