extends Node
## Global static definition index. Runtime state must never live here.

var _characters: Dictionary = {}
var _npcs: Dictionary = {}
var _factions: Dictionary = {}
var _skills: Dictionary = {}
var _items: Dictionary = {}
var _dialogues: Dictionary = {}
var _quests: Dictionary = {}
var _regions: Dictionary = {}
var _pets: Dictionary = {}
var _mounts: Dictionary = {}
var _schedules: Dictionary = {}
var _attacks: Dictionary = {}
# Legacy survival prototype buckets
var _enemies: Dictionary = {}
var _weapons: Dictionary = {}
var _levels: Dictionary = {}


func _ready() -> void:
	load_defaults()


func register_character(def: CharacterDefinition) -> void:
	_put(_characters, def.id if def else &"", def, "character")


func register_npc(def: NPCDefinition) -> void:
	register_character(def)
	_put(_npcs, def.id if def else &"", def, "npc")


func register_faction(def: FactionDefinition) -> void:
	_put(_factions, def.id if def else &"", def, "faction")


func register_skill(def: SkillDefinition) -> void:
	_put(_skills, def.id if def else &"", def, "skill")


func register_item(def: ItemDefinition) -> void:
	_put(_items, def.id if def else &"", def, "item")


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


func register_pet(def: PetDefinition) -> void:
	_put(_pets, def.id if def else &"", def, "pet")


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


func get_faction(id: StringName) -> FactionDefinition:
	return _factions.get(id) as FactionDefinition


func get_skill(id: StringName) -> SkillDefinition:
	return _skills.get(id) as SkillDefinition


func get_item(id: StringName) -> ItemDefinition:
	return _items.get(id) as ItemDefinition


func get_dialogue(id: StringName) -> DialogueDefinition:
	return _dialogues.get(id) as DialogueDefinition


func get_quest(id: StringName) -> QuestDefinition:
	return _quests.get(id) as QuestDefinition


func get_region(id: StringName) -> RegionDefinition:
	return _regions.get(id) as RegionDefinition


func get_pet(id: StringName) -> PetDefinition:
	return _pets.get(id) as PetDefinition


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
	_register_dir("res://resources/npcs/", register_npc)
	_register_dir("res://resources/factions/", register_faction)
	_register_dir("res://resources/skills/", register_skill)
	_register_dir("res://resources/items/", register_item)
	_register_dir("res://resources/dialogues/", register_dialogue)
	_register_dir("res://resources/quests/", register_quest)
	_register_dir("res://resources/regions/", register_region)
	_register_dir("res://resources/pets/", register_pet)
	_register_dir("res://resources/mounts/", register_mount)
	_register_dir("res://resources/schedules/", register_schedule)
	_register_dir("res://resources/attacks/", register_attack)
	# Legacy survival prototype
	_register_dir("res://resources/enemies/", register_enemy)
	_register_dir("res://resources/weapons/", register_weapon)
	_register_dir("res://resources/levels/", register_level)


func _register_dir(dir_path: String, registrar: Callable, recursive: bool = false) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if recursive and dir.current_is_dir() and not file_name.begins_with("."):
			_register_dir(dir_path.path_join(file_name), registrar, true)
		elif not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(dir_path.path_join(file_name))
			if res != null:
				registrar.call(res)
		file_name = dir.get_next()
	dir.list_dir_end()


func _register_content_resource(res: Resource) -> void:
	if res is WorldEffect or res is WorldCondition:
		pass  # Content pack resources loaded for editor reference; not indexed globally.
	elif res is DialogueSelectorDefinition:
		pass


func _put(bucket: Dictionary, id: StringName, value: Resource, kind: String) -> void:
	if id == &"" or value == null:
		push_error("ResourceRegistry: refusing empty %s definition" % kind)
		return
	if bucket.has(id):
		push_error("ResourceRegistry: duplicate %s id '%s'" % [kind, String(id)])
		return
	bucket[id] = value
