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

var npc_state: NPCState = NPCState.IDLE
var _home_position: Vector3
var _wander_target: Vector3
var _attack_target: CharacterController
var _nav: NavigationAgent3D
var _schedule: ScheduleComponent


func _ready() -> void:
	super._ready()
	_home_position = global_position
	_nav = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	_schedule = get_node_or_null("ScheduleComponent") as ScheduleComponent
	if npc_definition != null:
		apply_definition(npc_definition)
	if health != null:
		health.damaged.connect(_on_damaged)
	if source is CharacterController:
		react_to_aggression(source as CharacterController)


func _physics_process(delta: float) -> void:
	game_time += delta
	match npc_state:
		NPCState.ATTACK:
			_process_attack(delta)
		NPCState.FLEE:
			_process_flee(delta)
		NPCState.WANDER, NPCState.FOLLOW_SCHEDULE:
			_process_wander(delta)
		_:
			velocity = Vector3.ZERO
	move_and_slide()


func set_npc_state(new_state: NPCState) -> void:
	npc_state = new_state


func react_to_aggression(attacker: CharacterController) -> void:
	if attacker == null:
		return
	var disp := RelationshipService.get_disposition(character_id)
	if disp == RelationshipComponent.Disposition.FRIENDLY:
		RelationshipService.change_affinity(character_id, -10.0, &"attacked_friendly")
	elif disp == RelationshipComponent.Disposition.NEUTRAL:
		RelationshipService.change_affinity(character_id, -20.0, &"attacked_neutral")
	if relationship != null:
		relationship.register_aggression(attacker, 10.0, {})
	var local_disp := relationship.get_disposition(attacker.character_id) if relationship else RelationshipComponent.Disposition.NEUTRAL
	if local_disp == RelationshipComponent.Disposition.HOSTILE or RelationshipService.get_disposition(character_id) == RelationshipComponent.Disposition.HOSTILE:
		_attack_target = attacker
		npc_state = NPCState.ATTACK
	elif disp == RelationshipComponent.Disposition.FRIENDLY:
		npc_state = NPCState.FLEE
	else:
		_attack_target = attacker
		npc_state = NPCState.ATTACK
	EventBus.affinity_changed_notice.emit(character_id, -10.0)


func can_talk_to(actor: CharacterController) -> bool:
	if actor == null or relationship == null:
		return false
	return relationship.get_disposition(actor.character_id) != RelationshipComponent.Disposition.HOSTILE


func _process_attack(delta: float) -> void:
	if _attack_target == null or not is_instance_valid(_attack_target):
		npc_state = NPCState.IDLE
		return
	var to_target := _attack_target.global_position - global_position
	to_target.y = 0.0
	if to_target.length() > 2.0:
		velocity = to_target.normalized() * (definition.run_speed if definition else 5.0)
	else:
		velocity = Vector3.ZERO
		if combat != null:
			combat.try_attack(energy)


func _process_flee(delta: float) -> void:
	if _attack_target == null:
		npc_state = NPCState.WANDER
		return
	var away := global_position - _attack_target.global_position
	away.y = 0.0
	velocity = away.normalized() * (definition.run_speed if definition else 5.0)


func _process_wander(delta: float) -> void:
	if _schedule != null:
		_schedule.tick()
	var target := _wander_target
	if global_position.distance_to(target) < 0.5:
		_pick_wander_target()
		target = _wander_target
	var dir := (target - global_position)
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
