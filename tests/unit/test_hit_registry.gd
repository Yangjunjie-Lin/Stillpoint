extends RefCounted


func run() -> bool:
	var hitbox := Hitbox3D.new()
	hitbox.set_active(true)
	var hurt := Hurtbox3D.new()
	var key := hurt.get_instance_id()
	hitbox._hit_targets[key] = true
	var ok := hitbox._hit_targets.has(key)
	hitbox.set_active(false)
	ok = ok and hitbox._hit_targets.is_empty()
	hitbox.free()
	hurt.free()
	return ok
