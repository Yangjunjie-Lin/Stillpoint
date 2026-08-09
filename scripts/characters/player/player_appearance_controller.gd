class_name PlayerAppearanceController
extends Node3D
## Replaces the placeholder player visual with the selected origin model.

@export var fallback_scene: PackedScene

var current_origin_id: StringName = &""
var current_model: Node3D


func apply_origin(origin_id: StringName) -> bool:
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
		(current_model as StylizedHeroModel).preview_idle_motion = false
	add_child(current_model)
	current_origin_id = origin_id
	return true


func clear_model() -> void:
	if current_model != null:
		current_model.free()
	current_model = null
	current_origin_id = &""
