extends Node

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _remaining: float = 0.0
var _frequency: float = 220.0
var _ambient_phase: float = 0.0
var _purity: float = 0.0
var _veiled: bool = false

func _ready() -> void:
	EventBus.audio_requested.connect(play_cue)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.corruption_field_changed.connect(_on_corruption_field_changed)
	EventBus.entered_veiled.connect(func() -> void: _veiled = true)
	EventBus.exited_veiled.connect(func() -> void: _veiled = false)
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
		&"intercessor": _frequency = 610.0; _remaining = 0.45
		&"deflect": _frequency = 1180.0; _remaining = 0.18
		&"denied": _frequency = 92.0; _remaining = 0.42
		&"host_return": _frequency = 920.0; _remaining = 0.75
		_: _frequency = 260.0; _remaining = 0.06

func _process(delta: float) -> void:
	if _playback == null:
		return
	_remaining = maxf(0.0, _remaining - delta)
	var frames: int = mini(_playback.get_frames_available(), 256)
	for i: int in range(frames):
		_phase = fmod(_phase + _frequency / 22050.0, 1.0)
		_ambient_phase = fmod(_ambient_phase + (82.0 + _purity * 146.0) / 22050.0, 1.0)
		var envelope: float = clampf(_remaining * 4.0, 0.0, 1.0)
		var cue: float = sin(_phase * TAU) * 0.08 * envelope
		var ambient_level: float = (0.0015 if _veiled else lerpf(0.003, 0.012, _purity))
		var harmonic: float = sin(_ambient_phase * TAU) + sin(_ambient_phase * TAU * (1.5 + _purity * 0.5)) * _purity * 0.45
		var sample: float = cue + harmonic * ambient_level
		_playback.push_frame(Vector2(sample, sample))

func _on_corruption_field_changed(_values: PackedFloat32Array, _width: int, _height: int, purity: float, _anchor: float) -> void:
	_purity = clampf(purity, 0.0, 1.0)

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
