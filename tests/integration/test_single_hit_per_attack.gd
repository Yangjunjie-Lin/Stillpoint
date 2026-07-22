extends RefCounted


func run() -> bool:
	var hitbox := Hitbox3D.new()
	hitbox.maximum_targets = 1
	hitbox.set_active(true)
	var hurt_a := Hurtbox3D.new()
	var hurt_b := Hurtbox3D.new()
	var sweep := MeleeSweep3D.new()
	sweep.maximum_targets = 1
	sweep.begin_sweep()
	var ok := sweep.register_overlap_hurtbox(hurt_a)
	ok = ok and not sweep.register_overlap_hurtbox(hurt_a)
	ok = ok and not sweep.register_overlap_hurtbox(hurt_b)
	hitbox.free()
	hurt_a.free()
	hurt_b.free()
	sweep.free()
	return ok
