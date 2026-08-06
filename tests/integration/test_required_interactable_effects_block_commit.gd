extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var player := world.player

	var town_root := world.region_service.get_current_region_root()
	var portal := town_root.find_child("WildernessPortal", true, false) as TransitionPortal
	if portal == null:
		push_error("WildernessPortal missing from town region")
		world.free()
		return false
	var portal_gate := RemoveItemEffect.new()
	portal_gate.item_id = &"portal_gate"
	portal_gate.required_success = true
	portal.effects = [portal_gate]
	portal.interact(player, InteractionContext.new(player))
	var ok := world.current_region_id == &"base:town"
	player.inventory.add_item(&"portal_gate", 1)
	portal.interact(player, InteractionContext.new(player))
	await WorldTestHelper.await_frames(tree)
	ok = ok and world.current_region_id == &"base:wilderness"

	var pickup := WorldTestHelper.find_pickup(world)
	if pickup == null:
		push_error("HerbPickup missing from wilderness region")
		world.free()
		return false
	var pickup_gate := RemoveItemEffect.new()
	pickup_gate.item_id = &"pickup_gate"
	pickup_gate.required_success = true
	pickup.effects = [pickup_gate]
	pickup.interact(player, InteractionContext.new(player))
	ok = ok and pickup.visible and player.inventory.count_item(&"herb") == 0
	player.inventory.add_item(&"pickup_gate", 1)
	pickup.interact(player, InteractionContext.new(player))
	ok = ok and not pickup.visible and player.inventory.count_item(&"herb") == 1

	world.free()
	if not ok:
		push_error("required interactable effect failure was committed or swallowed")
	return ok
