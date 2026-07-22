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
var current_region_id: StringName = &""


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
	if p_region_service != null:
		current_region_id = p_region_service.get_current_region_id()


func with_event(event: GameplayEvent) -> WorldSessionContext:
	var copy := WorldSessionContext.new(
		world_session, player, entity_repository, region_service,
		quest_manager, world_flags, event,
	)
	return copy
