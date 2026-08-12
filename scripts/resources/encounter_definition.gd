class_name EncounterDefinition
extends Resource
## Server-authored hidden encounter. Trigger rules remain outside the public ontology.

enum TriggerKind {
	GAMEPLAY_EVENT,
	EXPLORATION_ZONE,
}

enum RepeatPolicy {
	ONCE_PER_SAVE,
	ONCE_PER_WORLD_DAY,
}

enum VisibilityPolicy {
	WITNESSED,
	PLAYER_PRIVATE,
}

@export var id: StringName = &""
@export var display_name: String = "Encounter"
@export_multiline var discovery_text: String = "Something unusual has happened."
@export var trigger_kind: TriggerKind = TriggerKind.GAMEPLAY_EVENT
@export var repeat_policy: RepeatPolicy = RepeatPolicy.ONCE_PER_SAVE
@export var visibility_policy: VisibilityPolicy = VisibilityPolicy.WITNESSED
@export var conditions: Array[WorldCondition] = []
@export var reward_effects: Array[WorldEffect] = []
@export var participant_node_ids: Array[StringName] = []
@export var public_location_node_id: StringName = &""
@export var public_reward_category_ids: Array[StringName] = []
@export var lore_tags: Array[StringName] = []
@export_range(0, 99, 1) var minimum_level_hint: int = 0
@export_range(0.0, 1.0, 0.01) var trigger_chance: float = 1.0
@export var hidden_salt: StringName = &""


func is_valid() -> bool:
	return (
		id != &""
		and not display_name.strip_edges().is_empty()
		and not discovery_text.strip_edges().is_empty()
		and trigger_chance >= 0.0
		and trigger_chance <= 1.0
		and not reward_effects.is_empty()
	)


func public_catalog_dict() -> Dictionary:
	return {
		"id": String(id),
		"node_id": "encounter:%s" % String(id),
		"display_name": display_name,
		"trigger_kind": TriggerKind.keys()[trigger_kind].to_snake_case(),
		"repeat_policy": RepeatPolicy.keys()[repeat_policy].to_snake_case(),
		"visibility_policy": VisibilityPolicy.keys()[visibility_policy].to_snake_case(),
		"participant_node_ids": _strings(participant_node_ids),
		"public_location_node_id": String(public_location_node_id),
		"public_reward_category_ids": _strings(public_reward_category_ids),
		"lore_tags": _strings(lore_tags),
		"minimum_level_hint": minimum_level_hint,
	}


func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
