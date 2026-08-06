class_name InteractionIndex
extends Node
## Spatial index of interactables in the active region.

var _interactables: Array[Interactable] = []
var _current_region_id: StringName = &""


func register(interactable: Interactable) -> void:
	if interactable != null and not _interactables.has(interactable):
		_interactables.append(interactable)


func unregister(interactable: Interactable) -> void:
	_interactables.erase(interactable)


func clear() -> void:
	_interactables.clear()


func set_current_region(region_id: StringName) -> void:
	_current_region_id = RegionIdUtil.normalize(region_id)


func query_nearby(player: PlayerController3D, max_distance: float = 3.0) -> Array:
	var result: Array = []
	if player == null:
		return result
	for item in _interactables:
		if item == null or not item.is_interaction_enabled():
			continue
		if _current_region_id != &"" and RegionIdUtil.normalize(item.region_id) != _current_region_id:
			continue
		var dist := player.global_position.distance_to(item.global_position)
		if dist <= max_distance:
			result.append(item)
	result.sort_custom(func(a: Interactable, b: Interactable) -> bool:
		return a.get_priority(player) > b.get_priority(player)
	)
	return result


func get_registered_count() -> int:
	return _interactables.size()
