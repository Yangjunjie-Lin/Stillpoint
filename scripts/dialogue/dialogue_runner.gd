class_name DialogueRunner
extends RefCounted

signal line_presented(speaker: String, text: String)
signal choices_presented(choices: Array)
signal dialogue_finished

var _definition: DialogueDefinition
var _current_node: DialogueNode
var _npc: NPCController
var _player: PlayerController3D


func start(dialogue: DialogueDefinition, npc: NPCController, player: PlayerController3D) -> bool:
	if dialogue == null or player == null:
		return false
	_definition = dialogue
	_npc = npc
	_player = player
	_current_node = dialogue.get_node(dialogue.start_node_id)
	if _current_node == null:
		return false
	_present_node()
	return true


func choose(index: int) -> void:
	if _current_node == null:
		return
	if index < 0 or index >= _current_node.choices.size():
		dialogue_finished.emit()
		return
	var choice := _current_node.choices[index]
	if _npc != null and choice.affinity_delta != 0.0:
		RelationshipService.change_affinity(_npc.character_id, choice.affinity_delta, &"dialogue")
		if _npc.relationship != null:
			_npc.relationship.change_affinity(_player.character_id, choice.affinity_delta, &"dialogue")
	if choice.quest_effect != &"":
		QuestManager.start_quest(choice.quest_effect)
	_next_node(choice.next_node_id)


func _present_node() -> void:
	if _current_node == null:
		dialogue_finished.emit()
		return
	if _npc != null and _player != null:
		if _current_node.requires_not_attacked:
			var disp := _npc.relationship.get_disposition(_player.character_id)
			if disp == RelationshipComponent.Disposition.HOSTILE:
				line_presented.emit(_current_node.speaker, "I don't want to talk to you.")
				dialogue_finished.emit()
				return
	for line in _current_node.lines:
		line_presented.emit(_current_node.speaker, line)
	if not _current_node.choices.is_empty():
		var available: Array = []
		for choice in _current_node.choices:
			if choice.requires_not_hostile and _npc != null:
				if _npc.relationship.get_disposition(_player.character_id) == RelationshipComponent.Disposition.HOSTILE:
					continue
			if RelationshipService.get_affinity(_npc.character_id if _npc else &"") < choice.required_affinity:
				continue
			available.append(choice)
		choices_presented.emit(available)
		return
	_next_node(_current_node.next_node_id)


func _next_node(node_id: StringName) -> void:
	if node_id == &"":
		dialogue_finished.emit()
		return
	_current_node = _definition.get_node(node_id)
	if _current_node == null:
		dialogue_finished.emit()
		return
	_present_node()
