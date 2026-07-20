extends Node
## Owns scene transitions through the Main CurrentScene slot.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const GAMEPLAY := "res://scenes/gameplay/gameplay.tscn"

var _current_scene: Node = null


func go_to_main_menu() -> void:
	change_scene(MAIN_MENU)


func go_to_gameplay() -> void:
	change_scene(GAMEPLAY)


func change_scene(scene_path: String) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("SceneRouter: failed to load %s" % scene_path)
		return
	var root := get_tree().root.get_node_or_null("Main")
	if root == null:
		# Fallback when launched from a leaf scene in the editor.
		get_tree().change_scene_to_packed(packed)
		return
	var slot: Node = root.get_node("CurrentScene")
	for child in slot.get_children():
		child.queue_free()
	_current_scene = packed.instantiate()
	slot.add_child(_current_scene)
