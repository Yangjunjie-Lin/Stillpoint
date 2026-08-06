class_name NPCCognitionSaveProvider
extends SaveSectionProvider

const SECTION_ID := &"npc_cognition"
const SECTION_VERSION := 1

var backend_player_profile_id: String = ""
var world_save_id: String = "slot-01"
var cache := NPCMemoryCache.new()
var _dirty: bool = false

func get_section_id() -> StringName: return SECTION_ID
func get_section_version() -> int: return SECTION_VERSION
func is_dirty() -> bool: return _dirty

func capture_save_data() -> Dictionary:
	var data := cache.to_dict()
	data["section_version"] = SECTION_VERSION
	data["backend_player_profile_id"] = backend_player_profile_id
	data["world_save_id"] = world_save_id
	return data

func restore_save_data(data: Dictionary) -> bool:
	## Save v4 from 0.7.1 legitimately has no cognition section.
	if data.is_empty():
		backend_player_profile_id = ""
		world_save_id = "slot-01"
		cache.clear()
		_dirty = false
		return true
	if int(data.get("section_version", 1)) > SECTION_VERSION: return false
	backend_player_profile_id = str(data.get("backend_player_profile_id", ""))
	world_save_id = str(data.get("world_save_id", "slot-01"))
	if not cache.from_dict(data): return false
	_dirty = false
	return true

func mark_dirty() -> void: _dirty = true
func clear_dirty() -> void: _dirty = false

func delete_npc_memory(npc_persistent_id: String) -> void:
	cache.delete_npc(backend_player_profile_id, world_save_id, npc_persistent_id)
	mark_dirty()

func delete_all_player_memory() -> void:
	cache.delete_player(backend_player_profile_id)
	mark_dirty()

func export_memory_data() -> Dictionary:
	return cache.export_player_data(backend_player_profile_id)
