class_name PetCompanionMenu
extends Control
## Modal companion sheet for care, routine, equipment and free conversation.

@onready var name_label: Label = %PetName
@onready var identity_label: Label = %Identity
@onready var vitals_label: Label = %Vitals
@onready var temperament_label: Label = %Temperament
@onready var skills_label: RichTextLabel = %Skills
@onready var mode_button: Button = %ModeButton
@onready var lifestyle_option: OptionButton = %LifestyleOption
@onready var location_option: OptionButton = %LocationOption
@onready var proactive_check: CheckBox = %ProactiveCheck
@onready var food_list: ItemList = %FoodList
@onready var equipment_list: ItemList = %EquipmentList
@onready var collar_button: Button = %CollarButton
@onready var body_button: Button = %BodyButton
@onready var charm_button: Button = %CharmButton
@onready var dialogue_input: LineEdit = %DialogueInput
@onready var dialogue_reply: Label = %DialogueReply
@onready var status_label: Label = %Status

var _world: WorldSession
var _player: PlayerController3D
var _pet: PetController
var _tree_was_paused: bool = false
var _player_input_was_enabled: bool = true

const STAY_LOCATIONS: Array[Dictionary] = [
	{"id": "pet_rest_area", "region": "base:player_home", "label": "Home rest corner"},
	{"id": "farmyard", "region": "base:farmland", "label": "Farmyard"},
	{"id": "town_square", "region": "base:town", "label": "Town square"},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mode_button.pressed.connect(_toggle_mode)
	lifestyle_option.item_selected.connect(_choose_lifestyle)
	location_option.item_selected.connect(_choose_location)
	proactive_check.toggled.connect(_toggle_proactive)
	%FeedButton.pressed.connect(_feed_selected)
	collar_button.pressed.connect(_equip_selected.bind(&"collar"))
	body_button.pressed.connect(_equip_selected.bind(&"body"))
	charm_button.pressed.connect(_equip_selected.bind(&"charm"))
	%UnequipCollar.pressed.connect(_unequip.bind(&"collar"))
	%UnequipBody.pressed.connect(_unequip.bind(&"body"))
	%UnequipCharm.pressed.connect(_unequip.bind(&"charm"))
	%SendDialogue.pressed.connect(_send_dialogue)
	dialogue_input.text_submitted.connect(func(_text: String) -> void: _send_dialogue())
	%CloseButton.pressed.connect(close_menu)
	_apply_theme()


func _exit_tree() -> void:
	if visible and get_tree() != null:
		get_tree().paused = _tree_was_paused


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		close_menu()
		get_viewport().set_input_as_handled()


func open_menu(pet: PetController) -> void:
	_world = _find_world()
	_player = _world.player if _world != null else null
	if visible or pet == null or _player == null:
		return
	_pet = pet
	_tree_was_paused = get_tree().paused
	_player_input_was_enabled = _player.state.input_enabled
	_player.set_input_enabled(false)
	get_tree().paused = true
	visible = true
	status_label.text = ""
	dialogue_reply.text = ""
	_refresh()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _tree_was_paused
	if _player != null:
		_player.set_input_enabled(_player_input_was_enabled)
	_pet = null


func is_open() -> bool:
	return visible


func show_reply(reply: Dictionary) -> void:
	if _pet == null:
		return
	_pet.set_dialogue_motion(false)
	dialogue_reply.text = str(reply.get("reply_text", "Pip watches you quietly."))
	status_label.text = "Safe fallback used." if bool(reply.get("fallback", false)) else "Conversation complete."
	%SendDialogue.disabled = false
	dialogue_input.editable = true


func _refresh() -> void:
	if not visible or _pet == null or _pet.runtime_state == null:
		return
	var state := _pet.runtime_state
	var definition := _pet.pet_definition
	name_label.text = _pet.get_display_name()
	identity_label.text = "%s  ·  %s  ·  persistent companion" % [
		definition.species.display_name,
		definition.personality.display_name,
	]
	vitals_label.text = "Level %d  XP %d/%d\nHP %.0f/%.0f  Stamina %.0f/%.0f\nMood %.0f  Hunger %.0f  Bond %.0f" % [
		state.get_level(), state.get_experience(), state.experience_to_next_level(),
		state.get_current_health(), state.get_max_health(),
		state.get_current_stamina(), state.get_max_stamina(),
		state.get_mood(), state.get_hunger(), state.get_affection(),
	]
	var biases := definition.personality.behavior_biases()
	temperament_label.text = "Curiosity %.0f%%  Courage %.0f%%  Sociability %.0f%%\nProgram-owned behavior: %s" % [
		definition.personality.curiosity * 100.0,
		definition.personality.courage * 100.0,
		definition.personality.sociability * 100.0,
		"protective" if float(biases.get("engage_hostile", 0.0)) >= 0.5 else "cautious",
	]
	var skill_lines: Array[String] = ["[b]Life skills[/b]"]
	for skill in definition.life_skills:
		skill_lines.append("• %s  %.1f / %.0f" % [skill.display_name, state.get_skill_progress(skill.id), skill.max_proficiency])
	skill_lines.append("[b]Attack skill[/b]")
	for skill in definition.attack_skills:
		skill_lines.append("• %s  power %.0f  stamina %.0f" % [skill.display_name, skill.base_power, skill.stamina_cost])
	skills_label.text = "\n".join(skill_lines)
	mode_button.text = "Following owner" if state.is_following() else "Living independently"
	_rebuild_lifestyles()
	_rebuild_locations()
	proactive_check.set_pressed_no_signal(state.is_auto_dialogue_enabled())
	_populate_food()
	_populate_equipment()
	collar_button.text = _slot_text(&"collar")
	body_button.text = _slot_text(&"body")
	charm_button.text = _slot_text(&"charm")


func _rebuild_lifestyles() -> void:
	lifestyle_option.clear()
	for index in _pet.pet_definition.lifestyles.size():
		var lifestyle := _pet.pet_definition.lifestyles[index]
		lifestyle_option.add_item(lifestyle.display_name)
		lifestyle_option.set_item_metadata(index, String(lifestyle.id))
		if lifestyle.id == _pet.runtime_state.get_lifestyle_id():
			lifestyle_option.select(index)


func _rebuild_locations() -> void:
	location_option.clear()
	for index in STAY_LOCATIONS.size():
		var data := STAY_LOCATIONS[index]
		location_option.add_item(str(data.label))
		location_option.set_item_metadata(index, data)
		if str(data.id) == String(_pet.runtime_state.get_stay_location_id()):
			location_option.select(index)


func _populate_food() -> void:
	food_list.clear()
	for index in _player.inventory.slot_count:
		var stack := _player.inventory.get_slot(index)
		if stack == null or stack.is_empty():
			continue
		var item := ResourceRegistry.get_item(stack.item_id)
		if item == null or not item.is_pet_food():
			continue
		var row := food_list.add_item("%s ×%d  nutrition %.0f" % [item.display_name, stack.quantity, item.pet_nutrition])
		food_list.set_item_metadata(row, index)


func _populate_equipment() -> void:
	equipment_list.clear()
	for index in _player.inventory.slot_count:
		var stack := _player.inventory.get_slot(index)
		if stack == null or stack.is_empty():
			continue
		var item := ResourceRegistry.get_item(stack.item_id)
		if item == null or not item.is_pet_equipment():
			continue
		var row := equipment_list.add_item("%s  ·  %s" % [item.display_name, ", ".join(item.pet_tags)])
		equipment_list.set_item_metadata(row, index)


func _toggle_mode() -> void:
	_pet.toggle_mode()
	status_label.text = "Pip will follow you." if _pet.runtime_state.is_following() else "Pip will follow the selected routine here."
	_refresh()


func _choose_lifestyle(index: int) -> void:
	var id := StringName(str(lifestyle_option.get_item_metadata(index)))
	if _pet.runtime_state.choose_lifestyle(id):
		_pet.set_following(false)
		status_label.text = "Lifestyle changed to %s." % lifestyle_option.get_item_text(index)
	_refresh()


func _choose_location(index: int) -> void:
	var data: Variant = location_option.get_item_metadata(index)
	if data is Dictionary and _pet.runtime_state.set_stay_location(StringName(str(data.region)), StringName(str(data.id))):
		status_label.text = "Preferred stay location updated."
	_refresh()


func _toggle_proactive(enabled: bool) -> void:
	_pet.runtime_state.set_auto_dialogue_enabled(enabled)
	status_label.text = "Pip may start a conversation." if enabled else "Pip will only answer when spoken to."


func _feed_selected() -> void:
	var selected := food_list.get_selected_items()
	var ok := not selected.is_empty() and _pet.feed_from_inventory(
		_player.inventory, int(food_list.get_item_metadata(selected[0]))
	)
	status_label.text = "Pip enjoyed the food." if ok else "Select a suitable food from the backpack."
	_refresh()


func _equip_selected(slot_id: StringName) -> void:
	var selected := equipment_list.get_selected_items()
	var ok := not selected.is_empty() and _pet.equip_from_inventory(
		_player.inventory, int(equipment_list.get_item_metadata(selected[0])), slot_id
	)
	status_label.text = "Equipment fitted." if ok else "That item does not fit this slot or species."
	_refresh()


func _unequip(slot_id: StringName) -> void:
	var ok := _pet.unequip_to_inventory(slot_id, _player.inventory)
	status_label.text = "Equipment returned to backpack." if ok else "No room in the backpack or slot is empty."
	_refresh()


func _send_dialogue() -> void:
	var text := dialogue_input.text.strip_edges()
	if text.is_empty():
		status_label.text = "Enter something to say to Pip."
		return
	if _world == null or not _world.ask_pet(_pet, text):
		status_label.text = "Pet cognition is unavailable; no gameplay state changed."
		return
	dialogue_input.clear()
	dialogue_input.editable = false
	%SendDialogue.disabled = true
	status_label.text = "Pip is listening..."


func _slot_text(slot_id: StringName) -> String:
	var equipped := _pet.runtime_state.get_equipped_item(slot_id)
	var definition := ResourceRegistry.get_item(equipped) if equipped != &"" else null
	return "%s: %s" % [String(slot_id).capitalize(), definition.display_name if definition != null else "Empty"]


func _find_world() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return get_tree().get_first_node_in_group("world_manager") as WorldSession


func _apply_theme() -> void:
	var panel := get_node_or_null("Center/Panel") as PanelContainer
	if panel != null:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("101d22")
		style.border_color = Color("5b8a72")
		style.set_border_width_all(2)
		style.set_corner_radius_all(11)
		style.shadow_color = Color(0, 0, 0, 0.72)
		style.shadow_size = 18
		panel.add_theme_stylebox_override("panel", style)
