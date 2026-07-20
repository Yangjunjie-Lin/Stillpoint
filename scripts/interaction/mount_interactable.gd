class_name MountInteractable
extends Interactable

@export var mount_path: NodePath

var _mount: MountController


func _ready() -> void:
	if mount_path != NodePath():
		_mount = get_node_or_null(mount_path) as MountController


func can_interact(actor: CharacterController, _context: InteractionContext) -> bool:
	return actor is PlayerController3D and _mount != null


func get_interaction_text(_actor: CharacterController) -> String:
	if _mount == null:
		return "Ride"
	return "Dismount" if _mount.is_mounted else "Ride"


func interact(actor: CharacterController, _context: InteractionContext) -> void:
	if _mount == null:
		return
	var player := actor as PlayerController3D
	if _mount.is_mounted:
		_mount.dismount()
	else:
		_mount.mount(player)
