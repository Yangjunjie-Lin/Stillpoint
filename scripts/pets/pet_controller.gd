class_name PetController
extends CharacterBody3D
## World actor for a program-authoritative pet companion.

signal state_changed(reason: StringName)
signal autonomous_dialogue_requested(context: Dictionary)
signal downed(source: Node)
signal recovered_from_downed()

enum Mode { FOLLOW, STAY }

@export var pet_id: StringName = &"mossfox"
@export var region_id: StringName = &"base:town"
@export var follow_distance: float = 2.5
@export var move_speed: float = 4.4
@export var pet_definition: PetCompanionDefinition
@export_range(0.1, 24.0, 0.1) var downed_recovery_game_hours: float = 6.0
@export_range(0.1, 24.0, 0.1) var life_skill_practice_interval_game_hours: float = 1.0

var mode: Mode = Mode.FOLLOW
var bond: float = 0.0
var unlocked: bool = true
var runtime_state := PetRuntimeState.new()
var behavior_runtime: PetBehaviorRuntime
var _owner: PlayerController3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _desired_destination: Vector3
var _should_move: bool = false
var _speed_scale: float = 1.0
var _motion_override: StringName = &""
var _motion_override_remaining: float = 0.0
var _recent_owner_interaction: float = 0.0
var _downed_game_hours: float = 0.0
var _life_skill_game_hours: float = 0.0
var _last_world_time_minutes: int = -1
var _present_in_current_region: bool = true


func _ready() -> void:
	# Pets do not physically shove the owner, but can be hit by hostile hitboxes.
	collision_layer = 0
	collision_mask = 1
	if pet_definition == null:
		pet_definition = ResourceRegistry.get_pet_companion(pet_id)
	if pet_definition == null:
		pet_definition = _build_safe_definition()
	if runtime_state.get_definition_id() == &"":
		runtime_state.initialize(
			pet_definition,
			_resolve_persistent_id(),
			&"base:player/main",
			pet_definition.display_name,
		)
	_sync_legacy_fields()
	behavior_runtime = get_node_or_null("PetBehaviorRuntime") as PetBehaviorRuntime
	if behavior_runtime == null:
		behavior_runtime = PetBehaviorRuntime.new()
		behavior_runtime.name = "PetBehaviorRuntime"
		add_child(behavior_runtime)
	behavior_runtime.setup(self, _owner, runtime_state, pet_definition)
	behavior_runtime.movement_intent_requested.connect(_on_movement_intent)
	behavior_runtime.attack_intent_requested.connect(_on_attack_intent)
	behavior_runtime.autonomous_dialogue_suggested.connect(_on_autonomous_dialogue)
	runtime_state.state_changed.connect(_on_runtime_state_changed)
	_last_world_time_minutes = WorldTimeService.get_total_minutes()
	_sync_species_visual()
	_sync_equipment_visuals()


func configure_definition(
	definition: PetCompanionDefinition,
	instance_id: StringName,
	owner_id: StringName = &"base:player/main",
) -> bool:
	if is_node_ready() or definition == null or not definition.is_valid() \
			or instance_id == &"" or owner_id == &"":
		return false
	pet_definition = definition
	pet_id = definition.id
	return runtime_state.initialize(
		definition, instance_id, owner_id, definition.display_name
	)


func setup(owner: PlayerController3D) -> void:
	_owner = owner
	if behavior_runtime != null:
		behavior_runtime.set_companion_owner(owner)
	if _last_world_time_minutes < 0:
		_last_world_time_minutes = WorldTimeService.get_total_minutes()


func _physics_process(delta: float) -> void:
	_sync_runtime_from_legacy()
	if not _present_in_current_region or not visible or process_mode == Node.PROCESS_MODE_DISABLED:
		return
	_recent_owner_interaction = maxf(0.0, _recent_owner_interaction - delta * 0.08)
	if _motion_override_remaining > 0.0:
		_motion_override_remaining = maxf(0.0, _motion_override_remaining - delta)
		if _motion_override_remaining <= 0.0:
			_motion_override = &""
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	var world_context := _build_world_context()
	# Movement intents are edge-free policy output: a frame that emits no intent
	# means stop. In particular this clears the previous follow destination as
	# soon as a legacy STAY command is synchronized into the runtime state.
	_should_move = false
	if behavior_runtime != null:
		behavior_runtime.tick(delta, world_context)
	if _should_move:
		var direction := _desired_destination - global_position
		direction.y = 0.0
		if direction.length() > 0.35:
			var equipment_speed := float(
				runtime_state.get_equipment_effects().move_speed_bonus
			)
			var speed := (move_speed + equipment_speed) \
				* clampf(_speed_scale, 0.25, 2.0)
			velocity.x = direction.normalized().x * speed
			velocity.z = direction.normalized().z * speed
			look_at(global_position + Vector3(velocity.x, 0.0, velocity.z), Vector3.UP)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_should_move = false
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 5.0)
	move_and_slide()
	_update_presentation()


func receive_damage(amount: float, source: Node, _context: Dictionary = {}) -> float:
	if not _present_in_current_region or runtime_state.get_current_health() <= 0.0:
		return 0.0
	var dealt := runtime_state.take_damage(amount)
	if dealt <= 0.0:
		return 0.0
	_should_move = false
	velocity = Vector3.ZERO
	if runtime_state.get_current_health() <= 0.0:
		_downed_game_hours = 0.0
		play_action(&"downed", downed_recovery_game_hours * 60.0)
		downed.emit(source)
	else:
		play_action(&"hurt", 0.45)
	return dealt


func advance_game_time(game_hours: float, offline: bool = false) -> bool:
	## Called from trusted clock/session code. Offline simulation is deliberately
	## deterministic and never spawns combat or requests dialogue.
	if not is_finite(game_hours) or game_hours <= 0.0:
		return false
	var activity := behavior_runtime.current_activity if behavior_runtime != null \
		else PetBehaviorRuntime.ACTIVITY_IDLE
	var resting := offline or activity in [
		PetBehaviorRuntime.ACTIVITY_IDLE,
		PetBehaviorRuntime.ACTIVITY_REST,
		PetBehaviorRuntime.ACTIVITY_DOWNED,
	]
	var changed := runtime_state.advance_needs(game_hours, resting)
	if runtime_state.get_current_health() <= 0.0:
		_downed_game_hours += game_hours
		if _downed_game_hours >= downed_recovery_game_hours \
				and runtime_state.recover_from_downed(0.25):
			_downed_game_hours = 0.0
			_motion_override = &""
			_motion_override_remaining = 0.0
			recovered_from_downed.emit()
			changed = true
	if not runtime_state.is_following() and runtime_state.get_current_health() > 0.0:
		_life_skill_game_hours += game_hours
		while _life_skill_game_hours >= life_skill_practice_interval_game_hours:
			_life_skill_game_hours -= life_skill_practice_interval_game_hours
			changed = _practice_current_lifestyle(offline) or changed
	return changed


func sync_game_clock(offline: bool = false) -> float:
	var current_minutes := WorldTimeService.get_total_minutes()
	if _last_world_time_minutes < 0:
		_last_world_time_minutes = current_minutes
		return 0.0
	var elapsed_minutes := maxi(0, current_minutes - _last_world_time_minutes)
	_last_world_time_minutes = current_minutes
	var game_hours := float(elapsed_minutes) / 60.0
	if game_hours > 0.0:
		advance_game_time(game_hours, offline)
	return game_hours


func update_region_presence(current_region: StringName) -> bool:
	sync_game_clock(not _present_in_current_region)
	var normalized := RegionIdUtil.normalize(current_region)
	var should_be_present := runtime_state.is_following() \
		or RegionIdUtil.normalize(runtime_state.get_stay_region_id()) == normalized
	_present_in_current_region = should_be_present
	visible = should_be_present
	set_physics_process(should_be_present)
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.disabled = not should_be_present
	var hurtbox := get_node_or_null("PetHurtbox3D") as Area3D
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", should_be_present)
	var interactable := get_node_or_null("PetInteractable") as Interactable
	if interactable != null:
		interactable.interaction_enabled = should_be_present
	if should_be_present:
		region_id = normalized
		_sync_identity_region(normalized)
		if runtime_state.is_following():
			teleport_to_owner()
		else:
			_move_to_authored_stay_marker()
	return should_be_present


func is_present_in_current_region() -> bool:
	return _present_in_current_region


func toggle_mode() -> void:
	runtime_state.set_following(not runtime_state.is_following())
	runtime_state.apply_owner_interaction(&"follow_command", 1.0, 1.0)
	_recent_owner_interaction = 1.0
	_sync_legacy_fields()


func set_following(following: bool) -> bool:
	var changed := runtime_state.set_following(following)
	_sync_legacy_fields()
	if changed:
		var world := get_tree().get_first_node_in_group("world_manager") as WorldSession
		if world != null:
			update_region_presence(world.current_region_id)
	return changed


func teleport_to_owner() -> void:
	if _owner == null or not runtime_state.is_following():
		return
	var stable_hash := absi(String(runtime_state.get_pet_instance_id()).hash())
	var angle := float(stable_hash % 6283) / 1000.0
	var radius := 1.8 + float((stable_hash / 6283) % 4) * 0.25
	global_position = _owner.global_position + Vector3(
		cos(angle) * radius, 0.0, sin(angle) * radius
	)
	region_id = _owner.current_region_id
	_sync_identity_region(region_id)
	reset_physics_interpolation()


func feed_from_inventory(inventory: InventoryComponent, slot_index: int) -> bool:
	if inventory == null:
		return false
	var stack := inventory.get_slot(slot_index)
	if stack == null or stack.is_empty():
		return false
	var item := ResourceRegistry.get_item(stack.item_id)
	if item == null or not item.is_pet_food():
		return false
	var hunger_before := runtime_state.get_hunger()
	var affection_before := runtime_state.get_affection()
	# Feeding a full pet is permitted as a bonding treat, but only one real item
	# is removed and every state delta is program-authored.
	if inventory.remove_from_slot(slot_index, 1) != 1:
		return false
	runtime_state.feed(item.pet_nutrition, item.pet_mood_gain, item.pet_affection_gain)
	if is_equal_approx(runtime_state.get_hunger(), hunger_before) \
			and is_equal_approx(runtime_state.get_affection(), affection_before):
		# The resource is valid but all values were zero; rollback defensively.
		inventory.add_item(item.id, 1)
		return false
	_recent_owner_interaction = 1.0
	play_action(&"eat", 1.8)
	return true


func equip_from_inventory(
	inventory: InventoryComponent,
	inventory_slot_index: int,
	slot_id: StringName,
) -> bool:
	var changed := runtime_state.equip_from_inventory(
		slot_id, inventory, inventory_slot_index
	)
	if changed:
		_sync_equipment_visuals()
	return changed


func unequip_to_inventory(slot_id: StringName, inventory: InventoryComponent) -> bool:
	var changed := runtime_state.unequip_to_inventory(slot_id, inventory)
	if changed:
		_sync_equipment_visuals()
	return changed


func set_dialogue_motion(active: bool) -> void:
	if active:
		play_action(&"talk", 3.0)
	elif _motion_override == &"talk":
		_motion_override = &""
		_motion_override_remaining = 0.0


func play_action(action: StringName, duration: float = 1.0) -> void:
	_motion_override = action
	_motion_override_remaining = maxf(0.0, duration)
	_update_presentation()


func get_display_name() -> String:
	var nickname := runtime_state.get_nickname()
	return nickname if not nickname.is_empty() else pet_definition.display_name


func get_persistence_key() -> StringName:
	return &"pet"


func capture_state() -> Dictionary:
	return to_dict()


func restore_state(data: Dictionary) -> void:
	from_dict(data)


func get_state_version() -> int:
	return PetRuntimeState.SECTION_VERSION


func to_dict() -> Dictionary:
	_sync_runtime_from_legacy()
	var data := runtime_state.to_dict()
	data["pet_id"] = String(pet_id)
	data["bond"] = runtime_state.get_affection()
	data["mode"] = mode
	data["unlocked"] = unlocked
	data["region_id"] = String(region_id)
	data["position"] = {
		"x": global_position.x,
		"y": global_position.y,
		"z": global_position.z,
	}
	if behavior_runtime != null:
		data["behavior_runtime"] = behavior_runtime.capture_runtime_state()
	return data


func from_dict(data: Dictionary) -> void:
	if pet_definition == null:
		pet_definition = ResourceRegistry.get_pet_companion(
			StringName(str(data.get("definition_id", data.get("pet_id", pet_id))))
		)
	if pet_definition == null:
		pet_definition = _build_safe_definition()
	var migrated := data.duplicate(true)
	var is_legacy := int(migrated.get("section_version", 0)) == 0
	if is_legacy and str(migrated.get("pet_id", "")) in [
		"placeholder_pet", "pet",
	]:
		migrated["pet_id"] = String(pet_definition.id)
	# Only the scene controller can resolve the canonical world instance. Older
	# placeholder saves had no instance_id, so bind them to the authored
	# WorldEntityIdentity instead of accepting the domain migration fallback.
	# PetRuntimeState intentionally keeps its context-free fallback for callers
	# that do not own a world entity.
	if is_legacy and str(migrated.get("instance_id", "")).strip_edges().is_empty():
		migrated["instance_id"] = String(_resolve_persistent_id())
	if not runtime_state.from_dict(migrated, pet_definition):
		push_warning("PetController: rejected invalid companion state")
		return
	pet_id = runtime_state.get_definition_id()
	region_id = StringName(str(data.get("region_id", runtime_state.get_stay_region_id())))
	var pos: Variant = data.get("position", {})
	if pos is Dictionary and not (pos as Dictionary).is_empty():
		global_position = Vector3(
			float(pos.get("x", global_position.x)),
			float(pos.get("y", global_position.y)),
			float(pos.get("z", global_position.z)),
		)
	if behavior_runtime != null and data.get("behavior_runtime", {}) is Dictionary:
		behavior_runtime.restore_runtime_state(data.get("behavior_runtime", {}))
	_last_world_time_minutes = WorldTimeService.get_total_minutes()
	_sync_legacy_fields()
	_sync_species_visual()
	_sync_equipment_visuals()


func _build_world_context() -> Dictionary:
	var hostiles: Array = []
	var world := get_tree().get_first_node_in_group("world_manager") as WorldSession
	if world != null and world.entity_repository != null:
		for entity in world.entity_repository.get_loaded_entities_in_region(region_id):
			if entity == self or entity == _owner or not entity is NPCController:
				continue
			var npc := entity as NPCController
			if npc.is_downed or npc.is_permanently_dead or npc.npc_definition == null:
				continue
			if npc.npc_definition.npc_role != &"enemy":
				continue
			hostiles.append({
				"target": npc,
				"hostile": true,
				"alive": true,
				"persistent_id": String(NPCIdentityResolver.resolve_persistent_id(npc)),
				"position": npc.global_position,
				"threat_to_owner": npc.npc_state in [NPCController.NPCState.CHASE, NPCController.NPCState.ATTACK],
				"is_boss": npc.npc_definition.dungeon_boss_id != &"",
			})
	return {
		"health_ratio": runtime_state.get_health_ratio(),
		"stamina_ratio": runtime_state.get_stamina_ratio(),
		"hunger_ratio": runtime_state.get_hunger_ratio(),
		"hostiles": hostiles,
		"combat_enabled": true,
		"owner_position": _owner.global_position if _owner != null else global_position,
		"owner_busy": _owner == null or not _owner.state.input_enabled,
		"dialogue_available": bool(SaveService.settings.get("ai_dialogue_enabled", false)),
		"dialogue_opportunity": _recent_owner_interaction > 0.7,
		"owner_interaction_score": _recent_owner_interaction,
		# The player-selected authored marker is distinct from the current region.
		# Keeping it here prevents a long stay from rewriting `farmyard` into a
		# synthetic `region:base:farmland` location.
		"current_location_id": runtime_state.get_stay_location_id(),
		"current_region_id": region_id,
		"activity_targets": {
			"rest": global_position,
			"forage": global_position + global_transform.basis.x * 2.0,
			"guard": _owner.global_position if _owner != null else global_position,
			# -Z is the authored/model forward direction throughout Godot gameplay.
			"explore": global_position - global_transform.basis.z * 3.0,
			"train": global_position + global_transform.basis.x * -2.0,
		},
	}


func _on_movement_intent(destination: Vector3, speed_scale: float, _reason: StringName) -> void:
	_desired_destination = destination
	_speed_scale = speed_scale
	_should_move = true


func _on_attack_intent(target: Variant, attack_skill_id: StringName) -> void:
	if not target is CharacterController:
		return
	var actor := target as CharacterController
	if actor.is_downed or actor.is_permanently_dead:
		return
	var skill := pet_definition.get_skill(attack_skill_id)
	if skill == null or not skill.is_attack_skill():
		return
	if global_position.distance_to(actor.global_position) > skill.range + 0.5:
		_desired_destination = actor.global_position
		_should_move = true
		return
	if not runtime_state.spend_stamina(skill.stamina_cost):
		return
	# Damage is authored by PetSkillDefinition and applied through the target's
	# canonical receive_damage API. The provider has no path into this method.
	var equipment_attack := float(runtime_state.get_equipment_effects().attack_bonus)
	actor.receive_damage(skill.base_power + equipment_attack, self, {
		"attack_id": String(skill.id),
		"blockable": true,
		"from_pet": true,
	})
	runtime_state.practice_skill(skill.id)
	play_action(&"pounce", 0.7)


func _practice_current_lifestyle(offline: bool) -> bool:
	var lifestyle := pet_definition.get_lifestyle(runtime_state.get_lifestyle_id()) \
		if pet_definition != null else null
	if lifestyle == null:
		return false
	var changed := false
	var multiplier := maxf(0.1, lifestyle.activity_multiplier)
	if offline:
		multiplier *= 0.5
	for skill_id in lifestyle.practiced_life_skill_ids:
		var skill := pet_definition.get_skill(skill_id)
		if skill == null or skill.is_attack_skill():
			continue
		changed = runtime_state.practice_skill(
			skill.id, skill.proficiency_gain_per_use * multiplier
		) > 0.0 or changed
	return changed


func _sync_identity_region(value: StringName) -> void:
	var identity := get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if identity != null:
		identity.region_id = value
	var interactable := get_node_or_null("PetInteractable") as Interactable
	if interactable != null:
		interactable.region_id = value


func _move_to_authored_stay_marker() -> void:
	var world := get_tree().get_first_node_in_group("world_manager") as WorldSession
	if world == null or world.region_service == null:
		return
	var marker := world.region_service.find_spawn(runtime_state.get_stay_location_id())
	global_position = marker.origin
	reset_physics_interpolation()


func _on_autonomous_dialogue(context: Dictionary) -> void:
	if not bool(SaveService.settings.get("pet_proactive_dialogue_enabled", true)):
		return
	autonomous_dialogue_requested.emit(context.duplicate(true))


func _on_runtime_state_changed(_revision: int, reason: StringName) -> void:
	_sync_legacy_fields()
	if reason in [&"follow_mode", &"stay_location"]:
		var world := get_tree().get_first_node_in_group("world_manager") as WorldSession
		if world != null:
			update_region_presence(world.current_region_id)
	state_changed.emit(reason)


func _sync_legacy_fields() -> void:
	mode = Mode.FOLLOW if runtime_state.is_following() else Mode.STAY
	bond = runtime_state.get_affection()
	unlocked = runtime_state.is_unlocked()


func _sync_runtime_from_legacy() -> void:
	# Save v0 and existing gameplay callers expose mode/bond as mutable fields.
	# Capture both values first: changing follow mode emits synchronously and the
	# compatibility signal handler refreshes every legacy field.
	if runtime_state.get_definition_id() == &"":
		return
	var requested_mode := mode
	var requested_bond := bond
	if not is_finite(requested_bond):
		_sync_legacy_fields()
		return
	var requested_following := requested_mode == Mode.FOLLOW
	if runtime_state.is_following() != requested_following:
		runtime_state.set_following(requested_following)
	var affection_delta := requested_bond - runtime_state.get_affection()
	if not is_zero_approx(affection_delta):
		runtime_state.apply_owner_interaction(
			&"legacy_controller_compatibility", 0.0, affection_delta
		)


func _sync_equipment_visuals() -> void:
	var model := get_node_or_null("VisualRoot/PetModel") as StylizedPetModel
	if model != null:
		model.set_equipment(
			runtime_state.get_equipped_item(&"collar"),
			runtime_state.get_equipped_item(&"body"),
			runtime_state.get_equipped_item(&"charm"),
		)


func _sync_species_visual() -> void:
	var model := get_node_or_null("VisualRoot/PetModel") as StylizedPetModel
	if model != null and pet_definition != null:
		model.configure_species(pet_definition.species)


func _update_presentation() -> void:
	var model := get_node_or_null("VisualRoot/PetModel") as StylizedPetModel
	if model == null:
		return
	if _motion_override != &"":
		model.set_motion_state(_motion_override)
	elif behavior_runtime != null:
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		model.set_motion_state(
			(&"run" if horizontal_speed > move_speed * 1.05 else &"walk")
			if horizontal_speed > 0.1
			else behavior_runtime.current_activity
		)
	else:
		model.set_motion_state(&"idle")


func _resolve_persistent_id() -> StringName:
	var identity := get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if identity != null and identity.persistent_id != &"":
		return identity.persistent_id
	return StringName("base:player/pet/%s_0001" % String(pet_id))


func _build_safe_definition() -> PetCompanionDefinition:
	var species := PetSpeciesDefinition.new()
	species.id = &"mossfox"
	species.display_name = "Moss Fox"
	species.description = "A nimble fox-like companion native to Greywake."
	species.species_tags = [&"fox", &"small_companion", &"quadruped"]
	species.habitat_tags = [&"farmland", &"wilderness", &"home"]
	species.preferred_food_tags = [&"meat", &"grain", &"fresh_food"]
	species.base_max_health = 46.0
	species.base_max_stamina = 68.0
	species.natural_defense = 1.5
	species.hunger_per_game_hour = 0.8
	var personality := PetPersonalityProfile.new()
	personality.id = &"curious_loyal"
	personality.display_name = "Curious and Loyal"
	personality.courage = 0.62
	personality.curiosity = 0.9
	personality.sociability = 0.76
	personality.loyalty = 0.9
	personality.playfulness = 0.82
	personality.aggression = 0.42
	var attributes := PetAttributeProfile.new()
	attributes.vitality = 8
	attributes.endurance = 9
	attributes.agility = 12
	attributes.perception = 12
	attributes.focus = 8
	var home := PetLifestyleDefinition.new()
	home.id = &"home_companion"
	home.display_name = "Home Companion"
	home.description = "Rest, play, and guard the player's home."
	home.permitted_program_action_ids = [&"rest", &"guard", &"socialize"]
	var forager := PetLifestyleDefinition.new()
	forager.id = &"forager"
	forager.display_name = "Trail Forager"
	forager.description = "Search safe nearby ground and practice scent work."
	forager.permitted_program_action_ids = [&"forage", &"explore", &"return_home"]
	forager.practiced_life_skill_ids = [&"scent_foraging"]
	var guardian := PetLifestyleDefinition.new()
	guardian.id = &"guardian"
	guardian.display_name = "House Guardian"
	guardian.description = "Stay alert near an assigned safe place."
	guardian.permitted_program_action_ids = [&"guard", &"train", &"rest"]
	guardian.permits_independent_combat = true
	var scent := PetSkillDefinition.new()
	scent.id = &"scent_foraging"
	scent.display_name = "Scent Foraging"
	scent.description = "Recognize safe nearby forage by scent."
	scent.program_action_id = &"pet_forage"
	scent.governing_attribute = &"perception"
	var pounce := PetSkillDefinition.new()
	pounce.id = &"moon_pounce"
	pounce.display_name = "Moon Pounce"
	pounce.description = "A quick protective pounce against a program-confirmed hostile."
	pounce.kind = PetSkillDefinition.SkillKind.ATTACK
	pounce.program_action_id = &"pet_melee_pounce"
	pounce.stamina_cost = 8.0
	pounce.cooldown_seconds = 0.8
	pounce.base_power = 9.0
	pounce.range = 2.0
	var collar := PetEquipmentSlotDefinition.new()
	collar.id = &"collar"
	collar.display_name = "Collar"
	collar.accepted_item_tags = [&"pet_collar"]
	collar.allowed_species_tags = [&"fox", &"small_companion"]
	collar.required_item_fit_tags = [&"fox"]
	collar.maximum_weight = 2.0
	var body := PetEquipmentSlotDefinition.new()
	body.id = &"body"
	body.display_name = "Body Gear"
	body.accepted_item_tags = [&"pet_armor"]
	body.allowed_species_tags = [&"small_companion"]
	body.required_item_fit_tags = [&"fox"]
	body.maximum_weight = 4.0
	var charm := PetEquipmentSlotDefinition.new()
	charm.id = &"charm"
	charm.display_name = "Charm"
	charm.accepted_item_tags = [&"pet_charm"]
	charm.required_item_fit_tags = [&"fox"]
	charm.maximum_weight = 1.0
	var definition := PetCompanionDefinition.new()
	definition.id = &"mossfox"
	definition.display_name = "Pip"
	definition.biography = "A bright-eyed moss fox adopted near Stillpoint's farmland."
	definition.species = species
	definition.personality = personality
	definition.base_attributes = attributes
	definition.lifestyles = [home, forager, guardian]
	definition.default_lifestyle_id = &"home_companion"
	definition.life_skills = [scent]
	definition.attack_skills = [pounce]
	definition.equipment_slots = [collar, body, charm]
	definition.server_dialogue_profile_id = &"pet:mossfox"
	definition.speech_style_tags = [&"short", &"warm", &"sensory", &"playful"]
	definition.llm_advisory_intent_ids = [&"seek_affection", &"comment_on_world"]
	definition.default_stay_region_id = &"base:player_home"
	definition.default_stay_location_id = &"pet_rest_area"
	return definition
