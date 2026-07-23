extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var def := RegionDefinition.new()
	def.id = &"test:arena"
	def.display_name = "Test Arena"
	def.scene = load("res://scenes/regions/town/town_region.tscn") as PackedScene
	ResourceRegistry.register_region(def)
	world.discover_region(&"test:arena")
	world.save_coordinator.mark_region_dirty(&"test:arena")
	world.save_coordinator.save_dirty_sections()

	var path := "user://saves/slot_01/regions/test_arena.json"
	if not FileAccess.file_exists(path):
		push_error("new region chunk file not written: %s" % path)
		world.free()
		return false

	world.free()
	return true
