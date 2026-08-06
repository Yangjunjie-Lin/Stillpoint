extends RefCounted

const PID := &"base:wilderness/npc/runtime_duplicate_test"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var effect := SpawnEntityEffect.new()
	effect.definition_id = &"bandit"
	effect.persistent_id = PID
	effect.region_id = &"base:wilderness"
	effect.use_current_region = false
	if not effect.apply(WorldEffectContext.new(world.get_session_context())).success:
		world.free()
		return false
	world.transition_to(&"base:wilderness")
	world.transition_to(&"base:town")
	world.transition_to(&"base:wilderness")
	var count := _count_entities(world.region_service.get_current_region_root(), PID)
	var retry := effect.apply(WorldEffectContext.new(world.get_session_context()))
	var count_after_retry := _count_entities(world.region_service.get_current_region_root(), PID)
	var ok := count == 1 and retry.success and count_after_retry == 1
	if not ok:
		push_error("runtime snapshot materialized more than once")
	world.free()
	return ok


func _count_entities(root: Node, persistent_id: StringName) -> int:
	if root == null:
		return 0
	var count := 0
	var identity := root.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if identity != null and identity.persistent_id == persistent_id:
		count += 1
	for child in root.get_children():
		count += _count_entities(child, persistent_id)
	return count
