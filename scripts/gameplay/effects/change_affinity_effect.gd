class_name ChangeAffinityEffect
extends WorldEffect

@export var npc_id: StringName = &""
@export var delta: float = 0.0
@export var reason: StringName = &"effect"


func apply(_context: WorldEffectContext) -> EffectResult:
	if npc_id == &"":
		return EffectResult.failure("empty npc")
	RelationshipService.change_affinity(npc_id, delta, reason)
	return EffectResult.success()
