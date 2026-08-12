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
	HEAD,
	LEGS,
	FEET,
	HANDS,
	WRISTS,
	RING_LEFT,
	RING_RIGHT,
	BELT,
	DECOR_HEAD,
	DECOR_BODY,
	DECOR_HANDS,
	DECOR_FEET,
	DECOR_ORNAMENT,
}

enum EquipmentClass {
	ATTRIBUTE,
	DECORATIVE,
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
@export var alternate_equip_slots: Array[EquipSlot] = []
@export var equipment_class: EquipmentClass = EquipmentClass.ATTRIBUTE
@export var use_kind: UseKind = UseKind.NONE
@export var health_restore: float = 0.0
@export var energy_restore: float = 0.0
@export var tool_attack_id: StringName = &""
@export var utility_actions: Array[StringName] = []
@export var attack_bonus: float = 0.0
@export var defense_bonus: float = 0.0
@export var energy_regen_bonus: float = 0.0
@export var max_health_bonus: float = 0.0
@export var max_energy_bonus: float = 0.0
@export var move_speed_bonus: float = 0.0
@export var charisma_bonus: float = 0.0
@export_range(0.0, 100.0, 0.1) var equipment_weight: float = 0.0
@export_range(0, 100, 1) var required_strength: int = 0
@export_range(0, 100, 1) var required_vitality: int = 0
@export var rarity: StringName = &"common"
@export_range(0, 100, 1) var starter_balance_value: int = 0
@export_group("Skill Book")
@export var teaches_skill_id: StringName = &""
@export_range(0.0, 100.0, 0.5) var proficiency_points: float = 0.0
@export_group("World Appearance")
@export var visual_archetype: StringName = &""
@export var hand_form: StringName = &""
@export_range(1, 2, 1) var grip_hands: int = 1
@export var can_be_off_hand: bool = true
@export var visual_primary_color: Color = Color("8a7455")
@export var visual_secondary_color: Color = Color("d8d2c4")
@export_group("Legacy Survival Prototype")
@export var effect_kind: StringName = &"shield"
@export var duration: float = 8.0
@export var color: Color = Color(0.25, 0.9, 0.42)
@export var texture: Texture2D
@export var scene: PackedScene
@export var spawn_weight: float = 1.0
@export var minimum_level: int = 1
@export var score_bonus: int = 10


func is_combat_tool() -> bool:
	return (
		item_type == ItemType.TOOL
		and use_kind == UseKind.TOOL_ACTION
		and tool_attack_id != &""
	)


func is_equippable() -> bool:
	return equip_slot != EquipSlot.NONE


func supports_equip_slot(slot: int) -> bool:
	return slot == int(equip_slot) or slot in alternate_equip_slots


func is_decorative_equipment() -> bool:
	return is_equippable() and equipment_class == EquipmentClass.DECORATIVE


func is_attribute_equipment() -> bool:
	return is_equippable() and equipment_class == EquipmentClass.ATTRIBUTE


func resolved_hand_form() -> StringName:
	if hand_form != &"":
		return hand_form
	if item_type == ItemType.WEAPON or item_type == ItemType.TOOL:
		return resolved_visual_archetype()
	return &""


func can_hold_in_off_hand() -> bool:
	return can_be_off_hand and grip_hands == 1 and resolved_hand_form() != &""


func is_skill_book() -> bool:
	return (
		use_kind == UseKind.CONSUME
		and teaches_skill_id != &""
		and proficiency_points > 0.0
	)


func supports_utility_action(action_id: StringName) -> bool:
	return action_id != &"" and utility_actions.has(action_id)


func resolved_visual_archetype() -> StringName:
	if visual_archetype != &"":
		return visual_archetype
	match effect_kind:
		&"shield":
			return &"shield_emblem"
		&"speed":
			return &"speed_boot"
		&"double":
			return &"double_arrow"
		&"large":
			return &"large_orb"
		&"pierce":
			return &"piercing_arrow"
		&"points":
			return &"score_token"
	match item_type:
		ItemType.WEAPON:
			return &"one_hand_sword"
		ItemType.TOOL:
			return &"field_pick"
		ItemType.MATERIAL:
			return &"herb_bundle"
		ItemType.FOOD, ItemType.CONSUMABLE:
			return &"travel_ration"
		ItemType.GIFT, ItemType.QUEST:
			return &"gift_box"
	return &"generic_trinket"
