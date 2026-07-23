extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var flags := WorldFlagService.new()
	var ctx := WorldSessionContext.new(world, world.player, world.entity_repository, world.region_service, QuestManager, flags)
	var effect_ctx := WorldEffectContext.new(ctx)

	var empty := UnlockPetEffect.new()
	var empty_result := empty.apply(effect_ctx)
	if empty_result.success:
		push_error("UnlockPetEffect should fail with empty pet id")
		world.free()
		flags.free()
		return false

	var unlock := UnlockPetEffect.new()
	unlock.pet_id = &"test_pet_unit"
	var ok_result := unlock.apply(effect_ctx)
	if not ok_result.success:
		push_error("UnlockPetEffect failed: %s" % ok_result.message)
		world.free()
		flags.free()
		return false
	if not world.unlocked_pet_ids.has("test_pet_unit"):
		push_error("unlocked_pet_ids missing test_pet_unit")
		world.free()
		flags.free()
		return false

	world.free()
	flags.free()
	return true
