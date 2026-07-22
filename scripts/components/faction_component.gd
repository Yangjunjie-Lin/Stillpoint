class_name FactionComponent
extends Node

@export var faction_id: StringName = &"neutral"
@export var reputation_override: float = NAN


func get_reputation() -> float:
	if is_finite(reputation_override):
		return reputation_override
	var def := ResourceRegistry.get_faction(faction_id)
	if def == null:
		return 0.0
	return def.default_player_reputation


func to_dict() -> Dictionary:
	return {
		"faction_id": String(faction_id),
		"reputation_override": reputation_override if is_finite(reputation_override) else null,
	}


func from_dict(data: Dictionary) -> void:
	faction_id = StringName(str(data.get("faction_id", faction_id)))
	var override_value: Variant = data.get("reputation_override", null)
	if override_value == null or typeof(override_value) not in [TYPE_INT, TYPE_FLOAT]:
		reputation_override = NAN
	else:
		reputation_override = float(override_value)
