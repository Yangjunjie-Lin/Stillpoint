extends Node
## Lightweight SFX/music helpers with a small AudioStreamPlayer pool.

const POOL_SIZE := 8

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _music_player: AudioStreamPlayer
var _current_music: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	for _i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)


func play_sfx(stream: AudioStream, _position: Vector2 = Vector2.ZERO, volume_db: float = 0.0) -> void:
	if stream == null or DisplayServer.get_name() == "headless":
		return
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func play_ui_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	play_sfx(stream, Vector2.ZERO, volume_db)


func play_music(stream: AudioStream, _fade_seconds: float = 0.5) -> void:
	if stream == null or DisplayServer.get_name() == "headless":
		return
	if _current_music == stream and _music_player.playing:
		return
	_current_music = stream
	_music_player.stream = stream
	_music_player.play()


func stop_music(_fade_seconds: float = 0.5) -> void:
	_music_player.stop()
	_current_music = null
