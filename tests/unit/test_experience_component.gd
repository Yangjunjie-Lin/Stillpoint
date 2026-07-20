extends RefCounted


func run() -> bool:
	var xp := ExperienceComponent.new()
	xp.curve = ExperienceCurve.new()
	xp.level = 1
	xp.current_experience = 0
	xp.experience_to_next_level = xp.curve.required_for_level(1)
	xp.total_experience = 0

	# Attach a temp health parent for level-up restore path.
	var host := Node.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = 100.0
	health.current_health = 90.0
	host.add_child(health)
	host.add_child(xp)

	var threshold := xp.experience_to_next_level
	var levels := xp.grant_experience(threshold + 17, 1.0)
	var ok := levels == 1 and xp.level == 2 and xp.current_experience == 17
	ok = ok and health.max_health == 110.0
	ok = ok and health.current_health <= health.max_health

	var huge := xp.experience_to_next_level
	huge += CombatMath.experience_required_for_level(3)
	huge += CombatMath.experience_required_for_level(4)
	var multi := xp.grant_experience(huge, 2.0)
	ok = ok and multi >= 2 and xp.level >= 4

	host.free()
	if not ok:
		push_error("ExperienceComponent assertions failed")
	return ok
