class_name PlayerController3D
extends CharacterController

@export var camera_rig_path: NodePath
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.0
@export var acceleration: float = 18.0
@export var deceleration: float = 22.0

var hotbar := HotbarController.new()
var inventory: InventoryComponent
var equipment: EquipmentComponent
var current_region_id: StringName = &"town"

var _camera: Camera3D
var _collision_shape: CollisionShape3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _jump_velocity: float = 6.5
var _walk_speed: float = 4.0
var _run_speed: float = 7.0
var _crouch_speed: float = 2.5
var _base_defense: float = 0.0
var _base_energy_regen: float = 0.0


func _ready() -> void:
	super._ready()
	inventory = get_node_or_null("InventoryComponent") as InventoryComponent
	equipment = get_node_or_null("EquipmentComponent") as EquipmentComponent
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
		_walk_speed = definition.walk_speed
		_run_speed = definition.run_speed
		_crouch_speed = definition.crouch_speed
	_base_defense = health.defense if health != null else 0.0
	_base_energy_regen = energy.regen_per_second if energy != null else 0.0
	if equipment != null and not equipment.equipment_changed.is_connected(apply_equipment_bonuses):
		equipment.equipment_changed.connect(apply_equipment_bonuses)
	apply_equipment_bonuses()


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
	var attack_bonus := 0.0
	var defense_bonus := 0.0
	var regen_bonus := 0.0
	if equipment != null:
		for slot in EquipmentComponent.EQUIP_SLOTS:
			var item_definition := equipment.get_equipped_definition(slot)
			if item_definition == null:
				continue
			attack_bonus += item_definition.attack_bonus
			defense_bonus += item_definition.defense_bonus
			regen_bonus += item_definition.energy_regen_bonus
	if health != null:
		health.defense = maxf(0.0, _base_defense + defense_bonus)
	if energy != null:
		energy.regen_per_second = maxf(0.0, _base_energy_regen + regen_bonus)
	if combat != null:
		combat.damage_bonus = maxf(0.0, attack_bonus)


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
	data["current_region_id"] = String(current_region_id)
	data["game_time"] = game_time
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	hotbar.from_dict(data.get("hotbar", {}))
	if inventory != null:
		inventory.from_dict(data.get("inventory", {}))
	if health != null:
		_base_defense = health.defense
	if equipment != null:
		equipment.from_dict(data.get("equipment", {}))
	apply_equipment_bonuses()
	current_region_id = StringName(str(data.get("current_region_id", current_region_id)))
	game_time = float(data.get("game_time", game_time))
