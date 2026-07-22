class_name Hitbox3D
extends Area3D

signal hit_landed(target: Node3D, damage: float)

@export var team: StringName = &"player"
@export var damage: float = 10.0
@export var attack_id: StringName = &"basic_melee"
@export var active: bool = false

var source: Node = null
var _hit_targets: Dictionary = {}


func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)


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


func _on_area_entered(area: Area3D) -> void:
	if not active:
		return
	if not area is Hurtbox3D:
		return
	var hurt := area as Hurtbox3D
	if hurt.team == team:
		return
	var key := hurt.get_instance_id()
	if _hit_targets.has(key):
		return
	_hit_targets[key] = true
	var context := {
		"attack_id": String(attack_id),
		"team": String(team),
		"is_normal_attack": true,
		"from_player": team == &"player",
		"direction": -global_transform.basis.z if source is Node3D else Vector3.FORWARD,
	}
	var dealt := hurt.receive_damage(damage, source, context)
	if dealt > 0.0:
		hit_landed.emit(hurt.get_parent(), dealt)
