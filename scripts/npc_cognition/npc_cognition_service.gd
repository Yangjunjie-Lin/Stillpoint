class_name NPCCognitionService
extends Node

var save_provider := NPCCognitionSaveProvider.new()
var gateway: NPCDialogueGateway
var conversation_controller: NPCConversationController

func _init() -> void:
	_build_components()

func _ready() -> void:
	if gateway.get_parent() == null:
		add_child(gateway)
	if conversation_controller.get_parent() == null:
		add_child(conversation_controller)

func _build_components() -> void:
	if gateway != null: return
	gateway = NPCDialogueGateway.new()
	conversation_controller = NPCConversationController.new()
	conversation_controller.setup(gateway, save_provider.cache)

func is_ai_enabled() -> bool:
	return bool(SaveService.settings.get("ai_dialogue_enabled", false))

func can_use_free_form(npc: NPCController) -> bool:
	return is_ai_enabled() and npc != null and npc.npc_definition != null and npc.npc_definition.mind_profile != null

func delete_npc_memory(npc_persistent_id: String) -> void:
	save_provider.delete_npc_memory(npc_persistent_id)

func delete_all_player_memory() -> void:
	save_provider.delete_all_player_memory()

func export_memory_data() -> Dictionary:
	return save_provider.export_memory_data()
