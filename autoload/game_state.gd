extends Node

enum Phase { TITLE, PLAYING, COMPLETE, FAILED }

const SAVE_PATH: String = "user://garden_reclaimed.save"
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
var persistence_enabled: bool = true

func _ready() -> void:
	EventBus.mission_outcome_requested.connect(_on_mission_outcome_requested)
	_load_progress()
	call_deferred("_emit_campaign")

func _process(delta: float) -> void:
	if phase == Phase.PLAYING:
		elapsed += delta

func start_game() -> void:
	if phase != Phase.TITLE:
		return
	var mission: MissionResource = current_mission()
	if mission == null:
		push_error("Unable to load selected mission")
		return
	phase = Phase.PLAYING
	elapsed = 0.0
	EventBus.restoration_state_changed.emit(completed.size())
	EventBus.mission_selected.emit(selected_mission, mission)
	EventBus.game_started.emit()
	EventBus.game_phase_changed.emit(&"PLAYING")

func return_to_title() -> void:
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

func current_mission() -> MissionResource:
	if selected_mission < 0 or selected_mission >= MISSION_PATHS.size():
		return null
	return load(MISSION_PATHS[selected_mission]) as MissionResource

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
		complete()
		completed[str(selected_mission)] = true
		unlocked_count = maxi(unlocked_count, mini(MISSION_PATHS.size(), selected_mission + 2))
		_save_progress()
		_emit_campaign()
	else:
		fail(reason)

func _emit_campaign() -> void:
	EventBus.campaign_changed.emit(selected_mission, unlocked_count, completed.duplicate())

func _save_progress() -> void:
	if not persistence_enabled:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save campaign progress")
		return
	file.store_string(JSON.stringify({
		"selected_mission": selected_mission,
		"unlocked_count": unlocked_count,
		"completed": completed.keys()
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
	var data := parsed as Dictionary
	unlocked_count = clampi(int(data.get("unlocked_count", 1)), 1, MISSION_PATHS.size())
	selected_mission = clampi(int(data.get("selected_mission", unlocked_count - 1)), 0, unlocked_count - 1)
	completed.clear()
	for value: Variant in data.get("completed", []):
		completed[str(value)] = true

func _reset_for_test() -> void:
	persistence_enabled = false
	phase = Phase.TITLE
	elapsed = 0.0
	selected_mission = 0
	unlocked_count = 1
	completed.clear()
	_emit_campaign()
