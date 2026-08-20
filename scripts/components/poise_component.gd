class_name PoiseComponent
extends Node
## Reusable stagger resistance model. Runtime poise is deliberately transient.

signal poise_changed(current: float, maximum: float)
signal poise_broken

@export var max_poise: float = 100.0
@export var regen_delay: float = 1.2
@export var regen_rate: float = 24.0

var current_poise: float = 100.0
var _regen_remaining: float = 0.0
var _break_emitted := false


func _ready() -> void:
	current_poise = max_poise


func _process(delta: float) -> void:
	if _regen_remaining > 0.0:
		_regen_remaining -= delta
		return
	if current_poise < max_poise:
		current_poise = minf(max_poise, current_poise + regen_rate * delta)
		if current_poise > 0.0:
			_break_emitted = false
		poise_changed.emit(current_poise, max_poise)


func apply_damage(amount: float, multiplier: float = 1.0) -> bool:
	if amount <= 0.0:
		return false
	current_poise = maxf(0.0, current_poise - amount * maxf(0.0, multiplier))
	_regen_remaining = regen_delay
	poise_changed.emit(current_poise, max_poise)
	if current_poise > 0.0 or _break_emitted:
		return false
	_break_emitted = true
	poise_broken.emit()
	return true


func reset(value: float = -1.0) -> void:
	current_poise = maxf(0.0, max_poise if value < 0.0 else minf(value, max_poise))
	_regen_remaining = regen_delay
	_break_emitted = current_poise <= 0.0
	poise_changed.emit(current_poise, max_poise)


func is_broken() -> bool:
	return current_poise <= 0.0
