class_name ItemDefinition
extends Resource

enum ItemType {
	CONSUMABLE,
	TOOL,
	WEAPON,
	MATERIAL,
	QUEST,
	GIFT,
	FOOD,
	PET_ITEM,
	MOUNT_ITEM,
	FURNITURE,
	KEY_ITEM,
	MISC,
}

enum EquipSlot {
	NONE,
	WEAPON,
	ARMOR,
	CHARM,
}

enum UseKind {
	NONE,
	CONSUME,
	TOOL_ACTION,
}

@export var id: StringName = &"item"
@export var display_name: String = "Item"
@export var item_type: ItemType = ItemType.MISC
@export var max_stack: int = 99
@export var description: String = ""
@export var icon: Texture2D
@export_group("RPG Inventory")
@export var equip_slot: EquipSlot = EquipSlot.NONE
@export var use_kind: UseKind = UseKind.NONE
@export var health_restore: float = 0.0
@export var energy_restore: float = 0.0
@export var tool_attack_id: StringName = &""
@export var attack_bonus: float = 0.0
@export var defense_bonus: float = 0.0
@export var energy_regen_bonus: float = 0.0
@export_range(0, 100, 1) var starter_balance_value: int = 0
@export_group("Legacy Survival Prototype")
@export var effect_kind: StringName = &"shield"
@export var duration: float = 8.0
@export var color: Color = Color(0.25, 0.9, 0.42)
@export var texture: Texture2D
@export var scene: PackedScene
@export var spawn_weight: float = 1.0
@export var minimum_level: int = 1
@export var score_bonus: int = 10
