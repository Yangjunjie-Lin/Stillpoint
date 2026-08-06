extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var mira := WorldTestHelper.find_npc(world, "Mira")
	if mira == null or mira.health == null or mira.energy == null:
		push_error("Mira not found or missing components")
		world.free()
		return false

	mira.health.current_health = 55.0
	mira.energy.current_energy = 40.0
	mira.is_downed = false
	var snap := EntitySnapshot.new()
	var identity := mira.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if identity == null:
		push_error("Mira missing identity")
		world.free()
		return false
	snap.persistent_id = identity.persistent_id
	snap.definition_id = identity.definition_id
	snap.region_id = identity.region_id
	snap.capture_from_node(mira)

	var parent := Node3D.new()
	var restored := world.actor_factory.restore_actor(snap, parent)
	await WorldTestHelper.await_frames(tree)
	if restored == null:
		push_error("restore_actor failed for NPC snapshot")
		parent.free()
		world.free()
		return false
	if not is_equal_approx(restored.health.current_health, 55.0):
		push_error("health not restored from snapshot")
		parent.free()
		world.free()
		return false
	if not is_equal_approx(restored.energy.current_energy, 40.0):
		push_error("energy not restored from snapshot")
		parent.free()
		world.free()
		return false

	parent.free()
	world.free()
	return true
