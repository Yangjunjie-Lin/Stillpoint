extends Node
## Global static definition index. Runtime state must never live here.

var _characters: Dictionary = {}
var _npcs: Dictionary = {}
var _factions: Dictionary = {}
var _origins: Dictionary = {}
var _professions: Dictionary = {}
var _skills: Dictionary = {}
var _items: Dictionary = {}
var _shops: Dictionary = {}
var _jobs: Dictionary = {}
var _worksites: Dictionary = {}
var _forge_recipes: Dictionary = {}
var _dialogues: Dictionary = {}
var _quests: Dictionary = {}
var _regions: Dictionary = {}
var _dungeons: Dictionary = {}
var _encounters: Dictionary = {}
var _houses: Dictionary = {}
var _containers: Dictionary = {}
var _crops: Dictionary = {}
var _pets: Dictionary = {}
var _pet_companions: Dictionary = {}
var _mounts: Dictionary = {}
var _schedules: Dictionary = {}
var _attacks: Dictionary = {}
# Legacy survival prototype buckets
var _enemies: Dictionary = {}
var _weapons: Dictionary = {}
var _levels: Dictionary = {}
var _default_keys: Dictionary = {}


func _ready() -> void:
	load_defaults()
	_capture_default_keys()


func register_character(def: CharacterDefinition) -> void:
	_put(_characters, def.id if def else &"", def, "character")


func register_npc(def: NPCDefinition) -> void:
	register_character(def)
	_put(_npcs, def.id if def else &"", def, "npc")


func register_faction(def: FactionDefinition) -> void:
	_put(_factions, def.id if def else &"", def, "faction")


func register_origin(def: CharacterOriginDefinition) -> void:
	_put(_origins, def.id if def else &"", def, "origin")


func register_profession(def: ProfessionDefinition) -> void:
	_put(_professions, def.id if def else &"", def, "profession")


func register_skill(def: SkillDefinition) -> void:
	_put(_skills, def.id if def else &"", def, "skill")


func register_encounter(def: EncounterDefinition) -> void:
	_put(_encounters, def.id if def else &"", def, "encounter")


func register_item(def: ItemDefinition) -> void:
	_put(_items, def.id if def else &"", def, "item")


func register_shop(def: ShopDefinition) -> void:
	_put(_shops, def.id if def else &"", def, "shop")


func register_job(def: JobDefinition) -> void:
	_put(_jobs, def.id if def else &"", def, "job")


func register_worksite(def: WorkSiteDefinition) -> void:
	_put(_worksites, def.id if def else &"", def, "worksite")


func register_forge_recipe(def: ForgeRecipeDefinition) -> void:
	_put(_forge_recipes, def.id if def else &"", def, "forge recipe")


func register_dialogue(def: DialogueDefinition) -> void:
	_put(_dialogues, def.id if def else &"", def, "dialogue")


func register_quest(def: QuestDefinition) -> void:
	_put(_quests, def.id if def else &"", def, "quest")


func register_region(def: RegionDefinition) -> void:
	_put(_regions, def.id if def else &"", def, "region")
	# Legacy alias registration for migration and tests.
	if def != null:
		match String(def.id):
			"base:town":
				_regions[&"town"] = def
			"base:wilderness":
				_regions[&"wilderness"] = def
			"base:dungeon":
				_regions[&"dungeon"] = def


func register_dungeon(def: DungeonDefinition) -> void:
	_put(_dungeons, def.id if def else &"", def, "dungeon")


func register_house(def: HouseDefinition) -> void:
	_put(_houses, def.id if def else &"", def, "house")


func register_container(def: ContainerDefinition) -> void:
	_put(_containers, def.id if def else &"", def, "container")


func register_crop(def: CropDefinition) -> void:
	_put(_crops, def.id if def else &"", def, "crop")


func register_pet(def: PetDefinition) -> void:
	_put(_pets, def.id if def else &"", def, "pet")


func register_pet_companion(def: PetCompanionDefinition) -> void:
	_put(_pet_companions, def.id if def else &"", def, "pet companion")


func register_mount(def: MountDefinition) -> void:
	_put(_mounts, def.id if def else &"", def, "mount")


func register_schedule(def: ScheduleDefinition) -> void:
	_put(_schedules, def.id if def else &"", def, "schedule")


func register_attack(def: AttackDefinition) -> void:
	_put(_attacks, def.id if def else &"", def, "attack")


func register_enemy(def: EnemyDefinition) -> void:
	_put(_enemies, def.id if def else &"", def, "enemy")


func register_weapon(def: WeaponDefinition) -> void:
	_put(_weapons, def.id if def else &"", def, "weapon")


func register_level(def: LevelDefinition) -> void:
	_put(_levels, def.id if def else &"", def, "level")


func get_character(id: StringName) -> CharacterDefinition:
	return _characters.get(id) as CharacterDefinition


func get_npc(id: StringName) -> NPCDefinition:
	return _npcs.get(id) as NPCDefinition


func get_all_npcs() -> Array[NPCDefinition]:
	var result: Array[NPCDefinition] = []
	var ids := _npcs.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id in ids:
		var definition := _npcs[id] as NPCDefinition
		if definition != null:
			result.append(definition)
	return result


func get_all_npc_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition in get_all_npcs():
		result.append(definition.id)
	return result


func get_faction(id: StringName) -> FactionDefinition:
	return _factions.get(id) as FactionDefinition


func get_all_factions() -> Array[FactionDefinition]:
	var result: Array[FactionDefinition] = []
	for id in _sorted_keys(_factions):
		var definition := _factions[id] as FactionDefinition
		if definition != null:
			result.append(definition)
	return result


func get_selectable_factions() -> Array[FactionDefinition]:
	var result: Array[FactionDefinition] = []
	for definition in get_all_factions():
		if definition.selectable:
			result.append(definition)
	return result


func get_origin(id: StringName) -> CharacterOriginDefinition:
	return _origins.get(id) as CharacterOriginDefinition


func get_all_origins() -> Array[CharacterOriginDefinition]:
	var result: Array[CharacterOriginDefinition] = []
	for id in _sorted_keys(_origins):
		var definition := _origins[id] as CharacterOriginDefinition
		if definition != null:
			result.append(definition)
	return result


func get_all_origin_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition in get_all_origins():
		result.append(definition.id)
	return result


func get_profession(id: StringName) -> ProfessionDefinition:
	return _professions.get(id) as ProfessionDefinition


func get_all_professions() -> Array[ProfessionDefinition]:
	var result: Array[ProfessionDefinition] = []
	for id in _sorted_keys(_professions):
		var definition := _professions[id] as ProfessionDefinition
		if definition != null:
			result.append(definition)
	return result


func get_all_profession_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition in get_all_professions():
		result.append(definition.id)
	return result


func get_skill(id: StringName) -> SkillDefinition:
	return _skills.get(id) as SkillDefinition


func get_all_skills() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for id in _sorted_keys(_skills):
		var definition := _skills[id] as SkillDefinition
		if definition != null:
			result.append(definition)
	return result


func get_encounter(id: StringName) -> EncounterDefinition:
	return _encounters.get(id) as EncounterDefinition


func get_all_encounters() -> Array[EncounterDefinition]:
	var result: Array[EncounterDefinition] = []
	for id in _sorted_keys(_encounters):
		var definition := _encounters[id] as EncounterDefinition
		if definition != null:
			result.append(definition)
	return result


func get_item(id: StringName) -> ItemDefinition:
	return _items.get(id) as ItemDefinition


func get_all_items() -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for id in _sorted_keys(_items):
		var definition := _items[id] as ItemDefinition
		if definition != null:
			result.append(definition)
	return result


func get_dialogue(id: StringName) -> DialogueDefinition:
	return _dialogues.get(id) as DialogueDefinition


func get_quest(id: StringName) -> QuestDefinition:
	return _quests.get(id) as QuestDefinition


func get_region(id: StringName) -> RegionDefinition:
	return _regions.get(id) as RegionDefinition


func get_dungeon(id: StringName) -> DungeonDefinition:
	return _dungeons.get(id) as DungeonDefinition


func get_all_dungeons() -> Array[DungeonDefinition]:
	var result: Array[DungeonDefinition] = []
	for id in _sorted_keys(_dungeons):
		var definition := _dungeons[id] as DungeonDefinition
		if definition != null:
			result.append(definition)
	return result


func get_shop(id: StringName) -> ShopDefinition:
	return _shops.get(id) as ShopDefinition


func get_all_shops() -> Array[ShopDefinition]:
	var result: Array[ShopDefinition] = []
	for id in _sorted_keys(_shops):
		var definition := _shops[id] as ShopDefinition
		if definition != null:
			result.append(definition)
	return result


func get_job(id: StringName) -> JobDefinition:
	return _jobs.get(id) as JobDefinition


func get_all_jobs() -> Array[JobDefinition]:
	var result: Array[JobDefinition] = []
	for id in _sorted_keys(_jobs):
		var definition := _jobs[id] as JobDefinition
		if definition != null:
			result.append(definition)
	return result


func get_worksite(id: StringName) -> WorkSiteDefinition:
	return _worksites.get(id) as WorkSiteDefinition


func get_all_worksites() -> Array[WorkSiteDefinition]:
	var result: Array[WorkSiteDefinition] = []
	for id in _sorted_keys(_worksites):
		var definition := _worksites[id] as WorkSiteDefinition
		if definition != null:
			result.append(definition)
	return result


func get_forge_recipe(id: StringName) -> ForgeRecipeDefinition:
	return _forge_recipes.get(id) as ForgeRecipeDefinition


func get_all_forge_recipes() -> Array[ForgeRecipeDefinition]:
	var result: Array[ForgeRecipeDefinition] = []
	for id in _sorted_keys(_forge_recipes):
		var definition := _forge_recipes[id] as ForgeRecipeDefinition
		if definition != null:
			result.append(definition)
	return result


func get_all_regions() -> Array[RegionDefinition]:
	var result: Array[RegionDefinition] = []
	var seen: Dictionary = {}
	for key in _regions.keys():
		var def := _regions[key] as RegionDefinition
		if def == null:
			continue
		var id := String(def.id)
		if seen.has(id):
			continue
		seen[id] = true
		result.append(def)
	return result


func get_all_region_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for def in get_all_regions():
		result.append(def.id)
	return result


func get_house(id: StringName) -> HouseDefinition:
	return _houses.get(id) as HouseDefinition


func get_all_houses() -> Array[HouseDefinition]:
	var result: Array[HouseDefinition] = []
	for id in _sorted_keys(_houses):
		var definition := _houses[id] as HouseDefinition
		if definition != null:
			result.append(definition)
	return result


func get_all_house_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition in get_all_houses():
		result.append(definition.id)
	return result


func get_player_housing_plans() -> Array[HouseDefinition]:
	var result: Array[HouseDefinition] = []
	for definition in get_all_houses():
		if definition.player_selectable:
			result.append(definition)
	result.sort_custom(func(a: HouseDefinition, b: HouseDefinition) -> bool:
		if a.construction_cost == b.construction_cost:
			return String(a.id) < String(b.id)
		return a.construction_cost < b.construction_cost
	)
	return result


func get_container(id: StringName) -> ContainerDefinition:
	return _containers.get(id) as ContainerDefinition


func get_all_containers() -> Array[ContainerDefinition]:
	var result: Array[ContainerDefinition] = []
	for id in _sorted_keys(_containers):
		var definition := _containers[id] as ContainerDefinition
		if definition != null:
			result.append(definition)
	return result


func get_all_container_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition in get_all_containers():
		result.append(definition.id)
	return result


func get_crop(id: StringName) -> CropDefinition:
	return _crops.get(id) as CropDefinition


func get_all_crops() -> Array[CropDefinition]:
	var result: Array[CropDefinition] = []
	for id in _sorted_keys(_crops):
		var definition := _crops[id] as CropDefinition
		if definition != null:
			result.append(definition)
	return result


func get_pet(id: StringName) -> PetDefinition:
	return _pets.get(id) as PetDefinition


func get_pet_companion(id: StringName) -> PetCompanionDefinition:
	return _pet_companions.get(id) as PetCompanionDefinition


func get_all_pet_companions() -> Array[PetCompanionDefinition]:
	var result: Array[PetCompanionDefinition] = []
	for id in _sorted_keys(_pet_companions):
		var definition := _pet_companions[id] as PetCompanionDefinition
		if definition != null:
			result.append(definition)
	return result


func get_mount(id: StringName) -> MountDefinition:
	return _mounts.get(id) as MountDefinition


func get_schedule(id: StringName) -> ScheduleDefinition:
	return _schedules.get(id) as ScheduleDefinition


func get_attack(id: StringName) -> AttackDefinition:
	return _attacks.get(id) as AttackDefinition


func get_enemy(id: StringName) -> EnemyDefinition:
	return _enemies.get(id) as EnemyDefinition


func get_weapon(id: StringName) -> WeaponDefinition:
	return _weapons.get(id) as WeaponDefinition


func get_level(id: StringName) -> LevelDefinition:
	return _levels.get(id) as LevelDefinition


func load_defaults() -> void:
	_register_dir("res://content/base/", _register_content_resource, true)
	_register_dir("res://resources/characters/", register_character)
	_register_dir("res://resources/npcs/", _register_npc_resource)
	_register_dir("res://resources/factions/", register_faction)
	_register_dir("res://resources/origins/", register_origin)
	_register_dir("res://resources/professions/", register_profession)
	_register_dir("res://resources/skills/", register_skill)
	_register_dir("res://resources/items/", register_item, true)
	_register_dir("res://resources/shops/", register_shop, true)
	_register_dir("res://resources/jobs/", register_job, true)
	_register_dir("res://resources/worksites/", register_worksite, true)
	_register_dir("res://resources/forge_recipes/", register_forge_recipe, true)
	_register_dir("res://resources/dialogues/", register_dialogue)
	_register_dir("res://resources/quests/", register_quest)
	_register_dir("res://resources/regions/", register_region)
	_register_dir("res://resources/dungeons/", register_dungeon)
	_register_dir("res://resources/encounters/", register_encounter)
	_register_dir("res://resources/houses/", register_house)
	_register_dir("res://resources/containers/", register_container)
	_register_dir("res://resources/crops/", register_crop)
	_register_dir("res://resources/pets/", register_pet)
	_register_dir("res://resources/pet_companions/", register_pet_companion, true)
	_register_dir("res://resources/mounts/", register_mount)
	_register_dir("res://resources/schedules/", register_schedule)
	_register_dir("res://resources/attacks/", register_attack)
	# Legacy survival prototype
	_register_dir("res://resources/enemies/", register_enemy)
	_register_dir("res://resources/weapons/", register_weapon)
	_register_dir("res://resources/levels/", register_level)


func clear_all() -> void:
	## Test-runner teardown hook; normal gameplay keeps the default index alive.
	_characters.clear()
	_npcs.clear()
	_factions.clear()
	_origins.clear()
	_professions.clear()
	_skills.clear()
	_items.clear()
	_shops.clear()
	_jobs.clear()
	_worksites.clear()
	_forge_recipes.clear()
	_dialogues.clear()
	_quests.clear()
	_regions.clear()
	_dungeons.clear()
	_encounters.clear()
	_houses.clear()
	_containers.clear()
	_crops.clear()
	_pets.clear()
	_pet_companions.clear()
	_mounts.clear()
	_schedules.clear()
	_attacks.clear()
	_enemies.clear()
	_weapons.clear()
	_levels.clear()
	_default_keys.clear()


func clear_test_registrations() -> void:
	## Keep authored content while releasing definitions registered by a test.
	var buckets := {
		"characters": _characters,
		"npcs": _npcs,
		"factions": _factions,
		"origins": _origins,
		"professions": _professions,
		"skills": _skills,
		"items": _items,
		"shops": _shops,
		"jobs": _jobs,
		"worksites": _worksites,
		"forge_recipes": _forge_recipes,
		"dialogues": _dialogues,
		"quests": _quests,
		"regions": _regions,
		"dungeons": _dungeons,
		"encounters": _encounters,
		"houses": _houses,
		"containers": _containers,
		"crops": _crops,
		"pets": _pets,
		"pet_companions": _pet_companions,
		"mounts": _mounts,
		"schedules": _schedules,
		"attacks": _attacks,
		"enemies": _enemies,
		"weapons": _weapons,
		"levels": _levels,
	}
	for bucket_name in buckets.keys():
		var bucket: Dictionary = buckets[bucket_name]
		var defaults: Dictionary = _default_keys.get(bucket_name, {})
		for key in bucket.keys():
			if not defaults.has(key):
				bucket.erase(key)


func _capture_default_keys() -> void:
	_default_keys = {
		"characters": _characters.duplicate(false),
		"npcs": _npcs.duplicate(false),
		"factions": _factions.duplicate(false),
		"origins": _origins.duplicate(false),
		"professions": _professions.duplicate(false),
		"skills": _skills.duplicate(false),
		"items": _items.duplicate(false),
		"shops": _shops.duplicate(false),
		"jobs": _jobs.duplicate(false),
		"worksites": _worksites.duplicate(false),
		"forge_recipes": _forge_recipes.duplicate(false),
		"dialogues": _dialogues.duplicate(false),
		"quests": _quests.duplicate(false),
		"regions": _regions.duplicate(false),
		"dungeons": _dungeons.duplicate(false),
		"encounters": _encounters.duplicate(false),
		"houses": _houses.duplicate(false),
		"containers": _containers.duplicate(false),
		"crops": _crops.duplicate(false),
		"pets": _pets.duplicate(false),
		"pet_companions": _pet_companions.duplicate(false),
		"mounts": _mounts.duplicate(false),
		"schedules": _schedules.duplicate(false),
		"attacks": _attacks.duplicate(false),
		"enemies": _enemies.duplicate(false),
		"weapons": _weapons.duplicate(false),
		"levels": _levels.duplicate(false),
	}


func _register_dir(dir_path: String, registrar: Callable, recursive: bool = false) -> void:
	# ResourceLoader preserves original resource names when exported text
	# resources are remapped to binary files. DirAccess exposes the remapped
	# package entries instead, so filtering its listing for `.tres` leaves the
	# packaged definition registry empty.
	for raw_entry in ResourceLoader.list_directory(dir_path):
		var entry := String(raw_entry)
		var is_directory := entry.ends_with("/")
		var clean_entry := entry.trim_suffix("/")
		var entry_path := clean_entry if clean_entry.begins_with("res://") \
			else dir_path.path_join(clean_entry)
		if recursive and is_directory and not clean_entry.get_file().begins_with("."):
			_register_dir(entry_path + "/", registrar, true)
		elif not is_directory and clean_entry.ends_with(".tres"):
			var res: Resource = load(entry_path)
			if res != null:
				registrar.call(res)


func _register_content_resource(res: Resource) -> void:
	if res is WorldEffect or res is WorldCondition:
		pass  # Content pack resources loaded for editor reference; not indexed globally.
	elif res is DialogueSelectorDefinition:
		pass


func _register_npc_resource(res: Resource) -> void:
	## The NPC folder also contains authoritative mind resources. Only full
	## NPCDefinition resources belong in the runtime definition registry.
	if res is NPCDefinition:
		register_npc(res as NPCDefinition)


func _put(bucket: Dictionary, id: StringName, value: Resource, kind: String) -> void:
	if id == &"" or value == null:
		push_error("ResourceRegistry: refusing empty %s definition" % kind)
		return
	if bucket.has(id):
		push_error("ResourceRegistry: duplicate %s id '%s'" % [kind, String(id)])
		return
	bucket[id] = value


func _sorted_keys(bucket: Dictionary) -> Array:
	var ids := bucket.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	return ids
