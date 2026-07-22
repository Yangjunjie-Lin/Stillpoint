class_name Hitbox3D
extends Area3D

signal hit_landed(target: Node3D, damage: float)

@export var team: StringName = &"player"
@export var damage: float = 10.0
@export var attack_id: StringName = &"basic_melee"
@export var active: bool = false
@export var maximum_targets: int = 1

var source: Node = null
var _hit_targets: Dictionary = {}
var _melee_sweep: MeleeSweep3D


func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 1 << 6  # hitbox
	collision_mask = (1 << 5) | (1 << 7)  # hurtbox + physics_prop
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_melee_sweep = get_node_or_null("../MeleeSweep3D") as MeleeSweep3D
	if _melee_sweep == null:
		_melee_sweep = get_parent().get_node_or_null("MeleeSweepRoot/MeleeSweep3D") as MeleeSweep3D


func set_active(value: bool) -> void:
	active = value
	monitoring = value
	if value:
		_hit_targets.clear()
		if source is CharacterController and (source as CharacterController).combat != null:
			var atk := (source as CharacterController).combat.attack
			if atk != null:
				damage = atk.damage
				attack_id = atk.id
				maximum_targets = atk.maximum_targets
	else:
		_hit_targets.clear()


func _on_area_entered(area: Area3D) -> void:
	if not active:
		return
	if not area is Hurtbox3D:
		return
	var hurt := area as Hurtbox3D
	if hurt.team == team:
		return
	if _melee_sweep != null and not _melee_sweep.register_overlap_hurtbox(hurt):
		return
	var key := hurt.get_instance_id()
	if _hit_targets.has(key):
		return
	if _hit_targets.size() >= maximum_targets:
		return
	_hit_targets[key] = true
	var context := {
		"attack_id": String(attack_id),
		"team": String(team),
		"is_normal_attack": true,
		"from_player": team == &"player",
		"direction": -global_transform.basis.z if source is Node3D else Vector3.FORWARD,
		"blockable": true,
	}
	var dealt := hurt.receive_damage(damage, source, context)
	if dealt > 0.0:
		hit_landed.emit(hurt.get_parent(), dealt)
		if source is CharacterController:
			var combat := (source as CharacterController).combat
			if combat != null:
				combat.notify_hit_landed(hurt, dealt, context)


func _on_body_entered(body: Node3D) -> void:
	if not active:
		return
	if body.has_method("apply_attack_impulse"):
		var direction := -global_transform.basis.z
		if source is Node3D:
			direction = ((body as Node3D).global_position - (source as Node3D).global_position).normalized()
		body.call("apply_attack_impulse", direction, damage)
