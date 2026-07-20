extends RefCounted


func run() -> bool:
	var mount := MountController.new()
	mount.is_mounted = true
	mount.is_mounted = false
	return not mount.is_mounted
