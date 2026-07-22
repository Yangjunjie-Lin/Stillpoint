extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/characters/player_3d.tscn") as PackedScene
	var player := packed.instantiate() as PlayerController3D
	tree.root.add_child(player)
	await tree.physics_frame
	var combat := player.combat
	var ok := not combat.hitbox_active
	combat.open_attack_window()
	await tree.process_frame
	ok = ok and combat.hitbox_active
	combat.close_attack_window()
	ok = ok and not combat.hitbox_active
	combat.finish_attack()
	ok = ok and combat.combat_state == CombatComponent.CombatState.READY
	player.free()
	return ok
