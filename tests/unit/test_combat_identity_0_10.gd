extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var defender := CharacterTestFactory.create("Defender010")
	var attacker := CharacterTestFactory.create("Attacker010")
	tree.root.add_child(defender)
	tree.root.add_child(attacker)
	await tree.process_frame
	defender.global_position = Vector3.ZERO
	attacker.global_position = Vector3(0.0, 0.0, -2.0)
	var combat := defender.combat
	var energy_before := defender.energy.current_energy
	var heavy_ok := combat.request_attack(&"attack_heavy_1")
	var energy_after := defender.energy.current_energy
	var heavy_definition := combat.get_current_attack_definition()
	var heavy_cost_once := is_equal_approx(energy_before - energy_after, heavy_definition.energy_cost)
	combat.cancel_attack(&"test_cleanup")
	var dodge_before := defender.energy.current_energy
	var dodge_ok := combat.request_dodge(Vector3.BACK)
	var dodge_after := defender.energy.current_energy
	var dodge_once := is_equal_approx(dodge_before - dodge_after, combat.dodge_energy_cost)
	await tree.create_timer(combat.dodge_duration + 0.05).timeout
	var parry_attack := AttackDefinition.new()
	parry_attack.parryable = true
	combat.set_guarding(true)
	var context := {"attack_definition": parry_attack, "parryable": true, "blockable": true}
	var parry_damage := combat.resolve_incoming_damage(20.0, attacker, defender, defender.energy, context)
	var parry_ok := is_zero_approx(parry_damage) and bool(context.get("was_parried", false))
	defender.free()
	attacker.free()
	return heavy_ok and heavy_cost_once and dodge_ok and dodge_once and parry_ok
