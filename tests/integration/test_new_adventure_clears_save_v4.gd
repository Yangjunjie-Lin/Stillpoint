extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	if not world.save_world_state():
		push_error("save failed")
		world.free()
		return false
	world.free()

	if not SaveSlotService.has_adventure_save():
		push_error("expected adventure save before clear")
		return false

	SaveSlotService.clear_adventure_save()
	if SaveSlotService.has_adventure_save():
		push_error("adventure save still present after clear")
		return false
	if GameManager.has_resumable_adventure():
		push_error("GameManager still reports resumable adventure after clear")
		return false
	return true
