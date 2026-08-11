class_name DungeonDefinition
extends Resource
## Authored ontology for a dungeon embedded in the connected world.

@export var id: StringName = &"dungeon"
@export var display_name: String = "Dungeon"
@export var region_id: StringName = &"base:dungeon"
@export var parent_region_id: StringName = &"base:wilderness"
@export var entrance_location_id: StringName = &"location:dungeon_gate"
@export var guard_definition_id: StringName = &"dungeon_warden"
@export_range(1, 99, 1) var entry_level: int = 1
@export_range(1, 99, 1) var max_depth: int = 3
@export var floor_names: Array[String] = []
@export var boss_definition_ids: Array[StringName] = []
@export var lore_tags: Array[StringName] = []

func is_valid() -> bool:
	return (
		id != &""
		and display_name.strip_edges() != ""
		and region_id != &""
		and parent_region_id != &""
		and entry_level >= 1
		and max_depth >= 1
		and floor_names.size() == max_depth
	)

func to_catalog_dict() -> Dictionary:
	return {
		"id": String(id),
		"display_name": display_name,
		"region_id": String(region_id),
		"parent_region_id": String(parent_region_id),
		"entrance_location_id": String(entrance_location_id),
		"guard_definition_id": String(guard_definition_id),
		"entry_level": entry_level,
		"max_depth": max_depth,
		"floor_names": floor_names.duplicate(),
		"boss_definition_ids": boss_definition_ids.map(func(value: StringName) -> String: return String(value)),
		"lore_tags": lore_tags.map(func(value: StringName) -> String: return String(value)),
	}
