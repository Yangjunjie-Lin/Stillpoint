class_name GameplayEventBus
extends RefCounted
## Session-local gameplay event dispatcher.

signal event_emitted(event: GameplayEvent)

var _listeners: Array[Callable] = []


func emit_event(event: GameplayEvent) -> void:
	if event == null:
		return
	event_emitted.emit(event)
	for cb in _listeners:
		if cb.is_valid():
			cb.call(event)


func subscribe(callback: Callable) -> void:
	if not _listeners.has(callback):
		_listeners.append(callback)


func unsubscribe(callback: Callable) -> void:
	_listeners.erase(callback)


func clear() -> void:
	_listeners.clear()
