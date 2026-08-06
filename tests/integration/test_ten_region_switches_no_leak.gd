extends RefCounted

const REGIONS: Array[StringName] = [
	&"base:town",
	&"base:wilderness",
	&"base:dungeon",
	&"base:town",
	&"base:wilderness",
	&"base:dungeon",
	&"base:town",
	&"base:wilderness",
	&"base:dungeon",
	&"base:town",
]


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var slot := world.get_node_or_null("ActiveRegionSlot") as Node3D
	for region_id in REGIONS:
		world.transition_to(region_id)
		await WorldTestHelper.await_frames(tree, 2)
		if slot.get_child_count() > 1:
			push_error("multiple region roots attached after switch to %s" % region_id)
			world.free()
			return false
		for child in slot.get_children():
			if not child.is_queued_for_deletion() and child != world.region_service.get_current_region_root():
				push_error("stale region root not freed after switch")
				world.free()
				return false

	world.free()
	return true
