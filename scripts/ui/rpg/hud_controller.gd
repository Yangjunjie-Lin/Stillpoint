extends CanvasLayer
## RPG HUD: health, energy, time, region, interaction prompt.

@onready var health_label: Label = $VBox/HealthLabel
@onready var energy_label: Label = $VBox/EnergyLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var region_label: Label = $VBox/RegionLabel
@onready var move_label: Label = $VBox/MoveLabel
@onready var interact_label: Label = $VBox/InteractLabel
@onready var quest_label: Label = $VBox/QuestLabel

var _world: WorldManager


func _ready() -> void:
	_world = _find_world()
	WorldTimeService.minute_changed.connect(_on_time_changed)
	EventBus.dialogue_line.connect(_on_dialogue_line)
	EventBus.dialogue_finished.connect(func() -> void: interact_label.text = "")


func _process(_delta: float) -> void:
	if _world == null or _world.player == null:
		return
	var player := _world.player
	if player.health != null:
		health_label.text = "HP: %.0f / %.0f" % [player.health.current_health, player.health.max_health]
	if player.energy != null:
		energy_label.text = "EN: %.0f / %.0f" % [player.energy.current_energy, player.energy.max_energy]
	region_label.text = "Region: %s" % String(_world.current_region_id)
	move_label.text = "Run" if player.state.is_running else "Walk"
	interact_label.text = player.get_interaction_prompt()
	var runtime := QuestManager.get_runtime(&"demo_errand")
	if runtime != null and runtime.state == QuestDefinition.QuestState.ACTIVE:
		quest_label.text = "Quest: Mira's Errand"
	else:
		quest_label.text = "Quest: --"


func _on_time_changed(day: int, hour: int, minute: int) -> void:
	time_label.text = "Day %d  %02d:%02d" % [day, hour, minute]


func _on_dialogue_line(speaker: String, text: String) -> void:
	interact_label.text = "%s: %s" % [speaker, text]


func _find_world() -> WorldManager:
	var node := get_parent()
	if node is WorldManager:
		return node as WorldManager
	return null
