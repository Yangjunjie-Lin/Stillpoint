class_name GameplayHUD
extends Control

@onready var score_label: Label = %ScoreLabel
@onready var hp_label: Label = %HPLabel
@onready var hp_fill: ColorRect = %HPFill
@onready var exp_label: Label = %EXPLabel
@onready var exp_fill: ColorRect = %EXPFill
@onready var notice_label: Label = %NoticeLabel
@onready var effects_label: Label = %EffectsLabel

var _notice_until: float = -1.0


func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health)
	EventBus.player_experience_changed.connect(_on_exp)
	EventBus.score_changed.connect(_on_score)
	EventBus.notice_requested.connect(_on_notice)
	notice_label.text = ""


func _process(_delta: float) -> void:
	if _notice_until > 0.0 and Time.get_ticks_msec() / 1000.0 > _notice_until:
		notice_label.text = ""
		_notice_until = -1.0


func _on_health(current: float, maximum: float) -> void:
	hp_label.text = "HP %d / %d" % [int(current), int(maximum)]
	var ratio := CombatMath.health_ratio(current, maximum)
	hp_fill.scale.x = maxf(0.001, ratio)
	hp_fill.color = Color(1.0, 0.3, 0.35) if ratio <= 0.25 else Color(0.25, 0.91, 0.42)
	hp_label.modulate = Color(1, 0.55, 0.55) if ratio <= 0.25 else Color.WHITE


func _on_exp(current: int, to_next: int, level: int) -> void:
	exp_label.text = "LV. %d   EXP %d / %d" % [level, current, to_next]
	exp_fill.scale.x = maxf(0.001, CombatMath.experience_ratio(current, to_next))


func _on_score(total_score: int, _combat_score: int) -> void:
	score_label.text = "Score  %s" % _format_int(total_score)


func _on_notice(text: String) -> void:
	notice_label.text = text
	_notice_until = Time.get_ticks_msec() / 1000.0 + 2.0


func _format_int(value: int) -> String:
	var s := str(value)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return out
