extends Node

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase: float = 0.0
var _remaining: float = 0.0
var _frequency: float = 220.0
var _cue_kind: StringName = &""
var _ambient_phase: float = 0.0
var _legacy_phase: float = 0.0
var _nature_phase: float = 0.0
var _bird_phase: float = 0.0
var _purity: float = 0.0
var _legacy_strength: float = 0.0
var _veiled: bool = false

func _ready() -> void:
	EventBus.audio_requested.connect(play_cue)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.corruption_field_changed.connect(_on_corruption_field_changed)
	EventBus.restoration_legacy_changed.connect(_on_restoration_legacy_changed)
	EventBus.ariel_spoke.connect(func(_text: String) -> void: play_cue(&"ariel"))
	EventBus.prayer_started.connect(func() -> void: play_cue(&"prayer"))
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
	_cue_kind = kind
	match kind:
		&"hit": _frequency = 140.0; _remaining = 0.08
		&"purify": _frequency = 520.0; _remaining = 0.12
		&"declare": _frequency = 740.0; _remaining = 0.35
		&"legislate": _frequency = 410.0; _remaining = 0.55
		&"veiled": _frequency = 74.0; _remaining = 0.8
		&"victory": _frequency = 880.0; _remaining = 1.0
		&"failure": _frequency = 62.0; _remaining = 1.0
		&"intercessor": _frequency = 610.0; _remaining = 0.45
		&"ariel": _frequency = 240.0; _remaining = 0.62
		&"prayer": _frequency = 330.0; _remaining = 0.48
		&"deflect": _frequency = 1180.0; _remaining = 0.18
		&"denied": _frequency = 92.0; _remaining = 0.42
		&"host_return": _frequency = 920.0; _remaining = 0.75
		&"synthetic_ricochet": _frequency = 1280.0; _remaining = 0.22
		&"legacy_garden": _frequency = 659.25; _remaining = 0.72
		_: _frequency = 260.0; _remaining = 0.06

func _process(delta: float) -> void:
	if _playback == null:
		return
	_remaining = maxf(0.0, _remaining - delta)
	var frames: int = mini(_playback.get_frames_available(), 256)
	for i: int in range(frames):
		_phase = fmod(_phase + _frequency / 22050.0, 1.0)
		_ambient_phase = fmod(_ambient_phase + (82.0 + _purity * 146.0) / 22050.0, 1.0)
		_legacy_phase = fmod(_legacy_phase + 164.81 / 22050.0, 1.0)
		_nature_phase = fmod(_nature_phase + 0.38 / 22050.0, 1.0)
		var bird_envelope: float = pow(maxf(0.0, sin(_nature_phase * TAU)), 18.0)
		_bird_phase = fmod(_bird_phase + (1180.0 + bird_envelope * 720.0) / 22050.0, 1.0)
		var envelope: float = clampf(_remaining * 4.0, 0.0, 1.0)
		var cue_wave: float = sin(_phase * TAU)
		match _cue_kind:
			&"intercessor": cue_wave = sin(_phase * TAU) * 0.72 + sin(_phase * TAU * 1.5) * 0.28
			&"ariel": cue_wave = sin(_phase * TAU) * 0.56 + sin(_phase * TAU * 1.25) * 0.27 + sin(_phase * TAU * 1.5) * 0.17
			&"prayer": cue_wave = sin(_phase * TAU) * (0.68 + sin(_ambient_phase * TAU * 0.25) * 0.22)
			&"declare", &"legislate": cue_wave = sin(_phase * TAU) * 0.62 + sin(_phase * TAU * 2.0) * 0.24
		var cue: float = cue_wave * 0.08 * envelope
		var ambient_level: float = (0.0015 if _veiled else lerpf(0.003, 0.012, _purity))
		var harmonic: float = sin(_ambient_phase * TAU) + sin(_ambient_phase * TAU * (1.5 + _purity * 0.5)) * _purity * 0.45
		var legacy_chord: float = (sin(_legacy_phase * TAU) + sin(_legacy_phase * TAU * 1.25) * 0.55 + sin(_legacy_phase * TAU * 1.5) * 0.38) * _legacy_strength
		var corrupt_stem: float = (sin(_ambient_phase * TAU * 0.5) + sin(_ambient_phase * TAU * 0.707) * 0.62) * (1.0 - _purity) * 0.0035
		var water_stem: float = (sin(_ambient_phase * TAU * 0.37) + sin(_ambient_phase * TAU * 0.61) * 0.55) * _purity * 0.0018
		var bird_stem: float = sin(_bird_phase * TAU) * bird_envelope * _purity * 0.0028
		var environmental_stems: float = 0.0 if _veiled else corrupt_stem + water_stem + bird_stem
		var sample: float = cue + harmonic * ambient_level + legacy_chord * (0.0 if _veiled else 0.0045) + environmental_stems
		_playback.push_frame(Vector2(sample, sample))

func _on_corruption_field_changed(_values: PackedFloat32Array, _width: int, _height: int, purity: float, _anchor: float) -> void:
	_purity = clampf(purity, 0.0, 1.0)

static func restoration_stem_gain(source_count: int, mean_purity: float) -> float:
	return clampf(float(source_count) / 6.0, 0.0, 1.0) * clampf(mean_purity, 0.0, 1.0)

static func cue_voice_layer_count(kind: StringName) -> int:
	if kind == &"ariel":
		return 3
	if kind == &"intercessor":
		return 2
	return 1

func _on_restoration_legacy_changed(source_count: int, _bloom_count: int, mean_purity: float) -> void:
	_legacy_strength = restoration_stem_gain(source_count, mean_purity)
	if source_count > 0:
		play_cue(&"legacy_garden")

func _reset_for_test() -> void:
	_remaining = 0.0
	_cue_kind = &""
	_legacy_strength = 0.0

func shutdown() -> void:
	if _player != null:
		_player.stop()
		_player.stream = null
		_player.queue_free()
		_player = null
	_playback = null

func _exit_tree() -> void:
	shutdown()
