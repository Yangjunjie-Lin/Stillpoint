extends RefCounted


func run() -> bool:
	var ok := true
	var resources := _collect("res://resources/", ".tres")
	ok = ok and not resources.is_empty()
	var enemy_ids: Dictionary = {}
	var item_ids: Dictionary = {}
	var weapon_ids: Dictionary = {}
	var level_ids: Dictionary = {}

	for path in resources:
		var res: Resource = load(path)
		if res == null:
			push_error("Failed to load resource: %s" % path)
			ok = false
			continue
		if res is EnemyDefinition:
			var def := res as EnemyDefinition
			if enemy_ids.has(def.id):
				push_error("Duplicate enemy id: %s" % String(def.id))
				ok = false
			enemy_ids[def.id] = path
		elif res is ItemDefinition:
			var item := res as ItemDefinition
			if item_ids.has(item.id):
				push_error("Duplicate item id: %s" % String(item.id))
				ok = false
			item_ids[item.id] = path
		elif res is WeaponDefinition:
			var weapon := res as WeaponDefinition
			if weapon_ids.has(weapon.id):
				push_error("Duplicate weapon id: %s" % String(weapon.id))
				ok = false
			weapon_ids[weapon.id] = path
			if weapon.bullet_scene == null:
				push_error("Weapon missing bullet_scene: %s" % path)
				ok = false
		elif res is LevelDefinition:
			var level := res as LevelDefinition
			if level_ids.has(level.id):
				push_error("Duplicate level id: %s" % String(level.id))
				ok = false
			level_ids[level.id] = path
			if level.enemy_pool.is_empty():
				push_error("Level enemy_pool empty: %s" % path)
				ok = false
			for entry in level.item_pool:
				if entry == null:
					push_error("Level item_pool contains null: %s" % path)
					ok = false
			if level.scene == null:
				push_error("Level missing scene: %s" % path)
				ok = false

	ok = ok and not enemy_ids.is_empty()
	ok = ok and not item_ids.is_empty()
	ok = ok and enemy_ids.has(&"chase")
	ok = ok and item_ids.has(&"shield")

	var registry := ResourceRegistry.new()
	registry.load_defaults()
	if registry.get_enemy(&"chase") == null:
		push_error("ResourceRegistry missing chase")
		ok = false
	if registry.get_item(&"shield") == null:
		push_error("ResourceRegistry missing shield")
		ok = false

	if not ok:
		push_error("Resource integrity assertions failed")
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
