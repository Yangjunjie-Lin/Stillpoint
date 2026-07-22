class_name ShowNoticeEffect
extends WorldEffect

@export var message: String = ""


func apply(_context: WorldEffectContext) -> EffectResult:
	if message != "":
		EventBus.notice_requested.emit(message)
	return EffectResult.success()
