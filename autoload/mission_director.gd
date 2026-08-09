extends Node

const REQUIRED_HOLD_SECONDS: float = 2.0

var current_mission: MissionResource
var objectives: Array[MissionObjective] = []
var _context: Dictionary = {}
var _hold: float = 0.0
var _ended: bool = false
var _objective_tick: float = 0.0
var current_purity: float = 0.0

func _ready() -> void:
	EventBus.mission_selected.connect(_on_mission_selected)
	EventBus.game_started.connect(_on_game_started)
	EventBus.corruption_field_changed.connect(_on_field_changed)
	EventBus.thin_place_changed.connect(_on_thin_place_changed)
	EventBus.target_bound.connect(_on_target_bound)
	EventBus.host_arrived.connect(func() -> void: _context["host_arrived"] = true)
	EventBus.enemy_defeated.connect(_on_enemy_defeated)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	_on_mission_selected(0, load(GameState.MISSION_PATHS[0]))

func _process(delta: float) -> void:
	if not GameState.is_playing() or _ended or current_mission == null:
		return
	_context["elapsed"] = GameState.elapsed
	if current_mission.time_limit > 0.0 and GameState.elapsed >= current_mission.time_limit:
		_end(false, "THE COMMISSION WINDOW CLOSED")
		return
	if float(_context.get("anchor", 0.0)) >= current_mission.fail_corruption:
		_end(false, "THE THIN PLACE WAS RECLAIMED")
		return

	_objective_tick -= delta
	if _objective_tick <= 0.0:
		_objective_tick = 0.2
		_emit_objectives()
	if _all_objectives_complete():
		_hold += delta
		if _hold >= REQUIRED_HOLD_SECONDS:
			_end(true, "COMMISSION FULFILLED")
	else:
		_hold = 0.0

func _on_mission_selected(_index: int, mission: Resource) -> void:
	current_mission = mission as MissionResource
	_build_objectives()

func _build_objectives() -> void:
	objectives.clear()
	if current_mission == null:
		return
	for objective_id: String in current_mission.objective_ids:
		match StringName(objective_id):
			&"PURIFY_ZONE": objectives.append(PurifyZoneObjective.new(current_mission.target_purity))
			&"RESTORE_THIN_PLACE": objectives.append(RestoreThinPlaceObjective.new(current_mission.restore_integrity))
			&"BIND_TARGET": objectives.append(BindTargetObjective.new())
			&"SURVIVE_WAVES": objectives.append(SurviveWavesObjective.new(current_mission.survive_seconds))
			&"ESCORT_HOST": objectives.append(EscortHostObjective.new())
			&"BREAK_IDOL": objectives.append(BreakIdolObjective.new())
	_emit_objectives()

func _all_objectives_complete() -> bool:
	if objectives.is_empty():
		return false
	for objective: MissionObjective in objectives:
		if not objective.is_complete(_context):
			return false
	if current_mission != null and current_mission.boss_kind != &"" and not bool(_context.get("boss_defeated", false)):
		return false
	return true

func _emit_objectives() -> void:
	var labels := PackedStringArray()
	var states := PackedByteArray()
	for objective: MissionObjective in objectives:
		labels.append(objective.label)
		states.append(1 if objective.is_complete(_context) else 0)
	if current_mission != null and current_mission.boss_kind != &"":
		labels.append("OVERTHROW %s" % current_mission.boss_name)
		states.append(1 if bool(_context.get("boss_defeated", false)) else 0)
	EventBus.objective_state_changed.emit(labels, states)

func _end(success: bool, reason: String) -> void:
	if _ended:
		return
	_ended = true
	EventBus.mission_outcome_requested.emit(success, reason)
	EventBus.audio_requested.emit(&"victory" if success else &"failure")

func _on_field_changed(_values: PackedFloat32Array, _width: int, _height: int, purity: float, anchor: float) -> void:
	current_purity = purity
	_context["purity"] = purity
	_context["anchor"] = anchor
	if current_mission != null:
		EventBus.mission_progress_changed.emit(purity, current_mission.target_purity)

func _on_thin_place_changed(integrity: float, state: StringName) -> void:
	_context["thin_integrity"] = integrity
	_context["thin_state"] = state

func _on_target_bound(kind: StringName) -> void:
	if kind == &"FALLEN":
		_context["bound_target"] = true

func _on_enemy_defeated(kind: StringName, _position: Vector3) -> void:
	if kind == &"SYNTHETIC":
		_context["synthetics_defeated"] = int(_context.get("synthetics_defeated", 0)) + 1

func _on_boss_defeated(_kind: StringName) -> void:
	_context["boss_defeated"] = true
	_emit_objectives()

func _on_game_started() -> void:
	_ended = false
	_hold = 0.0
	_context = {
		"purity": 0.0,
		"anchor": 0.0,
		"thin_integrity": 0.0,
		"thin_state": &"SEVERED",
		"bound_target": false,
		"host_arrived": false,
		"synthetics_defeated": 0,
		"boss_defeated": false,
		"elapsed": 0.0
	}
	_emit_objectives()

func _reset_for_test() -> void:
	_hold = 0.0
	_ended = false
	_context.clear()
	current_purity = 0.0
	_on_mission_selected(0, load(GameState.MISSION_PATHS[0]))
