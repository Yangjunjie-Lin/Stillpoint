extends RefCounted


func run() -> bool:
	var combat := CombatComponent.new()
	combat.is_attacking = true
	combat.open_combo_window()
	var ok := combat.queue_attack(&"attack_light_2")
	ok = ok and combat._queued_attack_id == &"attack_light_2"
	combat.close_combo_window()
	ok = ok and combat._queued_attack_id == &""
	combat.free()
	return ok
