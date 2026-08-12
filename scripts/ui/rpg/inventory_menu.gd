class_name InventoryMenu
extends Control
## Stardew-inspired backpack/equipment modal backed by authoritative components.

@onready var backpack_grid: GridContainer = %BackpackGrid
@onready var equipment_grid: VBoxContainer = %EquipmentGrid
@onready var proficiency_label: Label = %ProficiencyLabel
@onready var item_name_label: Label = %ItemName
@onready var item_type_label: Label = %ItemType
@onready var description_label: Label = %Description
@onready var bonuses_label: Label = %Bonuses
@onready var status_label: Label = %Status
@onready var action_button: Button = %ActionButton

var _world: WorldSession
var _player: PlayerController3D
var _inventory: InventoryComponent
var _equipment: EquipmentComponent
var _inventory_buttons: Array[InventorySlotButton] = []
var _equipment_buttons: Dictionary = {}
var _selected_kind: StringName = &""
var _selected_inventory_index: int = -1
var _selected_equipment_slot: int = ItemDefinition.EquipSlot.NONE
var _tree_was_paused: bool = false
var _player_input_was_enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_theme()
	_build_backpack_slots(24)
	_build_equipment_slots()
	call_deferred("_bind_world")


func _exit_tree() -> void:
	if visible and get_tree() != null:
		get_tree().paused = _tree_was_paused


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"open_menu") or event.is_action_pressed(&"pause"):
		close_menu()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible:
		return
	if event.is_action_pressed(&"open_menu"):
		if _can_open():
			open_menu()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	if visible or not _can_open():
		return
	if _player == null:
		_bind_world()
	if _player == null:
		return
	_tree_was_paused = get_tree().paused
	_player_input_was_enabled = _player.state.input_enabled
	_player.set_input_enabled(false)
	get_tree().paused = true
	visible = true
	status_label.text = ""
	_refresh()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _tree_was_paused
	if _player != null:
		_player.set_input_enabled(_player_input_was_enabled)


func is_open() -> bool:
	return visible


func _bind_world() -> void:
	_world = _find_world()
	if _world == null or _world.player == null:
		if is_inside_tree():
			call_deferred("_bind_world")
		return
	_player = _world.player
	_inventory = _player.inventory
	_equipment = _player.get_node_or_null("EquipmentComponent") as EquipmentComponent
	if _inventory != null and not _inventory.inventory_changed.is_connected(_refresh):
		_inventory.inventory_changed.connect(_refresh)
	if _equipment != null and not _equipment.equipment_changed.is_connected(_on_equipment_changed):
		_equipment.equipment_changed.connect(_on_equipment_changed)
	_refresh()


func _build_backpack_slots(count: int) -> void:
	for child in backpack_grid.get_children():
		child.queue_free()
	_inventory_buttons.clear()
	for index in count:
		var button := InventorySlotButton.new()
		button.custom_minimum_size = Vector2(78.0, 82.0)
		button.focus_mode = Control.FOCUS_NONE
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 36)
		button.configure(self, &"inventory", index)
		button.pressed.connect(_select_inventory_slot.bind(index))
		button.gui_input.connect(_on_inventory_slot_gui_input.bind(index))
		backpack_grid.add_child(button)
		_inventory_buttons.append(button)


func _build_equipment_slots() -> void:
	for child in equipment_grid.get_children():
		child.queue_free()
	_equipment_buttons.clear()
	for slot in EquipmentComponent.EQUIP_SLOTS:
		var button := InventorySlotButton.new()
		button.custom_minimum_size = Vector2(270.0, 70.0)
		button.focus_mode = Control.FOCUS_NONE
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", 38)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.configure(self, &"equipment", -1, StringName(str(slot)))
		button.set_meta("equipment_slot", slot)
		button.pressed.connect(_select_equipment_slot.bind(slot))
		button.gui_input.connect(_on_equipment_slot_gui_input.bind(slot))
		equipment_grid.add_child(button)
		_equipment_buttons[slot] = button


func _refresh() -> void:
	if _inventory == null:
		return
	for index in _inventory_buttons.size():
		var button := _inventory_buttons[index]
		var stack := _inventory.get_slot(index)
		var selected := _selected_kind == &"inventory" and _selected_inventory_index == index
		_apply_slot_style(button, selected, index < HotbarController.SLOT_COUNT)
		button.icon = null
		if stack == null or stack.is_empty():
			button.set_compact_visual(_slot_heading(index), null, 0, "—")
			button.tooltip_text = "Slot %d · Empty" % (index + 1)
			continue
		var definition := ResourceRegistry.get_item(stack.item_id)
		var display_name := definition.display_name if definition != null else String(stack.item_id)
		button.set_compact_visual(
			_slot_heading(index),
			definition.icon if definition != null else null,
			stack.quantity,
			_short_name(display_name),
		)
		button.tooltip_text = _item_tooltip(definition, display_name, stack.quantity)

	if _equipment != null:
		for slot in EquipmentComponent.EQUIP_SLOTS:
			_refresh_equipment_slot(slot)
	_refresh_proficiencies()
	_refresh_details()


func _refresh_proficiencies() -> void:
	if proficiency_label == null or _player == null or _player.skills == null:
		return
	var lines: Array[String] = []
	var previous_category := ""
	for skill_state in _player.skills.get_all_skill_states():
		var category := str(skill_state.get("category", "utility")).to_upper()
		if category != previous_category:
			if not lines.is_empty():
				lines.append("")
			lines.append(category)
			previous_category = category
		lines.append("%s  %.1f/%.0f  L%d  %s  today %.1f/%.1f" % [
			str(skill_state.get("display_name", skill_state.get("skill_id", "Skill"))),
			float(skill_state.get("points", 0.0)),
			float(skill_state.get("max_proficiency", 100.0)),
			int(skill_state.get("level", 0)),
			str(skill_state.get("mastery", "untrained")).replace("_", " "),
			float(skill_state.get("gained_today", 0.0)),
			float(skill_state.get("daily_cap", 0.0)),
		])
	lines.append("")
	lines.append("Repeated place/tool practice loses efficiency and capacity; sustained overload can reduce proficiency. Rest or vary training to recover.")
	proficiency_label.text = "\n".join(lines)


func _refresh_equipment_slot(slot: int) -> void:
	var button := _equipment_buttons.get(slot) as InventorySlotButton
	if button == null:
		return
	var item_id := _equipment.get_equipped_item(slot)
	var selected := _selected_kind == &"equipment" and _selected_equipment_slot == slot
	_apply_slot_style(button, selected, false)
	button.icon = null
	if item_id == &"":
		button.set_equipment_visual(_equipment_slot_name(slot), "Empty", null)
		button.tooltip_text = "%s slot · Empty" % _equipment_slot_name(slot)
		return
	var definition := ResourceRegistry.get_item(item_id)
	var display_name := definition.display_name if definition != null else String(item_id)
	button.set_equipment_visual(
		_equipment_slot_name(slot),
		display_name,
		definition.icon if definition != null else null,
	)
	button.tooltip_text = _item_tooltip(definition, display_name, 1)


func _select_inventory_slot(index: int) -> void:
	_selected_kind = &"inventory"
	_selected_inventory_index = index
	_selected_equipment_slot = ItemDefinition.EquipSlot.NONE
	status_label.text = ""
	_refresh()


func _select_equipment_slot(slot: int) -> void:
	_selected_kind = &"equipment"
	_selected_equipment_slot = slot
	_selected_inventory_index = -1
	status_label.text = ""
	_refresh()


func _on_inventory_slot_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_RIGHT or (
		mouse.button_index == MOUSE_BUTTON_LEFT and mouse.double_click
	):
		_select_inventory_slot(index)
		_perform_selected_action()
		accept_event()


func _on_equipment_slot_gui_input(event: InputEvent, slot: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and (
		mouse.button_index == MOUSE_BUTTON_RIGHT
		or (mouse.button_index == MOUSE_BUTTON_LEFT and mouse.double_click)
	):
		_select_equipment_slot(slot)
		_perform_selected_action()
		accept_event()


func _on_action_pressed() -> void:
	_perform_selected_action()


func _perform_selected_action() -> void:
	if _inventory == null:
		return
	var succeeded := false
	if _selected_kind == &"equipment" and _equipment != null:
		succeeded = _equipment.unequip_to_inventory(_selected_equipment_slot, _inventory)
		status_label.text = "Unequipped." if succeeded else "Backpack is full."
	elif _selected_kind == &"inventory":
		var stack := _inventory.get_slot(_selected_inventory_index)
		if stack == null or stack.is_empty():
			status_label.text = "That slot is empty."
			_refresh()
			return
		var definition := ResourceRegistry.get_item(stack.item_id)
		if definition != null and definition.equip_slot != ItemDefinition.EquipSlot.NONE:
			succeeded = _equipment != null and _equipment.equip_from_inventory(
				_inventory, _selected_inventory_index, int(definition.equip_slot)
			)
			status_label.text = "Equipped %s." % definition.display_name if succeeded \
				else "That item cannot be equipped here."
		elif _player != null and _player.has_method("use_inventory_slot"):
			succeeded = bool(_player.call("use_inventory_slot", _selected_inventory_index))
			status_label.text = "Used %s." % (definition.display_name if definition else "item") \
				if succeeded else "That item cannot be used right now."
		else:
			status_label.text = "This item has no direct use."
	_refresh()


func get_slot_drag_data(button: InventorySlotButton) -> Dictionary:
	if _inventory == null:
		return {}
	if button.slot_kind == &"inventory":
		var stack := _inventory.get_slot(button.slot_index)
		if stack == null or stack.is_empty():
			return {}
		return {"source_kind": "inventory", "inventory_index": button.slot_index}
	if button.slot_kind == &"equipment" and _equipment != null:
		var equipment_slot := int(button.get_meta("equipment_slot", ItemDefinition.EquipSlot.NONE))
		if _equipment.get_equipped_item(equipment_slot) == &"":
			return {}
		return {"source_kind": "equipment", "equipment_slot": equipment_slot}
	return {}


func can_drop_slot_data(button: InventorySlotButton, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or _inventory == null:
		return false
	var source: Dictionary = data
	var source_kind := StringName(str(source.get("source_kind", "")))
	if button.slot_kind == &"inventory":
		return source_kind in [&"inventory", &"equipment"]
	if button.slot_kind != &"equipment" or source_kind != &"inventory" or _equipment == null:
		return false
	var source_index := int(source.get("inventory_index", -1))
	var stack := _inventory.get_slot(source_index)
	var target_slot := int(button.get_meta("equipment_slot", ItemDefinition.EquipSlot.NONE))
	return stack != null and not stack.is_empty() \
		and _equipment.is_slot_compatible(stack.item_id, target_slot)


func drop_slot_data(button: InventorySlotButton, data: Variant) -> void:
	if not can_drop_slot_data(button, data):
		return
	var source: Dictionary = data
	var source_kind := StringName(str(source.get("source_kind", "")))
	var succeeded := false
	if button.slot_kind == &"inventory" and source_kind == &"inventory":
		succeeded = _inventory.merge_or_swap(
			int(source.get("inventory_index", -1)), button.slot_index
		)
	elif button.slot_kind == &"equipment" and source_kind == &"inventory":
		var target_slot := int(button.get_meta("equipment_slot", ItemDefinition.EquipSlot.NONE))
		succeeded = _equipment.equip_from_inventory(
			_inventory, int(source.get("inventory_index", -1)), target_slot
		)
	elif button.slot_kind == &"inventory" and source_kind == &"equipment":
		var source_slot := int(source.get("equipment_slot", ItemDefinition.EquipSlot.NONE))
		if _equipment.has_method("unequip_to_inventory_slot"):
			succeeded = bool(_equipment.call(
				"unequip_to_inventory_slot", source_slot, _inventory, button.slot_index
			))
		else:
			succeeded = _equipment.unequip_to_inventory(source_slot, _inventory)
	status_label.text = "Moved item." if succeeded else "Cannot move that item."
	_refresh()


func _refresh_details() -> void:
	var definition: ItemDefinition = null
	var quantity := 0
	if _selected_kind == &"inventory" and _inventory != null:
		var stack := _inventory.get_slot(_selected_inventory_index)
		if stack != null and not stack.is_empty():
			definition = ResourceRegistry.get_item(stack.item_id)
			quantity = stack.quantity
	elif _selected_kind == &"equipment" and _equipment != null:
		definition = _equipment.get_equipped_definition(_selected_equipment_slot)
		quantity = 1 if definition != null else 0
	if definition == null:
		item_name_label.text = "Select an item"
		item_type_label.text = ""
		description_label.text = "Choose a backpack or equipment slot to inspect it."
		bonuses_label.text = ""
		action_button.disabled = true
		action_button.text = "Use / Equip"
		return
	item_name_label.text = "%s%s" % [definition.display_name, " ×%d" % quantity if quantity > 1 else ""]
	item_type_label.text = _item_type_name(int(definition.item_type))
	description_label.text = definition.description
	bonuses_label.text = _definition_bonuses(definition)
	action_button.disabled = false
	if _selected_kind == &"equipment":
		action_button.text = "Unequip"
	elif definition.equip_slot != ItemDefinition.EquipSlot.NONE:
		action_button.text = "Equip"
	elif definition.use_kind != ItemDefinition.UseKind.NONE:
		action_button.text = "Use"
	else:
		action_button.text = "No direct use"
		action_button.disabled = true


func _on_equipment_changed() -> void:
	_refresh()


func _can_open() -> bool:
	if _dialogue_panel_visible() or _pause_panel_visible():
		return false
	return not get_tree().paused


func _dialogue_panel_visible() -> bool:
	if _world == null:
		_world = _find_world()
	var panel := _world.get_node_or_null("WorldUI/DialoguePanel") as Control if _world else null
	return panel != null and panel.visible


func _pause_panel_visible() -> bool:
	if _world == null:
		_world = _find_world()
	var panel := _world.get_node_or_null("WorldUI/PausePanel") as Control if _world else null
	return panel != null and panel.visible


func _apply_theme() -> void:
	var panel := get_node_or_null("Center/Panel") as PanelContainer
	if panel != null:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("ead09b")
		style.border_color = Color("6e4822")
		style.set_border_width_all(5)
		style.set_corner_radius_all(14)
		style.shadow_color = Color(0.08, 0.045, 0.02, 0.55)
		style.shadow_size = 14
		panel.add_theme_stylebox_override("panel", style)
	var details := get_node_or_null("Center/Panel/Margin/VBox/Body/Side/Details") as PanelContainer
	if details != null:
		var detail_style := StyleBoxFlat.new()
		detail_style.bg_color = Color("f4e5bd")
		detail_style.border_color = Color("a6793e")
		detail_style.set_border_width_all(2)
		detail_style.set_corner_radius_all(8)
		details.add_theme_stylebox_override("panel", detail_style)


func _apply_slot_style(button: Button, selected: bool, hotbar_slot: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("f3dfa9") if selected else Color("d9b978")
	normal.border_color = Color("fff1b9") if selected else (
		Color("9c6b2f") if hotbar_slot else Color("795127")
	)
	normal.set_border_width_all(4 if selected else 2)
	normal.set_corner_radius_all(7)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("faebc3")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color("362310"))
	button.add_theme_color_override("font_hover_color", Color("362310"))
	button.add_theme_font_size_override("font_size", 12)


func _slot_heading(index: int) -> String:
	if index < HotbarController.SLOT_COUNT:
		return "HOTBAR %d" % (index + 1)
	return "SLOT %02d" % (index + 1)


func _equipment_slot_name(slot: int) -> String:
	match slot:
		ItemDefinition.EquipSlot.WEAPON:
			return "WEAPON"
		ItemDefinition.EquipSlot.ARMOR:
			return "ARMOR"
		ItemDefinition.EquipSlot.CHARM:
			return "CHARM"
	return "EQUIPMENT"


func _item_type_name(item_type: int) -> String:
	var keys := ItemDefinition.ItemType.keys()
	if item_type < 0 or item_type >= keys.size():
		return "MISC"
	return str(keys[item_type]).replace("_", " ")


func _definition_bonuses(definition: ItemDefinition) -> String:
	var parts: Array[String] = []
	if definition.health_restore > 0.0:
		parts.append("Restores %.0f health" % definition.health_restore)
	if definition.energy_restore > 0.0:
		parts.append("Restores %.0f energy" % definition.energy_restore)
	if definition.use_kind == ItemDefinition.UseKind.TOOL_ACTION:
		parts.append("Tool action: swing")
	if definition.attack_bonus > 0.0:
		parts.append("+%.0f attack" % definition.attack_bonus)
	if definition.defense_bonus > 0.0:
		parts.append("+%.0f defense" % definition.defense_bonus)
	if definition.energy_regen_bonus > 0.0:
		parts.append("+%.1f energy regeneration" % definition.energy_regen_bonus)
	if definition.is_skill_book():
		var skill := ResourceRegistry.get_skill(definition.teaches_skill_id)
		parts.append("Study: +%.1f %s proficiency" % [
			definition.proficiency_points,
			skill.display_name if skill != null else String(definition.teaches_skill_id),
		])
	return "\n".join(parts)


func _item_tooltip(definition: ItemDefinition, fallback_name: String, quantity: int) -> String:
	if definition == null:
		return "%s ×%d" % [fallback_name, quantity]
	var detail := definition.description.strip_edges()
	return "%s ×%d%s" % [
		definition.display_name,
		quantity,
		"\n%s" % detail if not detail.is_empty() else "",
	]


func _short_name(value: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned.length() <= 10:
		return cleaned
	return "%s…" % cleaned.left(9)


func _find_world() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return null
