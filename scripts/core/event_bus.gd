extends Node
## Global cross-system events. Prefer local signals for actor-local communication.

signal enemy_defeated(enemy_id: StringName, rewards: Dictionary)
signal player_level_changed(new_level: int)
signal player_health_changed(current: float, maximum: float)
signal player_experience_changed(current: int, to_next: int, level: int)
signal player_died(stats: Dictionary)
signal score_changed(total_score: int, combat_score: int)
signal objective_completed(objective_id: StringName)
signal level_completed(level_id: StringName)
signal run_paused(is_paused: bool)
signal notice_requested(text: String)
signal player_status_changed(text: String)
