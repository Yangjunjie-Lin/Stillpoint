class_name PlayerAppearanceController
extends Node3D
## Replaces the placeholder player visual with the selected origin model.

@export var fallback_scene: PackedScene

var current_origin_id: StringName = &""
var current_options: Dictionary = CharacterAppearanceOptions.default_options()
var current_model: Node3D


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
	return true


func clear_model() -> void:
	if current_model != null:
		current_model.free()
	current_model = null
	current_origin_id = &""
	current_options = CharacterAppearanceOptions.default_options()
