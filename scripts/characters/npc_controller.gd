class_name NPCController
extends CharacterController

enum NPCState {
	IDLE,
	WANDER,
	FOLLOW_SCHEDULE,
	TALK,
	WORK,
	FLEE,
	CHASE,
	ATTACK,
	DOWNED,
}

@export var npc_definition: NPCDefinition
@export var wander_radius: float = 8.0
@export var detect_radius: float = 10.0

var npc_state: NPCState = NPCState.IDLE
var _home_position: Vector3
var _wander_target: Vector3
var _attack_target: CharacterController
var _nav: NavigationAgent3D
var _schedule: ScheduleComponent
var _schedule_paused: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _knowledge_action_motion: StringName = &""
var _knowledge_action_remaining: float = 0.0
var _economic_planner := NPCEconomicPlanner.new()
var _economic_action_cooldown: float = 0.0


func _ready() -> void:
	super._ready()
	_home_position = global_position
	_wander_target = global_position
	_nav = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	_schedule = get_node_or_null("ScheduleComponent") as ScheduleComponent

	if npc_definition != null:
		apply_definition(npc_definition)
		_initialize_authored_economy()
		if _schedule != null and npc_definition.schedule != null:
			_schedule.schedule = npc_definition.schedule
	if equipment != null:
		if not equipment.equipment_changed.is_connected(apply_shared_equipment_effects):
			equipment.equipment_changed.connect(apply_shared_equipment_effects)
		apply_shared_equipment_effects()

	if combat != null:
		var hb := get_node_or_null("HitboxRoot/Hitbox3D") as Hitbox3D
		if hb != null:
			combat.hitbox = hb
			hb.source = self
			hb.team = &"npc"
			if combat.attack != null:
				hb.damage = combat.attack.damage
		if combat.attack == null:
			combat.attack = ResourceRegistry.get_attack(&"basic_melee")

	if health != null and not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged)

	if RelationshipService.get_disposition(character_id) == RelationshipComponent.Disposition.HOSTILE:
		npc_state = NPCState.CHASE
	else:
		npc_state = NPCState.FOLLOW_SCHEDULE if _schedule != null else NPCState.WANDER


func _physics_process(delta: float) -> void:
	if not visible or process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if is_permanently_dead:
		velocity = Vector3.ZERO
		_update_presentation()
		return
	if _knowledge_action_remaining > 0.0:
		_knowledge_action_remaining = maxf(0.0, _knowledge_action_remaining - delta)
		if _knowledge_action_remaining <= 0.0:
			_knowledge_action_motion = &""
	if is_downed:
		npc_state = NPCState.DOWNED
		velocity = Vector3.ZERO
		if not is_on_floor():
			velocity.y -= _gravity * delta
			move_and_slide()
		_update_presentation()
		return

	game_time += delta
	if energy != null and employment != null and employment.current_contract != null:
		energy.tick(delta)
	_economic_action_cooldown = maxf(0.0, _economic_action_cooldown - delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta

	match npc_state:
		NPCState.ATTACK, NPCState.CHASE:
			_process_attack(delta)
		NPCState.FLEE:
			_process_flee(delta)
		NPCState.WANDER, NPCState.FOLLOW_SCHEDULE, NPCState.WORK:
			_process_schedule_or_wander(delta)
		NPCState.TALK:
			velocity = Vector3.ZERO
		_:
			velocity = Vector3.ZERO
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length_squared() > 0.02:
		look_at(global_position + horizontal.normalized(), Vector3.UP)
	move_and_slide()
	_update_presentation()


func set_npc_state(new_state: NPCState) -> void:
	npc_state = new_state
	_schedule_paused = new_state in [
		NPCState.ATTACK, NPCState.CHASE, NPCState.FLEE, NPCState.TALK, NPCState.DOWNED
	]
	_update_presentation()


func play_knowledge_action(action_or_motion: StringName, duration: float = -1.0) -> void:
	if is_downed or is_permanently_dead:
		return
	_knowledge_action_motion = KnowledgeActionLibrary.resolve_motion(action_or_motion)
	_knowledge_action_remaining = (
		KnowledgeActionLibrary.action_duration(action_or_motion)
		if duration <= 0.0 else duration
	)
	_update_presentation()


func react_to_aggression(attacker: CharacterController, damage: float = 10.0) -> void:
	if attacker == null or is_downed or is_permanently_dead:
		return
	RelationshipService.register_aggression(character_id, damage, {})
	_emit_cognition_attack_event(attacker, damage)
	var disp := RelationshipService.get_disposition(character_id)
	_attack_target = attacker
	EventBus.affinity_changed_notice.emit(character_id, -maxf(1.0, damage * 0.5))

	if disp == RelationshipComponent.Disposition.HOSTILE:
		npc_state = NPCState.ATTACK
		_schedule_paused = true
	elif disp == RelationshipComponent.Disposition.FRIENDLY:
		npc_state = NPCState.FLEE
		_schedule_paused = true
	else:
		npc_state = NPCState.ATTACK
		_schedule_paused = true


func can_talk_to(actor: CharacterController) -> bool:
	if actor == null or is_downed or is_permanently_dead:
		return false
	if RelationshipService.is_temporarily_hostile(character_id):
		return false
	return RelationshipService.get_disposition(character_id) != RelationshipComponent.Disposition.HOSTILE


func can_engage_free_form(actor: CharacterController) -> bool:
	## Cognitive dialogue remains available to any living NPC, including hostile
	## characters that have no authored dialogue. Combat is paused by the dialogue
	## coordinator while the free-form exchange is active.
	return actor != null and not is_downed and not is_permanently_dead


func _handle_aggression_from(attacker: CharacterController, damage: float, _context: Dictionary) -> void:
	react_to_aggression(attacker, damage)


func _on_damaged(_amount: float, _source: Node) -> void:
	pass


func _emit_cognition_attack_event(attacker: Node, damage: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var world := tree.get_first_node_in_group("world_manager") as WorldSession
	if world == null or world.event_bus == null:
		return
	var source_id := _persistent_id_for(attacker)
	var target_id := NPCIdentityResolver.resolve_persistent_id(self)
	if target_id == &"":
		return
	var event := GameplayEvent.make(
		GameplayEventTypes.NPC_ATTACKED,
		source_id,
		target_id,
		character_id,
		region_id,
		damage,
		{"position": {"x": global_position.x, "y": global_position.y, "z": global_position.z}},
	)
	world.event_bus.emit_event(event)


func _persistent_id_for(node: Node) -> StringName:
	if node == null:
		return &""
	var identity := node.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	return identity.persistent_id if identity != null else &""


func _on_downed(_source: Node) -> void:
	npc_state = NPCState.DOWNED
	_schedule_paused = true
	velocity = Vector3.ZERO
	var anim := get_node_or_null("CombatAnimationController") as CombatAnimationController
	if anim != null:
		anim.request_downed()


func _on_permanent_death(_source: Node) -> void:
	npc_state = NPCState.DOWNED
	var anim := get_node_or_null("CombatAnimationController") as CombatAnimationController
	if anim != null:
		anim.request_death()
	queue_free()


func _update_presentation() -> void:
	var anim := get_node_or_null("CombatAnimationController") as CombatAnimationController
	if anim == null:
		return
	if is_downed or npc_state == NPCState.DOWNED:
		anim.set_context_motion(&"downed")
	elif _knowledge_action_motion != &"" and _knowledge_action_remaining > 0.0:
		anim.set_context_motion(_knowledge_action_motion)
	elif npc_state == NPCState.TALK:
		anim.set_context_motion(&"talk")
	else:
		anim.set_context_motion(&"")
	anim.set_locomotion(velocity, is_on_floor(), false)


func _process_attack(_delta: float) -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		_attack_target = _find_player()
	if _attack_target == null:
		npc_state = NPCState.IDLE
		return
	var to_target := _attack_target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > detect_radius * 1.5 and npc_state == NPCState.CHASE:
		velocity = Vector3.ZERO
		return
	if dist > 2.0:
		velocity = to_target.normalized() * (definition.run_speed if definition else 5.0)
	else:
		velocity = Vector3.ZERO
		if combat != null and not combat.is_attacking:
			combat.try_attack(energy)


func _process_flee(_delta: float) -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		npc_state = NPCState.WANDER
		_schedule_paused = false
		return
	var away := global_position - _attack_target.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.RIGHT
	velocity = away.normalized() * (definition.run_speed if definition else 5.0)


func _process_schedule_or_wander(_delta: float) -> void:
	if not _schedule_paused and _schedule != null:
		_schedule.tick()
		if _schedule.current_marker_id != &"":
			var marker := _find_marker(_schedule.current_marker_id)
			if marker != null:
				_wander_target = marker.global_position
				npc_state = NPCState.WORK if (
					_schedule.current_activity == &"work"
					and global_position.distance_to(_wander_target) < 0.8
				) else NPCState.FOLLOW_SCHEDULE
	var target := _wander_target
	if global_position.distance_to(target) < 0.6:
		if npc_state == NPCState.WORK:
			velocity = Vector3.ZERO
			_process_economic_action()
			return
		if npc_state != NPCState.FOLLOW_SCHEDULE:
			_pick_wander_target()
			target = _wander_target
		else:
			velocity = Vector3.ZERO
			return
	var dir := target - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		if _nav != null:
			_nav.target_position = target
		velocity = dir.normalized() * (definition.walk_speed if definition else 3.0)
	else:
		velocity = Vector3.ZERO


func _pick_wander_target() -> void:
	var offset := Vector3(
		randf_range(-wander_radius, wander_radius),
		0.0,
		randf_range(-wander_radius, wander_radius),
	)
	_wander_target = _home_position + offset


func _find_player() -> PlayerController3D:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player") as PlayerController3D


func _find_marker(marker_id: StringName) -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var world := tree.get_first_node_in_group("world_manager")
	if world == null:
		return null
	var session := world as WorldSession
	if session == null or session.region_service == null:
		return null
	var region := session.region_service.get_current_region_root()
	if region == null:
		return null
	var direct := region.get_node_or_null(String(marker_id)) as Node3D
	return direct if direct != null else region.find_child(String(marker_id), true, false) as Node3D


func _initialize_authored_economy() -> void:
	if npc_definition == null:
		return
	if wallet != null:
		wallet.restore_balance(npc_definition.starting_wallet_balance, {
			"actor_id": String(get_persistent_actor_id()),
			"reason": "authored_seed",
		})
	if inventory != null:
		for item_id in npc_definition.starting_inventory_item_ids:
			inventory.add_item(item_id, 1)
		for item_id in npc_definition.starting_equipment_item_ids:
			if inventory.count_item(item_id) <= 0:
				inventory.add_item(item_id, 1)
	if equipment != null and inventory != null:
		for item_id in npc_definition.starting_equipment_item_ids:
			for index in inventory.slot_count:
				var stack := inventory.get_slot(index)
				if stack != null and stack.item_id == item_id and stack.quantity > 0:
					equipment.equip_from_inventory(inventory, index)
					break
	if employment == null or npc_definition.job_id == &"" or npc_definition.worksite_id == &"":
		return
	var job := ResourceRegistry.get_job(npc_definition.job_id)
	if job == null:
		return
	var contract := EmploymentContract.new()
	contract.actor_id = get_persistent_actor_id()
	contract.job_id = job.id
	contract.worksite_id = npc_definition.worksite_id
	contract.status = EmploymentContract.STATUS_ACTIVE
	contract.start_day = WorldTimeService.day
	contract.wage_per_shift = job.base_wage
	contract.shift_start_hour = job.shift_start_hour
	contract.shift_end_hour = job.shift_end_hour
	employment.initialize_contract(contract)


func _process_economic_action() -> void:
	if _economic_action_cooldown > 0.0 or employment == null:
		return
	var world := get_tree().get_first_node_in_group("world_manager") as WorldSession
	if world == null:
		return
	var proposal := _economic_planner.propose_next(self)
	if proposal == null:
		return
	var result := world.submit_intent(proposal)
	if result.is_valid:
		play_knowledge_action(&"work", 1.5)
	var job := ResourceRegistry.get_job(employment.current_contract.job_id) \
		if employment.current_contract != null else null
	_economic_action_cooldown = maxf(1.0, job.shift_duration if job != null else 6.0)


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["npc_state"] = npc_state
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	npc_state = int(data.get("npc_state", npc_state)) as NPCState
	if is_downed:
		npc_state = NPCState.DOWNED
