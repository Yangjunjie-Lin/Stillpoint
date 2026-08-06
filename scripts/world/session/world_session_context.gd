class_name WorldSessionContext
extends RefCounted
## Read-only service bundle for Conditions, Effects, and Coordinators.

var world_session: Node = null
var player: PlayerController3D = null
var entity_repository: WorldEntityRepository = null
var region_service: RegionRuntimeService = null
var quest_manager: Node = null
var world_flags: WorldFlagService = null
var gameplay_event: GameplayEvent = null
# Deprecated compatibility property. It is intentionally computed on every read so
# older Effects cannot retain the Region that happened to be active at construction.
var current_region_id: StringName:
	get:
		return get_current_region_id()


func _init(
	p_world_session: Node = null,
	p_player: PlayerController3D = null,
	p_entity_repository: WorldEntityRepository = null,
	p_region_service: RegionRuntimeService = null,
	p_quest_manager: Node = null,
	p_world_flags: WorldFlagService = null,
	p_event: GameplayEvent = null,
) -> void:
	world_session = p_world_session
	player = p_player
	entity_repository = p_entity_repository
	region_service = p_region_service
	quest_manager = p_quest_manager
	world_flags = p_world_flags
	gameplay_event = p_event


func get_current_region_id() -> StringName:
	if region_service != null:
		return RegionIdUtil.normalize(region_service.get_current_region_id())

	if world_session != null:
		var value: Variant = world_session.get("current_region_id")
		if value != null:
			return RegionIdUtil.normalize(StringName(str(value)))

	return &""


func with_event(event: GameplayEvent) -> WorldSessionContext:
	var copy := WorldSessionContext.new(
		world_session, player, entity_repository, region_service,
		quest_manager, world_flags, event,
	)
	return copy
