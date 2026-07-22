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
	if actor is PlayerController3D:
		context.region_id = (actor as PlayerController3D).current_region_id
	for node in interactables:
		if not node is Interactable:
			continue
		var target := node as Interactable
		if not target.is_interaction_enabled():
			continue
		if not target.can_interact(actor, context):
			continue
		var dist := _distance(actor, target)
		if dist > max_distance:
			continue
		var facing_bonus := _facing_bonus(actor, target)
		var score := float(target.get_priority(actor)) - dist + facing_bonus
		if score > best_score:
			best_score = score
			best = target
	return best


static func _distance(actor: CharacterController, target: Interactable) -> float:
	if actor == null or target == null:
		return INF
	return actor.global_position.distance_to(target.global_position)


static func _facing_bonus(actor: CharacterController, target: Interactable) -> float:
	var forward := -actor.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return 0.0
	forward = forward.normalized()
	var to_target := target.global_position - actor.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.001:
		return 0.5
	return forward.dot(to_target.normalized()) * 0.5
