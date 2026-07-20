class_name GameOverScreen
extends Control

@onready var stats_label: Label = %StatsLabel


func show_stats(stats: Dictionary) -> void:
	stats_label.text = "\n".join([
		"Final Score  %s" % str(stats.get("score", 0)),
		"Level Reached  %s" % str(stats.get("level", 1)),
		"Enemies Defeated  %s" % str(stats.get("enemies_defeated", 0)),
		"Survival Time  %ss" % str(int(stats.get("survival_seconds", 0))),
	])


func _on_menu_pressed() -> void:
	GameManager.return_to_menu()
