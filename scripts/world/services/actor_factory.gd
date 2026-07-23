class_name ActorFactory
extends Node
## Creates and restores character actors from definitions and snapshots.

@export var default_npc_scene: PackedScene
@export var default_player_scene: PackedScene

var _entity_repository: WorldEntityRepository = null


func setup(repository: WorldEntityRepository) -> void:
	_entity_repository = repository


func spawn_actor(definition_id: StringName, context: ActorSpawnContext) -> CharacterController:
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
	var actor_node := scene.instantiate()
	var actor := actor_node as CharacterController
	if actor == null:
		if actor_node != null:
			actor_node.free()
		return null
	var parent := context.parent
	if parent == null:
		push_error("ActorFactory: missing parent")
		actor.free()
		return null
	# Apply identity and definition BEFORE add_child so _ready sees them.
	_apply_identity(actor, context, definition_id)
	if npc_def != null and actor is NPCController:
		actor.set("npc_definition", npc_def)
		actor.set("definition", npc_def)
		actor.set("character_id", npc_def.id)
	elif def != null:
		actor.set("definition", def)
		actor.set("character_id", def.id)
	parent.add_child(actor)
	if context.transform != Transform3D.IDENTITY:
		actor.global_transform = context.transform
	if context.snapshot != null:
		restore_snapshot_to_actor(actor, context.snapshot)
	if not ActorSceneValidator.validate(actor):
		push_error("ActorFactory: scene contract failed for %s" % String(definition_id))
		actor.queue_free()
		return null
	if _entity_repository != null:
		_entity_repository.register_entity(actor)
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


func _apply_identity(actor: Node, context: ActorSpawnContext, definition_id: StringName) -> void:
	var identity := _ensure_identity(actor)
	if context.persistent_id != &"":
		identity.persistent_id = context.persistent_id
	if context.region_id != &"":
		identity.region_id = context.region_id
	identity.definition_id = definition_id
	if identity.persistent_id == &"":
		identity.persistent_id = StringName("base:%s/actor/%s" % [
			String(RegionIdUtil.normalize(context.region_id)).trim_prefix("base:"),
			String(definition_id),
		])


func _ensure_identity(actor: Node) -> WorldEntityIdentity:
	for child in actor.get_children():
		if child is WorldEntityIdentity:
			return child as WorldEntityIdentity
	var identity := WorldEntityIdentity.new()
	identity.name = "WorldEntityIdentity"
	actor.add_child(identity)
	return identity
