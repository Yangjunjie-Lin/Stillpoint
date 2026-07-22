class_name DialogueUI
extends Control
## Choice-capable dialogue panel driven by EventBus / DialogueRunner.

signal choice_selected(index: int)

@onready var speaker_label: Label = %SpeakerLabel
@onready var body_label: Label = %BodyLabel
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var continue_hint: Label = %ContinueHint

var _choices: Array = []
var _active: bool = false


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.dialogue_line.connect(_on_line)
	EventBus.dialogue_choices.connect(_on_choices)
	EventBus.dialogue_finished.connect(_on_finished)


func _unhandled_input(event: InputEvent) -> void:
	if not _active or not visible:
		return
	for i in mini(_choices.size(), 9):
		if event is InputEventKey and event.pressed and not event.echo:
			var key_event := event as InputEventKey
			if key_event.keycode == KEY_1 + i or key_event.physical_keycode == KEY_1 + i:
				_select(i)
				get_viewport().set_input_as_handled()
				return


func _on_line(speaker: String, text: String) -> void:
	_active = true
	visible = true
	speaker_label.text = speaker
	body_label.text = text
	_clear_choices()
	continue_hint.visible = true
	continue_hint.text = "..."


func _on_choices(choices: Array) -> void:
	_active = true
	visible = true
	_choices = choices
	_clear_choices()
	continue_hint.visible = false
	for i in choices.size():
		var choice: DialogueChoice = choices[i] as DialogueChoice
		if choice == null:
			continue
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, choice.text]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var index := i
		button.pressed.connect(func() -> void: _select(index))
		choices_container.add_child(button)


func _on_finished() -> void:
	_active = false
	visible = false
	_clear_choices()
	_choices.clear()


func _select(index: int) -> void:
	choice_selected.emit(index)
	var world := get_tree().get_first_node_in_group("world_manager") as WorldManager
	if world != null:
		world.apply_dialogue_choice(index)


func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()
