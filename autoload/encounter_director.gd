extends Node

const WAVE_SECONDS: float = 24.0

var current_wave: int = 0
var intensity: float = 0.0
var _purity: float = 0.0
var _boss_spawned: bool = false
var _tick: float = 0.0

func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.corruption_field_changed.connect(_on_field_changed)

func _process(delta: float) -> void:
	if not GameState.is_playing():
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	var mission := GameState.current_mission()
	if mission == null:
		return
	var difficulty_mult: float = SettingsState.difficulty_multiplier() * GameState.ng_plus_multiplier()
	var next_wave: int = 1 + floori(GameState.elapsed / (WAVE_SECONDS / difficulty_mult))
	intensity = clampf((0.2 + GameState.elapsed / maxf(mission.time_limit if mission.time_limit > 0.0 else 150.0, 1.0) + (1.0 - _purity) * 0.35) * difficulty_mult, 0.0, 1.0)
	if next_wave != current_wave:
		current_wave = next_wave
		if current_wave > 1:
			EventBus.message_posted.emit("WAVE %02d // TERRITORIAL PRESSURE %d%%" % [current_wave, roundi(intensity * 100.0)], &"danger")
	EventBus.encounter_state_changed.emit(current_wave, intensity, _wave_label(current_wave))
	if not _boss_spawned and mission.boss_kind != &"" and _boss_triggered(mission):
		_boss_spawned = true
		EventBus.boss_spawn_requested.emit(mission.boss_kind, mission.boss_name, mission.boss_power)

func _boss_triggered(mission: MissionResource) -> bool:
	return (mission.boss_trigger_seconds > 0.0 and GameState.elapsed >= mission.boss_trigger_seconds) or (mission.boss_trigger_purity > 0.0 and _purity >= mission.boss_trigger_purity)

func _wave_label(wave: int) -> String:
	if wave <= 1: return "BREACH"
	if wave == 2: return "CONTESTED"
	if wave == 3: return "HOSTILE CONVERGENCE"
	return "THRONE PRESSURE"

func _on_field_changed(_values: PackedFloat32Array, _width: int, _height: int, purity: float, _anchor: float) -> void:
	_purity = purity

func _on_game_started() -> void:
	current_wave = 0
	intensity = 0.0
	_purity = 0.0
	_boss_spawned = false
	_tick = 0.0

func _reset_for_test() -> void:
	_on_game_started()
