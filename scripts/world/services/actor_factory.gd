class_name ActorFactory
extends Node
## Creates and restores character actors from definitions and snapshots.

signal actor_spawned(actor: CharacterController)

@export var default_npc_scene: PackedScene
@export var default_player_scene: PackedScene

var _entity_repository: WorldEntityRepository = null
var _region_service: RegionRuntimeService = null


func setup(
	repository: WorldEntityRepository,
	region_service: RegionRuntimeService = null,
) -> void:
	_entity_repository = repository
	_region_service = region_service


func set_region_service(region_service: RegionRuntimeService) -> void:
	_region_service = region_service


func spawn_actor(definition_id: StringName, context: ActorSpawnContext) -> CharacterController:
	if context == null:
		push_error("ActorFactory: missing spawn context")
		return null
	var persistent_id := _resolve_actor_persistent_id(context, context.snapshot)
	if persistent_id == &"":
		push_error(
			"ActorFactory: refusing persistent actor with no persistent_id (%s)"
			% String(definition_id)
		)
		return null
	var normalized_region := _resolve_actor_region(context, context.snapshot)
	if normalized_region == &"":
		push_error("ActorFactory: refusing persistent actor with no region (%s)" % String(definition_id))
		return null
	context.region_id = normalized_region
	var npc_def := ResourceRegistry.get_npc(definition_id)
	var char_def := ResourceRegistry.get_character(definition_id)
	var def: CharacterDefinition = npc_def if npc_def != null else char_def
	if def == null:
		push_error("ActorFactory: unknown definition %s" % String(definition_id))
		return null
	var scene: PackedScene = null
	if npc_def != null and npc_def.character_scene != null:
		scene = npc_def.character_scene
	elif def.character_scene != null:
		scene = def.character_scene
	elif default_npc_scene != null:
		scene = default_npc_scene
	if scene == null:
		push_error("ActorFactory: no scene for %s" % String(definition_id))
		return null
	var parent := context.parent
	if parent == null:
		push_error("ActorFactory: missing parent")
		return null
	var actor_node := scene.instantiate()
	var actor := actor_node as CharacterController
	if actor == null:
		if actor_node != null:
			actor_node.free()
		push_error("ActorFactory: scene root is not CharacterController for %s" % String(definition_id))
		return null
	# Apply identity, region and definition BEFORE add_child so _ready sees them.
	_apply_identity(actor, context, definition_id, normalized_region, persistent_id)
	if npc_def != null and actor is NPCController:
		actor.set("npc_definition", npc_def)
		actor.set("definition", npc_def)
		actor.set("character_id", npc_def.id)
	elif def != null:
		actor.set("definition", def)
		actor.set("character_id", def.id)
	if not ActorSceneValidator.validate(actor):
		push_error("ActorFactory: scene contract failed for %s" % String(definition_id))
		actor.free()
		return null
	parent.add_child(actor)
	if context.transform != Transform3D.IDENTITY:
		actor.global_transform = context.transform
	if context.snapshot != null:
		restore_snapshot_to_actor(actor, context.snapshot)
	# Snapshot component data can carry an older controller region. Metadata wins.
	_sync_actor_region(actor, normalized_region, context.snapshot)
	if _entity_repository != null:
		if not _entity_repository.register_entity(actor):
			actor.queue_free()
			return null
	actor_spawned.emit(actor)
	return actor


func restore_actor(snapshot: EntitySnapshot, parent: Node) -> CharacterController:
	if snapshot == null or snapshot.destroyed:
		return null
	if _entity_repository != null and _entity_repository.get_loaded_entity(snapshot.persistent_id) != null:
		var existing := _entity_repository.get_loaded_entity(snapshot.persistent_id)
		if existing is CharacterController:
			restore_snapshot_to_actor(existing as CharacterController, snapshot)
			return existing as CharacterController
	var ctx := ActorSpawnContext.new()
	ctx.definition_id = snapshot.definition_id
	ctx.persistent_id = snapshot.persistent_id
	ctx.region_id = snapshot.region_id
	ctx.parent = parent
	ctx.snapshot = snapshot
	if snapshot.transform_data.has("position"):
		var pos: Dictionary = snapshot.transform_data["position"]
		ctx.transform = Transform3D(
			Basis.IDENTITY,
			Vector3(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)), float(pos.get("z", 0.0))),
		)
	return spawn_actor(snapshot.definition_id, ctx)


func restore_snapshot_to_actor(actor: CharacterController, snapshot: EntitySnapshot) -> void:
	if actor is Node3D and snapshot != null:
		snapshot.apply_to_node(actor as Node3D)
		_sync_actor_region(actor, RegionIdUtil.normalize(snapshot.region_id), snapshot)


func _resolve_actor_region(
	context: ActorSpawnContext,
	snapshot: EntitySnapshot = null,
) -> StringName:
	var snapshot_region := &""
	if snapshot != null:
		snapshot_region = RegionIdUtil.normalize(snapshot.region_id)
	var context_region := &""
	if context != null:
		context_region = RegionIdUtil.normalize(context.region_id)
	if snapshot_region != &"":
		if context_region != &"" and context_region != snapshot_region:
			push_warning(
				"ActorFactory: snapshot region %s overrides spawn context region %s for %s"
				% [String(snapshot_region), String(context_region), String(snapshot.persistent_id)]
			)
		return snapshot_region
	if context_region != &"":
		return context_region
	if _region_service != null:
		return RegionIdUtil.normalize(_region_service.get_current_region_id())
	return &""


func _resolve_actor_persistent_id(
	context: ActorSpawnContext,
	snapshot: EntitySnapshot = null,
) -> StringName:
	if snapshot != null and snapshot.persistent_id != &"":
		return snapshot.persistent_id
	if context != null:
		return context.persistent_id
	return &""


func _apply_identity(
	actor: CharacterController,
	context: ActorSpawnContext,
	definition_id: StringName,
	normalized_region: StringName,
	persistent_id: StringName,
) -> void:
	var identity := _ensure_identity(actor)
	identity.persistent_id = persistent_id
	identity.region_id = normalized_region
	identity.definition_id = definition_id
	identity.runtime_spawned = context.snapshot != null and context.snapshot.runtime_spawned
	actor.region_id = normalized_region


func _sync_actor_region(
	actor: CharacterController,
	normalized_region: StringName,
	snapshot: EntitySnapshot = null,
) -> void:
	if actor == null or normalized_region == &"":
		return
	actor.region_id = normalized_region
	var identity := _ensure_identity(actor)
	identity.region_id = normalized_region
	if snapshot != null:
		identity.runtime_spawned = snapshot.runtime_spawned
		snapshot.region_id = normalized_region


func _ensure_identity(actor: Node) -> WorldEntityIdentity:
	for child in actor.get_children():
		if child is WorldEntityIdentity:
			return child as WorldEntityIdentity
	var identity := WorldEntityIdentity.new()
	identity.name = "WorldEntityIdentity"
	actor.add_child(identity)
	return identity
