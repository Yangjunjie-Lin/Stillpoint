class_name CombatComponent
extends Node

signal attack_started
signal attack_finished
signal blocked(amount: float, source: Node)
signal guard_broken
signal hit_confirmed(result: CombatHitResult)

enum CombatState {
	READY,
	WINDUP,
	ACTIVE,
	RECOVERY,
	GUARDING,
	BLOCKSTUN,
	HITSTUN,
	KNOCKED_DOWN,
	DISABLED,
}

@export var attack: AttackDefinition
@export var light_attack_ids: Array[StringName] = [&"attack_light_1", &"attack_light_2", &"attack_light_3"]
@export var hitbox: Hitbox3D
@export var melee_sweep: MeleeSweep3D
@export var guard_energy_cost: float = 5.0
@export var guard_reduction: float = 0.6
@export var watchdog_multiplier: float = 3.0

var combat_state: CombatState = CombatState.READY
var is_attacking: bool = false
var is_guarding: bool = false
var combo_window_open: bool = false
var hitbox_active: bool = false

var _owner: CharacterController
var _anim: CombatAnimationController
var _current_attack: AttackDefinition
var _combo_index: int = 0
var _queued_attack_id: StringName = &""
var _watchdog_timer: float = 0.0
var _hit_targets: Dictionary = {}


func _ready() -> void:
	_owner = get_parent() as CharacterController
	_anim = _owner.get_node_or_null("CombatAnimationController") as CombatAnimationController


func _physics_process(delta: float) -> void:
	if _watchdog_timer > 0.0:
		_watchdog_timer -= delta
		if _watchdog_timer <= 0.0 and is_attacking:
			cancel_attack(&"watchdog_timeout")


func try_attack(energy: EnergyComponent) -> bool:
	return request_attack(_next_light_attack_id())


func request_attack(attack_id: StringName) -> bool:
	var atk := _resolve_attack(attack_id)
	if atk == null:
		return false
	if combat_state in [CombatState.HITSTUN, CombatState.KNOCKED_DOWN, CombatState.DISABLED]:
		return false
	if is_attacking:
		return queue_attack(attack_id)
	if _owner != null and not _owner.state.can_attack():
		return false
	if _owner != null and _owner.energy != null and not _owner.energy.spend(atk.energy_cost):
		return false
	return _begin_attack(atk)


func queue_attack(attack_id: StringName) -> bool:
	if not combo_window_open:
		return false
	_queued_attack_id = attack_id
	return true


func open_attack_window() -> void:
	combat_state = CombatState.ACTIVE
	hitbox_active = true
	_hit_targets.clear()
	if hitbox != null:
		hitbox.damage = _current_attack.damage if _current_attack else attack.damage
		hitbox.attack_id = _current_attack.id if _current_attack else attack.id
		hitbox.maximum_targets = _current_attack.maximum_targets if _current_attack else 1
		hitbox.set_active(true)
	if melee_sweep != null:
		melee_sweep.damage = hitbox.damage if hitbox != null else attack.damage
		melee_sweep.attack_id = hitbox.attack_id if hitbox != null else attack.id
		melee_sweep.maximum_targets = _current_attack.maximum_targets if _current_attack else 1
		melee_sweep.begin_sweep()


func close_attack_window() -> void:
	hitbox_active = false
	if hitbox != null:
		hitbox.set_active(false)
	if melee_sweep != null:
		melee_sweep.end_sweep()
	if combat_state == CombatState.ACTIVE:
		combat_state = CombatState.RECOVERY


func open_combo_window() -> void:
	combo_window_open = true
	if _queued_attack_id != &"":
		var next_id := _queued_attack_id
		_queued_attack_id = &""
		finish_attack()
		request_attack(next_id)


func close_combo_window() -> void:
	combo_window_open = false
	_queued_attack_id = &""


func finish_attack() -> void:
	_finish_attack()


func cancel_attack(reason: StringName) -> void:
	close_attack_window()
	close_combo_window()
	_finish_attack()
	if reason != &"":
		push_warning("CombatComponent: attack cancelled (%s)" % reason)


func on_attack_animation_started() -> void:
	combat_state = CombatState.WINDUP


func notify_hit_landed(hurt: Hurtbox3D, dealt: float, context: Dictionary) -> void:
	if hurt == null:
		return
	var defender := hurt.get_character_owner()
	if defender == null:
		return
	var atk := _current_attack if _current_attack != null else attack
	var direction: Vector3 = context.get("direction", Vector3.FORWARD)
	var blocked_hit := bool(context.get("was_blocked", false))
	var back_attack := false
	if _owner != null and defender != null:
		back_attack = not GuardSystem.is_blocking(
			-defender.global_transform.basis.z,
			_owner.global_position,
			defender.global_position,
		)
	var result := CombatHitResult.make(_owner, defender, atk, dealt, blocked_hit, back_attack, direction)
	hit_confirmed.emit(result)
	EventBus.combat_hit_confirmed.emit(result)
	_apply_hit_feedback(defender, atk, result, direction)


func set_guarding(value: bool) -> void:
	is_guarding = value
	if value:
		combat_state = CombatState.GUARDING
		if _anim != null:
			_anim.request_guard(true)
		if _owner != null and not is_attacking:
			_owner.state.current = CharacterState.State.GUARD
	elif combat_state == CombatState.GUARDING:
		combat_state = CombatState.READY
		if _anim != null:
			_anim.request_guard(false)


func resolve_incoming_damage(
	amount: float,
	source: Node,
	defender: CharacterController,
	energy: EnergyComponent,
	context: Dictionary = {},
) -> float:
	if amount <= 0.0:
		return 0.0
	var atk_blockable := bool(context.get("blockable", true))
	var unblockable := bool(context.get("unblockable", false)) or not atk_blockable
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
	var guard_cost := guard_energy_cost
	if _current_attack != null:
		guard_cost = maxf(guard_cost, _current_attack.guard_damage * 0.5)
	if energy != null:
		if not energy.can_spend(guard_cost):
			guard_broken.emit()
			is_guarding = false
			combat_state = CombatState.READY
			var break_result := CombatHitResult.make(source, defender, attack, amount, false, true, Vector3.ZERO)
			EventBus.combat_guard_broken.emit(break_result)
			return amount
		energy.spend(guard_cost)
	var reduced := GuardSystem.apply_guard_reduction(amount, guard_reduction)
	blocked.emit(amount - reduced, source)
	context["was_blocked"] = true
	var block_result := CombatHitResult.make(source, defender, attack, amount - reduced, true, false, Vector3.ZERO)
	EventBus.combat_block_confirmed.emit(block_result)
	return reduced


# Legacy helpers used by tests.
func _begin_active() -> void:
	open_attack_window()


func _begin_recovery() -> void:
	close_attack_window()


func _begin_attack(atk: AttackDefinition) -> bool:
	_current_attack = atk
	is_attacking = true
	combat_state = CombatState.WINDUP
	combo_window_open = false
	_hit_targets.clear()
	if hitbox != null:
		hitbox.set_active(false)
		hitbox.damage = atk.damage
		hitbox.attack_id = atk.id
	if _owner != null:
		_owner.state.current = CharacterState.State.ATTACK
	attack_started.emit()
	var total := (atk.windup + atk.active + atk.recovery) * watchdog_multiplier
	_watchdog_timer = maxf(total, 1.0)
	if _anim != null:
		_anim.request_attack(atk)
	else:
		_fallback_attack_timeline(atk)
	return true


func _finish_attack() -> void:
	close_attack_window()
	close_combo_window()
	is_attacking = false
	hitbox_active = false
	combat_state = CombatState.READY
	_watchdog_timer = 0.0
	_current_attack = null
	if hitbox != null:
		hitbox.set_active(false)
	if _owner != null and _owner.state.current == CharacterState.State.ATTACK:
		_owner.state.current = CharacterState.State.IDLE
	attack_finished.emit()


func _fallback_attack_timeline(atk: AttackDefinition) -> void:
	on_attack_animation_started()
	var tree := get_tree()
	if tree == null:
		open_attack_window()
		close_attack_window()
		finish_attack()
		return
	call_deferred("_run_fallback", atk)


func _run_fallback(atk: AttackDefinition) -> void:
	await get_tree().create_timer(atk.windup).timeout
	open_attack_window()
	await get_tree().create_timer(atk.active).timeout
	close_attack_window()
	open_combo_window()
	await get_tree().create_timer(atk.recovery * 0.5).timeout
	close_combo_window()
	await get_tree().create_timer(atk.recovery * 0.5).timeout
	finish_attack()


func _resolve_attack(attack_id: StringName) -> AttackDefinition:
	if attack != null and (attack_id == &"" or attack.id == attack_id):
		attack.migrate_legacy_fields()
		return attack
	var resolved := ResourceRegistry.get_attack(attack_id)
	if resolved != null:
		resolved.migrate_legacy_fields()
		return resolved
	return attack


func _next_light_attack_id() -> StringName:
	if light_attack_ids.is_empty():
		return attack.id if attack != null else &"attack_light_1"
	var id := light_attack_ids[_combo_index % light_attack_ids.size()]
	_combo_index = (_combo_index + 1) % light_attack_ids.size()
	return id


func _apply_hit_feedback(
	defender: CharacterController,
	atk: AttackDefinition,
	result: CombatHitResult,
	direction: Vector3,
) -> void:
	if defender == null:
		return
	var knockback := defender.get_node_or_null("KnockbackComponent") as KnockbackComponent
	if knockback != null and atk != null and atk.knockback_distance > 0.0:
		knockback.apply_impulse(direction, atk.knockback_distance, atk.knockback_duration)
		if atk.launch_velocity > 0.0:
			knockback.apply_launch(atk.launch_velocity, direction * 0.2)
	var anim := defender.get_node_or_null("CombatAnimationController") as CombatAnimationController
	if anim != null:
		anim.request_hit_reaction(-direction, atk.poise_damage)
	if atk != null and atk.causes_knockdown:
		defender.state.current = CharacterState.State.DOWNED
