extends RefCounted
## Short menu ticks on the SFX bus. Recorded UI files replace the tones when they land.

const Settings = preload("res://game/match_settings.gd")
const Clips = preload("res://game/match_audio.gd")

static var _player: AudioStreamPlayer

static func play(host: Node, kind: String) -> void:
	if host == null:
		return
	_bus()
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		_player.name = "MenuSfx"
		_player.bus = "SFX"
		host.get_tree().root.add_child(_player)
	_player.bus = "SFX"
	var clip: AudioStream = Clips.cue_clip(kind)
	_player.stream = clip if clip != null else SMTone.cue(kind)
	_player.pitch_scale = 0.97 + randf() * 0.06
	_player.play()

static func _bus() -> void:
	var idx: int = Settings.append_bus("SFX", "Master")
	AudioServer.set_bus_volume_db(idx, Settings.sfx_bus_db())
