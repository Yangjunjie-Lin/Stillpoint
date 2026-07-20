class_name ResourceRegistry
extends RefCounted
## Indexes static definitions by id. Runtime state must never live here.

var _enemies: Dictionary = {}
var _items: Dictionary = {}
var _weapons: Dictionary = {}
var _levels: Dictionary = {}


func register_enemy(def: EnemyDefinition) -> void:
	_put(_enemies, def.id if def else &"", def, "enemy")


func register_item(def: ItemDefinition) -> void:
	_put(_items, def.id if def else &"", def, "item")


func register_weapon(def: WeaponDefinition) -> void:
	_put(_weapons, def.id if def else &"", def, "weapon")


func register_level(def: LevelDefinition) -> void:
	_put(_levels, def.id if def else &"", def, "level")


func get_enemy(id: StringName) -> EnemyDefinition:
	return _enemies.get(id) as EnemyDefinition


func get_item(id: StringName) -> ItemDefinition:
	return _items.get(id) as ItemDefinition


func get_weapon(id: StringName) -> WeaponDefinition:
	return _weapons.get(id) as WeaponDefinition


func get_level(id: StringName) -> LevelDefinition:
	return _levels.get(id) as LevelDefinition


func load_defaults() -> void:
	_register_dir("res://resources/enemies/", register_enemy)
	_register_dir("res://resources/items/", register_item)
	_register_dir("res://resources/weapons/", register_weapon)
	_register_dir("res://resources/levels/", register_level)


func _register_dir(dir_path: String, registrar: Callable) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(dir_path.path_join(file_name))
			if res != null:
				registrar.call(res)
		file_name = dir.get_next()
	dir.list_dir_end()


func _put(bucket: Dictionary, id: StringName, value: Resource, kind: String) -> void:
	if id == &"" or value == null:
		push_error("ResourceRegistry: refusing empty %s definition" % kind)
		return
	if bucket.has(id):
		push_error("ResourceRegistry: duplicate %s id '%s'" % [kind, String(id)])
		return
	bucket[id] = value
