class_name LootEntryDefinition
extends Resource
## One authored weighted result in a dungeon loot table.

@export var item_id: StringName = &""
@export_range(0.01, 1000.0, 0.01) var weight: float = 1.0
@export_range(1, 99, 1) var minimum_player_level: int = 1
@export_range(1, 99, 1) var maximum_player_level: int = 99
@export_range(1, 99, 1) var minimum_quantity: int = 1
@export_range(1, 99, 1) var maximum_quantity: int = 1


func is_valid() -> bool:
	return (
		item_id != &""
		and weight > 0.0
		and minimum_player_level >= 1
		and maximum_player_level >= minimum_player_level
		and minimum_quantity >= 1
		and maximum_quantity >= minimum_quantity
	)


func is_eligible(player_level: int) -> bool:
	return is_valid() and player_level >= minimum_player_level \
		and player_level <= maximum_player_level
