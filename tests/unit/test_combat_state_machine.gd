extends RefCounted


func run() -> bool:
	var combat := CombatComponent.new()
	var ok := combat.combat_state == CombatComponent.CombatState.READY
	combat.open_attack_window()
	ok = ok and combat.hitbox_active
	combat.close_attack_window()
	ok = ok and not combat.hitbox_active
	combat.combo_window_open = true
	ok = ok and combat.queue_attack(&"attack_light_2")
	combat.cancel_attack(&"test")
	ok = ok and not combat.is_attacking
	combat.free()
	return ok
