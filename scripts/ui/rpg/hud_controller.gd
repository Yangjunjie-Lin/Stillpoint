extends CanvasLayer
## RPG HUD: vitals, time, region, hotbar, interaction, quest, target, dialogue.

@onready var health_label: Label = $VBox/HealthLabel
@onready var energy_label: Label = $VBox/EnergyLabel
@onready var time_label: Label = $VBox/TimeLabel
@onready var region_label: Label = $VBox/RegionLabel
@onready var move_label: Label = $VBox/MoveLabel
@onready var interact_label: Label = $VBox/InteractLabel
@onready var quest_label: Label = $VBox/QuestLabel
@onready var hotbar_label: Label = $VBox/HotbarLabel if has_node("VBox/HotbarLabel") else null
@onready var target_label: Label = $VBox/TargetLabel if has_node("VBox/TargetLabel") else null

var _world: WorldSession


func _ready() -> void:
	_world = _find_world()
	WorldTimeService.minute_changed.connect(_on_time_changed)
	EventBus.dialogue_finished.connect(func() -> void: pass)
	_on_time_changed(WorldTimeService.day, WorldTimeService.hour, WorldTimeService.minute)


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
	if not _dialogue_open():
		interact_label.text = player.get_interaction_prompt()
	_update_hotbar(player)
	_update_quest()
	_update_target(player)


func _update_hotbar(player: PlayerController3D) -> void:
	if hotbar_label == null:
		return
	var idx := player.hotbar.selected_index + 1
	var slot_i := player.hotbar.get_inventory_slot_index()
	var name := "-"
	var qty := 0
	if player.inventory != null:
		var stack := player.inventory.get_slot(slot_i)
		if stack != null and not stack.is_empty():
			var def := ResourceRegistry.get_item(stack.item_id)
			name = def.display_name if def else String(stack.item_id)
			qty = stack.quantity
	hotbar_label.text = "Hotbar %d: %s x%d" % [idx, name, qty]


func _update_quest() -> void:
	var runtime := QuestManager.get_tracked_quest()
	if runtime == null:
		quest_label.text = "Quest: --"
		return
	if runtime.state == QuestDefinition.QuestState.COMPLETED:
		quest_label.text = "Quest: Complete"
		return
	if runtime.state != QuestDefinition.QuestState.ACTIVE:
		quest_label.text = "Quest: --"
		return
	var def := ResourceRegistry.get_quest(runtime.quest_id)
	var objective := QuestManager.get_current_objective(runtime.quest_id)
	if objective != null:
		quest_label.text = "Quest: %s" % objective.display_text
	elif def != null:
		quest_label.text = "Quest: %s" % def.display_name
	else:
		quest_label.text = "Quest: --"


func _update_target(player: PlayerController3D) -> void:
	if target_label == null:
		return
	var best: NPCController = null
	var best_dist := 4.0
	if _world == null or _world.region_service == null:
		target_label.text = ""
		return
	var region_root := _world.region_service.get_current_region_root()
	if region_root == null:
		target_label.text = ""
		return
	for node in region_root.find_children("*", "CharacterBody3D", true, false):
		if node is NPCController:
			var npc := node as NPCController
			var dist := player.global_position.distance_to(npc.global_position)
			if dist < best_dist:
				best_dist = dist
				best = npc
	if best == null:
		target_label.text = ""
		return
	var disp := RelationshipService.get_disposition(best.character_id)
	var disp_name := "Neutral"
	if disp == RelationshipComponent.Disposition.FRIENDLY:
		disp_name = "Friendly"
	elif disp == RelationshipComponent.Disposition.HOSTILE:
		disp_name = "Hostile"
	var name := best.definition.display_name if best.definition else String(best.character_id)
	var hp := best.health.current_health if best.health else 0.0
	var en := best.energy.current_energy if best.energy else 0.0
	target_label.text = "%s [%s] HP %.0f EN %.0f" % [name, disp_name, hp, en]


func _dialogue_open() -> bool:
	var panel := get_node_or_null("DialoguePanel")
	return panel != null and panel.visible


func _on_time_changed(day: int, hour: int, minute: int) -> void:
	time_label.text = "Day %d  %02d:%02d" % [day, hour, minute]


func _find_world() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return null
