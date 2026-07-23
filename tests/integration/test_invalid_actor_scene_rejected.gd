extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var parent := world.region_service.get_dynamic_parent()
	var ctx := ActorSpawnContext.new()
	ctx.definition_id = &"bandit"
	ctx.persistent_id = &"base:dungeon/npc/invalid_scene_test"
	ctx.region_id = &"base:dungeon"
	ctx.parent = parent

	var empty_scene := PackedScene.new()
	var node := Node3D.new()
	empty_scene.pack(node)
	node.free()
	world.actor_factory.default_npc_scene = empty_scene

	var actor := world.actor_factory.spawn_actor(&"bandit", ctx)
	if actor != null:
		push_error("factory should reject invalid actor scene")
		actor.queue_free()
		world.free()
		return false

	var probe := Node3D.new()
	if ActorSceneValidator.validate(probe):
		push_error("empty Node3D should fail validate")
		probe.free()
		world.free()
		return false
	probe.free()
	world.free()
	return true
