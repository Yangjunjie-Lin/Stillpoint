extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var character := CharacterTestFactory.create("TestGuardDefender")
	var attacker := Node3D.new()
	attacker.name = "TestGuardAttacker"
	tree.root.add_child(character)
	tree.root.add_child(attacker)
	await tree.process_frame
	var combat := character.combat
	combat.is_guarding = true
	character.global_transform = Transform3D(
		Basis.looking_at(Vector3(0, 0, -1), Vector3.UP),
		Vector3.ZERO
	)
	attacker.global_position = character.global_position + Vector3(0, 0, -2)
	var energy := character.energy
	energy.current_energy = 100.0
	energy.max_energy = 100.0
	var reduced := combat.resolve_incoming_damage(20.0, attacker, character, energy, {})
	var ok := reduced < 20.0
	attacker.global_position = character.global_position + Vector3(0, 0, 2)
	await tree.process_frame
	var full := combat.resolve_incoming_damage(20.0, attacker, character, energy, {})
	ok = ok and is_equal_approx(full, 20.0)
	character.queue_free()
	attacker.queue_free()
	await tree.process_frame
	return ok
