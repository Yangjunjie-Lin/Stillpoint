extends Node
## Bootstrap root. Autoloads are available; this hosts CurrentScene.


func _ready() -> void:
	SceneRouter.go_to_main_menu()
