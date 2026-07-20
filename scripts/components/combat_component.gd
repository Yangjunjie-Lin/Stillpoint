class_name CombatComponent
extends Node

signal attack_started
signal attack_finished

@export var attack: AttackDefinition
@export var hitbox: Hitbox3D

var is_attacking: bool = false
var is_guarding: bool = false
var _attack_timer: float = 0.0
var _phase: StringName = &""


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
	attack_started.emit()
	return true


func set_guarding(value: bool) -> void:
	is_guarding = value


func apply_incoming_damage(
	amount: float,
	source: Node,
	defender: CharacterController,
	energy: EnergyComponent,
) -> float:
	if is_guarding and source is Node3D and defender != null:
		if GuardSystem.is_blocking(
			-defender.global_transform.basis.z,
			(source as Node3D).global_position,
			defender.global_position,
		):
			if energy != null:
				energy.spend(attack.energy_cost if attack else 3.0)
			return GuardSystem.apply_guard_reduction(amount)
	var info := DamageInfo.make(amount, source)
	if defender != null and defender.health != null:
		return defender.health.apply_damage(info, false)
	return 0.0


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
	attack_finished.emit()
