class_name WorldSession
extends Node3D
## Thin world session coordinator; initializes services and exposes read-only APIs.

signal region_changed(region_id: StringName)
signal restore_failed(reason: StringName)

@export var player_scene: PackedScene
@export var initial_region_id: StringName = &"base:town"
@export var autosave_interval: float = 60.0

var event_bus := GameplayEventBus.new()
var player: PlayerController3D
var current_region_id: StringName = &""
var discovered_regions: Array = ["base:town"]
var unlocked_pet_ids: Array = []
var unlocked_mount_ids: Array = []
var _autosave_timer: float = 0.0
var _autosave_enabled: bool = true
var _restore_failed_state: bool = false
var _session_context: WorldSessionContext
var _pending_player_transform: Dictionary = {}
var _skip_saved_player_transform: bool = false

@onready var persistent_root: Node3D = $PersistentRoot
@onready var player_root: Node3D = $PersistentRoot/PlayerRoot
@onready var companion_root: Node3D = $PersistentRoot/CompanionRoot
@onready var active_region_slot: Node3D = $ActiveRegionSlot
@onready var world_services: Node = $WorldServices
@onready var entity_repository: WorldEntityRepository = $WorldServices/WorldEntityRepository
@onready var actor_factory: ActorFactory = $WorldServices/ActorFactory
@onready var region_service: RegionRuntimeService = $WorldServices/RegionRuntimeService
@onready var interaction_index: InteractionIndex = $WorldServices/InteractionIndex
@onready var dialogue_coordinator: DialogueCoordinator = $WorldServices/DialogueCoordinator
@onready var quest_event_router: QuestEventRouter = $WorldServices/QuestEventRouter
@onready var quest_coordinator: QuestCoordinator = $WorldServices/QuestCoordinator
@onready var save_coordinator: WorldSaveCoordinator = $WorldServices/WorldSaveCoordinator
@onready var simulation_service: WorldSimulationService = $WorldServices/WorldSimulationService
@onready var world_flags: WorldFlagService = $WorldServices/WorldFlagService
@onready var cognition_service: NPCCognitionService = $WorldServices/NPCCognitionService
@onready var dungeon_progression_service: DungeonProgressionService = $WorldServices/DungeonProgressionService
@onready var property_bank_service: PropertyBankService = $WorldServices/PropertyBankService

# Compatibility aliases for tests and legacy code paths.
var regions_root: Node3D
var actors_root: Node3D
var interactables_root: Node3D


func _ready() -> void:
	add_to_group("world_manager")
	regions_root = active_region_slot
	actors_root = companion_root
	interactables_root = active_region_slot
	_setup_services()
	_spawn_player()
	_spawn_companions()
	var start_region := RegionIdUtil.normalize(initial_region_id)
	if GameManager.resume_requested:
		var validation := SaveSlotService.inspect_adventure_summary()
		var restored := false
		if bool(validation.get("valid", false)):
			restored = save_coordinator.restore_session()
		GameManager.resume_requested = false
		if restored:
			current_region_id = region_service.get_current_region_id()
			if current_region_id == &"":
				restored = false
		if not restored:
			var reason := StringName(str(validation.get("reason", "restore_failed")))
			if reason == &"":
				reason = &"restore_failed"
			_handle_restore_failure(reason)
			return
	else:
		region_service.enter_region(start_region)
		current_region_id = region_service.get_current_region_id()
	region_service.region_changed.connect(_on_region_changed)
	if EventBus.has_signal("request_world_save"):
		EventBus.request_world_save.connect(save_world_state)


func _process(delta: float) -> void:
	if not _autosave_enabled or _restore_failed_state:
		return
	_autosave_timer += delta
	if _autosave_timer >= autosave_interval:
		_autosave_timer = 0.0
		# Autosave always marks core sections; regions only if dirty.
		save_coordinator.mark_dirty(&"player")
		save_coordinator.mark_dirty(&"global_world")
		save_coordinator.save_dirty_sections()


func _physics_process(_delta: float) -> void:
	if _restore_failed_state:
		return
	if player != null:
		var nearby := interaction_index.query_nearby(player, 3.0)
		player.update_interaction_targets(nearby)


func transition_to(
	region_id: StringName,
	spawn_id: StringName = &"spawn",
	via_portal: bool = true,
) -> void:
	var ctx := RegionTransitionContext.new()
	ctx.source_region_id = current_region_id
	ctx.target_spawn_id = spawn_id
	ctx.via_portal = via_portal
	if player != null:
		player.set_input_enabled(false)
	region_service.enter_region(region_id, spawn_id, ctx)
	if player != null:
		player.set_input_enabled(true)
	discover_region(region_id)
	save_world_state()


func discover_region(region_id: StringName) -> void:
	var norm := String(RegionIdUtil.normalize(region_id))
	if not discovered_regions.has(norm):
		discovered_regions.append(norm)
		save_coordinator.mark_dirty(&"global_world")


func save_world_state() -> bool:
	# A failed restore must remain read-only until this partial session is removed.
	if _restore_failed_state or not _autosave_enabled or player == null:
		return false
	save_coordinator.mark_dirty(&"player")
	save_coordinator.mark_dirty(&"global_world")
	save_coordinator.mark_dirty(&"relationships")
	save_coordinator.mark_dirty(&"quests")
	save_coordinator.mark_dirty(&"world_flags")
	save_coordinator.mark_dirty(&"companions")
	save_coordinator.mark_region_dirty(region_service.get_current_region_id())
	return save_coordinator.save_dirty_sections()


func load_world_state() -> bool:
	var restored := save_coordinator.restore_session()
	if restored:
		return true
	var validation := SaveSlotService.inspect_adventure_summary()
	var reason := StringName(str(validation.get("reason", "restore_failed")))
	if reason == &"":
		reason = &"restore_failed"
	_handle_restore_failure(reason)
	return false


func _handle_restore_failure(reason: StringName = &"restore_failed") -> void:
	if _restore_failed_state:
		return
	_restore_failed_state = true
	_autosave_enabled = false
	_autosave_timer = 0.0
	set_process(false)
	set_physics_process(false)
	if player != null:
		player.set_input_enabled(false)
	if region_service != null:
		region_service.unload_current_region()
	current_region_id = &""
	_pending_player_transform.clear()
	GameManager.run_active = false
	restore_failed.emit(reason)
	push_error(
		"WorldSession: restore failed (%s); returning to the main menu without saving"
		% String(reason)
	)
	SceneRouter.call_deferred("go_to_main_menu")


func start_dialogue(npc: NPCController) -> bool:
	return dialogue_coordinator.start_dialogue(npc, player)


func apply_dialogue_choice(index: int) -> void:
	dialogue_coordinator.apply_choice(index)


func ask_active_npc(text: String) -> bool:
	return dialogue_coordinator.start_free_form_from_active(text)


func cancel_free_form_dialogue() -> void:
	dialogue_coordinator.cancel_free_form()


func cancel_active_dialogue() -> void:
	dialogue_coordinator.cancel_dialogue()


func capture_player_data() -> Dictionary:
	var inventory_data := player.inventory.to_dict() if player.inventory else {}
	var equipment_data := player.equipment.to_dict() if player.equipment else {}
	var player_data := player.to_dict()
	player_data.erase("inventory")
	player_data.erase("equipment")
	player_data["region_id"] = String(current_region_id)
	return {
		"player": player_data,
		"inventory": inventory_data,
		"equipment": equipment_data,
	}


func restore_player_data(data: Dictionary) -> void:
	if player == null:
		return
	var player_data: Dictionary = data.get("player", {})
	_pending_player_transform = player_data.get("position", {})
	# Restore non-transform fields first; position applied after region load.
	var saved_pos := player.global_position
	player.from_dict(player_data)
	player.global_position = saved_pos
	if player.inventory != null:
		player.inventory.from_dict(data.get("inventory", {}))
	if player.equipment != null:
		player.equipment.from_dict(data.get("equipment", {}))
	player.apply_equipment_bonuses()


func apply_saved_player_transform(data: Dictionary) -> void:
	if player == null:
		return
	if _skip_saved_player_transform:
		_skip_saved_player_transform = false
		_pending_player_transform.clear()
		return
	var player_data: Dictionary = data.get("player", data)
	var pos: Dictionary = player_data.get("position", _pending_player_transform)
	if pos.is_empty():
		return
	player.global_position = Vector3(
		float(pos.get("x", player.global_position.x)),
		float(pos.get("y", player.global_position.y)),
		float(pos.get("z", player.global_position.z)),
	)
	player.reset_physics_interpolation()
	_pending_player_transform.clear()


func capture_global_world_data() -> Dictionary:
	return {
		"world_time": WorldTimeService.to_dict(),
		"discovered_regions": discovered_regions.duplicate(),
		"current_region_id": String(current_region_id),
		"property_banking": property_bank_service.capture_save_data()
			if property_bank_service != null else {},
	}


func restore_global_world_data(data: Dictionary) -> void:
	var discovered: Variant = data.get("discovered_regions", ["base:town"])
	if typeof(discovered) == TYPE_ARRAY:
		discovered_regions.clear()
		for d in discovered:
			discovered_regions.append(String(RegionIdUtil.normalize(StringName(str(d)))))
	if discovered_regions.is_empty():
		discovered_regions = ["base:town"]
	if property_bank_service != null:
		property_bank_service.restore_save_data(
			data.get("property_banking", {}) as Dictionary
			if data.get("property_banking", {}) is Dictionary else {}
		)


func open_property_storage(mode: StringName) -> bool:
	if property_bank_service == null or player == null:
		return false
	if mode == PropertyBankService.HOME_STORAGE_MODE and not property_bank_service.has_active_house():
		return false
	var menu := get_node_or_null("WorldUI/PropertyStorageMenu")
	if menu == null or not menu.has_method("open_menu"):
		return false
	menu.call("open_menu", mode)
	return true


func resolve_restored_region_id(region_id: StringName) -> StringName:
	if (
		region_id == &"base:player_home"
		and property_bank_service != null
		and not property_bank_service.has_active_house()
	):
		_skip_saved_player_transform = true
		call_deferred("_notify_repossessed_return")
		return &"base:town"
	return region_id


func _notify_repossessed_return() -> void:
	EventBus.notice_requested.emit(
		"Your residence was reclaimed during your absence. Stillpoint Bank holds the compensation and every stored belonging."
	)


func capture_companions() -> Dictionary:
	return {
		"pets": _serialize_pet(),
		"mounts": _serialize_mount(),
		"unlocked_pet_ids": unlocked_pet_ids.duplicate(),
		"unlocked_mount_ids": unlocked_mount_ids.duplicate(),
	}


func restore_companions(data: Dictionary) -> void:
	_restore_pet(data.get("pets", {}))
	_restore_mount(data.get("mounts", {}))
	unlocked_pet_ids = data.get("unlocked_pet_ids", []).duplicate()
	unlocked_mount_ids = data.get("unlocked_mount_ids", []).duplicate()


func unlock_pet(pet_id: StringName) -> bool:
	var key := String(pet_id)
	if key.is_empty():
		return false
	if not unlocked_pet_ids.has(key):
		unlocked_pet_ids.append(key)
		save_coordinator.mark_dirty(&"companions")
	return true


func unlock_mount(mount_id: StringName) -> bool:
	var key := String(mount_id)
	if key.is_empty():
		return false
	if not unlocked_mount_ids.has(key):
		unlocked_mount_ids.append(key)
		save_coordinator.mark_dirty(&"companions")
	return true


func get_session_context() -> WorldSessionContext:
	return _session_context


func _setup_services() -> void:
	actor_factory.setup(entity_repository)
	region_service.setup(self, entity_repository, actor_factory, interaction_index)
	dungeon_progression_service.setup(self, actor_factory)
	property_bank_service.setup(self)
	# Resolved from WorldSession root via RegionRuntimeService._get_slot().
	region_service.active_region_slot_path = NodePath("ActiveRegionSlot")
	save_coordinator.setup(self, entity_repository, region_service, world_flags)
	if not property_bank_service.property_state_changed.is_connected(_on_property_state_changed):
		property_bank_service.property_state_changed.connect(_on_property_state_changed)
	simulation_service.setup(entity_repository)
	_session_context = WorldSessionContext.new(
		self, null, entity_repository, region_service,
		QuestManager, world_flags,
	)
	cognition_service.setup(_session_context, event_bus, entity_repository)
	if not save_coordinator.register_save_provider(cognition_service.save_provider):
		push_error("WorldSession: failed to register the shared cognition save provider")
	dialogue_coordinator.setup(_session_context, cognition_service)
	quest_coordinator.setup(_session_context)
	quest_event_router.setup(_session_context, event_bus, quest_coordinator)


func _spawn_player() -> void:
	if player_scene == null:
		return
	player = player_scene.instantiate() as PlayerController3D
	player_root.add_child(player)
	player.add_to_group("player")
	var identity := WorldEntityIdentity.new()
	identity.name = "WorldEntityIdentity"
	identity.persistent_id = &"base:player/main"
	identity.definition_id = &"player"
	identity.region_id = RegionIdUtil.normalize(initial_region_id)
	identity.persistence_policy = WorldEntityIdentity.PersistencePolicy.GLOBAL
	player.add_child(identity)
	entity_repository.register_entity(player)
	_session_context.player = player
	if not GameManager.resume_requested:
		player.apply_character_build(GameManager.consume_pending_character_build(), true)
		_grant_starter_inventory()
	if player.inventory != null and not player.inventory.inventory_changed.is_connected(_on_player_items_changed):
		player.inventory.inventory_changed.connect(_on_player_items_changed)
	if player.equipment != null and not player.equipment.equipment_changed.is_connected(_on_player_items_changed):
		player.equipment.equipment_changed.connect(_on_player_items_changed)
	if player.experience != null and not player.experience.experience_changed.is_connected(_on_player_progression_changed):
		player.experience.experience_changed.connect(_on_player_progression_changed)
	var camera_rig := get_node_or_null("CameraRig") as CameraController3D
	if camera_rig != null:
		camera_rig.set_target(player)


func _on_property_state_changed() -> void:
	if save_coordinator != null:
		save_coordinator.mark_dirty(&"global_world")


func _spawn_companions() -> void:
	var pet := companion_root.get_node_or_null("Pet") as PetController
	if pet != null and player != null:
		pet.setup(player)
		var pid := pet.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
		if pid != null:
			entity_repository.register_entity(pet)
	var mount := companion_root.get_node_or_null("Mount") as MountController
	if mount != null:
		var mid := mount.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
		if mid != null:
			entity_repository.register_entity(mount)


func _grant_starter_inventory() -> void:
	if player == null or player.inventory == null:
		return
	var profession := ResourceRegistry.get_profession(player.profession_id)
	if not StarterKitCalculator.grant(player.inventory, profession):
		push_warning("WorldSession: invalid profession starter kit; using safe default")
		if not StarterKitCalculator.grant_safe_default(player.inventory):
			push_error("WorldSession: could not grant safe starter inventory")
	if not StarterKitCalculator.grant_farming_essentials(player.inventory):
		push_error("WorldSession: could not grant farming essentials")
	if not StarterKitCalculator.grant_utility_essentials(player.inventory):
		push_error("WorldSession: could not grant utility essentials")


func _on_player_progression_changed(_current: int, _to_next: int, _level: int) -> void:
	if save_coordinator != null:
		save_coordinator.mark_dirty(&"player")


func _serialize_pet() -> Dictionary:
	var pet := companion_root.get_node_or_null("Pet") as PetController
	if pet == null:
		return {}
	return pet.to_dict()


func _serialize_mount() -> Dictionary:
	var mount := companion_root.get_node_or_null("Mount") as MountController
	if mount == null:
		return {}
	return mount.to_dict()


func _restore_pet(data: Dictionary) -> void:
	var pet := companion_root.get_node_or_null("Pet") as PetController
	if pet != null and not data.is_empty():
		pet.from_dict(data)
		pet.setup(player)


func _restore_mount(data: Dictionary) -> void:
	var mount := companion_root.get_node_or_null("Mount") as MountController
	if mount != null and not data.is_empty():
		mount.from_dict(data)


func _on_region_changed(_previous: StringName, current: StringName) -> void:
	current_region_id = current
	region_changed.emit(current)
	EventBus.region_changed.emit(current)
	var pet := companion_root.get_node_or_null("Pet") as PetController
	if pet != null:
		pet.teleport_to_owner()
	var ev := GameplayEvent.make(
		GameplayEventTypes.REGION_ENTERED,
		&"base:player/main",
		&"",
		&"",
		current,
	)
	event_bus.emit_event(ev)


func _on_player_items_changed() -> void:
	if save_coordinator != null:
		save_coordinator.mark_dirty(&"player")
