class_name InteractionResolver
extends RefCounted
## Selects the best interactable near an actor.


static func find_best(
	actor: CharacterController,
	interactables: Array,
	max_distance: float = 3.0,
) -> Interactable:
	var best: Interactable = null
	var best_score := -INF
	var context := InteractionContext.new(actor)
	for node in interactables:
		if not node is Interactable:
			continue
		var target := node as Interactable
		if not target.can_interact(actor, context):
			continue
		var dist := _distance(actor, target)
		if dist > max_distance:
			continue
		var score := float(target.get_priority(actor)) - dist
		if score > best_score:
			best_score = score
			best = target
	return best


static func _distance(actor: CharacterController, target: Interactable) -> float:
	if actor == null or target == null:
		return INF
	var node3d := target.get_parent() as Node3D
	if node3d == null:
		node3d = target as Node3D
	if node3d == null:
		return INF
	return actor.global_position.distance_to(node3d.global_position)
