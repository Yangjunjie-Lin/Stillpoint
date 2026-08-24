class_name CombatComponent
extends Node

signal attack_started
signal attack_finished
signal blocked(amount: float, source: Node)
signal guard_broken
signal hit_confirmed(result: CombatHitResult)
signal parry_success(attacker: Node, defender: Node)
signal parry_failed
signal dodge_started(direction: Vector3)
signal dodge_finished
signal poise_broken
signal combat_state_changed(previous: CombatState, current: CombatState)

enum CombatState {
	READY,
	WINDUP,
	ACTIVE,
	RECOVERY,
	GUARDING,
	PARRY_WINDOW,
	DODGING,
	BLOCKSTUN,
	HITSTUN,
	STAGGERED,
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
@export var parry_window_duration: float = 0.16
@export var dodge_duration: float = 0.32
@export var dodge_distance: float = 3.2
@export var dodge_energy_cost: float = 18.0
@export var dodge_iframe_start: float = 0.04
@export var dodge_iframe_duration: float = 0.22
@export var stagger_duration: float = 0.55
@export var guard_poise_multiplier: float = 0.35

var combat_state: CombatState = CombatState.READY
var is_attacking: bool = false
var is_guarding: bool = false
var combo_window_open: bool = false
var hitbox_active: bool = false
var damage_bonus: float = 0.0
var poise: PoiseComponent

var _owner: CharacterController
var _anim: CombatAnimationController
var _current_attack: AttackDefinition
var _combo_index: int = 0
var _queued_attack_id: StringName = &""
var _watchdog_timer: float = 0.0
var _hit_targets: Dictionary = {}
var _parry_timer := 0.0
var _dodge_timer := 0.0
var _dodge_elapsed := 0.0
var _dodge_iframe_delay_remaining := 0.0
var _dodge_iframe_remaining := 0.0
var _dodge_direction := Vector3.ZERO
var _stun_timer := 0.0
var _fallback_poise := 100.0
var _fallback_max_poise := 100.0
var _fallback_poise_broken := false
var _attack_generation := 0


func _ready() -> void:
	_owner = get_parent() as CharacterController
	_anim = _owner.get_node_or_null("CombatAnimationController") as CombatAnimationController
	poise = _owner.get_node_or_null("PoiseComponent") as PoiseComponent
	if poise != null:
		if not poise.poise_broken.is_connected(_on_poise_broken):
			poise.poise_broken.connect(_on_poise_broken)


func _physics_process(delta: float) -> void:
	if _owner != null:
		if _owner.is_permanently_dead and combat_state != CombatState.DISABLED:
			enter_terminal_state(true)
			return
		if _owner.is_downed and combat_state != CombatState.KNOCKED_DOWN:
			enter_terminal_state(false)
			return
	if _parry_timer > 0.0:
		_parry_timer -= delta
		if _parry_timer <= 0.0 and combat_state == CombatState.PARRY_WINDOW:
			_set_combat_state(CombatState.GUARDING if is_guarding else CombatState.READY)
			if _anim != null:
				_anim.request_guard(is_guarding)
	if combat_state == CombatState.DODGING:
		_dodge_elapsed += delta
		_dodge_timer -= delta
		if _dodge_iframe_delay_remaining > 0.0:
			_dodge_iframe_delay_remaining -= delta
			if _dodge_iframe_delay_remaining <= 0.0 and _owner != null and _owner.hurtbox != null:
				_owner.hurtbox.grant_invulnerability(&"dodge")
		if _dodge_iframe_remaining > 0.0:
			_dodge_iframe_remaining -= delta
			if _dodge_iframe_remaining <= 0.0 and _owner != null and _owner.hurtbox != null:
				_owner.hurtbox.revoke_invulnerability(&"dodge")
		if _dodge_timer <= 0.0:
			_finish_dodge()
	if _stun_timer > 0.0:
		_stun_timer -= delta
		if _stun_timer <= 0.0 and combat_state in [CombatState.HITSTUN, CombatState.BLOCKSTUN, CombatState.STAGGERED, CombatState.KNOCKED_DOWN]:
			if _owner != null and (_owner.is_downed or _owner.is_permanently_dead):
				enter_terminal_state(_owner.is_permanently_dead)
				return
			var recover_to_guard := is_guarding and combat_state == CombatState.BLOCKSTUN
			_set_combat_state(CombatState.GUARDING if recover_to_guard else CombatState.READY)
			if _owner != null:
				_owner.state.current = CharacterState.State.GUARD if recover_to_guard else CharacterState.State.IDLE
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
	if combat_state in [CombatState.HITSTUN, CombatState.STAGGERED, CombatState.DODGING, CombatState.KNOCKED_DOWN, CombatState.DISABLED]:
		return false
	if is_attacking:
		return queue_attack(attack_id)
	if _owner != null and not _owner.state.can_attack():
		return false
	if _owner != null and _owner.energy != null and not _owner.energy.spend(atk.energy_cost):
		return false
	return _begin_attack(atk)


func request_heavy_attack() -> bool:
	return request_attack(&"attack_heavy_1")


func request_dodge(direction: Vector3 = Vector3.ZERO) -> bool:
	if _owner == null or _owner.energy == null:
		return false
	if is_attacking or combat_state in [CombatState.DODGING, CombatState.GUARDING, CombatState.HITSTUN, CombatState.STAGGERED, CombatState.KNOCKED_DOWN, CombatState.DISABLED, CombatState.PARRY_WINDOW]:
		return false
	if _owner.state.current in [CharacterState.State.DOWNED, CharacterState.State.DISABLED, CharacterState.State.MOUNTED, CharacterState.State.INTERACT]:
		return false
	if not _owner.energy.spend(dodge_energy_cost):
		return false
	if direction.length_squared() < 0.001:
		direction = -_owner.global_transform.basis.z
	_dodge_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	if _dodge_direction.length_squared() < 0.001:
		_dodge_direction = -_owner.global_transform.basis.z
	_dodge_timer = dodge_duration
	_dodge_elapsed = 0.0
	_dodge_iframe_delay_remaining = maxf(0.0, dodge_iframe_start)
	_dodge_iframe_remaining = maxf(0.0, dodge_iframe_start) + dodge_iframe_duration
	_set_combat_state(CombatState.DODGING)
	if _owner.hurtbox != null and dodge_iframe_start <= 0.0:
		_owner.hurtbox.grant_invulnerability(&"dodge")
	dodge_started.emit(_dodge_direction)
	if _anim != null:
		_anim.request_dodge(_dodge_direction)
	return true


func get_dodge_velocity() -> Vector3:
	if combat_state != CombatState.DODGING:
		return Vector3.ZERO
	var remaining_ratio := clampf(1.0 - _dodge_elapsed / maxf(dodge_duration, 0.01), 0.0, 1.0)
	return _dodge_direction * (dodge_distance / maxf(dodge_duration, 0.01)) * (0.45 + remaining_ratio * 0.55)


func is_dodging() -> bool:
	return combat_state == CombatState.DODGING


func is_dodge_iframe_active() -> bool:
	return is_dodging() and _dodge_iframe_remaining > 0.0 and _dodge_elapsed >= dodge_iframe_start


func begin_guard() -> bool:
	if _owner == null or is_attacking or not _owner.state.can_attack() or combat_state in [CombatState.DODGING, CombatState.HITSTUN, CombatState.STAGGERED, CombatState.KNOCKED_DOWN, CombatState.DISABLED]:
		return false
	is_guarding = true
	_parry_timer = parry_window_duration
	_set_combat_state(CombatState.PARRY_WINDOW)
	if _anim != null:
		_anim.request_parry_start()
	_owner.state.current = CharacterState.State.GUARD
	return true


func queue_attack(attack_id: StringName) -> bool:
	if not combo_window_open:
		return false
	_queued_attack_id = attack_id
	return true


func open_attack_window() -> void:
	if not is_attacking or _current_attack == null:
		return
	_set_combat_state(CombatState.ACTIVE)
	hitbox_active = true
	_hit_targets.clear()
	if hitbox != null:
		hitbox.damage = (_current_attack.damage if _current_attack else attack.damage) + damage_bonus
		hitbox.attack_id = _current_attack.id if _current_attack else attack.id
		hitbox.maximum_targets = _current_attack.maximum_targets if _current_attack else 1
		hitbox.set_active(true)
	if melee_sweep != null:
		melee_sweep.damage = hitbox.damage if hitbox != null else attack.damage + damage_bonus
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
		_set_combat_state(CombatState.RECOVERY)


func open_combo_window() -> void:
	if not is_attacking:
		return
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
	if is_attacking:
		_set_combat_state(CombatState.WINDUP)


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
	if value:
		if not is_guarding:
			begin_guard()
		return
	is_guarding = false
	_parry_timer = 0.0
	if combat_state in [CombatState.GUARDING, CombatState.PARRY_WINDOW]:
		_set_combat_state(CombatState.READY)
	if _anim != null:
		_anim.request_guard(false)
	if _owner != null and _owner.state.current == CharacterState.State.GUARD:
		_owner.state.current = CharacterState.State.IDLE


func resolve_incoming_damage(
	amount: float,
	source: Node,
	defender: CharacterController,
	energy: EnergyComponent,
	context: Dictionary = {},
) -> float:
	if amount <= 0.0:
		return 0.0
	var atk_context: AttackDefinition = context.get("attack_definition") as AttackDefinition
	var atk_blockable := bool(context.get("blockable", atk_context.blockable if atk_context != null else true))
	var unblockable := bool(context.get("unblockable", false)) or not atk_blockable
	if combat_state == CombatState.PARRY_WINDOW and not unblockable and bool(context.get("parryable", atk_context.parryable if atk_context != null else true)):
		if source is Node3D and defender != null and GuardSystem.is_blocking(
			-defender.global_transform.basis.z,
			(source as Node3D).global_position,
			defender.global_position,
		):
			context["was_parried"] = true
			_handle_parry_success(source, defender, atk_context)
			return 0.0
		parry_failed.emit()
	if not is_guarding or unblockable or defender == null:
		_apply_incoming_poise(atk_context, 1.0)
		_begin_stun(CombatState.HITSTUN, atk_context.hitstun_duration if atk_context != null else 0.2)
		return amount
	if not (source is Node3D):
		return amount
	if not GuardSystem.is_blocking(
		-defender.global_transform.basis.z,
		(source as Node3D).global_position,
		defender.global_position,
	):
		_apply_incoming_poise(atk_context, 1.0)
		_begin_stun(CombatState.HITSTUN, atk_context.hitstun_duration if atk_context != null else 0.2)
		return amount
	var guard_cost := guard_energy_cost
	if atk_context != null:
		guard_cost = maxf(guard_cost, atk_context.guard_damage * 0.5)
	if energy != null:
		if not energy.can_spend(guard_cost):
			guard_broken.emit()
			is_guarding = false
			_parry_timer = 0.0
			_set_combat_state(CombatState.READY)
			if _owner != null and _owner.state.current == CharacterState.State.GUARD:
				_owner.state.current = CharacterState.State.IDLE
			var break_result := CombatHitResult.make(source, defender, attack, amount, false, true, Vector3.ZERO)
			EventBus.combat_guard_broken.emit(break_result)
			return amount
		energy.spend(guard_cost)
	var reduced := GuardSystem.apply_guard_reduction(amount, guard_reduction)
	_apply_incoming_poise(atk_context, guard_poise_multiplier)
	_begin_stun(CombatState.BLOCKSTUN, atk_context.blockstun_duration if atk_context != null else 0.12)
	blocked.emit(amount - reduced, source)
	context["was_blocked"] = true
	var block_result := CombatHitResult.make(source, defender, attack, amount - reduced, true, false, Vector3.ZERO)
	EventBus.combat_block_confirmed.emit(block_result)
	return reduced


func get_current_attack_definition() -> AttackDefinition:
	return _current_attack if _current_attack != null else attack


func get_poise() -> float:
	return poise.current_poise if poise != null else _fallback_poise


func get_max_poise() -> float:
	return poise.max_poise if poise != null else _fallback_max_poise


func apply_poise_damage(amount: float, multiplier: float = 1.0) -> bool:
	if poise != null:
		return poise.apply_damage(amount, multiplier)
	if _fallback_poise <= 0.0 or amount <= 0.0:
		return false
	_fallback_poise = maxf(0.0, _fallback_poise - amount * multiplier)
	if _fallback_poise > 0.0 or _fallback_poise_broken:
		return false
	_fallback_poise_broken = true
	return true


func _apply_incoming_poise(atk: AttackDefinition, multiplier: float) -> void:
	if atk == null:
		return
	if apply_poise_damage(atk.poise_damage, multiplier) and poise == null:
		_on_poise_broken()


func _on_poise_broken() -> void:
	if combat_state in [CombatState.KNOCKED_DOWN, CombatState.DISABLED] or (_owner != null and (_owner.is_downed or _owner.is_permanently_dead)):
		return
	if is_attacking:
		_finish_attack()
	close_attack_window()
	_set_combat_state(CombatState.STAGGERED)
	_stun_timer = stagger_duration
	if _owner != null:
		_owner.state.current = CharacterState.State.ATTACK
	if _anim != null:
		_anim.request_stagger()
	poise_broken.emit()


func _handle_parry_success(source: Node, defender: CharacterController, atk: AttackDefinition) -> void:
	_parry_timer = 0.0
	_set_combat_state(CombatState.GUARDING)
	if _anim != null:
		_anim.request_parry_success()
	var attacker := source as CharacterController
	if attacker != null and attacker.combat != null:
		attacker.combat.enter_stagger(stagger_duration)
	parry_success.emit(source, defender)


func enter_stagger(duration: float = -1.0) -> void:
	if combat_state in [CombatState.KNOCKED_DOWN, CombatState.DISABLED] or (_owner != null and (_owner.is_downed or _owner.is_permanently_dead)):
		return
	_interrupt_current_action()
	is_guarding = false
	_parry_timer = 0.0
	if _anim != null:
		_anim.request_guard(false)
	_set_combat_state(CombatState.STAGGERED)
	_stun_timer = stagger_duration if duration < 0.0 else maxf(0.0, duration)
	if _owner != null:
		_owner.state.current = CharacterState.State.ATTACK
	if _anim != null:
		_anim.request_stagger()


func enter_knockdown(duration: float = -1.0) -> void:
	if combat_state == CombatState.DISABLED or (_owner != null and (_owner.is_downed or _owner.is_permanently_dead)):
		return
	_interrupt_current_action()
	is_guarding = false
	_parry_timer = 0.0
	_set_combat_state(CombatState.KNOCKED_DOWN)
	_stun_timer = stagger_duration if duration < 0.0 else maxf(0.0, duration)
	if _owner != null:
		_owner.state.current = CharacterState.State.ATTACK


func enter_terminal_state(permanent: bool) -> void:
	_interrupt_current_action()
	_clear_dodge_state()
	is_guarding = false
	_parry_timer = 0.0
	_stun_timer = 0.0
	_set_combat_state(CombatState.DISABLED if permanent else CombatState.KNOCKED_DOWN)


func reset_runtime_state() -> void:
	_interrupt_current_action()
	_clear_dodge_state()
	is_guarding = false
	_parry_timer = 0.0
	_stun_timer = 0.0
	if _owner != null and (_owner.is_downed or _owner.is_permanently_dead):
		_set_combat_state(CombatState.DISABLED if _owner.is_permanently_dead else CombatState.KNOCKED_DOWN)
	else:
		_set_combat_state(CombatState.READY)


func _begin_stun(next_state: CombatState, duration: float) -> void:
	if duration <= 0.0 or combat_state in [CombatState.DODGING, CombatState.STAGGERED, CombatState.KNOCKED_DOWN, CombatState.DISABLED]:
		return
	_interrupt_current_action()
	_parry_timer = 0.0
	_set_combat_state(next_state)
	_stun_timer = maxf(_stun_timer, duration)
	if _owner != null:
		_owner.state.current = CharacterState.State.ATTACK


func _finish_dodge() -> void:
	if combat_state != CombatState.DODGING:
		_clear_dodge_state()
		return
	_clear_dodge_state()
	if _owner != null and (_owner.is_downed or _owner.is_permanently_dead):
		enter_terminal_state(_owner.is_permanently_dead)
		return
	_set_combat_state(CombatState.READY)
	dodge_finished.emit()


func _clear_dodge_state() -> void:
	if _owner != null and _owner.hurtbox != null:
		_owner.hurtbox.revoke_invulnerability(&"dodge")
	_dodge_timer = 0.0
	_dodge_elapsed = 0.0
	_dodge_iframe_delay_remaining = 0.0
	_dodge_iframe_remaining = 0.0
	_dodge_direction = Vector3.ZERO


func _set_combat_state(next: CombatState) -> void:
	if combat_state == next:
		return
	var previous := combat_state
	combat_state = next
	combat_state_changed.emit(previous, next)


# Legacy helpers used by tests.
func _begin_active() -> void:
	open_attack_window()


func _begin_recovery() -> void:
	close_attack_window()


func _begin_attack(atk: AttackDefinition) -> bool:
	_attack_generation += 1
	_current_attack = atk
	is_attacking = true
	_set_combat_state(CombatState.WINDUP)
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
		_fallback_attack_timeline(atk, _attack_generation)
	return true


func _finish_attack() -> void:
	var was_attacking := is_attacking
	_attack_generation += 1
	close_attack_window()
	close_combo_window()
	is_attacking = false
	hitbox_active = false
	_watchdog_timer = 0.0
	_current_attack = null
	if hitbox != null:
		hitbox.set_active(false)
	if combat_state not in [CombatState.HITSTUN, CombatState.BLOCKSTUN, CombatState.STAGGERED, CombatState.KNOCKED_DOWN, CombatState.DISABLED]:
		_set_combat_state(CombatState.READY)
		if _owner != null and _owner.state.current == CharacterState.State.ATTACK:
			_owner.state.current = CharacterState.State.IDLE
	if was_attacking:
		attack_finished.emit()


func _interrupt_current_action() -> void:
	if combat_state == CombatState.DODGING:
		_clear_dodge_state()
		dodge_finished.emit()
	if is_attacking:
		_finish_attack()
	else:
		_attack_generation += 1
		close_attack_window()
		close_combo_window()
		_watchdog_timer = 0.0
		_current_attack = null


func _fallback_attack_timeline(atk: AttackDefinition, generation: int) -> void:
	on_attack_animation_started()
	var tree := get_tree()
	if tree == null:
		open_attack_window()
		close_attack_window()
		finish_attack()
		return
	call_deferred("_run_fallback", atk, generation)


func _run_fallback(atk: AttackDefinition, generation: int) -> void:
	await get_tree().create_timer(atk.windup).timeout
	if not _attack_is_current(atk, generation):
		return
	open_attack_window()
	await get_tree().create_timer(atk.active).timeout
	if not _attack_is_current(atk, generation):
		return
	close_attack_window()
	open_combo_window()
	await get_tree().create_timer(atk.recovery * 0.5).timeout
	if not _attack_is_current(atk, generation):
		return
	close_combo_window()
	await get_tree().create_timer(atk.recovery * 0.5).timeout
	if not _attack_is_current(atk, generation):
		return
	finish_attack()


func _attack_is_current(atk: AttackDefinition, generation: int) -> bool:
	return is_attacking and _current_attack == atk and _attack_generation == generation


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
	if anim != null and atk != null:
		anim.request_hit_reaction(-direction, atk.poise_damage)
	if atk != null and atk.causes_knockdown:
		var defender_combat := defender.combat
		if defender_combat != null:
			defender_combat.enter_knockdown(maxf(atk.hitstun_duration, stagger_duration))
