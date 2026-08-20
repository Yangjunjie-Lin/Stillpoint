extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var defender := CharacterTestFactory.create("ClosureDefender010")
	var poise := PoiseComponent.new()
	poise.name = "PoiseComponent"
	poise.max_poise = 10.0
	poise.regen_delay = 0.01
	poise.regen_rate = 100.0
	defender.add_child(poise)
	var attacker := CharacterTestFactory.create("ClosureAttacker010")
	tree.root.add_child(defender)
	tree.root.add_child(attacker)
	await tree.process_frame
	defender.combat.set_physics_process(false)
	attacker.combat.set_physics_process(false)
	defender.health.invulnerability_duration = 0.0
	defender.global_position = Vector3.ZERO
	attacker.global_position = Vector3(0.0, 0.0, -2.0)

	var parry_ok := _parry_regressions(defender, attacker)
	var dodge_ok := _dodge_regressions(defender, attacker)
	var terminal_ok := _terminal_and_restore_regressions(defender, attacker)
	var fallback_ok := await _interrupted_fallback_regression(defender)
	var poise_ok := _poise_regression(defender)
	var ok := parry_ok and dodge_ok and terminal_ok and fallback_ok and poise_ok

	defender.free()
	attacker.free()
	if not ok:
		print("Closure results: parry=%s dodge=%s terminal=%s fallback=%s poise=%s" % [
			str(parry_ok), str(dodge_ok), str(terminal_ok), str(fallback_ok), str(poise_ok),
		])
		push_error("0.10 combat closure regressions failed")
	return ok


func _parry_regressions(defender: CharacterController, attacker: CharacterController) -> bool:
	var combat := defender.combat
	var non_parryable := AttackDefinition.new()
	non_parryable.parryable = false
	non_parryable.poise_damage = 0.0
	combat.begin_guard()
	var context := {
		"attack_definition": non_parryable,
		"parryable": false,
		"blockable": true,
	}
	var dealt := combat.resolve_incoming_damage(20.0, attacker, defender, defender.energy, context)
	var ok := (
		dealt > 0.0
		and dealt < 20.0
		and not bool(context.get("was_parried", false))
		and bool(context.get("was_blocked", false))
		and combat.combat_state == CombatComponent.CombatState.BLOCKSTUN
	)

	combat.reset_runtime_state()
	defender.state.current = CharacterState.State.IDLE
	var parryable := AttackDefinition.new()
	parryable.parryable = true
	parryable.poise_damage = 0.0
	combat.begin_guard()
	combat._physics_process(combat.parry_window_duration + 0.01)
	var late_context := {"attack_definition": parryable, "blockable": true}
	var late_dealt := combat.resolve_incoming_damage(
		20.0, attacker, defender, defender.energy, late_context
	)
	ok = ok and late_dealt > 0.0 and late_dealt < 20.0
	ok = ok and not bool(late_context.get("was_parried", false))
	ok = ok and bool(late_context.get("was_blocked", false))
	ok = ok and combat.combat_state == CombatComponent.CombatState.BLOCKSTUN
	return ok


func _dodge_regressions(defender: CharacterController, attacker: CharacterController) -> bool:
	var combat := defender.combat
	combat.reset_runtime_state()
	defender.state.current = CharacterState.State.IDLE
	var before_health := defender.health.current_health
	var started := combat.request_dodge(Vector3.FORWARD)
	var before_iframe := defender.receive_damage(2.0, attacker)
	combat._physics_process(combat.dodge_iframe_start + 0.001)
	var during_iframe := defender.receive_damage(2.0, attacker)
	combat._physics_process(combat.dodge_iframe_duration + 0.001)
	var after_iframe := defender.receive_damage(2.0, attacker)
	var ok := (
		started
		and before_iframe > 0.0
		and is_zero_approx(during_iframe)
		and after_iframe > 0.0
		and defender.health.current_health < before_health
		and not defender.hurtbox.is_invulnerable()
	)

	combat.reset_runtime_state()
	defender.state.current = CharacterState.State.IDLE
	ok = combat.request_dodge(Vector3.RIGHT) and ok
	combat._physics_process(combat.dodge_iframe_start + 0.001)
	ok = defender.hurtbox.is_invulnerable() and ok
	combat.enter_stagger(0.1)
	ok = not defender.hurtbox.is_invulnerable() and ok
	ok = combat.combat_state == CombatComponent.CombatState.STAGGERED and ok
	return ok


func _terminal_and_restore_regressions(
	defender: CharacterController,
	attacker: CharacterController,
) -> bool:
	var combat := defender.combat
	combat.reset_runtime_state()
	defender.state.current = CharacterState.State.IDLE
	var hit := AttackDefinition.new()
	hit.hitstun_duration = 0.05
	hit.poise_damage = 0.0
	combat.resolve_incoming_damage(1.0, attacker, defender, defender.energy, {
		"attack_definition": hit,
		"unblockable": true,
	})
	var ok := combat.combat_state == CombatComponent.CombatState.HITSTUN
	defender.is_downed = true
	defender.state.current = CharacterState.State.DOWNED
	combat._physics_process(0.1)
	ok = combat.combat_state == CombatComponent.CombatState.KNOCKED_DOWN and ok
	combat._physics_process(0.1)
	ok = combat.combat_state == CombatComponent.CombatState.KNOCKED_DOWN and ok

	defender.is_downed = false
	defender.is_permanently_dead = true
	defender.state.current = CharacterState.State.DISABLED
	combat._physics_process(0.1)
	ok = combat.combat_state == CombatComponent.CombatState.DISABLED and ok
	combat._physics_process(0.1)
	ok = combat.combat_state == CombatComponent.CombatState.DISABLED and ok

	defender.is_permanently_dead = false
	defender.from_dict({
		"character_id": String(defender.character_id),
		"region_id": String(defender.region_id),
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"health": defender.health.to_dict(),
		"energy": defender.energy.to_dict(),
		"faction": defender.faction.to_dict(),
		"skills": defender.skills.to_dict(),
		"state": {
			"is_running": false,
			"is_crouching": false,
			"is_downed": false,
			"is_permanently_dead": false,
		},
	})
	ok = combat.combat_state == CombatComponent.CombatState.READY and ok
	ok = not combat.is_attacking and not combat.is_guarding and not combat.is_dodging() and ok
	return ok


func _interrupted_fallback_regression(defender: CharacterController) -> bool:
	var combat := defender.combat
	combat.reset_runtime_state()
	defender.state.current = CharacterState.State.IDLE
	var fallback_attack := AttackDefinition.new()
	fallback_attack.id = &"closure_fallback"
	fallback_attack.energy_cost = 0.0
	fallback_attack.windup = 0.02
	fallback_attack.active = 0.02
	fallback_attack.recovery = 0.02
	combat.attack = fallback_attack
	var started := combat.request_attack(fallback_attack.id)
	combat.enter_stagger(0.2)
	await (Engine.get_main_loop() as SceneTree).create_timer(0.1).timeout
	return (
		started
		and not combat.is_attacking
		and not combat.hitbox_active
		and combat.combat_state == CombatComponent.CombatState.STAGGERED
	)


func _poise_regression(defender: CharacterController) -> bool:
	var combat := defender.combat
	combat.reset_runtime_state()
	defender.state.current = CharacterState.State.IDLE
	combat.poise.reset()
	var first_break := combat.apply_poise_damage(4.0)
	var second_break := combat.apply_poise_damage(6.0)
	var ok := (
		not first_break
		and second_break
		and combat.combat_state == CombatComponent.CombatState.STAGGERED
		and combat.poise.is_broken()
	)
	combat.poise._process(combat.poise.regen_delay + 0.01)
	combat.poise._process(0.2)
	ok = combat.poise.current_poise > 0.0 and ok
	combat._physics_process(combat.stagger_duration + 0.01)
	ok = combat.combat_state == CombatComponent.CombatState.READY and ok
	return ok
