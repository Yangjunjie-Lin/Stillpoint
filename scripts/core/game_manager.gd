extends Node
## Cross-scene run metadata. Combat actors are not owned here.

const CHARACTER_BUILD_SECTION_VERSION: int = CharacterBuildCalculator.BUILD_SECTION_VERSION
const DEFAULT_ORIGIN_ID: StringName = &"wuxia_swordsman"
const DEFAULT_FACTION_ID: StringName = &"free_roads"
const DEFAULT_PROFESSION_ID: StringName = &"spirit_blade"
const DEFAULT_ATTRIBUTE_SEED: int = 804_020

var player_name: String = "Player"
var diagnostics_enabled: bool = false
var run_active: bool = false
var resume_requested: bool = false
var pending_character_build: Dictionary = {}


func _ready() -> void:
	pass


func start_new_adventure(requested_name: String = "Traveler") -> void:
	player_name = requested_name.strip_edges().substr(0, 24)
	if player_name.is_empty():
		player_name = "Traveler"
	run_active = true
	resume_requested = false
	QuestManager.reset_all()
	RelationshipService.reset_all()
	WorldTimeService.reset_all()
	SaveSlotService.clear_adventure_save()
	pending_character_build.clear()
	SceneRouter.go_to_character_creation()


func confirm_character_build(
	origin_id: StringName,
	faction_id: StringName,
	profession_id: StringName,
	appearance: Dictionary = {},
	attribute_seed: int = DEFAULT_ATTRIBUTE_SEED,
) -> bool:
	if not is_valid_character_build(origin_id, faction_id, profession_id):
		push_warning("GameManager: rejected invalid character build")
		return false
	var normalized_seed := CharacterBuildCalculator.normalize_seed(
		attribute_seed,
		DEFAULT_ATTRIBUTE_SEED,
	)
	pending_character_build = {
		"section_version": CHARACTER_BUILD_SECTION_VERSION,
		"origin_id": String(origin_id),
		"faction_id": String(faction_id),
		"profession_id": String(profession_id),
		"appearance": CharacterAppearanceOptions.normalize(appearance),
		"attribute_seed": normalized_seed,
		"attribute_generation_version": CharacterBuildCalculator.ATTRIBUTE_GENERATION_VERSION,
	}
	resume_requested = false
	run_active = true
	SceneRouter.go_to_world_session()
	return true


func is_valid_character_build(
	origin_id: StringName,
	faction_id: StringName,
	profession_id: StringName,
) -> bool:
	var origin := ResourceRegistry.get_origin(origin_id)
	var faction := ResourceRegistry.get_faction(faction_id)
	var profession := ResourceRegistry.get_profession(profession_id)
	return (
		origin != null
		and faction != null
		and faction.selectable
		and profession != null
	)


func get_default_character_build() -> Dictionary:
	return {
		"section_version": CHARACTER_BUILD_SECTION_VERSION,
		"origin_id": String(DEFAULT_ORIGIN_ID),
		"faction_id": String(DEFAULT_FACTION_ID),
		"profession_id": String(DEFAULT_PROFESSION_ID),
		"appearance": CharacterAppearanceOptions.default_options(),
		"attribute_seed": DEFAULT_ATTRIBUTE_SEED,
		"attribute_generation_version": CharacterBuildCalculator.ATTRIBUTE_GENERATION_VERSION,
	}


func consume_pending_character_build() -> Dictionary:
	var result := pending_character_build.duplicate(true)
	if result.is_empty():
		result = get_default_character_build()
	pending_character_build.clear()
	return result


func cancel_character_creation() -> void:
	pending_character_build.clear()
	run_active = false
	resume_requested = false
	SceneRouter.go_to_main_menu()


func continue_adventure() -> void:
	if not SaveSlotService.has_adventure_save():
		push_warning("GameManager: no world save to continue")
		return
	run_active = true
	resume_requested = true
	pending_character_build.clear()
	SceneRouter.go_to_world_session()


func has_resumable_adventure() -> bool:
	return SaveSlotService.has_adventure_save()


func start_new_run(requested_name: String = "Player") -> void:
	player_name = requested_name.strip_edges().substr(0, 24)
	if player_name.is_empty():
		player_name = "Player"
	run_active = true
	resume_requested = false
	SaveService.clear_run()
	SceneRouter.go_to_gameplay()


func continue_run() -> void:
	var summary := inspect_resumable_run()
	if not summary.valid:
		push_warning("GameManager: no resumable run (%s)" % summary.reason)
		return
	player_name = summary.player_name
	run_active = true
	resume_requested = true
	SceneRouter.go_to_gameplay()


func has_resumable_run() -> bool:
	return inspect_resumable_run().valid


func inspect_resumable_run(max_age_seconds: float = SaveService.DEFAULT_MAX_AGE) -> RunSaveSummary:
	var summary := SaveService.inspect_run(max_age_seconds)
	if not summary.valid:
		return summary
	if ResourceRegistry.get_level(summary.level_id) == null:
		summary.valid = false
		summary.reason = "unknown_level"
	return summary


func return_to_menu() -> void:
	var tree := get_tree()
	if tree != null:
		var world := tree.get_first_node_in_group("world_manager") as WorldSession
		if world != null:
			world.save_world_state()
	run_active = false
	resume_requested = false
	pending_character_build.clear()
	get_tree().paused = false
	SceneRouter.go_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		SaveService.toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_diagnostics"):
		diagnostics_enabled = not diagnostics_enabled
		get_viewport().set_input_as_handled()
