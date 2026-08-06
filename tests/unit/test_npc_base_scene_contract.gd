extends RefCounted


func run() -> bool:
	var packed: PackedScene = load("res://scenes/characters/base/npc_base_3d.tscn") as PackedScene
	if packed == null:
		push_error("npc_base_3d.tscn failed to load")
		return false
	var actor := packed.instantiate()
	if actor == null:
		push_error("npc_base_3d.tscn failed to instantiate")
		return false
	if not ActorSceneValidator.validate(actor):
		push_error("ActorSceneValidator rejected npc_base_3d.tscn")
		actor.free()
		return false
	actor.free()
	return true
