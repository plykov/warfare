extends Node

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _remaining: float = 0.0
var _frequency: float = 220.0

func _ready() -> void:
	EventBus.audio_requested.connect(play_cue)
	EventBus.settings_changed.connect(_on_settings_changed)
	# Godot 4.4 retains AudioStreamGeneratorPlayback until shutdown in headless
	# mode. Tests do not need an audio device, so avoid creating one there.
	if DisplayServer.get_name() == "headless":
		return
	_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.25
	_player.stream = stream
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()
	_on_settings_changed(SettingsState.values)

func _on_settings_changed(values: Dictionary) -> void:
	if _player != null:
		var volume: float = float(values.get(&"master_volume", 0.8))
		_player.volume_db = linear_to_db(maxf(volume, 0.0001))

func play_cue(kind: StringName) -> void:
	match kind:
		&"hit": _frequency = 140.0; _remaining = 0.08
		&"purify": _frequency = 520.0; _remaining = 0.12
		&"declare": _frequency = 740.0; _remaining = 0.35
		&"legislate": _frequency = 410.0; _remaining = 0.55
		&"veiled": _frequency = 74.0; _remaining = 0.8
		&"victory": _frequency = 880.0; _remaining = 1.0
		&"failure": _frequency = 62.0; _remaining = 1.0
		_: _frequency = 260.0; _remaining = 0.06

func _process(delta: float) -> void:
	if _playback == null or _remaining <= 0.0:
		return
	_remaining -= delta
	var frames: int = mini(_playback.get_frames_available(), 256)
	for i: int in range(frames):
		_phase = fmod(_phase + _frequency / 22050.0, 1.0)
		var envelope: float = clampf(_remaining * 4.0, 0.0, 1.0)
		var sample: float = sin(_phase * TAU) * 0.08 * envelope
		_playback.push_frame(Vector2(sample, sample))

func _reset_for_test() -> void:
	_remaining = 0.0

func shutdown() -> void:
	if _player != null:
		_player.stop()
		_player.stream = null
		_player.queue_free()
		_player = null
	_playback = null

func _exit_tree() -> void:
	shutdown()
