extends RefCounted

const TARGET := &"base:dungeon/npc/bandit_0002"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)

	var before := world.entity_repository.get_loaded_entity(TARGET)
	if before == null:
		push_error("target actor missing before destroy")
		world.free()
		return false

	var ctx := WorldEffectContext.new(world.get_session_context())
	var destroy := DestroyEntityEffect.new()
	destroy.persistent_id = TARGET
	destroy.apply(ctx)
	await WorldTestHelper.await_frames(tree)

	if world.entity_repository.get_loaded_entity(TARGET) != null:
		push_error("DestroyEntityEffect did not remove node")
		world.free()
		return false

	world.free()
	return true
