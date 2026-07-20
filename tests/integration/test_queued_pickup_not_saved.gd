extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	SaveService.clear_run()
	GameManager.resume_requested = false
	var packed: PackedScene = load("res://scenes/gameplay/gameplay.tscn") as PackedScene
	var gameplay := packed.instantiate() as GameplayController
	tree.root.add_child(gameplay)

	gameplay._spawn_item()
	var pickup: PickupItem = null
	for child in gameplay.pickups.get_children():
		if child is PickupItem:
			pickup = child as PickupItem
			break

	var ok := pickup != null
	if not ok:
		gameplay.free()
		return false

	pickup.queue_free()
	ok = ok and not pickup.is_saveable()

	gameplay._save_run()
	var saved := SaveService.load_run()
	ok = ok and (saved.get("pickups", []) as Array).is_empty()

	gameplay.free()
	SaveService.clear_run()

	if not ok:
		push_error("Queued pickup save filter failed")
	return ok
