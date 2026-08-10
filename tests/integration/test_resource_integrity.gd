extends RefCounted


func run() -> bool:
	var ok := true
	var resources := _collect("res://resources/", ".tres")
	ok = ok and not resources.is_empty()
	var enemy_ids: Dictionary = {}
	var item_ids: Dictionary = {}
	var weapon_ids: Dictionary = {}
	var level_ids: Dictionary = {}
	var region_ids: Dictionary = {}
	var npc_ids: Dictionary = {}
	var house_ids: Dictionary = {}
	var container_ids: Dictionary = {}
	var loot_table_ids: Dictionary = {}

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
		elif res is RegionDefinition:
			var region := res as RegionDefinition
			if region_ids.has(region.id):
				push_error("Duplicate region id: %s" % String(region.id))
				ok = false
			region_ids[region.id] = path
		elif res is NPCDefinition:
			var npc := res as NPCDefinition
			if npc_ids.has(npc.id):
				push_error("Duplicate npc id: %s" % String(npc.id))
				ok = false
			npc_ids[npc.id] = path
		elif res is HouseDefinition:
			var house := res as HouseDefinition
			if house_ids.has(house.id):
				push_error("Duplicate house id: %s" % String(house.id))
				ok = false
			house_ids[house.id] = path
			if not house.is_valid():
				push_error("Invalid house definition: %s" % path)
				ok = false
		elif res is ContainerDefinition:
			var container := res as ContainerDefinition
			if container_ids.has(container.id):
				push_error("Duplicate container id: %s" % String(container.id))
				ok = false
			container_ids[container.id] = path
			if not container.is_valid():
				push_error("Invalid container definition: %s" % path)
				ok = false
		elif res is LootTableDefinition:
			var loot_table := res as LootTableDefinition
			if loot_table_ids.has(loot_table.id):
				push_error("Duplicate loot table id: %s" % String(loot_table.id))
				ok = false
			loot_table_ids[loot_table.id] = path
			if not loot_table.is_valid():
				push_error("Invalid loot table definition: %s" % path)
				ok = false

	ok = ok and not enemy_ids.is_empty()
	ok = ok and not item_ids.is_empty()
	ok = ok and enemy_ids.has(&"chase")
	ok = ok and item_ids.has(&"shield")
	ok = ok and region_ids.has(&"base:town")
	ok = ok and npc_ids.has(&"mira")
	ok = ok and house_ids.size() == 8
	ok = ok and house_ids.has(&"building:mira_apothecary")
	ok = ok and house_ids.has(&"building:player_farmhouse")
	ok = ok and house_ids.has(&"building:player_courtyard_house")
	ok = ok and house_ids.has(&"building:player_townhouse")
	ok = ok and house_ids.has(&"building:stillpoint_bank")
	ok = ok and container_ids.size() == 2
	ok = ok and container_ids.has(&"chest")
	ok = ok and container_ids.has(&"pryable_cache")
	ok = ok and loot_table_ids.has(&"bandit_equipment")
	ok = ok and region_ids.has(&"base:farmland")
	ok = ok and region_ids.has(&"base:player_home")

	if ResourceRegistry.get_enemy(&"chase") == null:
		push_error("ResourceRegistry missing chase")
		ok = false
	if ResourceRegistry.get_item(&"shield") == null:
		push_error("ResourceRegistry missing shield")
		ok = false
	if ResourceRegistry.get_region(&"base:town") == null:
		push_error("ResourceRegistry missing base:town region")
		ok = false
	if ResourceRegistry.get_region(&"town") == null:
		push_error("ResourceRegistry missing legacy town alias")
		ok = false
	if ResourceRegistry.get_npc(&"mira") == null:
		push_error("ResourceRegistry missing mira npc")
		ok = false
	if ResourceRegistry.get_house(&"building:mira_apothecary") == null:
		push_error("ResourceRegistry missing Mira's apothecary")
		ok = false
	if ResourceRegistry.get_container(&"chest") == null:
		push_error("ResourceRegistry missing town chest ontology")
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
