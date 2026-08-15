class_name PetBehaviorAnchor3D
extends Marker3D
## Program-owned semantic waypoint for companion movement. LLM assessments may
## weight these tags, but can never create anchors or supply world coordinates.

@export var anchor_id: StringName = &"pet_anchor"
@export var behavior_tags: Array[StringName] = [&"explore"]
@export_range(0.0, 1.0, 0.01) var hazard: float = 0.0
@export var enabled: bool = true


func _ready() -> void:
	add_to_group("pet_behavior_anchors")


func to_motion_candidate(region_id: StringName) -> Dictionary:
	return {
		"id": String(anchor_id),
		"position": global_position,
		"tags": behavior_tags.duplicate(),
		"region_id": String(region_id),
		"reachable": enabled,
		"hazard": clampf(hazard, 0.0, 1.0),
	}
