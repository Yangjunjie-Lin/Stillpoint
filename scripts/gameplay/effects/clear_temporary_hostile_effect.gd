class_name ClearTemporaryHostileEffect
extends WorldEffect

@export var npc_id: StringName = &""


func apply(_context: WorldEffectContext) -> EffectResult:
	if npc_id == &"":
		return EffectResult.fail("empty npc")
	RelationshipService.set_temporary_hostile(npc_id, false)
	return EffectResult.ok()
