extends RefCounted


func run() -> bool:
	var ok := true
	var scenes := _collect("res://scenes/", ".tscn")
	ok = ok and not scenes.is_empty()
	for path in scenes:
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			push_error("Failed to load scene: %s" % path)
			ok = false
			continue
		var instance := packed.instantiate()
		if instance == null:
			push_error("Failed to instantiate scene: %s" % path)
			ok = false
			continue
		instance.free()

	var main := load("res://scenes/bootstrap/main.tscn") as PackedScene
	ok = ok and main != null and main.instantiate() != null
	var gameplay := load("res://scenes/gameplay/gameplay.tscn") as PackedScene
	ok = ok and gameplay != null
	var gp := gameplay.instantiate()
	ok = ok and gp != null
	if gp != null:
		gp.free()

	var player := load("res://scenes/actors/player/player.tscn") as PackedScene
	var player_node := player.instantiate()
	ok = ok and player_node.get_node_or_null("HealthComponent") != null
	ok = ok and player_node.get_node_or_null("WeaponComponent") != null
	ok = ok and player_node.get_node_or_null("MovementComponent") != null
	ok = ok and player_node.get_node_or_null("StatusEffectComponent") != null
	player_node.free()

	var enemy := load("res://scenes/actors/enemies/enemy_base.tscn") as PackedScene
	var enemy_node := enemy.instantiate()
	ok = ok and enemy_node.get_node_or_null("HealthComponent") != null
	ok = ok and enemy_node.get_node_or_null("Hitbox") != null
	ok = ok and enemy_node.get_node_or_null("Hurtbox") != null
	enemy_node.free()

	if not ok:
		push_error("Scene integrity assertions failed")
	return ok


func _collect(root_path: String, suffix: String) -> Array[String]:
	var out: Array[String] = []
	_walk(root_path, suffix, out)
	return out


func _walk(path: String, suffix: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var child := path.path_join(name)
		if dir.current_is_dir():
			_walk(child, suffix, out)
		elif name.ends_with(suffix):
			out.append(child)
		name = dir.get_next()
	dir.list_dir_end()
