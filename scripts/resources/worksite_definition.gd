class_name WorkSiteDefinition
extends Resource
## Immutable authored workplace definition. Money belongs to its business.

@export var id: StringName = &"worksite"
@export var display_name: String = "Worksite"
@export var worksite_type: StringName = &"workplace"
@export var region_id: StringName = &"base:town"
@export var allowed_job_ids: Array[StringName] = []
@export var work_marker_id: StringName = &"work"
@export_range(1, 1000, 1) var capacity: int = 1
@export_range(0.1, 10.0, 0.05) var workplace_efficiency: float = 1.0
@export var business_id: StringName = &""


func is_valid() -> bool:
	return id != &"" and worksite_type != &"" and region_id != &"" \
		and work_marker_id != &"" and business_id != &"" and capacity > 0
