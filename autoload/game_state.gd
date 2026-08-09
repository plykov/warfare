extends Node

enum Phase { TITLE, PLAYING, COMPLETE, FAILED }

const SAVE_PATH: String = "user://garden_reclaimed.save"
const SAVE_VERSION: int = 3
const MISSION_PATHS: PackedStringArray = [
	"res://missions/data/mission_01.tres",
	"res://missions/data/mission_02.tres",
	"res://missions/data/mission_03.tres",
	"res://missions/data/mission_04.tres",
	"res://missions/data/mission_05.tres",
	"res://missions/data/mission_06.tres",
	"res://missions/data/mission_07.tres",
	"res://missions/data/mission_08.tres"
]

var phase: Phase = Phase.TITLE
var elapsed: float = 0.0
var selected_mission: int = 0
var unlocked_count: int = 1
var completed: Dictionary = {}
var mission_records: Dictionary = {}
var garden_states: Dictionary = {}
var campaign_pride: float = 0.0
var persistence_enabled: bool = true
var paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.mission_outcome_requested.connect(_on_mission_outcome_requested)
	EventBus.pause_requested.connect(set_paused)
	EventBus.corruption_snapshot_ready.connect(_on_corruption_snapshot_ready)
	EventBus.laws_snapshot_ready.connect(_on_laws_snapshot_ready)
	EventBus.pride_changed.connect(_on_pride_changed)
	_load_progress()
	call_deferred("_emit_campaign")

func _process(delta: float) -> void:
	if phase == Phase.PLAYING and not paused:
		elapsed += delta

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and phase == Phase.PLAYING:
		EventBus.pause_requested.emit(not paused)
		get_viewport().set_input_as_handled()

func start_game() -> void:
	if phase != Phase.TITLE:
		return
	var mission: MissionResource = current_mission()
	if mission == null:
		push_error("Unable to load selected mission")
		return
	phase = Phase.PLAYING
	set_paused(false)
	elapsed = 0.0
	EventBus.restoration_state_changed.emit(completed.size())
	EventBus.mission_selected.emit(selected_mission, mission)
	EventBus.campaign_garden_state_loaded.emit(selected_mission, garden_states.get(str(selected_mission), {}).duplicate(true))
	EventBus.campaign_legacy_garden_loaded.emit(selected_mission, build_legacy_garden_state(selected_mission, garden_states))
	EventBus.campaign_pride_loaded.emit(campaign_pride)
	EventBus.game_started.emit()
	EventBus.game_phase_changed.emit(&"PLAYING")

func return_to_title() -> void:
	set_paused(false)
	phase = Phase.TITLE
	elapsed = 0.0
	_emit_campaign()
	EventBus.game_phase_changed.emit(&"TITLE")

func complete() -> void:
	if phase != Phase.PLAYING:
		return
	phase = Phase.COMPLETE
	EventBus.game_phase_changed.emit(&"COMPLETE")
	EventBus.mission_completed.emit()

func fail(reason: String = "THE GROUND WAS RECLAIMED") -> void:
	if phase != Phase.PLAYING:
		return
	phase = Phase.FAILED
	EventBus.game_phase_changed.emit(&"FAILED")
	EventBus.mission_failed.emit(reason)

func is_playing() -> bool:
	return phase == Phase.PLAYING

func set_paused(value: bool) -> void:
	var next: bool = value and phase == Phase.PLAYING
	if paused == next:
		return
	paused = next
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else (Input.MOUSE_MODE_CAPTURED if phase == Phase.PLAYING else Input.MOUSE_MODE_VISIBLE)
	EventBus.pause_changed.emit(paused)

func current_mission() -> MissionResource:
	if selected_mission < 0 or selected_mission >= MISSION_PATHS.size():
		return null
	return load(MISSION_PATHS[selected_mission]) as MissionResource

static func build_legacy_garden_state(mission_index: int, gardens: Dictionary) -> Dictionary:
	var cell_count: int = CorruptionDirector.GRID_WIDTH * CorruptionDirector.GRID_HEIGHT
	var composite: Array[float] = []
	composite.resize(cell_count)
	composite.fill(1.0)
	var source_count: int = 0
	var purity_total: float = 0.0
	var mission_indices: Array[int] = []
	for raw_key: Variant in gardens.keys():
		var source_index: int = int(str(raw_key))
		if source_index >= mission_index:
			continue
		var raw_state: Variant = gardens.get(str(raw_key), gardens.get(raw_key, {}))
		if not raw_state is Dictionary:
			continue
		var state := raw_state as Dictionary
		var raw_cells: Variant = state.get("cells", [])
		if not raw_cells is Array or (raw_cells as Array).size() != cell_count:
			continue
		var cells := raw_cells as Array
		for cell_index: int in range(cell_count):
			composite[cell_index] = minf(composite[cell_index], clampf(float(cells[cell_index]), 0.0, 1.0))
		source_count += 1
		purity_total += clampf(float(state.get("purity", 0.0)), 0.0, 1.0)
		mission_indices.append(source_index)
	mission_indices.sort()
	return {
		"cells": composite if source_count > 0 else [],
		"source_count": source_count,
		"mean_purity": purity_total / float(source_count) if source_count > 0 else 0.0,
		"mission_indices": mission_indices
	}

func select_mission(index: int) -> bool:
	if phase != Phase.TITLE or index < 0 or index >= unlocked_count or index >= MISSION_PATHS.size():
		return false
	selected_mission = index
	_emit_campaign()
	return true

func select_relative(delta: int) -> void:
	if phase != Phase.TITLE:
		return
	selected_mission = posmod(selected_mission + delta, unlocked_count)
	_emit_campaign()

func completed_count() -> int:
	return completed.size()

func _on_mission_outcome_requested(success: bool, reason: String) -> void:
	if success:
		_capture_garden_state()
	_record_attempt(success)
	if success:
		complete()
		completed[str(selected_mission)] = true
		unlocked_count = maxi(unlocked_count, mini(MISSION_PATHS.size(), selected_mission + 2))
		_emit_campaign()
	else:
		fail(reason)
	_save_progress()
	EventBus.campaign_records_changed.emit(mission_records.duplicate(true))

func _emit_campaign() -> void:
	EventBus.campaign_changed.emit(selected_mission, unlocked_count, completed.duplicate())
	EventBus.campaign_records_changed.emit(mission_records.duplicate(true))

func _record_attempt(success: bool) -> void:
	var key := str(selected_mission)
	var record: Dictionary = mission_records.get(key, {
		"attempts": 0,
		"clears": 0,
		"best_time": 0.0,
		"best_purity": 0.0
	}).duplicate()
	record.attempts = int(record.get("attempts", 0)) + 1
	if success:
		record.clears = int(record.get("clears", 0)) + 1
		var best_time: float = float(record.get("best_time", 0.0))
		if best_time <= 0.0 or elapsed < best_time:
			record.best_time = elapsed
		record.best_purity = maxf(float(record.get("best_purity", 0.0)), MissionDirector.current_purity)
	mission_records[key] = record

func _capture_garden_state() -> void:
	var key := str(selected_mission)
	if not garden_states.has(key):
		garden_states[key] = {}
	EventBus.campaign_snapshot_requested.emit(selected_mission)

func _on_corruption_snapshot_ready(mission_index: int, snapshot_cells: PackedFloat32Array, purity: float) -> void:
	var key := str(mission_index)
	var state: Dictionary = garden_states.get(key, {}).duplicate(true)
	state["cells"] = Array(snapshot_cells)
	state["purity"] = clampf(purity, 0.0, 1.0)
	garden_states[key] = state

func _on_laws_snapshot_ready(mission_index: int, laws: Dictionary) -> void:
	var key := str(mission_index)
	var state: Dictionary = garden_states.get(key, {}).duplicate(true)
	state["laws"] = laws.duplicate(true)
	garden_states[key] = state

func _on_pride_changed(value: float, _maximum: float) -> void:
	campaign_pride = clampf(value, 0.0, 100.0)

func _save_progress() -> void:
	if not persistence_enabled:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save campaign progress")
		return
	file.store_string(JSON.stringify({
		"save_version": SAVE_VERSION,
		"selected_mission": selected_mission,
		"unlocked_count": unlocked_count,
		"completed": completed.keys(),
		"mission_records": mission_records,
		"garden_states": garden_states,
		"campaign_pride": campaign_pride
	}))

func _load_progress() -> void:
	if not persistence_enabled or not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	_apply_progress_data(parsed as Dictionary)

func _apply_progress_data(data: Dictionary) -> void:
	unlocked_count = clampi(int(data.get("unlocked_count", 1)), 1, MISSION_PATHS.size())
	selected_mission = clampi(int(data.get("selected_mission", unlocked_count - 1)), 0, unlocked_count - 1)
	completed.clear()
	for value: Variant in data.get("completed", []):
		completed[str(value)] = true
	mission_records.clear()
	var stored_records: Variant = data.get("mission_records", {})
	if stored_records is Dictionary:
		for key: Variant in (stored_records as Dictionary).keys():
			var stored: Variant = (stored_records as Dictionary)[key]
			if stored is Dictionary:
				mission_records[str(key)] = (stored as Dictionary).duplicate(true)
	garden_states.clear()
	var stored_gardens: Variant = data.get("garden_states", {})
	if stored_gardens is Dictionary:
		for key: Variant in (stored_gardens as Dictionary).keys():
			var stored_state: Variant = (stored_gardens as Dictionary)[key]
			if stored_state is Dictionary:
				garden_states[str(key)] = (stored_state as Dictionary).duplicate(true)
	campaign_pride = clampf(float(data.get("campaign_pride", 0.0)), 0.0, 100.0)
	# Version 1 saves only had a completion list. Seed useful records without
	# invalidating anyone's existing campaign.
	if int(data.get("save_version", 1)) < SAVE_VERSION:
		for key: Variant in completed.keys():
			if not mission_records.has(str(key)):
				mission_records[str(key)] = {"attempts": 1, "clears": 1, "best_time": 0.0, "best_purity": 0.0}

func _reset_for_test() -> void:
	persistence_enabled = false
	phase = Phase.TITLE
	elapsed = 0.0
	selected_mission = 0
	unlocked_count = 1
	completed.clear()
	mission_records.clear()
	garden_states.clear()
	campaign_pride = 0.0
	paused = false
	get_tree().paused = false
	_emit_campaign()
