extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)

	if not world.save_coordinator.save_all():
		push_error("save_all failed")
		world.free()
		return false

	var manifest := world.save_coordinator._read_json("user://saves/slot_01/manifest.json")
	var chunks: Dictionary = manifest.get("region_chunks", {})
	var expected := {
		"base:town": "base_town.json",
		"base:wilderness": "base_wilderness.json",
		"base:dungeon": "base_dungeon.json",
	}
	for key in expected.keys():
		if str(chunks.get(key, "")) != expected[key]:
			push_error("manifest chunk mapping wrong for %s" % key)
			world.free()
			return false
		var fname: String = str(expected[key])
		var path: String = "user://saves/slot_01/regions/" + fname
		if not FileAccess.file_exists(path):
			push_error("missing chunk file %s" % path)
			world.free()
			return false
		var chunk := world.save_coordinator._read_json(path)
		if str(chunk.get("region_id", "")) != key:
			push_error("chunk region_id mismatch in %s" % fname)
			world.free()
			return false
		if fname.contains("wilderness") and key == "base:town":
			push_error("town chunk filename looks like wilderness")
			world.free()
			return false

	world.free()
	return true
