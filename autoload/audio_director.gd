extends Node

const CUE_PLAYER_COUNT: int = 6
const CUE_GAIN_DB: float = -12.0
const CUE_STREAMS: Dictionary = {
	&"hit": preload("res://assets/audio/sfx/hit.ogg"),
	&"purify": preload("res://assets/audio/sfx/purify.ogg"),
	&"declare": preload("res://assets/audio/sfx/declare.ogg"),
	&"legislate": preload("res://assets/audio/sfx/legislate.ogg"),
	&"veiled": preload("res://assets/audio/sfx/veiled.ogg"),
	&"victory": preload("res://assets/audio/sfx/victory.ogg"),
	&"failure": preload("res://assets/audio/sfx/failure.ogg"),
	&"intercessor": preload("res://assets/audio/sfx/intercessor.ogg"),
	&"ariel": preload("res://assets/audio/sfx/ariel.ogg"),
	&"prayer": preload("res://assets/audio/sfx/prayer.ogg"),
	&"deflect": preload("res://assets/audio/sfx/deflect.ogg"),
	&"denied": preload("res://assets/audio/sfx/denied.ogg"),
	&"host_return": preload("res://assets/audio/sfx/host_return.ogg"),
	&"synthetic_ricochet": preload("res://assets/audio/sfx/synthetic_ricochet.ogg"),
	&"legacy_garden": preload("res://assets/audio/sfx/legacy_garden.ogg"),
}

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _cue_players: Array[AudioStreamPlayer] = []
var _cue_cursor: int = 0
var _master_volume: float = 0.8
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
	for index: int in range(CUE_PLAYER_COUNT):
		var cue_player := AudioStreamPlayer.new()
		cue_player.name = "CuePlayer%02d" % index
		add_child(cue_player)
		_cue_players.append(cue_player)
	_on_settings_changed(SettingsState.values)

func _on_settings_changed(values: Dictionary) -> void:
	_master_volume = float(values.get(&"master_volume", 0.8))
	var master_db := linear_to_db(maxf(_master_volume, 0.0001))
	if _player != null:
		_player.volume_db = master_db
	for cue_player: AudioStreamPlayer in _cue_players:
		cue_player.volume_db = master_db + CUE_GAIN_DB

func play_cue(kind: StringName) -> void:
	if _cue_players.is_empty():
		return
	var stream := CUE_STREAMS.get(kind, CUE_STREAMS[&"hit"]) as AudioStream
	var selected_index: int = _cue_cursor % _cue_players.size()
	for offset: int in range(_cue_players.size()):
		var candidate_index: int = (_cue_cursor + offset) % _cue_players.size()
		if not _cue_players[candidate_index].playing:
			selected_index = candidate_index
			break
	var cue_player := _cue_players[selected_index]
	if cue_player.playing:
		cue_player.stop()
	cue_player.stream = stream
	cue_player.volume_db = linear_to_db(maxf(_master_volume, 0.0001)) + CUE_GAIN_DB
	cue_player.play()
	_cue_cursor = (selected_index + 1) % _cue_players.size()

func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames: int = mini(_playback.get_frames_available(), 256)
	for _frame: int in range(frames):
		_ambient_phase = fmod(_ambient_phase + (82.0 + _purity * 146.0) / 22050.0, 1.0)
		_legacy_phase = fmod(_legacy_phase + 164.81 / 22050.0, 1.0)
		_nature_phase = fmod(_nature_phase + 0.38 / 22050.0, 1.0)
		var bird_envelope: float = pow(maxf(0.0, sin(_nature_phase * TAU)), 18.0)
		_bird_phase = fmod(_bird_phase + (1180.0 + bird_envelope * 720.0) / 22050.0, 1.0)
		var ambient_level: float = (0.0015 if _veiled else lerpf(0.003, 0.012, _purity))
		var harmonic: float = sin(_ambient_phase * TAU) + sin(_ambient_phase * TAU * (1.5 + _purity * 0.5)) * _purity * 0.45
		var legacy_chord: float = (sin(_legacy_phase * TAU) + sin(_legacy_phase * TAU * 1.25) * 0.55 + sin(_legacy_phase * TAU * 1.5) * 0.38) * _legacy_strength
		var corrupt_stem: float = (sin(_ambient_phase * TAU * 0.5) + sin(_ambient_phase * TAU * 0.707) * 0.62) * (1.0 - _purity) * 0.0035
		var water_stem: float = (sin(_ambient_phase * TAU * 0.37) + sin(_ambient_phase * TAU * 0.61) * 0.55) * _purity * 0.0018
		var bird_stem: float = sin(_bird_phase * TAU) * bird_envelope * _purity * 0.0028
		var environmental_stems: float = 0.0 if _veiled else corrupt_stem + water_stem + bird_stem
		var sample: float = harmonic * ambient_level + legacy_chord * (0.0 if _veiled else 0.0045) + environmental_stems
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

static func cue_stream_for(kind: StringName) -> AudioStream:
	return CUE_STREAMS.get(kind) as AudioStream

func _on_restoration_legacy_changed(source_count: int, _bloom_count: int, mean_purity: float) -> void:
	_legacy_strength = restoration_stem_gain(source_count, mean_purity)
	if source_count > 0:
		play_cue(&"legacy_garden")

func _reset_for_test() -> void:
	for cue_player: AudioStreamPlayer in _cue_players:
		cue_player.stop()
		cue_player.stream = null
	_cue_cursor = 0
	_legacy_strength = 0.0

func shutdown() -> void:
	for cue_player: AudioStreamPlayer in _cue_players:
		cue_player.stop()
		cue_player.stream = null
		cue_player.queue_free()
	_cue_players.clear()
	_cue_cursor = 0
	if _player != null:
		_player.stop()
		_player.stream = null
		_player.queue_free()
		_player = null
	_playback = null

func _exit_tree() -> void:
	shutdown()
