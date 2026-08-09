class_name NPCCognitionSaveProvider
extends SaveSectionProvider

signal dirty_changed

const SECTION_ID := &"npc_cognition"
const SECTION_VERSION := 1

var backend_player_profile_id: String = ""
var world_save_id: String = "slot-01"
var cache := NPCMemoryCache.new()
var _dirty: bool = false

func _init() -> void:
	cache.changed.connect(_on_cache_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and cache != null \
		and cache.changed.is_connected(_on_cache_changed):
		cache.changed.disconnect(_on_cache_changed)

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
		# setup() has already supplied the private, install-owned identity for
		# this runtime. An older save with no cognition section must not erase it.
		cache.clear(false)
		_dirty = false
		return true
	if int(data.get("section_version", 1)) > SECTION_VERSION: return false
	var saved_player_profile_id := str(data.get("backend_player_profile_id", "")).strip_edges()
	var saved_world_save_id := str(data.get("world_save_id", "")).strip_edges()
	var runtime_player_profile_id := backend_player_profile_id.strip_edges()
	var runtime_world_save_id := world_save_id.strip_edges()
	var has_install_owned_runtime_scope := not runtime_player_profile_id.is_empty()
	if not cache.from_dict(data): return false
	# The install-owned runtime scope wins whenever setup() supplied it. This
	# prevents a copied or stale save from splitting dialogue and gameplay-event
	# cognition across different player identities.
	if has_install_owned_runtime_scope:
		backend_player_profile_id = runtime_player_profile_id
		world_save_id = runtime_world_save_id
		if saved_player_profile_id != runtime_player_profile_id \
			or saved_world_save_id != runtime_world_save_id:
			# Cognition state is private to its exact player/save scope. Never
			# migrate memories, sessions or pending writes across identities.
			cache.clear(false)
			mark_dirty()
			return true
	else:
		backend_player_profile_id = saved_player_profile_id
		if not saved_world_save_id.is_empty():
			world_save_id = saved_world_save_id
	_dirty = false
	return true

func mark_dirty() -> void:
	_dirty = true
	dirty_changed.emit()
func clear_dirty() -> void: _dirty = false

func delete_npc_memory(npc_persistent_id: String) -> void:
	cache.delete_npc(backend_player_profile_id, world_save_id, npc_persistent_id)
	mark_dirty()

func delete_all_player_memory() -> void:
	cache.delete_player(backend_player_profile_id)
	mark_dirty()

func export_memory_data() -> Dictionary:
	return cache.export_player_data(backend_player_profile_id)

func _on_cache_changed(_reason: StringName) -> void:
	mark_dirty()
