class_name PlayerAppearanceController
extends Node3D
## Replaces the placeholder player visual with the selected origin model.

@export var fallback_scene: PackedScene

var current_origin_id: StringName = &""
var current_options: Dictionary = CharacterAppearanceOptions.default_options()
var current_model: Node3D
var current_weapon: ItemDefinition
var current_armor: ItemDefinition
var current_charm: ItemDefinition
var current_held_item: ItemDefinition
var current_off_hand_item: ItemDefinition
var current_worn_items: Array[ItemDefinition] = []
var current_presentation_mode: StringName = EquipmentComponent.PRESENTATION_PROFESSION


func apply_origin(origin_id: StringName) -> bool:
	return apply_build(origin_id, CharacterAppearanceOptions.default_options())


func apply_build(origin_id: StringName, options: Dictionary) -> bool:
	var definition: Resource = null
	if ResourceRegistry.has_method("get_origin"):
		definition = ResourceRegistry.call("get_origin", origin_id) as Resource
	var model_scene := definition.get("model_scene") as PackedScene if definition != null else null
	if model_scene == null:
		model_scene = fallback_scene
	if model_scene == null:
		model_scene = load("res://scenes/characters/player/origins/wuxia_swordsman.tscn") as PackedScene
	if model_scene == null:
		return false
	if current_model != null:
		current_model.free()
	current_model = model_scene.instantiate() as Node3D
	if current_model == null:
		return false
	current_model.name = "ActiveOriginModel"
	if current_model is StylizedHeroModel:
		var hero := current_model as StylizedHeroModel
		hero.preview_idle_motion = false
		hero.apply_customization(options)
	add_child(current_model)
	current_origin_id = origin_id
	current_options = CharacterAppearanceOptions.normalize(options)
	_apply_current_loadout()
	return true


func apply_loadout(
	weapon: ItemDefinition,
	armor: ItemDefinition,
	charm: ItemDefinition,
	held_item: ItemDefinition,
	off_hand_item: ItemDefinition = null,
	worn_items: Array[ItemDefinition] = [],
	presentation_mode: StringName = EquipmentComponent.PRESENTATION_PROFESSION,
) -> void:
	current_weapon = weapon
	current_armor = armor
	current_charm = charm
	current_held_item = held_item
	current_off_hand_item = off_hand_item
	current_worn_items = worn_items.duplicate()
	current_presentation_mode = presentation_mode
	_apply_current_loadout()


func get_displayed_loadout() -> Dictionary:
	if current_model != null and current_model.has_method("get_displayed_loadout"):
		return current_model.call("get_displayed_loadout") as Dictionary
	return {}


func _apply_current_loadout() -> void:
	if current_model is StylizedHeroModel:
		(current_model as StylizedHeroModel).apply_loadout(
			current_weapon, current_armor, current_charm, current_held_item,
			current_off_hand_item, current_worn_items, current_presentation_mode,
		)


func clear_model() -> void:
	if current_model != null:
		current_model.free()
	current_model = null
	current_origin_id = &""
	current_options = CharacterAppearanceOptions.default_options()
	current_weapon = null
	current_armor = null
	current_charm = null
	current_held_item = null
	current_off_hand_item = null
	current_worn_items.clear()
	current_presentation_mode = EquipmentComponent.PRESENTATION_PROFESSION
