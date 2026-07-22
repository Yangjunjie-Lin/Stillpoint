extends RefCounted


func run() -> bool:
	var combat := CombatComponent.new()
	combat.attack = load("res://resources/attacks/attack_light_1.tres") as AttackDefinition
	var hitbox := Hitbox3D.new()
	combat.hitbox = hitbox
	combat.open_attack_window()
	var ok := hitbox.active
	combat.cancel_attack(&"cleanup")
	ok = ok and not hitbox.active and not combat.is_attacking
	hitbox.free()
	combat.free()
	return ok
