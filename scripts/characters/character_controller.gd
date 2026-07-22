class_name CharacterController
extends CharacterBody3D
## Shared base for player, NPC, pet, and mount actors.

signal damaged_received(amount: float, source: Node)
signal downed(source: Node)
signal died_permanently(source: Node)

@export var character_id: StringName = &""
@export var definition: CharacterDefinition
@export var region_id: StringName = &"town"

@onready var health: HealthComponent = $HealthComponent
@onready var energy: EnergyComponent = $EnergyComponent
@onready var faction: FactionComponent = $FactionComponent
@onready var relationship: RelationshipComponent = $RelationshipComponent
@onready var interaction: InteractionComponent = $InteractionComponent
@onready var combat: CombatComponent = $CombatComponent
@onready var skills: SkillComponent = $SkillComponent
@onready var status: StatusEffectComponent = $StatusEffectComponent
@onready var hurtbox: Hurtbox3D = $Hurtbox3D

var state := CharacterState.new()
var game_time: float = 0.0
var is_downed: bool = false
var is_permanently_dead: bool = false


func _ready() -> void:
	if character_id == &"":
		character_id = StringName(str(get_instance_id()))
	if definition != null:
		apply_definition(definition)
	if relationship != null:
		relationship.bind_owner(self)
	if health != null and not health.damaged.is_connected(_on_health_damaged):
		health.damaged.connect(_on_health_damaged)
	if health != null and not health.died.is_connected(_on_health_died):
		health.died.connect(_on_health_died)


func apply_definition(def: CharacterDefinition) -> void:
	definition = def
	character_id = def.id
	if health != null:
		health.max_health = def.max_health
		health.current_health = def.max_health
		health.death_recorded = false
	if energy != null:
		energy.max_energy = def.max_energy
		energy.current_energy = def.max_energy
	if faction != null:
		faction.faction_id = def.faction_id
	RelationshipService.ensure_registered(character_id, def.default_disposition)


func set_input_enabled(enabled: bool) -> void:
	state.input_enabled = enabled


## Unified damage entry: Hitbox → Hurtbox → here → Combat/Guard → Health.
func receive_damage(amount: float, source: Node, context: Dictionary = {}) -> float:
	if is_permanently_dead or amount <= 0.0:
		return 0.0
	if is_downed:
		return 0.0

	var final_amount := amount
	if combat != null:
		final_amount = combat.resolve_incoming_damage(amount, source, self, energy, context)
	if final_amount <= 0.0:
		return 0.0
	if health == null:
		return 0.0

	var dealt := health.apply_damage(DamageInfo.make(final_amount, source), false)
	_after_damage_received(dealt, source, context)
	return dealt


func _after_damage_received(dealt: float, source: Node, context: Dictionary) -> void:
	if dealt <= 0.0:
		return
	damaged_received.emit(dealt, source)
	if source is CharacterController:
		_handle_aggression_from(source as CharacterController, dealt, context)


func _handle_aggression_from(attacker: CharacterController, damage: float, context: Dictionary) -> void:
	pass


func _on_health_damaged(_amount: float, _source: Node) -> void:
	pass


func _on_health_died(source: Node) -> void:
	var can_kill := definition == null or definition.can_be_killed
	if can_kill:
		is_permanently_dead = true
		is_downed = false
		state.current = CharacterState.State.DISABLED
		set_input_enabled(false)
		died_permanently.emit(source)
		_on_permanent_death(source)
	else:
		# Story-critical: enter downed instead of permanent death.
		is_downed = true
		is_permanently_dead = false
		if health != null:
			health.death_recorded = false
			health.current_health = 1.0
			health.health_changed.emit(health.current_health, health.max_health)
		state.current = CharacterState.State.DOWNED
		set_input_enabled(false)
		downed.emit(source)
		_on_downed(source)


func _on_permanent_death(_source: Node) -> void:
	pass


func _on_downed(_source: Node) -> void:
	pass


func recover_from_downed(restore_health: float = 20.0) -> void:
	if not is_downed:
		return
	is_downed = false
	state.current = CharacterState.State.IDLE
	set_input_enabled(true)
	if health != null:
		health.current_health = clampf(restore_health, 1.0, health.max_health)
		health.death_recorded = false
		health.health_changed.emit(health.current_health, health.max_health)


func to_dict() -> Dictionary:
	return {
		"character_id": String(character_id),
		"region_id": String(region_id),
		"position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z,
		},
		"health": health.to_dict() if health else {},
		"energy": energy.to_dict() if energy else {},
		"faction": faction.to_dict() if faction else {},
		"skills": skills.to_dict() if skills else {},
		"state": {
			"is_running": state.is_running,
			"is_crouching": state.is_crouching,
			"is_downed": is_downed,
			"is_permanently_dead": is_permanently_dead,
		},
	}


func from_dict(data: Dictionary) -> void:
	character_id = StringName(str(data.get("character_id", character_id)))
	region_id = StringName(str(data.get("region_id", region_id)))
	var pos: Dictionary = data.get("position", {})
	global_position = Vector3(
		float(pos.get("x", global_position.x)),
		float(pos.get("y", global_position.y)),
		float(pos.get("z", global_position.z)),
	)
	reset_physics_interpolation()
	if health != null:
		health.from_dict(data.get("health", {}))
	if energy != null:
		energy.from_dict(data.get("energy", {}))
	if faction != null:
		faction.from_dict(data.get("faction", {}))
	if skills != null:
		skills.from_dict(data.get("skills", {}))
	var state_data: Dictionary = data.get("state", {})
	state.is_running = bool(state_data.get("is_running", false))
	state.is_crouching = bool(state_data.get("is_crouching", false))
	is_downed = bool(state_data.get("is_downed", false))
	is_permanently_dead = bool(state_data.get("is_permanently_dead", false))
	if is_downed:
		state.current = CharacterState.State.DOWNED
	elif is_permanently_dead:
		state.current = CharacterState.State.DISABLED
