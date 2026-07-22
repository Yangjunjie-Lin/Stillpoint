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


func _ready() -> void:
	super._ready()
	_home_position = global_position
	_wander_target = global_position
	_nav = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	_schedule = get_node_or_null("ScheduleComponent") as ScheduleComponent

	if npc_definition != null:
		apply_definition(npc_definition)

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
		return
	if is_downed:
		npc_state = NPCState.DOWNED
		velocity = Vector3.ZERO
		if not is_on_floor():
			velocity.y -= _gravity * delta
			move_and_slide()
		return

	game_time += delta
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
	move_and_slide()


func set_npc_state(new_state: NPCState) -> void:
	npc_state = new_state
	_schedule_paused = new_state in [
		NPCState.ATTACK, NPCState.CHASE, NPCState.FLEE, NPCState.TALK, NPCState.DOWNED
	]


func react_to_aggression(attacker: CharacterController, damage: float = 10.0) -> void:
	if attacker == null or is_downed or is_permanently_dead:
		return
	RelationshipService.register_aggression(character_id, damage, {})
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


func _handle_aggression_from(attacker: CharacterController, damage: float, _context: Dictionary) -> void:
	react_to_aggression(attacker, damage)


func _on_damaged(_amount: float, _source: Node) -> void:
	pass


func _on_downed(_source: Node) -> void:
	npc_state = NPCState.DOWNED
	_schedule_paused = true
	velocity = Vector3.ZERO


func _on_permanent_death(_source: Node) -> void:
	npc_state = NPCState.DOWNED
	queue_free()


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
				npc_state = NPCState.FOLLOW_SCHEDULE
	var target := _wander_target
	if global_position.distance_to(target) < 0.6:
		if npc_state != NPCState.FOLLOW_SCHEDULE:
			_pick_wander_target()
			target = _wander_target
		else:
			velocity = Vector3.ZERO
			return
	var dir := target - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
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
	var regions := world.get_node_or_null("Regions")
	if regions == null:
		return null
	var region := regions.get_node_or_null(String(region_id))
	if region == null:
		return null
	return region.get_node_or_null(String(marker_id)) as Node3D


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["npc_state"] = npc_state
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	npc_state = int(data.get("npc_state", npc_state)) as NPCState
	if is_downed:
		npc_state = NPCState.DOWNED
