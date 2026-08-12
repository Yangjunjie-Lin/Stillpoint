class_name InventoryMenu
extends Control
## Categorized RPG data ledger backed by authoritative runtime components.

@onready var backpack_grid: GridContainer = %BackpackGrid
@onready var equipment_grid: GridContainer = %EquipmentGrid
@onready var equipment_intro: Label = %EquipmentIntro
@onready var profession_equipment_button: Button = %ProfessionEquipmentButton
@onready var decorative_equipment_button: Button = %DecorativeEquipmentButton
@onready var toggle_presentation_button: Button = %TogglePresentationButton
@onready var proficiency_label: RichTextLabel = %ProficiencyLabel
@onready var character_label: RichTextLabel = %CharacterLabel
@onready var equipment_summary: Label = %EquipmentSummary
@onready var page_stack: TabContainer = %PageStack
@onready var page_title: Label = %PageTitle
@onready var page_subtitle: Label = %PageSubtitle
@onready var page_counter: Label = %PageCounter
@onready var capacity_label: Label = %CapacityLabel
@onready var category_hint: Label = %CategoryHint
@onready var backpack_tab: Button = %BackpackTab
@onready var equipment_tab: Button = %EquipmentTab
@onready var skills_tab: Button = %SkillsTab
@onready var character_tab: Button = %CharacterTab
@onready var skill_loadout_row: HBoxContainer = %SkillLoadoutRow
@onready var skill_context_label: Label = %SkillContextLabel
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
var _skill_selectors: Array[OptionButton] = []
var _selected_kind: StringName = &""
var _selected_inventory_index: int = -1
var _selected_equipment_slot: int = ItemDefinition.EquipSlot.NONE
var _tree_was_paused: bool = false
var _player_input_was_enabled: bool = true
var _active_page: int = 0
var _equipment_category: StringName = EquipmentComponent.PRESENTATION_PROFESSION

const PAGE_DATA := [
	{"title": "Backpack", "subtitle": "Carry, arrange and use field supplies",
		"hint": "Backpack: arrange supplies and inspect item details"},
	{"title": "Equipment", "subtitle": "Review the active combat and travel loadout",
		"hint": "Equipment: drag compatible items into a slot or inspect equipped gear"},
	{"title": "Skill Proficiency", "subtitle": "Compare disciplines, daily progress and fatigue",
		"hint": "Skills: practice variety preserves learning efficiency and daily capacity"},
	{"title": "Character", "subtitle": "Identity, affiliation, progression and core capabilities",
		"hint": "Character: a concise overview of the current adventurer"},
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_theme()
	backpack_tab.pressed.connect(_select_page.bind(0))
	equipment_tab.pressed.connect(_select_page.bind(1))
	skills_tab.pressed.connect(_select_page.bind(2))
	character_tab.pressed.connect(_select_page.bind(3))
	profession_equipment_button.pressed.connect(
		_select_equipment_category.bind(EquipmentComponent.PRESENTATION_PROFESSION)
	)
	decorative_equipment_button.pressed.connect(
		_select_equipment_category.bind(EquipmentComponent.PRESENTATION_DECORATIVE)
	)
	toggle_presentation_button.pressed.connect(_toggle_equipment_presentation)
	_build_backpack_slots(24)
	_build_equipment_slots()
	_build_skill_loadout_controls()
	_select_page(0)
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
	_select_page(_active_page)
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
	if _equipment != null and not _equipment.presentation_mode_changed.is_connected(_on_presentation_mode_changed):
		_equipment.presentation_mode_changed.connect(_on_presentation_mode_changed)
	_refresh()


func _build_backpack_slots(count: int) -> void:
	for child in backpack_grid.get_children():
		child.queue_free()
	_inventory_buttons.clear()
	for index in count:
		var button := InventorySlotButton.new()
		button.custom_minimum_size = Vector2(73.0, 78.0)
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
		button.custom_minimum_size = Vector2(346.0, 48.0)
		button.focus_mode = Control.FOCUS_NONE
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("icon_max_width", 30)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.configure(self, &"equipment", -1, StringName(str(slot)))
		button.set_meta("equipment_slot", slot)
		button.pressed.connect(_select_equipment_slot.bind(slot))
		button.gui_input.connect(_on_equipment_slot_gui_input.bind(slot))
		equipment_grid.add_child(button)
		_equipment_buttons[slot] = button
	_refresh_equipment_category()


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
	_refresh_skill_loadout()
	_refresh_character_overview()
	_refresh_equipment_summary()
	_refresh_equipment_category()
	_refresh_capacity()
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
			lines.append("[color=#58c8b6][font_size=15]%s[/font_size][/color]" % category)
			previous_category = category
		var points := float(skill_state.get("points", 0.0))
		var maximum := float(skill_state.get("max_proficiency", 100.0))
		var filled := clampi(roundi(points / maxf(1.0, maximum) * 12.0), 0, 12)
		var meter := "■".repeat(filled) + "·".repeat(12 - filled)
		lines.append("[color=#e3d19f]%s[/color]  [color=#5cc7b5]%s[/color]  %.1f/%.0f   L%d  %s   [color=#81999a]today %.1f/%.1f[/color]" % [
			str(skill_state.get("display_name", skill_state.get("skill_id", "Skill"))),
			meter,
			points,
			maximum,
			int(skill_state.get("level", 0)),
			str(skill_state.get("mastery", "untrained")).replace("_", " "),
			float(skill_state.get("gained_today", 0.0)),
			float(skill_state.get("daily_cap", 0.0)),
		])
	lines.append("")
	lines.append("[color=#809697]Training note: repeated use of one place or tool reduces efficiency and capacity. Rest or vary practice to recover.[/color]")
	proficiency_label.text = "\n".join(lines)


func _build_skill_loadout_controls() -> void:
	for child in skill_loadout_row.get_children():
		child.queue_free()
	_skill_selectors.clear()
	for slot_index in SkillLoadoutComponent.ACTIVE_SLOT_COUNT:
		var stack := VBoxContainer.new()
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key_label := Label.new()
		key_label.text = "SLOT %d  [%s]" % [
			slot_index + 1,
			InputBindingService.get_display_text(StringName("skill_slot_%d" % (slot_index + 1))),
		]
		key_label.add_theme_color_override("font_color", Color("76caba"))
		key_label.add_theme_font_size_override("font_size", 11)
		var selector := OptionButton.new()
		selector.custom_minimum_size = Vector2(160.0, 36.0)
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.item_selected.connect(_on_skill_selector_changed.bind(slot_index))
		stack.add_child(key_label)
		stack.add_child(selector)
		skill_loadout_row.add_child(stack)
		_skill_selectors.append(selector)


func _refresh_skill_loadout() -> void:
	if _player == null or _player.skill_loadout == null:
		return
	var available := _player.skill_loadout.get_available_active_skills()
	for slot_index in _skill_selectors.size():
		var selector := _skill_selectors[slot_index]
		var selected_skill_id := _player.skill_loadout.get_slot_skill_id(slot_index)
		selector.clear()
		selector.add_item("Empty")
		selector.set_item_metadata(0, "")
		var selected_index := 0
		for definition in available:
			selector.add_item(definition.display_name)
			var item_index := selector.item_count - 1
			selector.set_item_metadata(item_index, String(definition.id))
			if definition.id == selected_skill_id:
				selected_index = item_index
		selector.select(selected_index)
		var state_ := _player.skill_loadout.get_slot_state(slot_index, _player)
		selector.tooltip_text = str(state_.get("reason", ""))
	var main_hand := _player.get_main_hand_item_definition()
	var off_hand := _player.get_off_hand_item_definition()
	var passives := _player.skill_loadout.get_active_passives(
		_player, _player.current_region_id
	)
	var passive_names: Array[String] = []
	for passive in passives:
		passive_names.append(passive.display_name)
	skill_context_label.text = "Main hand: %s   ·   Off hand (1–9): %s   ·   Scene passives: %s" % [
		main_hand.display_name if main_hand != null else "Empty",
		off_hand.display_name if off_hand != null else "Empty",
		", ".join(passive_names) if not passive_names.is_empty() else "None",
	]


func _on_skill_selector_changed(item_index: int, slot_index: int) -> void:
	if _player == null or _player.skill_loadout == null:
		return
	var selector := _skill_selectors[slot_index]
	var skill_id := StringName(str(selector.get_item_metadata(item_index)))
	if not _player.skill_loadout.configure_slot(slot_index, skill_id):
		status_label.text = "Active loadout rejected: duplicate skill or offensive limit exceeded."
	else:
		status_label.text = "Skill slot %d configured." % (slot_index + 1)
	_refresh_skill_loadout()


func _refresh_character_overview() -> void:
	if character_label == null or _player == null:
		return
	var origin := ResourceRegistry.get_origin(_player.origin_id)
	var faction := ResourceRegistry.get_faction(_player.selected_faction_id)
	var profession := ResourceRegistry.get_profession(_player.profession_id)
	var level := _player.experience.level if _player.experience != null else 1
	var xp := _player.experience.current_experience if _player.experience != null else 0
	var next_xp := _player.experience.experience_to_next_level if _player.experience != null else 0
	var wallet := _world.property_bank_service.wallet_balance if _world != null and _world.property_bank_service != null else 0
	var bank := _world.property_bank_service.bank_balance if _world != null and _world.property_bank_service != null else 0
	var health_text := "--"
	if _player.health != null:
		health_text = "%.0f / %.0f" % [_player.health.current_health, _player.health.max_health]
	var energy_text := "--"
	if _player.energy != null:
		energy_text = "%.0f / %.0f" % [_player.energy.current_energy, _player.energy.max_energy]
	var load_state := _player.get_equipment_load_state()
	character_label.text = "\n".join([
		"[color=#58c8b6][font_size=15]IDENTITY[/font_size][/color]",
		"[font_size=22][color=#ead49f]%s[/color][/font_size]" % GameManager.player_name,
		"Origin       [color=#d0d8d2]%s[/color]" % (origin.display_name if origin != null else String(_player.origin_id)),
		"Faction      [color=#d0d8d2]%s[/color]" % (faction.display_name if faction != null else String(_player.selected_faction_id)),
		"Profession   [color=#d0d8d2]%s[/color]" % (profession.display_name if profession != null else String(_player.profession_id)),
		"",
		"[color=#58c8b6][font_size=15]PROGRESSION & VITALS[/font_size][/color]",
		"Level        [color=#ead49f]%d[/color]     XP  %d / %d" % [level, xp, next_xp],
		"Health       %s     Energy  %s" % [health_text, energy_text],
		"Strength     %d     Vitality %d     Charisma %.1f" % [_player.get_physical_strength(), _player.get_physical_vitality(), _player.get_charisma()],
		"Defense      %.1f     Load %.1f / %.1f" % [_player.health.defense if _player.health != null else 0.0, float(load_state.get("attribute_weight", 0.0)), float(load_state.get("capacity", 0.0))],
		"",
		"[color=#58c8b6][font_size=15]WORLD STATUS[/font_size][/color]",
		"Region       %s" % String(_world.current_region_id if _world != null else _player.current_region_id),
		"Funds        %d coin on hand     %d coin banked" % [wallet, bank],
	])


func _refresh_equipment_summary() -> void:
	if equipment_summary == null or _equipment == null:
		return
	var attack_bonus := 0.0
	var defense_bonus := 0.0
	var energy_bonus := 0.0
	var charisma_bonus := 0.0
	var attribute_equipped_count := 0
	var decorative_equipped_count := 0
	for slot in EquipmentComponent.EQUIP_SLOTS:
		var definition := _equipment.get_equipped_definition(slot)
		if definition == null:
			continue
		if definition.is_decorative_equipment():
			decorative_equipped_count += 1
			charisma_bonus += definition.charisma_bonus
		else:
			attribute_equipped_count += 1
			attack_bonus += definition.attack_bonus
			defense_bonus += definition.defense_bonus
			energy_bonus += definition.energy_regen_bonus
	var load_state := _player.get_equipment_load_state() if _player != null else {}
	var load_label := "OVERLOADED  -%.0f%% effectiveness" % (float(load_state.get("penalty_ratio", 0.0)) * 100.0) \
		if bool(load_state.get("overloaded", false)) else "Within physical capacity"
	var profession := ResourceRegistry.get_profession(_player.profession_id) if _player != null else null
	var profession_label := profession.display_name if profession != null else "Adventurer"
	if _equipment_category == EquipmentComponent.PRESENTATION_DECORATIVE:
		equipment_summary.text = "DECORATIVE PRESENTATION\n%d / %d slots equipped  ·  Charisma +%.1f  ·  no physical requirements\nActive visible layer: %s" % [
			decorative_equipped_count, EquipmentComponent.DECORATIVE_SLOTS.size(), charisma_bonus,
			"Decorative Outfit" if _equipment.get_presentation_mode() == EquipmentComponent.PRESENTATION_DECORATIVE else "Profession Gear",
		]
	else:
		equipment_summary.text = "PROFESSION LOADOUT · %s\n%d / %d slots equipped  ·  %.1f / %.1f load  ·  %s\nAttack +%.1f  Defense +%.1f  Energy +%.1f" % [
			profession_label, attribute_equipped_count, EquipmentComponent.ATTRIBUTE_SLOTS.size(), float(load_state.get("attribute_weight", 0.0)), float(load_state.get("capacity", 0.0)), load_label, attack_bonus, defense_bonus, energy_bonus,
		]


func _select_equipment_category(category: StringName) -> void:
	_equipment_category = EquipmentComponent.PRESENTATION_DECORATIVE \
		if category == EquipmentComponent.PRESENTATION_DECORATIVE \
		else EquipmentComponent.PRESENTATION_PROFESSION
	_selected_kind = &""
	_selected_equipment_slot = ItemDefinition.EquipSlot.NONE
	status_label.text = ""
	_refresh()


func _toggle_equipment_presentation() -> void:
	if _equipment == null:
		return
	var mode := _equipment.toggle_presentation_mode()
	status_label.text = "Now showing %s." % (
		"decorative outfit" if mode == EquipmentComponent.PRESENTATION_DECORATIVE \
		else "profession gear"
	)
	_refresh()


func _refresh_equipment_category() -> void:
	if _equipment == null:
		return
	var visible_slots := _equipment.get_slots_for_presentation(_equipment_category)
	for raw_slot in _equipment_buttons:
		var button := _equipment_buttons[raw_slot] as InventorySlotButton
		if button != null:
			button.visible = int(raw_slot) in visible_slots
	_apply_category_style(
		profession_equipment_button,
		_equipment_category == EquipmentComponent.PRESENTATION_PROFESSION,
	)
	_apply_category_style(
		decorative_equipment_button,
		_equipment_category == EquipmentComponent.PRESENTATION_DECORATIVE,
	)
	var decorative := _equipment_category == EquipmentComponent.PRESENTATION_DECORATIVE
	if equipment_intro != null:
		equipment_intro.text = (
			"Decorative outfit slots focus on appearance and charisma. They have no physical requirements."
			if decorative else
			"Profession gear defines the combat silhouette and is governed by level, strength, vitality and load."
		)
	if toggle_presentation_button != null:
		var showing_decor := _equipment.get_presentation_mode() == EquipmentComponent.PRESENTATION_DECORATIVE
		toggle_presentation_button.text = (
			"Show Profession Gear" if showing_decor else "Show Decorative Outfit"
		)
		toggle_presentation_button.tooltip_text = (
			"Switch only the visible outfit layer. Equipped bonuses remain active."
		)


func _refresh_capacity() -> void:
	if capacity_label == null or _inventory == null:
		return
	var occupied := 0
	for index in _inventory.slot_count:
		var stack := _inventory.get_slot(index)
		if stack != null and not stack.is_empty():
			occupied += 1
	capacity_label.text = "%d / %d occupied" % [occupied, _inventory.slot_count]


func _select_page(index: int) -> void:
	_active_page = clampi(index, 0, PAGE_DATA.size() - 1)
	if page_stack != null:
		page_stack.current_tab = _active_page
	var data: Dictionary = PAGE_DATA[_active_page]
	if page_title != null:
		page_title.text = str(data.get("title", "Data"))
	if page_subtitle != null:
		page_subtitle.text = str(data.get("subtitle", ""))
	if category_hint != null:
		category_hint.text = str(data.get("hint", ""))
	if page_counter != null:
		page_counter.text = "%02d / %02d" % [_active_page + 1, PAGE_DATA.size()]
	for entry in [[backpack_tab, 0], [equipment_tab, 1], [skills_tab, 2], [character_tab, 3]]:
		var button := entry[0] as Button
		if button != null:
			_apply_category_style(button, int(entry[1]) == _active_page)
	if capacity_label != null:
		capacity_label.visible = _active_page == 0
	if action_button != null:
		action_button.visible = _active_page in [0, 1]
	_refresh_details()


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
	if _active_page == 2:
		item_name_label.text = "Skill configuration"
		item_type_label.text = "ACTIVE LOADOUT & SCENE PASSIVES"
		description_label.text = (
			"Four rebindable active slots are available. No more than three offensive skills "
			+ "may be carried, and their availability follows the forms held in both hands."
		)
		bonuses_label.text = "Passive skills require no slot and activate automatically when their scene and proficiency conditions match."
		status_label.text = ""
		action_button.disabled = true
		return
	if _active_page == 3:
		item_name_label.text = "Adventurer record"
		item_type_label.text = "IDENTITY & WORLD STATUS"
		description_label.text = (
			"This page collects the character's origin, faction, profession, progression, "
			+ "vitals, location, and funds in one readable record."
		)
		bonuses_label.text = "Server-owned identity data also informs NPC cognition without granting NPCs knowledge they have not learned."
		status_label.text = ""
		action_button.disabled = true
		return
	if _active_page == 1 and _selected_kind == &"":
		var decorative := _equipment_category == EquipmentComponent.PRESENTATION_DECORATIVE
		item_name_label.text = "Decorative outfit" if decorative else "Profession gear"
		item_type_label.text = "APPEARANCE & CHARISMA" if decorative else "PROFESSION & ATTRIBUTES"
		description_label.text = (
			"Decorative pieces control the visible style layer and raise charisma without physical requirements."
			if decorative else
			"Attribute equipment expresses the profession's combat silhouette and is governed by level, strength, vitality and load."
		)
		bonuses_label.text = "Use the display switch to change the visible layer instantly. Both equipped sets remain active."
		status_label.text = ""
		action_button.disabled = true
		return
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


func _on_presentation_mode_changed(_mode: StringName) -> void:
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
		style.bg_color = Color("101b21")
		style.border_color = Color("315d5d")
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
		style.shadow_size = 18
		panel.add_theme_stylebox_override("panel", style)
	var workspace := get_node_or_null("Center/Panel/Margin/VBox/Body/Workspace") as PanelContainer
	if workspace != null:
		var workspace_style := StyleBoxFlat.new()
		workspace_style.bg_color = Color("13242a")
		workspace_style.border_color = Color("28454a")
		workspace_style.set_border_width_all(1)
		workspace_style.set_corner_radius_all(6)
		workspace.add_theme_stylebox_override("panel", workspace_style)
	var details := get_node_or_null("Center/Panel/Margin/VBox/Body/Details") as PanelContainer
	if details != null:
		var detail_style := StyleBoxFlat.new()
		detail_style.bg_color = Color("0c171d")
		detail_style.border_color = Color("2c4a4f")
		detail_style.set_border_width_all(1)
		detail_style.set_corner_radius_all(6)
		details.add_theme_stylebox_override("panel", detail_style)
	for button in [backpack_tab, equipment_tab, skills_tab, character_tab]:
		if button != null:
			_apply_category_style(button, false)


func _apply_category_style(button: Button, selected: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("25494c") if selected else Color("13272d")
	normal.border_color = Color("56c7b4") if selected else Color("29464b")
	normal.set_border_width_all(2 if selected else 1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 13
	normal.content_margin_right = 13
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("2b5657")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color("e9d8aa") if selected else Color("8ba4a4"))
	button.add_theme_color_override("font_hover_color", Color("f0dfb4"))


func _apply_slot_style(button: Button, selected: bool, hotbar_slot: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("2a4f50") if selected else Color("172c32")
	normal.border_color = Color("66d0bd") if selected else (
		Color("8a7445") if hotbar_slot else Color("335157")
	)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(5)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("315b5c")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color("d7e0d8"))
	button.add_theme_color_override("font_hover_color", Color("f2e2b6"))
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
			return "CHEST / TOP"
		ItemDefinition.EquipSlot.CHARM:
			return "ORNAMENT"
		ItemDefinition.EquipSlot.HEAD:
			return "HEAD"
		ItemDefinition.EquipSlot.LEGS:
			return "TROUSERS"
		ItemDefinition.EquipSlot.FEET:
			return "SHOES"
		ItemDefinition.EquipSlot.HANDS:
			return "GLOVES"
		ItemDefinition.EquipSlot.WRISTS:
			return "BRACERS"
		ItemDefinition.EquipSlot.RING_LEFT:
			return "LEFT RING"
		ItemDefinition.EquipSlot.RING_RIGHT:
			return "RIGHT RING"
		ItemDefinition.EquipSlot.BELT:
			return "BELT"
		ItemDefinition.EquipSlot.DECOR_HEAD:
			return "HEAD DECOR"
		ItemDefinition.EquipSlot.DECOR_BODY:
			return "BODY DECOR"
		ItemDefinition.EquipSlot.DECOR_HANDS:
			return "HAND DECOR"
		ItemDefinition.EquipSlot.DECOR_FEET:
			return "FOOT DECOR"
		ItemDefinition.EquipSlot.DECOR_ORNAMENT:
			return "EXTRA ORNAMENT"
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
	if definition.max_health_bonus > 0.0:
		parts.append("+%.0f maximum health" % definition.max_health_bonus)
	if definition.max_energy_bonus > 0.0:
		parts.append("+%.0f maximum energy" % definition.max_energy_bonus)
	if definition.move_speed_bonus > 0.0:
		parts.append("+%.2f movement speed" % definition.move_speed_bonus)
	if definition.charisma_bonus > 0.0:
		parts.append("+%.1f charisma · decorative, no physical requirement" % definition.charisma_bonus)
	if definition.is_attribute_equipment():
		parts.append("Weight %.1f · requires level %d, strength %d, vitality %d" % [definition.equipment_weight, definition.minimum_level, definition.required_strength, definition.required_vitality])
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
