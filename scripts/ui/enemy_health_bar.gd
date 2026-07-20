class_name EnemyHealthBar
extends Control

@onready var fill: ColorRect = $Fill


func set_ratio(ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	if fill != null:
		fill.scale.x = maxf(0.001, clamped)
		if clamped > 0.5:
			fill.color = Color(0.25, 0.91, 0.42)
		elif clamped > 0.25:
			fill.color = Color(1.0, 0.82, 0.4)
		else:
			fill.color = Color(1.0, 0.3, 0.35)
