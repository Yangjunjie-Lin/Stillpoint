class_name CombatComponent
extends Node

signal attack_started
signal attack_finished
signal blocked(amount: float, source: Node)
signal guard_broken

@export var attack: AttackDefinition
@export var hitbox: Hitbox3D
@export var guard_energy_cost: float = 5.0
@export var guard_reduction: float = 0.6

var is_attacking: bool = false
var is_guarding: bool = false
var _attack_timer: float = 0.0
var _phase: StringName = &""
var _owner: CharacterController


func _ready() -> void:
	_owner = get_parent() as CharacterController


func _process(delta: float) -> void:
	if not is_attacking:
		return
	_attack_timer -= delta
	if _phase == &"windup" and _attack_timer <= 0.0:
		_begin_active()
	elif _phase == &"active" and _attack_timer <= 0.0:
		_begin_recovery()
	elif _phase == &"recovery" and _attack_timer <= 0.0:
		_finish_attack()


func try_attack(energy: EnergyComponent) -> bool:
	if is_attacking or attack == null:
		return false
	if energy != null and not energy.spend(attack.energy_cost):
		return false
	is_attacking = true
	_phase = &"windup"
	_attack_timer = attack.windup
	if hitbox != null:
		hitbox.set_active(false)
		hitbox.damage = attack.damage
		hitbox.attack_id = attack.id
	if _owner != null:
		_owner.state.current = CharacterState.State.ATTACK
	attack_started.emit()
	return true


func set_guarding(value: bool) -> void:
	is_guarding = value
	if _owner != null and value and not is_attacking:
		_owner.state.current = CharacterState.State.GUARD


## Returns final damage after guard; does NOT apply health.
func resolve_incoming_damage(
	amount: float,
	source: Node,
	defender: CharacterController,
	energy: EnergyComponent,
	context: Dictionary = {},
) -> float:
	if amount <= 0.0:
		return 0.0
	var unblockable := bool(context.get("unblockable", false))
	if not is_guarding or unblockable or defender == null:
		return amount
	if not (source is Node3D):
		return amount
	if not GuardSystem.is_blocking(
		-defender.global_transform.basis.z,
		(source as Node3D).global_position,
		defender.global_position,
	):
		return amount
	if energy != null:
		if not energy.can_spend(guard_energy_cost):
			guard_broken.emit()
			is_guarding = false
			return amount
		energy.spend(guard_energy_cost)
	var reduced := GuardSystem.apply_guard_reduction(amount, guard_reduction)
	blocked.emit(amount - reduced, source)
	return reduced


func _begin_active() -> void:
	_phase = &"active"
	_attack_timer = attack.active if attack else 0.2
	if hitbox != null:
		hitbox.set_active(true)


func _begin_recovery() -> void:
	_phase = &"recovery"
	_attack_timer = attack.recovery if attack else 0.25
	if hitbox != null:
		hitbox.set_active(false)


func _finish_attack() -> void:
	is_attacking = false
	_phase = &""
	if hitbox != null:
		hitbox.set_active(false)
	if _owner != null and _owner.state.current == CharacterState.State.ATTACK:
		_owner.state.current = CharacterState.State.IDLE
	attack_finished.emit()
