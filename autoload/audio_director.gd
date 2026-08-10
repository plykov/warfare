extends Node

const CUE_PLAYER_COUNT: int = 6
const CUE_GAIN_DB: float = -12.0
const AMBIENT_FLOOR_DB: float = -80.0
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
const AMBIENT_STREAMS: Dictionary = {
	&"corrupt": preload("res://assets/audio/ambient/corrupt_bed.ogg"),
	&"pure": preload("res://assets/audio/ambient/pure_bed.ogg"),
	&"water": preload("res://assets/audio/ambient/water_bed.ogg"),
	&"bird": preload("res://assets/audio/ambient/bird_bed.ogg"),
	&"legacy": preload("res://assets/audio/ambient/legacy_bed.ogg"),
}

var _ambient_players: Dictionary = {}
var _cue_players: Array[AudioStreamPlayer] = []
var _cue_cursor: int = 0
var _master_volume: float = 0.8
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
	EventBus.entered_veiled.connect(_on_entered_veiled)
	EventBus.exited_veiled.connect(_on_exited_veiled)
	# Tests do not need an audio device, so avoid creating players headlessly.
	if DisplayServer.get_name() == "headless":
		return
	for kind: StringName in AMBIENT_STREAMS:
		var ambient_player := AudioStreamPlayer.new()
		ambient_player.name = "%sBed" % String(kind).capitalize()
		ambient_player.stream = AMBIENT_STREAMS[kind]
		ambient_player.volume_db = AMBIENT_FLOOR_DB
		add_child(ambient_player)
		_ambient_players[kind] = ambient_player
		ambient_player.play()
	for index: int in range(CUE_PLAYER_COUNT):
		var cue_player := AudioStreamPlayer.new()
		cue_player.name = "CuePlayer%02d" % index
		add_child(cue_player)
		_cue_players.append(cue_player)
	_on_settings_changed(SettingsState.values)

func _on_settings_changed(values: Dictionary) -> void:
	_master_volume = float(values.get(&"master_volume", 0.8))
	var master_db := linear_to_db(maxf(_master_volume, 0.0001))
	for cue_player: AudioStreamPlayer in _cue_players:
		cue_player.volume_db = master_db + CUE_GAIN_DB
	_update_ambient_levels()

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
	_update_ambient_levels()

static func ambient_gain_for(kind: StringName, purity: float, legacy_strength: float, veiled: bool) -> float:
	var clamped_purity := clampf(purity, 0.0, 1.0)
	if veiled:
		return 0.0015 if kind == &"pure" else 0.0
	match kind:
		&"corrupt":
			return (1.0 - clamped_purity) * 0.0035
		&"pure":
			return lerpf(0.003, 0.012, clamped_purity)
		&"water":
			return clamped_purity * 0.0018
		&"bird":
			return clamped_purity * 0.0028
		&"legacy":
			return clampf(legacy_strength, 0.0, 1.0) * 0.0045
		_:
			return 0.0

func _update_ambient_levels() -> void:
	if _ambient_players.is_empty():
		return
	var master_db := linear_to_db(maxf(_master_volume, 0.0001))
	for kind: StringName in _ambient_players:
		var gain := ambient_gain_for(kind, _purity, _legacy_strength, _veiled)
		var layer_db := AMBIENT_FLOOR_DB if gain <= 0.0 else maxf(AMBIENT_FLOOR_DB, linear_to_db(gain))
		var ambient_player := _ambient_players[kind] as AudioStreamPlayer
		ambient_player.volume_db = maxf(AMBIENT_FLOOR_DB, master_db + layer_db)

func _on_corruption_field_changed(_values: PackedFloat32Array, _width: int, _height: int, purity: float, _anchor: float) -> void:
	_purity = clampf(purity, 0.0, 1.0)
	_update_ambient_levels()

func _on_entered_veiled() -> void:
	_veiled = true
	_update_ambient_levels()

func _on_exited_veiled() -> void:
	_veiled = false
	_update_ambient_levels()

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

static func ambient_stream_for(kind: StringName) -> AudioStream:
	return AMBIENT_STREAMS.get(kind) as AudioStream

func _on_restoration_legacy_changed(source_count: int, _bloom_count: int, mean_purity: float) -> void:
	_legacy_strength = restoration_stem_gain(source_count, mean_purity)
	_update_ambient_levels()
	if source_count > 0:
		play_cue(&"legacy_garden")

func _reset_for_test() -> void:
	for cue_player: AudioStreamPlayer in _cue_players:
		cue_player.stop()
		cue_player.stream = null
	_cue_cursor = 0
	_legacy_strength = 0.0
	_update_ambient_levels()

func shutdown() -> void:
	for ambient_player: AudioStreamPlayer in _ambient_players.values():
		ambient_player.stop()
		ambient_player.stream = null
		ambient_player.queue_free()
	_ambient_players.clear()
	for cue_player: AudioStreamPlayer in _cue_players:
		cue_player.stop()
		cue_player.stream = null
		cue_player.queue_free()
	_cue_players.clear()
	_cue_cursor = 0

func _exit_tree() -> void:
	shutdown()
