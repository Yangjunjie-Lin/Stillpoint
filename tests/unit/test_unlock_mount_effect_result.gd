extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var flags := WorldFlagService.new()
	var ctx := WorldSessionContext.new(world, world.player, world.entity_repository, world.region_service, QuestManager, flags)
	var effect_ctx := WorldEffectContext.new(ctx)

	var empty := UnlockMountEffect.new()
	var empty_result := empty.apply(effect_ctx)
	if empty_result.success:
		push_error("UnlockMountEffect should fail with empty mount id")
		world.free()
		flags.free()
		return false

	var unlock := UnlockMountEffect.new()
	unlock.mount_id = &"test_mount_unit"
	var ok_result := unlock.apply(effect_ctx)
	if not ok_result.success:
		push_error("UnlockMountEffect failed: %s" % ok_result.message)
		world.free()
		flags.free()
		return false
	if not world.unlocked_mount_ids.has("test_mount_unit"):
		push_error("unlocked_mount_ids missing test_mount_unit")
		world.free()
		flags.free()
		return false

	world.free()
	flags.free()
	return true
