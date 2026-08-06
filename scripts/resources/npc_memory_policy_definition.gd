class_name NPCMemoryPolicyDefinition
extends Resource

@export var recent_turn_limit: int = 6
@export var retrieval_limit: int = 10
@export var graph_depth: int = 2
@export var prompt_token_budget: int = 2400
@export var max_output_tokens: int = 400
@export var default_half_life_hours: float = 168.0
@export var high_salience_half_life_hours: float = 8760.0
@export var semantic_weight: float = 0.40
@export var salience_weight: float = 0.15
@export var goal_weight: float = 0.10
@export var graph_weight: float = 0.10
@export var relationship_weight: float = 0.10
@export var recency_weight: float = 0.10
@export var reinforcement_weight: float = 0.05

func to_catalog_dict() -> Dictionary:
	return {"recent_turn_limit": recent_turn_limit, "retrieval_limit": retrieval_limit,
		"graph_depth": mini(graph_depth, 2), "prompt_token_budget": prompt_token_budget,
		"max_output_tokens": max_output_tokens,
		"default_half_life_hours": default_half_life_hours,
		"high_salience_half_life_hours": high_salience_half_life_hours,
		"weights": {"semantic": semantic_weight, "salience": salience_weight,
			"goal": goal_weight, "graph": graph_weight,
			"relationship": relationship_weight, "recency": recency_weight,
			"reinforcement": reinforcement_weight}}
