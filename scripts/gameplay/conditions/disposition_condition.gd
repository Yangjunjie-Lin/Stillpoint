class_name DispositionCondition
extends WorldCondition

@export var npc_id: StringName = &""
@export var required_disposition: RelationshipComponent.Disposition = RelationshipComponent.Disposition.NEUTRAL


func evaluate(_context: WorldSessionContext) -> bool:
	if npc_id == &"":
		return false
	return RelationshipService.get_disposition(npc_id) == required_disposition
