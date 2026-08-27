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

enum InventoryCategory {
	ALL,
	TOOLS,
	WEAPONS,
	WEARABLES,
	CONSUMABLES,
	SKILL_BOOKS,
	MATERIALS,
	QUEST_ITEMS,
	OTHER,
}

@export var id: StringName = &"item"
@export var display_name: String = "Item"
@export var item_type: ItemType = ItemType.MISC
@export var max_stack: int = 99
@export var description: String = ""
@export var icon: Texture2D
@export_group("Commerce")
@export_range(0, 1000000, 1) var buy_price: int = 0
@export_range(0, 1000000, 1) var sell_price: int = 0
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
@export_group("Work")
## Generic authored capabilities used by deterministic job/tool evaluation.
@export var work_tags: Array[StringName] = []
@export_range(0.1, 10.0, 0.05) var work_efficiency: float = 1.0
@export_group("Pet Care")
## Bounded tags used by authored pet equipment slots and food preferences.
@export var pet_tags: Array[StringName] = []
@export_range(0.0, 100.0, 0.5) var pet_nutrition: float = 0.0
@export_range(0.0, 25.0, 0.5) var pet_mood_gain: float = 0.0
@export_range(0.0, 25.0, 0.5) var pet_affection_gain: float = 0.0
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


func is_pet_food() -> bool:
	return item_type in [ItemType.FOOD, ItemType.PET_ITEM] and pet_nutrition > 0.0


func is_pet_equipment() -> bool:
	return item_type == ItemType.PET_ITEM and pet_nutrition <= 0.0 and not pet_tags.is_empty()


func resolved_inventory_category() -> int:
	# Priority is intentional: skill books are authored as quest-like consumables,
	# while weapons are equipment but belong beside tools in the backpack.
	if is_skill_book():
		return InventoryCategory.SKILL_BOOKS
	if item_type == ItemType.TOOL:
		return InventoryCategory.TOOLS
	if item_type == ItemType.WEAPON:
		return InventoryCategory.WEAPONS
	if is_equippable():
		return InventoryCategory.WEARABLES
	if use_kind == UseKind.CONSUME or item_type in [ItemType.CONSUMABLE, ItemType.FOOD]:
		return InventoryCategory.CONSUMABLES
	if item_type == ItemType.MATERIAL:
		return InventoryCategory.MATERIALS
	if item_type in [ItemType.QUEST, ItemType.GIFT, ItemType.KEY_ITEM]:
		return InventoryCategory.QUEST_ITEMS
	return InventoryCategory.OTHER


func matches_inventory_category(category: int) -> bool:
	return category == InventoryCategory.ALL or category == resolved_inventory_category()


func ontology_node_id() -> StringName:
	var raw := String(id)
	return id if raw.begins_with("item:") else StringName("item:%s" % raw)


func catalog_metadata() -> Dictionary:
	return {
		"definition_id": String(id),
		"description": description,
		"item_type": item_type,
		"inventory_category": resolved_inventory_category(),
		"max_stack": max_stack,
		"buy_price": buy_price,
		"sell_price": sell_price,
		"rarity": String(rarity),
		"minimum_level": minimum_level,
		"equip_slot": equip_slot,
		"equipment_class": equipment_class,
		"equipment_weight": equipment_weight,
		"required_strength": required_strength,
		"required_vitality": required_vitality,
		"work_tags": _string_names(work_tags),
		"work_efficiency": work_efficiency,
		"visual_archetype": String(resolved_visual_archetype()),
		"pet_tags": _string_names(pet_tags),
		"pet_nutrition": pet_nutrition,
	}


func to_catalog_dict() -> Dictionary:
	return {
		"node_id": String(ontology_node_id()),
		"node_type": "item",
		"label": display_name,
		"metadata": catalog_metadata(),
	}


func supports_utility_action(action_id: StringName) -> bool:
	return action_id != &"" and utility_actions.has(action_id)


func supports_work_tag(tag: StringName) -> bool:
	return tag != &"" and work_tags.has(tag)


func supports_all_work_tags(required_tags: Array[StringName]) -> bool:
	for tag in required_tags:
		if not supports_work_tag(tag):
			return false
	return true


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


func _string_names(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
