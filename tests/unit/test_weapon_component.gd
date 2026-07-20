extends RefCounted


func run() -> bool:
	var base := WeaponDefinition.new()
	base.id = &"test"
	base.damage = 10.0
	base.cooldown = 0.5
	base.projectile_count = 1
	base.piercing = false
	base.projectile_scale = 1.0
	base.projectile_speed = 900.0
	base.projectile_lifetime = 2.0
	base.bullet_scene = load("res://scenes/combat/bullet.tscn") as PackedScene

	var weapon := WeaponComponent.new()
	weapon.base_weapon = base
	weapon.minimum_cooldown = 0.18
	weapon.rapid_fire_cooldown = 0.05

	var status := StatusEffectComponent.new()
	var ok := true

	var stats := weapon.build_runtime_stats(status, 0.0)
	ok = ok and stats.projectile_count == 1
	ok = ok and stats.piercing == false
	ok = ok and is_equal_approx(stats.damage, 10.0)

	status.apply(&"double", 5.0, 0.0)
	stats = weapon.build_runtime_stats(status, 1.0)
	ok = ok and stats.projectile_count == 2
	ok = ok and stats.spread_degrees >= 12.0

	status.update_clock(6.0)
	stats = weapon.build_runtime_stats(status, 6.0)
	ok = ok and stats.projectile_count == 1

	status.apply(&"pierce", 2.0, 10.0)
	stats = weapon.build_runtime_stats(status, 10.5)
	ok = ok and stats.piercing == true
	status.update_clock(13.0)
	stats = weapon.build_runtime_stats(status, 13.0)
	ok = ok and stats.piercing == false

	status.apply(&"large", 2.0, 20.0)
	stats = weapon.build_runtime_stats(status, 20.0)
	ok = ok and is_equal_approx(stats.projectile_scale, 1.8)
	ok = ok and is_equal_approx(stats.damage, 15.0)
	# Repeat pickup must not stack multipliers.
	status.apply(&"large", 2.0, 20.5)
	stats = weapon.build_runtime_stats(status, 20.5)
	ok = ok and is_equal_approx(stats.projectile_scale, 1.8)
	ok = ok and is_equal_approx(stats.damage, 15.0)
	ok = ok and is_equal_approx(base.damage, 10.0)
	ok = ok and is_equal_approx(base.projectile_scale, 1.0)

	status.clear_all()
	status.apply(&"rapid_fire", 1.0, 30.0)
	stats = weapon.build_runtime_stats(status, 30.0)
	ok = ok and is_equal_approx(stats.cooldown, 0.05)
	status.update_clock(32.0)
	stats = weapon.build_runtime_stats(status, 32.0)
	ok = ok and is_equal_approx(stats.cooldown, 0.5)

	weapon.cooldown_reduction = 1.0
	stats = weapon.build_runtime_stats(status, 40.0)
	ok = ok and is_equal_approx(stats.cooldown, weapon.minimum_cooldown)

	weapon.free()
	status.free()
	if not ok:
		push_error("WeaponComponent assertions failed")
	return ok
