class_name JobDefinition
extends Resource
## Immutable authored economic role. Runtime employment belongs to actors.

@export var id: StringName = &"job"
@export var display_name: String = "Job"
@export_multiline var description: String = ""
@export var work_skill_id: StringName = &""
@export var preferred_attribute_ids: Array[StringName] = []
@export var required_work_tags: Array[StringName] = []
@export var optional_tool_tags: Array[StringName] = []
@export var worksite_types: Array[StringName] = []
@export_range(0, 1000000, 1) var base_wage: int = 0
@export_range(1.0, 86400.0, 1.0) var shift_duration: float = 60.0
@export_range(0.0, 1000.0, 0.5) var energy_cost: float = 0.0
@export_range(0.0, 100000.0, 0.1) var base_output: float = 1.0
@export var work_action_id: StringName = &"work"
@export_range(0, 23, 1) var shift_start_hour: int = 8
@export_range(0, 23, 1) var shift_end_hour: int = 18


func is_valid() -> bool:
	return id != &"" and work_skill_id != &"" and not worksite_types.is_empty() and base_wage >= 0 and base_output > 0.0
