class_name PlayerController3D
extends CharacterController

const CHARACTER_BUILD_SECTION_VERSION: int = CharacterBuildCalculator.BUILD_SECTION_VERSION

@export var camera_rig_path: NodePath
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.0
@export var acceleration: float = 18.0
@export var deceleration: float = 22.0

var hotbar := HotbarController.new()
var inventory: InventoryComponent
var equipment: EquipmentComponent
var experience: ExperienceComponent
var current_region_id: StringName = &"town"
var origin_id: StringName = GameManager.DEFAULT_ORIGIN_ID
var selected_faction_id: StringName = GameManager.DEFAULT_FACTION_ID
var profession_id: StringName = GameManager.DEFAULT_PROFESSION_ID
var appearance_options: Dictionary = CharacterAppearanceOptions.default_options()
var attribute_seed: int = GameManager.DEFAULT_ATTRIBUTE_SEED
var attribute_generation_version: int = CharacterBuildCalculator.ATTRIBUTE_GENERATION_VERSION
var attribute_points: Dictionary = CharacterBuildCalculator.roll_attribute_points(attribute_seed)

var _camera: Camera3D
var _collision_shape: CollisionShape3D
var _appearance_controller: PlayerAppearanceController
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _jump_velocity: float = 6.5
var _walk_speed: float = 4.0
var _run_speed: float = 7.0
var _crouch_speed: float = 2.5
var _base_max_health: float = 120.0
var _base_max_energy: float = 100.0
var _base_walk_speed: float = 4.0
var _base_run_speed: float = 7.0
var _base_crouch_speed: float = 2.5
var _base_defense: float = 0.0
var _base_energy_regen: float = 0.0
var _character_build_bonuses: Dictionary = CharacterBuildCalculator.empty_bonuses()


func _ready() -> void:
	super._ready()
	inventory = get_node_or_null("InventoryComponent") as InventoryComponent
	equipment = get_node_or_null("EquipmentComponent") as EquipmentComponent
	experience = get_node_or_null("ExperienceComponent") as ExperienceComponent
	_appearance_controller = get_node_or_null(
		"VisualRoot/CharacterModel"
	) as PlayerAppearanceController
	_collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	_resolve_camera()
	if combat != null:
		var hb := get_node_or_null("CombatPivot/HitboxRoot/Hitbox3D") as Hitbox3D
		if hb == null:
			hb = get_node_or_null("HitboxRoot/Hitbox3D") as Hitbox3D
		if hb != null:
			combat.hitbox = hb
			hb.source = self
			hb.team = &"player"
		var sweep := get_node_or_null("MeleeSweepRoot/MeleeSweep3D") as MeleeSweep3D
		if sweep != null:
			combat.melee_sweep = sweep
			sweep.source = self
			sweep.team = &"player"
		combat.light_attack_ids = [&"attack_light_1", &"attack_light_2", &"attack_light_3"]
	if definition != null:
		_jump_velocity = definition.jump_velocity
		_base_max_health = definition.max_health
		_base_max_energy = definition.max_energy
		_base_walk_speed = definition.walk_speed
		_base_run_speed = definition.run_speed
		_base_crouch_speed = definition.crouch_speed
	_base_defense = health.defense if health != null else 0.0
	_base_energy_regen = energy.regen_per_second if energy != null else 0.0
	if equipment != null and not equipment.equipment_changed.is_connected(apply_equipment_bonuses):
		equipment.equipment_changed.connect(apply_equipment_bonuses)
	if equipment != null and not equipment.equipment_changed.is_connected(_sync_loadout_visuals):
		equipment.equipment_changed.connect(_sync_loadout_visuals)
	if inventory != null and not inventory.inventory_changed.is_connected(_sync_loadout_visuals):
		inventory.inventory_changed.connect(_sync_loadout_visuals)
	if inventory != null and not inventory.inventory_changed.is_connected(apply_equipment_bonuses):
		inventory.inventory_changed.connect(apply_equipment_bonuses)
	if not hotbar.selection_changed.is_connected(_on_hotbar_selection_changed):
		hotbar.selection_changed.connect(_on_hotbar_selection_changed)
	if experience != null:
		if not experience.experience_changed.is_connected(_on_experience_changed):
			experience.experience_changed.connect(_on_experience_changed)
		if not experience.leveled_up.is_connected(_on_leveled_up):
			experience.leveled_up.connect(_on_leveled_up)
		_on_experience_changed(
			experience.current_experience,
			experience.experience_to_next_level,
			experience.level,
		)
	if not EventBus.combat_hit_confirmed.is_connected(_on_combat_hit_confirmed):
		EventBus.combat_hit_confirmed.connect(_on_combat_hit_confirmed)
	if not EventBus.combat_block_confirmed.is_connected(_on_combat_block_confirmed):
		EventBus.combat_block_confirmed.connect(_on_combat_block_confirmed)
	apply_character_build(GameManager.get_default_character_build(), true)


func _physics_process(delta: float) -> void:
	var knockback := get_node_or_null("KnockbackComponent") as KnockbackComponent
	if not state.input_enabled:
		velocity.y -= _gravity * delta
		if knockback != null:
			velocity += knockback.get_combined_horizontal()
			knockback.tick(delta)
		move_and_slide()
		return
	game_time += delta
	if state.can_move():
		_handle_movement(delta, knockback)
	else:
		velocity.y -= _gravity * delta
		if knockback != null:
			velocity += knockback.get_combined_horizontal()
			knockback.tick(delta)
		move_and_slide()
	if energy != null:
		energy.tick(delta, state.is_running and is_on_floor(), combat.is_guarding if combat else false)
	var anim := get_node_or_null("CombatAnimationController") as CombatAnimationController
	if anim != null:
		anim.set_locomotion(velocity, is_on_floor(), state.is_crouching)


func _unhandled_input(event: InputEvent) -> void:
	if not state.input_enabled:
		return
	if event.is_action_pressed(&"toggle_walk_run"):
		if state.is_crouching or (combat != null and combat.is_guarding):
			return
		if energy != null and energy.is_fatigued:
			state.is_running = false
		else:
			state.is_running = not state.is_running
	elif event.is_action_pressed(&"jump"):
		_try_jump()
	elif event.is_action_pressed(&"crouch"):
		_set_crouching(true)
	elif event.is_action_released(&"crouch"):
		_try_stand()
	elif event.is_action_pressed(&"normal_attack"):
		if combat != null and state.can_attack():
			combat.request_attack(&"attack_light_1")
	elif event.is_action_pressed(&"interact"):
		_try_interact()
	elif event.is_action_pressed(&"hotbar_next"):
		hotbar.select_next()
	elif event.is_action_pressed(&"hotbar_previous"):
		hotbar.select_previous()
	elif event.is_action_pressed(&"use_hotbar_item"):
		use_selected_hotbar_item()
	else:
		for index in HotbarController.SLOT_COUNT:
			if event.is_action_pressed(StringName("hotbar_slot_%d" % (index + 1))):
				hotbar.select_index(index)
				break

	if combat != null:
		combat.set_guarding(Input.is_action_pressed(&"guard") and state.can_attack())


func _handle_movement(delta: float, knockback: KnockbackComponent = null) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0
	var input_dir := MovementMotor.get_input_direction()
	var speed := _crouch_speed if state.is_crouching else (_run_speed if state.is_running else _walk_speed)
	if state.is_running and energy != null and energy.is_fatigued:
		state.is_running = false
		speed = _walk_speed
	var camera_basis := _camera.global_transform.basis if _camera else global_transform.basis
	velocity = MovementMotor.compute_velocity(
		self, camera_basis, input_dir, velocity, speed, acceleration, deceleration, delta
	)
	velocity = MovementMotor.clamp_diagonal_speed(velocity, speed)
	if knockback != null:
		velocity += knockback.get_combined_horizontal()
		knockback.tick(delta)
	if input_dir.length_squared() > 0.001:
		var look := Vector3(velocity.x, 0.0, velocity.z).normalized()
		if look.length_squared() > 0.001:
			look_at(global_position + look, Vector3.UP)
	move_and_slide()


func _try_jump() -> void:
	if not is_on_floor() or state.is_crouching:
		return
	if combat != null and combat.is_attacking:
		return
	velocity.y = _jump_velocity


func _set_crouching(value: bool) -> void:
	state.is_crouching = value
	if value:
		state.is_running = false
		_apply_crouch_height(crouch_height)
	else:
		_apply_crouch_height(stand_height)


func _try_stand() -> bool:
	if not _has_headroom():
		return false
	_set_crouching(false)
	return true


func _has_headroom() -> bool:
	var space := get_world_3d().direct_space_state if get_world_3d() else null
	if space == null or _collision_shape == null:
		return true
	var from := global_position
	var to := global_position + Vector3.UP * (stand_height - crouch_height + 0.2)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	return space.intersect_ray(query).is_empty()


func _apply_crouch_height(height: float) -> void:
	if _collision_shape != null and _collision_shape.shape is CapsuleShape3D:
		(_collision_shape.shape as CapsuleShape3D).height = height


func _try_interact() -> void:
	if interaction == null:
		return
	var context := InteractionContext.new(self)
	context.world_time = game_time
	context.region_id = current_region_id
	interaction.try_interact(self, context)


func update_interaction_targets(nodes: Array) -> void:
	if interaction != null:
		interaction.update_target(self, nodes)


func get_interaction_prompt() -> String:
	if interaction == null or interaction.current_target == null:
		return ""
	var key := InputBindingService.get_display_text(&"interact") if has_node("/root/InputBindingService") else "F"
	return "[%s] %s" % [key, interaction.current_target.get_interaction_text(self)]


func use_selected_hotbar_item() -> bool:
	return use_inventory_slot(hotbar.get_inventory_slot_index())


func get_selected_item_definition() -> ItemDefinition:
	if inventory == null:
		return null
	var stack := inventory.get_slot(hotbar.get_inventory_slot_index())
	if stack == null or stack.is_empty():
		return null
	return ResourceRegistry.get_item(stack.item_id)


func get_attack_motion_state() -> StringName:
	var selected := get_selected_item_definition()
	return &"tool_attack" if selected != null and selected.is_combat_tool() else &"attack"


func use_inventory_slot(index: int) -> bool:
	if inventory == null:
		return false
	var stack := inventory.get_slot(index)
	if stack == null or stack.is_empty():
		return false
	var item_definition := ResourceRegistry.get_item(stack.item_id)
	if item_definition == null:
		return false
	if item_definition.equip_slot != ItemDefinition.EquipSlot.NONE:
		return equipment != null and equipment.equip_from_inventory(
			inventory, index, int(item_definition.equip_slot)
		)
	if item_definition.use_kind == ItemDefinition.UseKind.TOOL_ACTION:
		if combat == null or item_definition.tool_attack_id == &"":
			return false
		var activated := combat.request_attack(item_definition.tool_attack_id)
		if activated:
			EventBus.notice_requested.emit("Used %s." % item_definition.display_name)
		return activated
	if item_definition.use_kind != ItemDefinition.UseKind.CONSUME:
		return false
	if item_definition.is_skill_book():
		if skills == null or ResourceRegistry.get_skill(item_definition.teaches_skill_id) == null:
			return false
		var before := skills.get_points(item_definition.teaches_skill_id)
		var definition := ResourceRegistry.get_skill(item_definition.teaches_skill_id)
		if before >= definition.max_proficiency - 0.0001:
			EventBus.notice_requested.emit("You have already mastered %s." % definition.display_name)
			return false
		if not inventory.consume_one(index):
			return false
		skills.set_proficiency_points(
			item_definition.teaches_skill_id,
			before + item_definition.proficiency_points,
		)
		_mark_player_progress_dirty()
		EventBus.notice_requested.emit(
			"Studied %s: %s proficiency increased."
			% [item_definition.display_name, definition.display_name]
		)
		return true
	var health_gain := 0.0
	var energy_gain := 0.0
	if health != null and not health.is_dead():
		health_gain = minf(item_definition.health_restore, health.max_health - health.current_health)
	if energy != null:
		energy_gain = minf(item_definition.energy_restore, energy.max_energy - energy.current_energy)
	if health_gain <= 0.0 and energy_gain <= 0.0:
		return false
	if not inventory.consume_one(index):
		return false
	if health_gain > 0.0:
		health.heal(health_gain)
	if energy_gain > 0.0:
		energy.restore(energy_gain)
	EventBus.notice_requested.emit("Used %s." % item_definition.display_name)
	return true


func apply_equipment_bonuses() -> void:
	var attack_bonus := float(_character_build_bonuses.get(&"attack_bonus", 0.0))
	var defense_bonus := float(_character_build_bonuses.get(&"defense_bonus", 0.0))
	var regen_bonus := float(_character_build_bonuses.get(&"energy_regen_bonus", 0.0))
	var active_tool := get_selected_item_definition()
	if active_tool == null or not active_tool.is_combat_tool():
		active_tool = null
	if equipment != null:
		for slot in EquipmentComponent.EQUIP_SLOTS:
			var item_definition := equipment.get_equipped_definition(slot)
			if item_definition == null:
				continue
			if active_tool == null or slot != ItemDefinition.EquipSlot.WEAPON:
				attack_bonus += item_definition.attack_bonus
			defense_bonus += item_definition.defense_bonus
			regen_bonus += item_definition.energy_regen_bonus
	if active_tool != null:
		attack_bonus += active_tool.attack_bonus
	if experience != null:
		attack_bonus += experience.bullet_damage_bonus
	if health != null:
		health.defense = maxf(0.0, _base_defense + defense_bonus)
	if energy != null:
		energy.regen_per_second = maxf(0.0, _base_energy_regen + regen_bonus)
	if combat != null:
		combat.damage_bonus = maxf(0.0, attack_bonus)


func _on_hotbar_selection_changed(_index: int) -> void:
	apply_equipment_bonuses()
	_sync_loadout_visuals()


func _sync_loadout_visuals() -> void:
	if _appearance_controller == null:
		return
	var weapon: ItemDefinition = null
	var armor: ItemDefinition = null
	var charm: ItemDefinition = null
	if equipment != null:
		weapon = equipment.get_equipped_definition(ItemDefinition.EquipSlot.WEAPON)
		armor = equipment.get_equipped_definition(ItemDefinition.EquipSlot.ARMOR)
		charm = equipment.get_equipped_definition(ItemDefinition.EquipSlot.CHARM)
	var held_item: ItemDefinition = null
	if inventory != null:
		var selected_slot := hotbar.get_inventory_slot_index()
		var stack := inventory.get_slot(selected_slot)
		if stack != null and not stack.is_empty():
			var selected := ResourceRegistry.get_item(stack.item_id)
			if selected != null and selected.resolved_visual_archetype() != &"":
				held_item = selected
	_appearance_controller.apply_loadout(weapon, armor, charm, held_item)


func apply_character_build(build_data: Dictionary, restore_to_full: bool = false) -> bool:
	var requested_origin := StringName(str(
		build_data.get("origin_id", GameManager.DEFAULT_ORIGIN_ID)
	))
	var requested_faction := StringName(str(
		build_data.get("faction_id", GameManager.DEFAULT_FACTION_ID)
	))
	var requested_profession := StringName(str(
		build_data.get("profession_id", GameManager.DEFAULT_PROFESSION_ID)
	))
	var origin := ResourceRegistry.get_origin(requested_origin)
	var faction_definition := ResourceRegistry.get_faction(requested_faction)
	var profession := ResourceRegistry.get_profession(requested_profession)
	if (
		origin == null
		or faction_definition == null
		or not faction_definition.selectable
		or profession == null
	):
		requested_origin = GameManager.DEFAULT_ORIGIN_ID
		requested_faction = GameManager.DEFAULT_FACTION_ID
		requested_profession = GameManager.DEFAULT_PROFESSION_ID
		origin = ResourceRegistry.get_origin(requested_origin)
		faction_definition = ResourceRegistry.get_faction(requested_faction)
		profession = ResourceRegistry.get_profession(requested_profession)
	if origin == null or faction_definition == null or profession == null:
		push_error("PlayerController3D: character build definitions are unavailable")
		return false
	origin_id = requested_origin
	selected_faction_id = requested_faction
	profession_id = requested_profession
	var raw_generation: Variant = build_data.get(
		"attribute_generation_version",
		CharacterBuildCalculator.ATTRIBUTE_GENERATION_VERSION,
	)
	attribute_generation_version = -1
	if (
		typeof(raw_generation) in [TYPE_INT, TYPE_FLOAT]
		and is_finite(float(raw_generation))
		and is_equal_approx(float(raw_generation), float(int(raw_generation)))
	):
		attribute_generation_version = int(raw_generation)
	if attribute_generation_version != CharacterBuildCalculator.ATTRIBUTE_GENERATION_VERSION:
		push_warning("PlayerController3D: unsupported attribute generation version; using safe default")
		attribute_generation_version = CharacterBuildCalculator.ATTRIBUTE_GENERATION_VERSION
		attribute_seed = GameManager.DEFAULT_ATTRIBUTE_SEED
	else:
		attribute_seed = CharacterBuildCalculator.normalize_seed(
			build_data.get("attribute_seed", GameManager.DEFAULT_ATTRIBUTE_SEED),
			GameManager.DEFAULT_ATTRIBUTE_SEED,
		)
	attribute_points = CharacterBuildCalculator.roll_attribute_points(attribute_seed)
	var raw_appearance: Variant = build_data.get("appearance", {})
	appearance_options = CharacterAppearanceOptions.normalize(
		raw_appearance as Dictionary if raw_appearance is Dictionary else {},
	)
	_character_build_bonuses = CharacterBuildCalculator.calculate_bonuses(
		origin,
		faction_definition,
		profession,
		attribute_points,
	)
	_recompute_character_build_stats(restore_to_full)
	if faction != null:
		faction.faction_id = selected_faction_id
	if _appearance_controller != null:
		_appearance_controller.apply_build(origin_id, appearance_options)
	apply_equipment_bonuses()
	_sync_loadout_visuals()
	return true


func get_character_build_data() -> Dictionary:
	return {
		"section_version": CHARACTER_BUILD_SECTION_VERSION,
		"origin_id": String(origin_id),
		"faction_id": String(selected_faction_id),
		"profession_id": String(profession_id),
		"appearance": appearance_options.duplicate(true),
		"attribute_seed": attribute_seed,
		"attribute_generation_version": attribute_generation_version,
	}


func get_character_build_bonuses() -> Dictionary:
	return _character_build_bonuses.duplicate(true)


func get_physical_strength() -> int:
	return CharacterBuildCalculator.physical_strength_from_bonuses(
		_character_build_bonuses
	)


func get_combat_level() -> int:
	return experience.level if experience != null else 1


func grant_combat_experience(amount: int) -> int:
	if experience == null or amount <= 0:
		return 0
	experience.enemies_defeated += 1
	var levels := experience.grant_experience(amount, game_time)
	apply_equipment_bonuses()
	return levels


func practice_skill(
	skill_id: StringName,
	activity_id: StringName,
	tool_id: StringName = &"",
	base_points: float = -1.0,
) -> Dictionary:
	if skills == null:
		return {}
	var context := {
		"day": WorldTimeService.day,
		"activity_id": String(activity_id),
		"location_id": _skill_practice_location_id(),
		"tool_id": String(tool_id),
	}
	if base_points >= 0.0:
		context["base_points"] = base_points
	var result := skills.practice(skill_id, context)
	if str(result.get("outcome", "")) in ["gained", "daily_cap", "overtrained"]:
		EventBus.skill_proficiency_changed.emit(result.duplicate(true))
		_mark_player_progress_dirty()
	if str(result.get("outcome", "")) == "overtrained":
		EventBus.notice_requested.emit(
			"Overtraining reduced %s proficiency by %.1f. Change place or tool and rest."
			% [
				str(result.get("display_name", String(skill_id))),
				absf(float(result.get("delta", 0.0))),
			]
		)
	return result


func _on_combat_hit_confirmed(result: CombatHitResult) -> void:
	if result == null or result.attacker != self or result.damage_dealt <= 0.0:
		return
	var tool := get_selected_item_definition()
	if tool != null and tool.is_combat_tool():
		practice_skill(&"improvised_weapons", &"land_tool_hit", tool.id)
		return
	var weapon_id := &"" as StringName
	if equipment != null:
		var weapon := equipment.get_equipped_definition(ItemDefinition.EquipSlot.WEAPON)
		if weapon != null:
			weapon_id = weapon.id
	practice_skill(&"melee_combat", &"land_melee_hit", weapon_id)


func _on_combat_block_confirmed(result: CombatHitResult) -> void:
	if result == null or result.defender != self:
		return
	var weapon_id := &"" as StringName
	if equipment != null:
		var weapon := equipment.get_equipped_definition(ItemDefinition.EquipSlot.WEAPON)
		if weapon != null:
			weapon_id = weapon.id
	practice_skill(&"guarding", &"successful_guard", weapon_id)


func _skill_practice_location_id() -> String:
	const CELL_SIZE := 6.0
	return "%s@%d,%d" % [
		String(current_region_id),
		floori(global_position.x / CELL_SIZE),
		floori(global_position.z / CELL_SIZE),
	]


func _mark_player_progress_dirty() -> void:
	var node: Node = self
	while node != null:
		if node is WorldSession:
			var session := node as WorldSession
			if session.save_coordinator != null:
				session.save_coordinator.mark_dirty(&"player")
			return
		node = node.get_parent()


func get_effective_movement_speeds() -> Dictionary:
	return {
		"walk": _walk_speed,
		"run": _run_speed,
		"crouch": _crouch_speed,
	}


func _recompute_character_build_stats(restore_to_full: bool) -> void:
	var saved_health := health.current_health if health != null else 0.0
	var saved_energy := energy.current_energy if energy != null else 0.0
	if health != null:
		var level_health_bonus := 0.0
		if experience != null and experience.curve != null:
			level_health_bonus = float(maxi(0, experience.level - 1)) \
				* experience.curve.health_gain_per_level
		health.max_health = maxf(
			1.0,
			_base_max_health
				+ float(_character_build_bonuses.get(&"max_health_bonus", 0.0))
				+ level_health_bonus,
		)
		health.current_health = (
			health.max_health if restore_to_full
			else clampf(saved_health, 0.0, health.max_health)
		)
		health.health_changed.emit(health.current_health, health.max_health)
	if energy != null:
		energy.max_energy = maxf(
			1.0,
			_base_max_energy + float(_character_build_bonuses.get(&"max_energy_bonus", 0.0)),
		)
		energy.current_energy = (
			energy.max_energy if restore_to_full
			else clampf(saved_energy, 0.0, energy.max_energy)
		)
		energy.energy_changed.emit(energy.current_energy, energy.max_energy)
	var move_bonus := float(_character_build_bonuses.get(&"move_speed_bonus", 0.0))
	_walk_speed = maxf(0.5, _base_walk_speed + move_bonus)
	_run_speed = maxf(_walk_speed, _base_run_speed + move_bonus)
	_crouch_speed = maxf(0.25, _base_crouch_speed + move_bonus)


func _resolve_camera() -> void:
	if camera_rig_path != NodePath():
		var rig := get_node_or_null(camera_rig_path)
		if rig != null:
			_camera = rig.get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		_camera = get_viewport().get_camera_3d()


func to_dict() -> Dictionary:
	var data := super.to_dict()
	if data.has("health") and data["health"] is Dictionary:
		(data["health"] as Dictionary)["defense"] = _base_defense
	data["hotbar"] = hotbar.to_dict()
	data["inventory"] = inventory.to_dict() if inventory else {}
	data["equipment"] = equipment.to_dict() if equipment else {}
	data["experience"] = experience.to_dict() if experience else {}
	data["character_build"] = get_character_build_data()
	data["current_region_id"] = String(current_region_id)
	data["game_time"] = game_time
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	if experience != null:
		experience.from_dict(data.get("experience", {}))
	hotbar.from_dict(data.get("hotbar", {}))
	if inventory != null:
		inventory.from_dict(data.get("inventory", {}))
	if equipment != null:
		equipment.from_dict(data.get("equipment", {}))
	var build_data: Variant = data.get("character_build", GameManager.get_default_character_build())
	if typeof(build_data) != TYPE_DICTIONARY:
		build_data = GameManager.get_default_character_build()
	apply_character_build(build_data as Dictionary, false)
	current_region_id = StringName(str(data.get("current_region_id", current_region_id)))
	game_time = float(data.get("game_time", game_time))


func _on_experience_changed(current: int, to_next: int, level: int) -> void:
	EventBus.player_experience_changed.emit(current, to_next, level)


func _on_leveled_up(new_level: int) -> void:
	apply_equipment_bonuses()
	EventBus.notice_requested.emit("LEVEL UP! Reached level %d." % new_level)
