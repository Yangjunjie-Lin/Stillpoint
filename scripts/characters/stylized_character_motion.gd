class_name StylizedCharacterMotion
extends RefCounted
## Lightweight procedural motion rig for the project's modular low-poly characters.
##
## Models opt into the rig by using the shared semantic part names below. This
## keeps player origins and NPC archetypes animated without coupling gameplay to
## a particular imported skeleton or animation library.

const MOTION_PARTS: Array[StringName] = [
	&"LeftLeg",
	&"RightLeg",
	&"LeftBoot",
	&"RightBoot",
	&"LeftArm",
	&"RightArm",
	&"LeftHand",
	&"RightHand",
	&"Torso",
	&"Head",
	&"Neck",
]

var _root: Node3D
var _root_transform := Transform3D.IDENTITY
var _parts: Dictionary = {}
var _base_transforms: Dictionary = {}
var _arm_chains: Array[Dictionary] = []
var _state: StringName = &"idle"
var _time: float = 0.0


func bind(model_root: Node3D) -> void:
	_root = model_root
	_parts.clear()
	_base_transforms.clear()
	_arm_chains.clear()
	_time = 0.0
	if _root == null:
		return
	_root_transform = _root.transform
	for part_name in MOTION_PARTS:
		var part := _root.find_child(String(part_name), true, false) as Node3D
		if part == null:
			continue
		_parts[part_name] = part
		_base_transforms[part_name] = part.transform
	_register_arm_chain(&"LeftArm", &"LeftHand")
	_register_arm_chain(&"RightArm", &"RightHand")


func set_state(state: StringName) -> void:
	var normalized := state if state != &"" else &"idle"
	if normalized == _state:
		return
	_state = normalized
	_time = 0.0


func get_state() -> StringName:
	return _state


func update(delta: float) -> void:
	if _root == null or not is_instance_valid(_root):
		return
	_time += maxf(delta, 0.0)
	_reset_pose()
	match _state:
		&"walk", &"crouch_walk":
			_apply_walk(1.0 if _state == &"walk" else 0.62)
		&"run":
			_apply_run()
		&"talk":
			_apply_talk()
		&"point":
			_apply_point()
		&"explain":
			_apply_explain()
		&"work":
			_apply_work()
		&"present":
			_apply_present()
		&"salute":
			_apply_salute()
		&"recall":
			_apply_recall()
		&"reassure", &"thank":
			_apply_reassure(_state == &"thank")
		&"inspect":
			_apply_inspect()
		&"avoid":
			_apply_avoid()
		&"threaten":
			_apply_threaten()
		&"attack", &"attack_light_1", &"attack_light_2", &"attack_light_3":
			_apply_attack()
		&"guard":
			_apply_guard()
		&"hit", &"hit_front_light", &"hit_back_light", &"hit_left_light", \
			&"hit_right_light", &"hit_heavy":
			_apply_hit()
		&"downed":
			_apply_downed(false)
		&"death":
			_apply_downed(true)
		&"jump_loop", &"fall":
			_apply_airborne()
		&"crouch_idle":
			_apply_idle(0.45)
		_:
			_apply_idle(1.0)
	_sync_arm_chains()


func _register_arm_chain(arm_name: StringName, hand_name: StringName) -> void:
	var arm := _parts.get(arm_name) as Node3D
	var hand := _parts.get(hand_name) as Node3D
	if arm == null or hand == null:
		return
	var arm_base := arm.transform
	var hand_base := hand.transform
	var hand_offset := hand_base.origin - arm_base.origin
	# Both meshes were authored around their centers. Reflecting the hand offset
	# across the arm center yields a stable shoulder pivot without requiring a
	# Skeleton3D asset and keeps every procedural archetype compatible.
	var shoulder := arm_base.origin - hand_offset
	_arm_chains.append({
		"arm": arm,
		"hand": hand,
		"arm_base": arm_base,
		"hand_base": hand_base,
		"shoulder": shoulder,
	})


func _sync_arm_chains() -> void:
	for chain in _arm_chains:
		var arm := chain.get("arm") as Node3D
		var hand := chain.get("hand") as Node3D
		if arm == null or hand == null or not is_instance_valid(arm) or not is_instance_valid(hand):
			continue
		var arm_base: Transform3D = chain["arm_base"]
		var hand_base: Transform3D = chain["hand_base"]
		var shoulder: Vector3 = chain["shoulder"]
		var arm_delta := arm.transform.basis * arm_base.basis.inverse()
		arm.position = shoulder + arm_delta * (arm_base.origin - shoulder)
		hand.position = shoulder + arm_delta * (hand_base.origin - shoulder)
		# Retain wrist gesture rotation, then inherit the whole arm rotation.
		hand.basis = arm_delta * hand.transform.basis


func _reset_pose() -> void:
	_root.transform = _root_transform
	for part_name in _parts:
		var part := _parts[part_name] as Node3D
		if part != null and is_instance_valid(part):
			part.transform = _base_transforms[part_name]


func _apply_idle(amount: float) -> void:
	var breath := sin(_time * 1.75)
	_root.position.y += breath * 0.012 * amount
	_rotate(&"Torso", Vector3(breath * 0.012, 0.0, sin(_time * 0.7) * 0.012) * amount)
	_rotate(&"Head", Vector3(sin(_time * 0.9) * 0.01, sin(_time * 0.42) * 0.025, 0.0) * amount)
	_rotate(&"LeftArm", Vector3(sin(_time * 0.68) * 0.025, 0.0, 0.0) * amount)
	_rotate(&"RightArm", Vector3(-sin(_time * 0.68) * 0.025, 0.0, 0.0) * amount)


func _apply_walk(amount: float) -> void:
	var phase := _time * 7.4
	var swing := sin(phase) * 0.58 * amount
	var lift := absf(sin(phase)) * 0.035 * amount
	_root.position.y += lift
	_rotate(&"LeftLeg", Vector3(swing, 0.0, 0.0))
	_rotate(&"RightLeg", Vector3(-swing, 0.0, 0.0))
	_rotate(&"LeftBoot", Vector3(-swing * 0.28, 0.0, 0.0))
	_rotate(&"RightBoot", Vector3(swing * 0.28, 0.0, 0.0))
	_rotate(&"LeftArm", Vector3(-swing * 0.72, 0.0, 0.02))
	_rotate(&"RightArm", Vector3(swing * 0.72, 0.0, -0.02))
	_rotate(&"Torso", Vector3(0.0, sin(phase) * 0.045, sin(phase * 0.5) * 0.025))


func _apply_run() -> void:
	var phase := _time * 10.5
	var swing := sin(phase) * 0.82
	_root.position.y += absf(sin(phase)) * 0.065
	_root.rotation.x += 0.09
	_rotate(&"LeftLeg", Vector3(swing, 0.0, 0.0))
	_rotate(&"RightLeg", Vector3(-swing, 0.0, 0.0))
	_rotate(&"LeftBoot", Vector3(-swing * 0.36, 0.0, 0.0))
	_rotate(&"RightBoot", Vector3(swing * 0.36, 0.0, 0.0))
	_rotate(&"LeftArm", Vector3(-swing * 0.9, 0.0, 0.08))
	_rotate(&"RightArm", Vector3(swing * 0.9, 0.0, -0.08))
	_rotate(&"Torso", Vector3(0.05, sin(phase) * 0.07, sin(phase * 0.5) * 0.04))


func _apply_talk() -> void:
	var gesture := sin(_time * 3.2)
	var other := sin(_time * 2.1 + 1.4)
	_apply_idle(0.45)
	_rotate(&"LeftArm", Vector3(-0.35 + gesture * 0.18, 0.0, -0.26))
	_rotate(&"RightArm", Vector3(-0.58 + other * 0.22, 0.0, 0.38))
	_rotate(&"LeftHand", Vector3(gesture * 0.12, gesture * 0.2, 0.0))
	_rotate(&"RightHand", Vector3(other * 0.12, other * 0.2, 0.0))
	_rotate(&"Head", Vector3(sin(_time * 2.5) * 0.035, gesture * 0.045, 0.0))


func _apply_point() -> void:
	_apply_idle(0.35)
	var emphasis := sin(_time * 3.0) * 0.08
	_rotate(&"RightArm", Vector3(-1.35 + emphasis, 0.0, 0.38))
	_rotate(&"RightHand", Vector3(0.0, -0.18, 0.0))
	_rotate(&"Head", Vector3(0.0, 0.2, 0.0))


func _apply_explain() -> void:
	_apply_idle(0.35)
	var gesture := sin(_time * 2.8)
	_rotate(&"LeftArm", Vector3(-0.7 + gesture * 0.18, 0.0, -0.42))
	_rotate(&"RightArm", Vector3(-0.82 - gesture * 0.15, 0.0, 0.46))
	_rotate(&"LeftHand", Vector3(0.0, gesture * 0.22, 0.0))
	_rotate(&"RightHand", Vector3(0.0, -gesture * 0.22, 0.0))


func _apply_work() -> void:
	var cycle := sin(_time * 5.2)
	_root.rotation.x += 0.06
	_rotate(&"LeftArm", Vector3(-0.85 + cycle * 0.32, 0.0, -0.2))
	_rotate(&"RightArm", Vector3(-0.85 - cycle * 0.32, 0.0, 0.2))
	_rotate(&"Torso", Vector3(0.08, cycle * 0.05, 0.0))


func _apply_present() -> void:
	_apply_idle(0.25)
	_rotate(&"LeftArm", Vector3(-1.08, 0.0, -0.28))
	_rotate(&"RightArm", Vector3(-1.08, 0.0, 0.28))
	_rotate(&"LeftHand", Vector3(-0.2, 0.0, 0.0))
	_rotate(&"RightHand", Vector3(-0.2, 0.0, 0.0))


func _apply_salute() -> void:
	_apply_idle(0.25)
	_rotate(&"RightArm", Vector3(-1.45, 0.0, 0.65))
	_rotate(&"RightHand", Vector3(-0.35, 0.0, 0.0))
	_rotate(&"Head", Vector3(-0.05, 0.0, 0.0))


func _apply_recall() -> void:
	_apply_idle(0.2)
	_rotate(&"RightArm", Vector3(-1.15, 0.0, 0.5))
	_rotate(&"RightHand", Vector3(-0.25, 0.25, 0.0))
	_rotate(&"Head", Vector3(-0.12, -0.15, 0.08))


func _apply_reassure(thanking: bool) -> void:
	_apply_idle(0.28)
	var bow := 0.16 if thanking else 0.04
	_root.rotation.x += bow
	_rotate(&"LeftArm", Vector3(-0.62, 0.0, -0.38))
	_rotate(&"RightArm", Vector3(-0.62, 0.0, 0.38))


func _apply_inspect() -> void:
	_apply_idle(0.2)
	_root.rotation.x += 0.12
	_rotate(&"Head", Vector3(0.18, sin(_time * 1.8) * 0.15, 0.0))
	_rotate(&"LeftArm", Vector3(-0.5, 0.0, -0.2))
	_rotate(&"RightArm", Vector3(-0.5, 0.0, 0.2))


func _apply_avoid() -> void:
	_apply_idle(0.2)
	_root.position.z += 0.08
	_root.rotation.y += 0.25
	_rotate(&"LeftArm", Vector3(-0.35, 0.0, -0.45))
	_rotate(&"RightArm", Vector3(-0.35, 0.0, 0.45))


func _apply_threaten() -> void:
	var pulse := sin(_time * 3.5) * 0.1
	_root.rotation.x += 0.08
	_rotate(&"RightArm", Vector3(-0.8 - pulse, -0.12, 0.55))
	_rotate(&"LeftArm", Vector3(-0.35, 0.0, -0.28))
	_rotate(&"Head", Vector3(0.06, 0.0, 0.0))


func _apply_attack() -> void:
	var progress := clampf(_time / 0.55, 0.0, 1.0)
	var strike := sin(progress * PI)
	_root.rotation.y -= strike * 0.28
	_rotate(&"Torso", Vector3(strike * 0.08, -strike * 0.55, -strike * 0.08))
	_rotate(&"RightArm", Vector3(-0.45 - strike * 1.55, -strike * 0.38, strike * 0.3))
	_rotate(&"RightHand", Vector3(-strike * 0.38, 0.0, 0.0))
	_rotate(&"LeftArm", Vector3(-0.2 - strike * 0.35, 0.0, -0.25))
	_rotate(&"LeftLeg", Vector3(strike * 0.18, 0.0, -strike * 0.06))
	_rotate(&"RightLeg", Vector3(-strike * 0.12, 0.0, strike * 0.06))


func _apply_guard() -> void:
	_root.rotation.x += 0.04
	_rotate(&"LeftArm", Vector3(-0.92, 0.08, -0.55))
	_rotate(&"RightArm", Vector3(-0.84, -0.08, 0.55))
	_rotate(&"Torso", Vector3(0.06, 0.0, 0.0))


func _apply_hit() -> void:
	var impact := sin(clampf(_time / 0.32, 0.0, 1.0) * PI)
	_root.position.z += impact * 0.11
	_root.rotation.x -= impact * 0.2
	_rotate(&"Torso", Vector3(-impact * 0.22, impact * 0.08, impact * 0.08))
	_rotate(&"LeftArm", Vector3(impact * 0.45, 0.0, -impact * 0.45))
	_rotate(&"RightArm", Vector3(impact * 0.45, 0.0, impact * 0.45))
	_rotate(&"Head", Vector3(-impact * 0.18, impact * 0.12, 0.0))


func _apply_downed(dead: bool) -> void:
	var settle := clampf(_time / (0.38 if dead else 0.5), 0.0, 1.0)
	_root.rotation.z -= settle * (PI * 0.5 if dead else 1.22)
	_root.position.x -= settle * 0.48
	_root.position.y -= settle * (0.5 if dead else 0.38)
	_rotate(&"LeftArm", Vector3(0.25, 0.0, -0.5 * settle))
	_rotate(&"RightArm", Vector3(-0.25, 0.0, 0.5 * settle))


func _apply_airborne() -> void:
	_rotate(&"LeftLeg", Vector3(-0.26, 0.0, -0.04))
	_rotate(&"RightLeg", Vector3(0.36, 0.0, 0.04))
	_rotate(&"LeftArm", Vector3(0.24, 0.0, -0.18))
	_rotate(&"RightArm", Vector3(0.24, 0.0, 0.18))
	_rotate(&"Torso", Vector3(-0.06 if _state == &"jump_loop" else 0.08, 0.0, 0.0))


func _rotate(part_name: StringName, radians: Vector3) -> void:
	var part := _parts.get(part_name) as Node3D
	if part == null or not is_instance_valid(part):
		return
	part.rotation += radians
