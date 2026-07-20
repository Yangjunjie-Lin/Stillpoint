extends Node
## Placeholder audio bus. SFX/music hooks for future content.

@export var master_volume_db: float = 0.0


func play_sfx(_stream: AudioStream, _volume_db: float = 0.0) -> void:
	pass


func play_music(_stream: AudioStream, _volume_db: float = 0.0) -> void:
	pass
