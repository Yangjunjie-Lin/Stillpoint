class_name RelationshipCondition
extends WorldCondition

@export var npc_id: StringName = &""
@export var min_affinity: float = -100.0
@export var max_affinity: float = 100.0


func evaluate(_context: WorldSessionContext) -> bool:
	if npc_id == &"":
		return false
	var affinity := RelationshipService.get_affinity(npc_id)
	return affinity >= min_affinity and affinity <= max_affinity
