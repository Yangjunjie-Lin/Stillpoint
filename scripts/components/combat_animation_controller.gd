class_name CombatAnimationController
extends Node
## Drives AnimationPlayer/AnimationTree and forwards animation events to CombatComponent.

signal animation_action_started(action_id: StringName)
signal animation_action_finished(action_id: StringName)

@export var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var animation_tree_path: NodePath = NodePath("AnimationTree")

var _owner: CharacterController
var _player: AnimationPlayer
var _tree: AnimationTree
var _combat: CombatComponent
var _current_action: StringName = &""
var _locomotion_state: StringName = &"idle"
var _context_motion: StringName = &""
var _visual_action_serial: int = 0
var _visual_action_locked: bool = false


func _ready() -> void:
	_owner = get_parent() as CharacterController
	# Child _ready() runs before the parent's @onready fields are assigned.
	if _owner != null:
		_combat = _owner.get_node_or_null("CombatComponent") as CombatComponent
	if _combat != null and not _combat.attack_finished.is_connected(_on_combat_attack_finished):
		_combat.attack_finished.connect(_on_combat_attack_finished)
	_player = get_node_or_null(animation_player_path) as AnimationPlayer
	_tree = get_node_or_null(animation_tree_path) as AnimationTree
	if _player == null and _owner != null:
		_player = _owner.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player != null:
		_ensure_placeholder_library()
		if not _player.animation_finished.is_connected(_on_animation_finished):
			_player.animation_finished.connect(_on_animation_finished)


func request_attack(attack: AttackDefinition) -> bool:
	if attack == null or _combat == null:
		return false
	var anim_name := String(attack.animation_name)
	if anim_name == "":
		anim_name = "attack_light_1"
	var clip := _clip_name(anim_name)
	_current_action = attack.id
	_visual_action_serial += 1
	_visual_action_locked = true
	var attack_motion := &"attack"
	if _owner.has_method("get_attack_motion_state"):
		attack_motion = StringName(_owner.call("get_attack_motion_state"))
	_set_visual_motion(attack_motion)
	animation_action_started.emit(attack.id)
	if _player != null and _player.has_animation(clip):
		_player.play(clip, -1.0, attack.animation_speed)
	else:
		_simulate_attack_timeline.call_deferred(attack)
	return true


func _clip_name(short_name: String) -> StringName:
	var full := "combat/%s" % short_name
	if _player != null and _player.has_animation(full):
		return full
	if _player != null and _player.has_animation(short_name):
		return short_name
	return StringName(short_name)


func request_guard(active: bool) -> void:
	_visual_action_serial += 1
	_visual_action_locked = active
	_set_visual_motion(&"guard" if active else _base_motion())
	if _player == null:
		return
	if active:
		if _player.has_animation("combat/guard_loop"):
			_player.play("combat/guard_loop")
	else:
		if _player.has_animation("combat/guard_exit"):
			_player.play("combat/guard_exit")


func request_hit_reaction(direction: Vector3, severity: float) -> void:
	var anim := _pick_hit_animation(direction, severity)
	_visual_action_serial += 1
	_visual_action_locked = true
	var serial := _visual_action_serial
	_set_visual_motion(StringName(anim))
	_restore_visual_after.call_deferred(0.36, serial)
	if _player != null and _player.has_animation(_clip_name(anim)):
		_player.play(_clip_name(anim))


func request_downed() -> void:
	_visual_action_serial += 1
	_visual_action_locked = true
	_set_visual_motion(&"downed")
	if _player != null and _player.has_animation("downed"):
		_player.play("downed")


func request_death() -> void:
	_visual_action_serial += 1
	_visual_action_locked = true
	_set_visual_motion(&"death")
	if _player != null and _player.has_animation("death"):
		_player.play("death")


func set_locomotion(velocity: Vector3, grounded: bool, crouching: bool) -> void:
	var horiz := Vector2(velocity.x, velocity.z).length()
	var next := &"idle"
	if not grounded:
		next = &"fall" if velocity.y < -0.5 else &"jump_loop"
	elif crouching:
		next = &"crouch_walk" if horiz > 0.2 else &"crouch_idle"
	elif horiz > 5.0:
		next = &"run"
	elif horiz > 0.2:
		next = &"walk"
	var changed := next != _locomotion_state
	_locomotion_state = next
	if _visual_action_locked or (_combat != null and _combat.is_attacking):
		return
	if _context_motion == &"":
		_set_visual_motion(next)
	if changed and _player != null and _player.has_animation(_clip_name(String(next))):
		_player.play(_clip_name(String(next)))


func set_context_motion(state: StringName) -> void:
	if state == _context_motion:
		return
	_context_motion = state
	_visual_action_serial += 1
	if not _visual_action_locked and (_combat == null or not _combat.is_attacking):
		_set_visual_motion(_base_motion())


# --- Animation method track callbacks ----------------------------------------

func attack_started() -> void:
	if _combat != null:
		_combat.on_attack_animation_started()


func attack_window_open() -> void:
	if _combat != null:
		_combat.open_attack_window()


func attack_window_close() -> void:
	if _combat != null:
		_combat.close_attack_window()


func combo_window_open() -> void:
	if _combat != null:
		_combat.open_combo_window()


func combo_window_close() -> void:
	if _combat != null:
		_combat.close_combo_window()


func movement_window_open() -> void:
	pass


func movement_window_close() -> void:
	pass


func attack_finished() -> void:
	if _combat != null:
		_combat.finish_attack()
	animation_action_finished.emit(_current_action)
	_current_action = &""
	_visual_action_serial += 1
	_visual_action_locked = false
	_set_visual_motion(_base_motion())


func _on_animation_finished(anim_name: StringName) -> void:
	if String(anim_name).begins_with("attack_"):
		attack_finished()


func _simulate_attack_timeline(attack: AttackDefinition) -> void:
	# Programmatic timeline when placeholder clips are absent.
	attack_started()
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(attack.windup / maxf(attack.animation_speed, 0.01)).timeout
	attack_window_open()
	await tree.create_timer(attack.active / maxf(attack.animation_speed, 0.01)).timeout
	attack_window_close()
	combo_window_open()
	await tree.create_timer(attack.recovery * 0.5 / maxf(attack.animation_speed, 0.01)).timeout
	combo_window_close()
	await tree.create_timer(attack.recovery * 0.5 / maxf(attack.animation_speed, 0.01)).timeout
	attack_finished()


func _pick_hit_animation(direction: Vector3, severity: float) -> String:
	if severity >= 1.5:
		return "hit_heavy"
	var local := direction
	if _owner != null:
		local = _owner.global_transform.basis.inverse() * direction
	if absf(local.x) > absf(local.z):
		return "hit_right_light" if local.x > 0.0 else "hit_left_light"
	return "hit_back_light" if local.z > 0.0 else "hit_front_light"


func _base_motion() -> StringName:
	return _context_motion if _context_motion != &"" else _locomotion_state


func _set_visual_motion(state: StringName) -> void:
	if _owner == null:
		return
	var visual_root := _owner.get_node_or_null("VisualRoot")
	if visual_root == null:
		visual_root = _owner
	var pending: Array[Node] = [visual_root]
	while not pending.is_empty():
		var node: Node = pending.pop_front()
		if node.has_method("set_motion_state"):
			node.call("set_motion_state", state)
			return
		for child in node.get_children():
			pending.append(child)


func _restore_visual_after(seconds: float, serial: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(seconds).timeout
	if serial != _visual_action_serial:
		return
	if _owner != null and (_owner.is_downed or _owner.is_permanently_dead):
		return
	_visual_action_locked = false
	_set_visual_motion(_base_motion())


func _on_combat_attack_finished() -> void:
	if _owner != null and (_owner.is_downed or _owner.is_permanently_dead):
		return
	_visual_action_locked = false
	_set_visual_motion(_base_motion())


func _ensure_placeholder_library() -> void:
	if _player == null:
		return
	const LIB_NAME := "combat"
	if _player.has_animation_library(LIB_NAME):
		return
	var lib := AnimationLibrary.new()
	for anim_name in [
		"idle", "walk", "run", "crouch_idle", "crouch_walk", "jump_loop", "fall",
		"guard_loop", "guard_exit", "attack_light_1", "attack_light_2", "attack_light_3",
		"hit_front_light", "hit_back_light", "hit_left_light", "hit_right_light",
		"hit_heavy", "downed", "death",
	]:
		lib.add_animation(anim_name, _make_attack_placeholder(anim_name))
	_player.add_animation_library(LIB_NAME, lib)


func _make_attack_placeholder(anim_name: String) -> Animation:
	var anim := Animation.new()
	anim.length = 0.6
	if anim_name.begins_with("attack_light"):
		anim.length = 0.55
		_add_method_key(anim, 0.0, "attack_started")
		_add_method_key(anim, 0.12, "attack_window_open")
		_add_method_key(anim, 0.28, "attack_window_close")
		_add_method_key(anim, 0.32, "combo_window_open")
		_add_method_key(anim, 0.45, "combo_window_close")
		_add_method_key(anim, 0.55, "attack_finished")
	elif anim_name == "idle":
		anim.length = 1.0
		anim.loop_mode = Animation.LOOP_LINEAR
	else:
		anim.length = 0.4
	return anim


func _add_method_key(anim: Animation, time: float, method: String) -> void:
	var track := anim.add_track(Animation.TYPE_METHOD)
	# AnimationPlayer's default root is this controller, so method tracks target it directly.
	anim.track_set_path(track, NodePath("."))
	anim.track_insert_key(track, time, {"method": method, "args": []})
