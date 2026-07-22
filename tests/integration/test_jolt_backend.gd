extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var svc: Node = tree.root.get_node("PhysicsSettingsService")
	return svc.call("get_physics_backend") == "Jolt Physics"
