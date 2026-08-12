class_name PetHurtbox3D
extends Hurtbox3D
## Combat adapter for PetController, which deliberately is not a full
## CharacterController. Hostile Hitbox3D nodes can therefore use the canonical
## receive_damage contract without giving pets player/NPC combat authority.

var _pet: PetController


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = 1 << 5
	collision_mask = 0
	_pet = get_parent() as PetController


func receive_damage(amount: float, source: Node, context: Dictionary = {}) -> float:
	if _pet == null:
		_pet = get_parent() as PetController
	return _pet.receive_damage(amount, source, context) if _pet != null else 0.0
