class_name SetTemporaryHostileEffect
extends WorldEffect

@export var npc_id: StringName = &""


func apply(_context: WorldEffectContext) -> EffectResult:
	if npc_id == &"":
		return EffectResult.failure("empty npc")
	RelationshipService.set_temporary_hostile(npc_id, true)
	return EffectResult.success()
