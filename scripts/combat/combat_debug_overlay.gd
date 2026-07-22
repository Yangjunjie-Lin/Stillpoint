class_name CombatDebugOverlay
extends CanvasLayer

@export var enabled_by_default: bool = false

var _player: PlayerController3D
var _label: Label


func _ready() -> void:
	visible = enabled_by_default
	_label = Label.new()
	_label.position = Vector2(12, 520)
	_label.add_theme_font_size_override("font_size", 12)
	add_child(_label)
	set_process(enabled_by_default)


func bind_player(player_node: PlayerController3D) -> void:
	_player = player_node


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_diagnostics"):
		visible = not visible
		set_process(visible)


func _process(_delta: float) -> void:
	if _player == null:
		_label.text = "Combat Debug (F11)"
		return
	var combat := _player.combat
	var anim := _player.get_node_or_null("CombatAnimationController") as CombatAnimationController
	var kb := _player.get_node_or_null("KnockbackComponent") as KnockbackComponent
	_label.text = """Combat Debug (F11)
Backend: %s | TPS: %d | Interp: %s
State: %s | Anim Attack: %s
Hitbox: %s | Combo Win: %s
KB: %s
""" % [
		PhysicsSettingsService.get_physics_backend(),
		PhysicsSettingsService.get_physics_ticks_per_second(),
		str(PhysicsSettingsService.is_physics_interpolation_enabled()),
		CombatComponent.CombatState.keys()[combat.combat_state] if combat else "?",
		str(combat.hitbox_active if combat else false),
		str(combat.combo_window_open if combat else false),
		str(kb.external_velocity if kb else Vector3.ZERO),
	]
