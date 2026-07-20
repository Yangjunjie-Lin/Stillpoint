class_name ObjectiveDefinition
extends Resource

enum ObjectiveType {
	TALK,
	VISIT,
	COLLECT,
	DELIVER,
	INTERACT,
	DEFEAT,
	PROTECT,
	FOLLOW,
	DISCOVER,
	RELATIONSHIP,
	CUSTOM,
}

@export var id: StringName = &"objective"
@export var display_text: String = ""
@export var objective_type: ObjectiveType = ObjectiveType.TALK
@export var target_id: StringName = &""
@export var required_count: int = 1
@export var region_id: StringName = &""
