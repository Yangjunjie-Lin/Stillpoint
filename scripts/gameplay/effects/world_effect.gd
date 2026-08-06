class_name WorldEffect
extends Resource
## Applies a world change through explicit context.

@export var required_success: bool = false
## Optional author-defined identifier used to make retryable sequences idempotent.
## Empty IDs fall back to the effect's stable position within a named sequence.
@export var effect_id: StringName = &""


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


static func apply_sequence_once(
	effects: Array[WorldEffect],
	context: WorldEffectContext,
	applied_effect_ids: Dictionary,
	sequence_id: StringName,
) -> EffectResult:
	## Applies each successful effect at most once for this sequence. This permits a
	## required failure to be repaired and retried without replaying earlier rewards.
	for index in effects.size():
		var effect := effects[index]
		if effect == null:
			continue
		var stable_id := effect.get_stable_effect_id(sequence_id, index)
		var key := String(stable_id)
		if applied_effect_ids.has(key):
			continue
		var result := effect.apply(context)
		if result.success:
			applied_effect_ids[key] = true
			continue
		if effect.required_success:
			return result
	return EffectResult.ok()


func get_stable_effect_id(sequence_id: StringName, index: int) -> StringName:
	var local_id := String(effect_id)
	if local_id == "":
		local_id = "effect_%04d" % index
	return StringName("%s/%s" % [String(sequence_id), local_id])
