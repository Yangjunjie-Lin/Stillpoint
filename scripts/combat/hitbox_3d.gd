class_name Hitbox3D
extends Area3D

signal hit_landed(target: Node3D, damage: float)

@export var team: StringName = &"player"
@export var damage: float = 10.0
@export var active: bool = false

var source: Node = null


func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func set_active(value: bool) -> void:
	active = value
	monitoring = value


func _on_area_entered(area: Area3D) -> void:
	if not active:
		return
	if area is Hurtbox3D:
		var hurt := area as Hurtbox3D
		if hurt.team == team:
			return
		var dealt := hurt.receive_damage(damage, source)
		if dealt > 0.0:
			hit_landed.emit(hurt.get_parent(), dealt)


func _on_body_entered(_body: Node3D) -> void:
	pass
