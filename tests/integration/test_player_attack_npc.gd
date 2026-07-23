extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 2)
	var player := world.player
	var mira := WorldTestHelper.find_npc(world, "Mira")
	if player == null or mira == null or player.combat == null:
		world.free()
		return false
	RelationshipService.ensure_registered(&"mira", &"friendly")
	var before := mira.health.current_health
	player.global_position = mira.global_position + Vector3(0, 0, 1.2)
	player.look_at(mira.global_position, Vector3.UP)
	player.combat.open_attack_window()
	if player.combat.hitbox != null:
		player.combat.hitbox.set_active(true)
	var dealt := mira.receive_damage(12.0, player, {"is_normal_attack": true})
	var ok := dealt > 0.0 and mira.health.current_health < before
	ok = ok and RelationshipService.get_affinity(&"mira") < 60.0
	world.free()
	return ok
