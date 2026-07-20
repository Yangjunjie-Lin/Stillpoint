extends RefCounted


func run() -> bool:
	var health := HealthComponent.new()
	health.max_health = 100.0
	health.current_health = 100.0
	health.defense = 5.0
	health.invulnerability_duration = 0.75
	health.minimum_damage = 1.0

	var dealt := health.apply_damage_at(DamageInfo.make(20.0), 1.0, false)
	var ok := dealt == 15.0 and is_equal_approx(health.current_health, 85.0)
	ok = ok and health.apply_damage_at(DamageInfo.make(20.0), 1.2, false) == 0.0
	ok = ok and health.apply_damage_at(DamageInfo.make(20.0), 1.0, true) == 0.0
	health.current_health = 5.0
	health.invulnerable_until = -1.0
	health.apply_damage_at(DamageInfo.make(50.0), 10.0, false)
	ok = ok and health.is_dead()
	ok = ok and health.death_recorded
	var again := health.apply_damage_at(DamageInfo.make(10.0), 11.0, false)
	ok = ok and again == 0.0
	if not ok:
		push_error("HealthComponent assertions failed")
	return ok
