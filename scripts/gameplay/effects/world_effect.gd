class_name WorldEffect
extends Resource
## Applies a world change through explicit context.

@export var required_success: bool = false


func apply(_context: WorldEffectContext) -> EffectResult:
	return EffectResult.ok()


static func apply_sequence(
	effects: Array[WorldEffect],
	context: WorldEffectContext,
) -> EffectResult:
	for effect in effects:
		if effect == null:
			continue
		var result := effect.apply(context)
		if effect.required_success and not result.success:
			return result
	return EffectResult.ok()
