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
var wallet: WalletComponent
var inventory: InventoryComponent
var equipment: EquipmentComponent
var attributes: ActorAttributesComponent
var employment: EmploymentComponent
var game_time: float = 0.0
var is_downed: bool = false
var is_permanently_dead: bool = false
var _shared_base_combat_damage_bonus: float = 0.0
var _shared_base_defense: float = 0.0
var _shared_base_energy_regen: float = 0.0
var _shared_base_max_health: float = 1.0
var _shared_base_max_energy: float = 1.0


func _ready() -> void:
	wallet = get_node_or_null("WalletComponent") as WalletComponent
	inventory = get_node_or_null("InventoryComponent") as InventoryComponent
	equipment = get_node_or_null("EquipmentComponent") as EquipmentComponent
	attributes = get_node_or_null("ActorAttributesComponent") as ActorAttributesComponent
	employment = get_node_or_null("EmploymentComponent") as EmploymentComponent
	if definition != null:
		apply_definition(definition)
	if relationship != null:
		relationship.bind_owner(self)
	if health != null and not health.damaged.is_connected(_on_health_damaged):
		health.damaged.connect(_on_health_damaged)
	if health != null and not health.died.is_connected(_on_health_died):
		health.died.connect(_on_health_died)
	_capture_shared_equipment_baselines()


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
	if attributes != null:
		attributes.apply_attributes(def.actor_attributes)
	RelationshipService.ensure_registered(character_id, def.default_disposition)


func get_actor_attribute(attribute_id: StringName, fallback: float = 0.0) -> float:
	return attributes.get_attribute(attribute_id, fallback) if attributes != null else fallback


func get_persistent_actor_id() -> StringName:
	var identity := get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	return identity.persistent_id if identity != null else &""


func apply_shared_equipment_effects() -> void:
	## NPCs and other non-player actors consume the same authored equipment
	## bonuses. PlayerController3D layers build/loadout rules on this calculator.
	var bonuses := EquipmentEffectCalculator.calculate(equipment)
	if combat != null:
		combat.damage_bonus = maxf(
			0.0,
			_shared_base_combat_damage_bonus + float(bonuses.get("attack_bonus", 0.0)),
		)
	if health != null:
		health.defense = maxf(
			0.0,
			_shared_base_defense + float(bonuses.get("defense_bonus", 0.0)),
		)
		health.max_health = maxf(
			1.0,
			_shared_base_max_health + float(bonuses.get("max_health_bonus", 0.0)),
		)
		health.current_health = minf(health.current_health, health.max_health)
		health.health_changed.emit(health.current_health, health.max_health)
	if energy != null:
		energy.regen_per_second = maxf(
			0.0,
			_shared_base_energy_regen + float(bonuses.get("energy_regen_bonus", 0.0)),
		)
		energy.max_energy = maxf(
			1.0,
			_shared_base_max_energy + float(bonuses.get("max_energy_bonus", 0.0)),
		)
		energy.current_energy = minf(energy.current_energy, energy.max_energy)
		energy.energy_changed.emit(energy.current_energy, energy.max_energy)


func _capture_shared_equipment_baselines() -> void:
	_shared_base_combat_damage_bonus = combat.damage_bonus if combat != null else 0.0
	_shared_base_defense = health.defense if health != null else 0.0
	_shared_base_energy_regen = energy.regen_per_second if energy != null else 0.0
	_shared_base_max_health = health.max_health if health != null else 1.0
	_shared_base_max_energy = energy.max_energy if energy != null else 1.0


func set_input_enabled(enabled: bool) -> void:
	state.input_enabled = enabled


## Unified damage entry: Hitbox → Hurtbox → here → Combat/Guard → Health.
func receive_damage(amount: float, source: Node, context: Dictionary = {}) -> float:
	if is_permanently_dead or amount <= 0.0:
		return 0.0
	if is_downed:
		return 0.0
	if hurtbox != null and hurtbox.is_invulnerable() and not bool(context.get("ignore_dodge_iframe", false)):
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
		if combat != null:
			combat.enter_terminal_state(true)
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
		if combat != null:
			combat.enter_terminal_state(false)
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
	if combat != null:
		combat.reset_runtime_state()
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
	else:
		state.current = CharacterState.State.IDLE
	if combat != null:
		combat.reset_runtime_state()


func get_persistence_key() -> StringName:
	return &"character"


func capture_state() -> Dictionary:
	return to_dict()


func restore_state(data: Dictionary) -> void:
	from_dict(data)


func get_state_version() -> int:
	return 1
