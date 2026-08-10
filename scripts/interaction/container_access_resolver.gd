class_name ContainerAccessResolver
extends RefCounted
## Resolves authored container access without consuming tools or using weapon damage.

const METHOD_NONE: StringName = &"none"
const METHOD_FORCE: StringName = &"force"
const METHOD_TOOL: StringName = &"tool"


static func evaluate(
	player: PlayerController3D,
	definition: ContainerDefinition,
) -> Dictionary:
	var result := {
		"method": METHOD_NONE,
		"strength": 0,
		"required_strength": 0,
		"tool": null,
	}
	if player == null or definition == null or not definition.is_valid():
		return result
	var strength := player.get_physical_strength()
	result["strength"] = strength
	result["required_strength"] = definition.force_open_strength
	var selected_tool := player.get_selected_item_definition()
	if (
		selected_tool != null
		and selected_tool.supports_utility_action(
			definition.required_utility_action
		)
	):
		result["method"] = METHOD_TOOL
		result["tool"] = selected_tool
		return result
	if strength >= definition.force_open_strength:
		result["method"] = METHOD_FORCE
	return result


static func interaction_text(
	player: PlayerController3D,
	definition: ContainerDefinition,
) -> String:
	if definition == null:
		return "Container unavailable"
	var access := evaluate(player, definition)
	match StringName(access.get("method", METHOD_NONE)):
		METHOD_TOOL:
			var tool := access.get("tool") as ItemDefinition
			return "Open %s with %s" % [
				definition.display_name,
				tool.display_name if tool != null else "tool",
			]
		METHOD_FORCE:
			return "Force open %s (Strength %d/%d)" % [
				definition.display_name,
				int(access.get("strength", 0)),
				definition.force_open_strength,
			]
		_:
			return "Requires Strength %d or a %s" % [
				definition.force_open_strength,
				_utility_tool_label(definition.required_utility_action),
			]


static func blocked_notice(definition: ContainerDefinition, strength: int) -> String:
	if definition == null:
		return "This container cannot be opened."
	return "%s needs Strength %d (current %d) or a selected %s." % [
		definition.display_name,
		definition.force_open_strength,
		strength,
		_utility_tool_label(definition.required_utility_action),
	]


static func _utility_tool_label(action_id: StringName) -> String:
	match action_id:
		&"pry_open":
			return "prying tool"
		&"till_soil":
			return "soil-working tool"
		_:
			return "%s tool" % String(action_id).replace("_", " ")
